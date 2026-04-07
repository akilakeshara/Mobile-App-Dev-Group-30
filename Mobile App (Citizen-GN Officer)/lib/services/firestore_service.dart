import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/complaint.dart';
import '../models/application.dart';
import '../models/gn_appointment.dart';
import '../models/user_model.dart';
import '../models/officer_alert.dart';
import '../utils/input_validators.dart';
import 'offline_sync_queue_service.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _offlineSyncInitialized = false;

  FirestoreService() {
    _initializeOfflineSync();
  }

  // Use anonymous user id if not signed in for testing
  String get currentUserId => _auth.currentUser?.uid ?? 'anonymous_user';
  ValueListenable<int> get pendingSyncCount =>
      OfflineSyncQueueService.instance.pendingCount;
  ValueListenable<bool> get isSyncInProgress =>
      OfflineSyncQueueService.instance.syncing;

  Future<void> flushOfflineQueue() {
    return OfflineSyncQueueService.instance.flushPendingWrites();
  }

  Future<int> getLocalEncryptionKeyVersion() {
    return OfflineSyncQueueService.instance.getActiveEncryptionKeyVersion();
  }

  Future<int> rotateLocalEncryptionKeyAndReencryptQueue() {
    return OfflineSyncQueueService.instance
        .rotateEncryptionKeyAndReencryptQueue();
  }

  void _initializeOfflineSync() {
    if (_offlineSyncInitialized) return;
    _offlineSyncInitialized = true;

    OfflineSyncQueueService.instance.initialize(_db).catchError((error) {
      debugPrint('Offline sync initialization failed: $error');
    });
  }

  bool _shouldQueueOnError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'network-request-failed' ||
          error.code == 'deadline-exceeded';
    }
    return false;
  }

  Future<void> _setWithOfflineFallback({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    try {
      await _db
          .collection(collection)
          .doc(documentId)
          .set(data, SetOptions(merge: merge));
      await OfflineSyncQueueService.instance.flushPendingWrites();
    } catch (e) {
      if (_shouldQueueOnError(e)) {
        await OfflineSyncQueueService.instance.enqueueSet(
          collectionName: collection,
          documentId: documentId,
          payload: data,
          merge: merge,
        );
        debugPrint(
          'Queued offline set for $collection/$documentId due to network issue.',
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> _updateWithOfflineFallback({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _db.collection(collection).doc(documentId).update(data);
      await OfflineSyncQueueService.instance.flushPendingWrites();
    } catch (e) {
      if (_shouldQueueOnError(e)) {
        await OfflineSyncQueueService.instance.enqueueUpdate(
          collectionName: collection,
          documentId: documentId,
          payload: data,
        );
        debugPrint(
          'Queued offline update for $collection/$documentId due to network issue.',
        );
        return;
      }
      rethrow;
    }
  }

  // --------- USERS ---------

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
    return null;
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<void> createUser(UserModel user) async {
    final data = user.toMap();
    data['nicNormalized'] = InputValidators.normalizeNic(user.nic);
    data['phoneNormalized'] = InputValidators.normalizePhoneToLocal(user.phone);
    await _setWithOfflineFallback(
      collection: 'users',
      documentId: user.id,
      data: data,
    );
  }

  Future<void> updateUser(UserModel user) async {
    final data = user.toMap();
    data['nicNormalized'] = InputValidators.normalizeNic(user.nic);
    data['phoneNormalized'] = InputValidators.normalizePhoneToLocal(user.phone);
    await _updateWithOfflineFallback(
      collection: 'users',
      documentId: user.id,
      data: data,
    );
  }

  Future<void> updateUserPreferredLanguage(
    String uid,
    String languageCode,
  ) async {
    await _setWithOfflineFallback(
      collection: 'users',
      documentId: uid,
      data: {'preferredLanguage': languageCode},
      merge: true,
    );
  }

  Future<void> updateUserProfilePhoto(
    String uid,
    String profileImageUrl,
  ) async {
    await _setWithOfflineFallback(
      collection: 'users',
      documentId: uid,
      data: {'profileImageUrl': profileImageUrl},
      merge: true,
    );
  }

  Future<UserModel?> getCitizenByNic(String nic) async {
    final normalizedNic = InputValidators.normalizeNic(nic);
    if (normalizedNic.isEmpty) return null;

    try {
      final normalizedQuery = await _db
          .collection('users')
          .where('nicNormalized', isEqualTo: normalizedNic)
          .limit(1)
          .get();

      if (normalizedQuery.docs.isNotEmpty) {
        final doc = normalizedQuery.docs.first;
        final data = doc.data();
        if ((data['role'] ?? 'citizen') == 'citizen') {
          return UserModel.fromMap(data, doc.id);
        }
      }

      final legacyCandidates = <String>{
        normalizedNic,
        normalizedNic.toLowerCase(),
      }.toList();

      final legacyQuery = await _db
          .collection('users')
          .where('nic', whereIn: legacyCandidates)
          .limit(5)
          .get();

      for (final doc in legacyQuery.docs) {
        final data = doc.data();
        if ((data['role'] ?? 'citizen') != 'citizen') {
          continue;
        }

        final model = UserModel.fromMap(data, doc.id);
        await _db.collection('users').doc(doc.id).set({
          'nicNormalized': normalizedNic,
        }, SetOptions(merge: true));
        return model;
      }

      return null;
    } catch (e) {
      debugPrint('Error finding citizen by NIC: $e');
      return null;
    }
  }

  Future<UserModel?> getCitizenByPhone(String phone) async {
    final normalizedPhone = InputValidators.normalizePhoneToLocal(phone);
    final e164Phone = InputValidators.toE164SriLankanPhone(phone);
    if (normalizedPhone.isEmpty && e164Phone.isEmpty) return null;

    try {
      final normalizedQuery = await _db
          .collection('users')
          .where('phoneNormalized', isEqualTo: normalizedPhone)
          .limit(1)
          .get();

      if (normalizedQuery.docs.isNotEmpty) {
        final doc = normalizedQuery.docs.first;
        final data = doc.data();
        if ((data['role'] ?? 'citizen') == 'citizen') {
          return UserModel.fromMap(data, doc.id);
        }
      }

      final legacyCandidates = <String>{
        normalizedPhone,
        e164Phone,
      }.where((value) => value.isNotEmpty).toList();
      if (legacyCandidates.isEmpty) return null;

      final legacyQuery = await _db
          .collection('users')
          .where('phone', whereIn: legacyCandidates)
          .limit(5)
          .get();

      for (final doc in legacyQuery.docs) {
        final data = doc.data();
        if ((data['role'] ?? 'citizen') != 'citizen') {
          continue;
        }

        final model = UserModel.fromMap(data, doc.id);
        await _db.collection('users').doc(doc.id).set({
          'phoneNormalized': normalizedPhone,
        }, SetOptions(merge: true));
        return model;
      }

      return null;
    } catch (e) {
      debugPrint('Error finding citizen by phone: $e');
      return null;
    }
  }

  Future<UserModel?> getOfficerByOfficerId(String officerId) async {
    final normalizedOfficerId = InputValidators.normalizeOfficerId(officerId);
    if (normalizedOfficerId.isEmpty) {
      return null;
    }

    try {
      final normalizedQuery = await _db
          .collection('users')
          .where('officerIdNormalized', isEqualTo: normalizedOfficerId)
          .limit(1)
          .get();

      if (normalizedQuery.docs.isNotEmpty) {
        final doc = normalizedQuery.docs.first;
        final data = doc.data();
        final role = (data['role'] ?? '').toString().toLowerCase();
        if (role == 'officer' || role == 'admin') {
          return UserModel.fromMap(data, doc.id);
        }
      }

      final legacyCandidates = <String>{
        normalizedOfficerId,
        normalizedOfficerId.toLowerCase(),
      }.toList();

      final legacyQuery = await _db
          .collection('users')
          .where('officerId', whereIn: legacyCandidates)
          .limit(5)
          .get();

      for (final doc in legacyQuery.docs) {
        final data = doc.data();
        final role = (data['role'] ?? '').toString().toLowerCase();
        if (role != 'officer' && role != 'admin') {
          continue;
        }

        await _db.collection('users').doc(doc.id).set({
          'officerIdNormalized': normalizedOfficerId,
        }, SetOptions(merge: true));
        return UserModel.fromMap(data, doc.id);
      }
    } catch (e) {
      debugPrint('Error finding officer by officer ID: $e');
    }

    return null;
  }

  Future<bool> validateOfficerPassword({
    required String officerUid,
    required String rawPassword,
  }) async {
    final password = rawPassword.trim();
    if (password.isEmpty) {
      return false;
    }

    try {
      final doc = await _db.collection('users').doc(officerUid).get();
      final data = doc.data();
      if (data == null) {
        return false;
      }

      final role = (data['role'] ?? '').toString().toLowerCase();
      if (role != 'officer' && role != 'admin') {
        return false;
      }

      final candidates =
          <String>[
                (data['officerPassword'] ?? '').toString(),
                (data['password'] ?? '').toString(),
              ]
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();

      if (candidates.isEmpty) {
        return false;
      }

      return candidates.any((stored) => stored == password);
    } catch (e) {
      debugPrint('Error validating officer password: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getWasteCollectionScheduleForUser(
    String uid,
  ) async {
    try {
      final user = await getUser(uid);
      if (user == null) {
        return null;
      }

      final configDoc = await _db
          .collection('config')
          .doc('waste_collection_schedule')
          .get();

      if (!configDoc.exists) {
        return null;
      }

      final configData = configDoc.data();
      if (configData == null) {
        return null;
      }

      final rawHierarchy =
          configData['provinces'] ?? configData['hierarchy'] ?? configData;
      if (rawHierarchy is! Map) {
        return null;
      }

      final provinceNode = _findScheduleNode(
        rawHierarchy,
        _buildLookupCandidates(user.province),
      );
      if (provinceNode is! Map) {
        return null;
      }

      final districtNode = _findScheduleNode(
        provinceNode,
        _buildLookupCandidates(user.district),
      );
      if (districtNode is! Map) {
        return null;
      }

      final areaNode = _findScheduleNode(
        districtNode,
        _buildLookupCandidates(
          user.pradeshiyaSabha,
          fallback: [user.gramasewaWasama, user.division],
        ),
      );

      if (areaNode == null) {
        return {
          'areaLabel': [
            user.pradeshiyaSabha,
            user.gramasewaWasama,
            user.district,
            user.province,
          ].where((value) => value.isNotEmpty).join(', '),
          'province': user.province,
          'district': user.district,
          'pradeshiyaSabha': user.pradeshiyaSabha,
          'announcement': null,
          'nextCollection': null,
          'route': null,
          'notes': null,
          'updatedAt':
              configData['updatedAt'] ??
              configData['lastUpdatedAt']?.toString(),
          'entries': const <Map<String, dynamic>>[],
        };
      }

      return _normalizeWasteCollectionSchedule(
        areaNode,
        user: user,
        updatedAt: configData['updatedAt'] ?? configData['lastUpdatedAt'],
      );
    } catch (e) {
      debugPrint('Error loading waste collection schedule: $e');
      return null;
    }
  }

  Map<String, dynamic>? _normalizeWasteCollectionSchedule(
    dynamic areaNode, {
    required UserModel user,
    dynamic updatedAt,
  }) {
    if (areaNode == null) {
      return null;
    }

    final entries = <Map<String, String>>[];
    String? announcement;
    String? nextCollection;
    String? route;
    String? notes;

    void addEntry(dynamic day, dynamic value) {
      final entry = <String, String>{'day': (day ?? '').toString().trim()};

      if (value is Map) {
        entry['time'] = (value['time'] ?? value['pickupTime'] ?? '')
            .toString()
            .trim();
        entry['notes'] = (value['notes'] ?? value['note'] ?? '')
            .toString()
            .trim();
        entry['route'] = (value['route'] ?? value['area'] ?? '')
            .toString()
            .trim();
      } else {
        entry['time'] = value.toString().trim();
      }

      if (entry.values.any((value) => value.isNotEmpty)) {
        entries.add(entry);
      }
    }

    if (areaNode is Map) {
      announcement = (areaNode['announcement'] ?? areaNode['message'] ?? '')
          .toString()
          .trim();
      nextCollection =
          (areaNode['nextCollection'] ?? areaNode['nextPickup'] ?? '')
              .toString()
              .trim();
      route = (areaNode['route'] ?? areaNode['tractorRoute'] ?? '')
          .toString()
          .trim();
      notes =
          (areaNode['notes'] ??
                  areaNode['note'] ??
                  areaNode['description'] ??
                  '')
              .toString()
              .trim();

      final weeklySchedule = areaNode['weeklySchedule'];
      if (weeklySchedule is List) {
        for (final item in weeklySchedule) {
          if (item is Map) {
            addEntry(item['day'] ?? item['date'] ?? item['label'], item);
          }
        }
      }

      final days = areaNode['days'];
      if (days is Map) {
        for (final entry in days.entries) {
          addEntry(entry.key, entry.value);
        }
      }

      final schedule = areaNode['schedule'];
      if (schedule is List) {
        for (final item in schedule) {
          if (item is Map) {
            addEntry(item['day'] ?? item['date'] ?? item['label'], item);
          }
        }
      } else if (schedule is Map) {
        for (final entry in schedule.entries) {
          addEntry(entry.key, entry.value);
        }
      }

      if (entries.isEmpty && nextCollection.isNotEmpty) {
        entries.add({
          'day': 'Next collection',
          'time': nextCollection,
          'notes': notes,
          'route': route,
        });
      }
    } else if (areaNode is List) {
      for (final item in areaNode) {
        if (item is Map) {
          addEntry(item['day'] ?? item['date'] ?? item['label'], item);
        } else {
          addEntry('Schedule', item);
        }
      }
    } else {
      final text = areaNode.toString().trim();
      if (text.isNotEmpty) {
        entries.add({'day': 'Schedule', 'time': text});
      }
    }

    return {
      'areaLabel': [
        user.pradeshiyaSabha,
        user.district,
        user.province,
      ].where((value) => value.isNotEmpty).join(', '),
      'province': user.province,
      'district': user.district,
      'pradeshiyaSabha': user.pradeshiyaSabha,
      'announcement': announcement,
      'nextCollection': nextCollection,
      'route': route,
      'notes': notes,
      'updatedAt': updatedAt?.toString(),
      'entries': entries,
    };
  }

  dynamic _findScheduleNode(dynamic root, List<String> candidates) {
    if (root is! Map || candidates.isEmpty) {
      return null;
    }

    for (final entry in root.entries) {
      if (_matchesScheduleKey(entry.key, candidates)) {
        return entry.value;
      }
    }

    for (final entry in root.entries) {
      final value = entry.value;
      if (value is Map) {
        final nested = _findScheduleNode(value, candidates);
        if (nested != null) {
          return nested;
        }
      }
    }

    return null;
  }

  List<String> _buildLookupCandidates(
    String value, {
    List<String> fallback = const [],
  }) {
    final candidates = <String>[];

    void addCandidate(String input) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) {
        return;
      }

      final normalized = trimmed.toLowerCase();
      candidates.add(trimmed);
      candidates.add(normalized);
      candidates.add(normalized.replaceAll(RegExp(r'\s+ps$'), ''));
      candidates.add(normalized.replaceAll(' pradeshiya sabha', ''));
      candidates.add(normalized.replaceAll(RegExp(r'[^a-z0-9]'), ''));
      candidates.add(normalized.replaceAll(RegExp(r'\s+'), ''));
    }

    addCandidate(value);
    for (final item in fallback) {
      addCandidate(item);
    }

    return candidates.toSet().toList();
  }

  bool _matchesScheduleKey(dynamic key, List<String> candidates) {
    final keyValue = key?.toString().trim() ?? '';
    if (keyValue.isEmpty) {
      return false;
    }

    final normalizedKey = _normalizeScheduleText(keyValue);
    return candidates.any((candidate) {
      final normalizedCandidate = _normalizeScheduleText(candidate);
      return normalizedKey == normalizedCandidate;
    });
  }

  String _normalizeScheduleText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\bpradeshiya\s+sabha\b'), '')
        .replaceAll(RegExp(r'\bps\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // --------- APP CONFIG ---------

  Stream<List<String>> getComplaintCategories() {
    return _db.collection('config').doc('complaints').snapshots().map((doc) {
      final data = doc.data();
      final raw = data?['categories'];
      if (raw is List) {
        return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return <String>[
        'Infrastructure',
        'Electricity',
        'Water Supply',
        'Waste Management',
        'Public Health',
        'Other',
      ];
    });
  }

  Future<Map<String, Map<String, Map<String, List<String>>>>>
  getAdministrativeHierarchyConfig() async {
    try {
      final doc = await _db
          .collection('config')
          .doc('administrative_hierarchy')
          .get();

      if (!doc.exists) {
        return {};
      }

      final data = doc.data();
      if (data == null) {
        return {};
      }

      final rawHierarchy = data['provinces'] ?? data['hierarchy'] ?? data;
      return _parseAdministrativeHierarchy(rawHierarchy);
    } catch (e) {
      debugPrint('Error loading administrative hierarchy config: $e');
      return {};
    }
  }

  Map<String, Map<String, Map<String, List<String>>>>
  _parseAdministrativeHierarchy(dynamic raw) {
    final result = <String, Map<String, Map<String, List<String>>>>{};
    if (raw is! Map) {
      return result;
    }

    raw.forEach((provinceKey, districtsRaw) {
      if (provinceKey == null || districtsRaw is! Map) {
        return;
      }

      final districts = <String, Map<String, List<String>>>{};
      districtsRaw.forEach((districtKey, sabhasRaw) {
        if (districtKey == null) {
          return;
        }

        final sabhas = <String, List<String>>{};
        if (sabhasRaw is Map) {
          sabhasRaw.forEach((sabhaKey, wasamasRaw) {
            if (sabhaKey == null) {
              return;
            }

            final wasamas = wasamasRaw is List
                ? wasamasRaw
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty)
                      .toList()
                : <String>[];
            sabhas[sabhaKey.toString()] = wasamas;
          });
        }

        districts[districtKey.toString()] = sabhas;
      });

      if (districts.isNotEmpty) {
        result[provinceKey.toString()] = districts;
      }
    });

    return result;
  }

  Stream<List<Map<String, dynamic>>> getServiceCatalog() {
    return _db
        .collection('service_catalog')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return <Map<String, dynamic>>[
              {'name': 'Birth Certificate Copy', 'fee': 250.0},
              {'name': 'Death Certificate Copy', 'fee': 250.0},
              {'name': 'Marriage Certificate Copy', 'fee': 250.0},
              {'name': 'NIC Renewal', 'fee': 250.0},
              {'name': 'Passport Application', 'fee': 250.0},
              {'name': 'Driving License Renewal', 'fee': 250.0},
            ];
          }

          return snapshot.docs.map((doc) {
            final data = doc.data();
            final fee = data['fee'];
            final parsedFee = fee is num ? fee.toDouble() : 250.0;
            return <String, dynamic>{
              'id': doc.id,
              'name': (data['name'] ?? 'Service').toString(),
              'fee': parsedFee,
            };
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> getUserNotifications({int limit = 20}) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              'id': doc.id,
              'title': (data['title'] ?? 'Notification').toString(),
              'body': (data['body'] ?? '').toString(),
              'isRead': data['isRead'] == true,
              'createdAt': (data['createdAt'] ?? '').toString(),
            };
          }).toList();
        });
  }

  Future<void> markNotificationAsRead(String id) async {
    await _updateWithOfflineFallback(
      collection: 'notifications',
      documentId: id,
      data: {'isRead': true},
    );
  }

  Future<void> _createNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    final notificationId = 'NTF-${DateTime.now().millisecondsSinceEpoch}';
    await _setWithOfflineFallback(
      collection: 'notifications',
      documentId: notificationId,
      data: {
        'userId': userId,
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // --------- APPLICATIONS ---------

  Stream<List<Application>> getUserApplications() {
    return _db
        .collection('applications')
        .where('userId', isEqualTo: currentUserId)
        // Not using orderBy directly in query to avoid requiring composite indexes for beta testing
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Application.fromMap(doc.data(), doc.id))
              .toList();
          // Sort locally by createdAt descending
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> addApplication(Application app) async {
    await _setWithOfflineFallback(
      collection: 'applications',
      documentId: app.id,
      data: app.toMap(),
    );
  }

  // --------- COMPLAINTS ---------

  Stream<List<Complaint>> getUserComplaints() {
    return _db
        .collection('complaints')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Complaint.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> addComplaint(Complaint complaint) async {
    await _setWithOfflineFallback(
      collection: 'complaints',
      documentId: complaint.id,
      data: complaint.toMap(),
    );
  }

  // --------- GN APPOINTMENTS ---------

  Stream<List<GnAppointment>> getUserGnAppointments() {
    return _db
        .collection('gn_appointments')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => GnAppointment.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<GnAppointment>> getOfficerGnAppointments() {
    return _db.collection('gn_appointments').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => GnAppointment.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<GnAppointment>> getOfficerScopedGnAppointments(
    UserModel officer,
  ) {
    return getOfficerGnAppointments().map((items) {
      if (officer.role.toLowerCase() == 'admin') {
        return items;
      }

      return items
          .where((appointment) => _matchesOfficerArea(officer, appointment))
          .toList();
    });
  }

  bool _matchesOfficerArea(UserModel officer, GnAppointment appointment) {
    final officerAreas = [
      officer.province,
      officer.district,
      officer.pradeshiyaSabha,
      officer.gramasewaWasama,
      officer.division,
    ].where((value) => value.trim().isNotEmpty).toList();

    if (officerAreas.isEmpty) {
      return false;
    }

    final appointmentAreas = [
      appointment.province,
      appointment.district,
      appointment.pradeshiyaSabha,
      appointment.gramasewaWasama,
    ].where((value) => value.trim().isNotEmpty).toList();

    for (final officerArea in officerAreas) {
      final normalizedOfficerArea = _normalizeAreaText(officerArea);
      if (normalizedOfficerArea.isEmpty) {
        continue;
      }

      for (final appointmentArea in appointmentAreas) {
        if (_normalizeAreaText(appointmentArea) == normalizedOfficerArea) {
          return true;
        }
      }
    }

    return false;
  }

  String _normalizeAreaText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\bpradeshiya\s+sabha\b'), '')
        .replaceAll(RegExp(r'\bps\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<String> addGnAppointment(GnAppointment appointment) async {
    await _setWithOfflineFallback(
      collection: 'gn_appointments',
      documentId: appointment.id,
      data: appointment.toMap(),
    );

    await _createNotification(
      userId: appointment.userId,
      title: 'GN appointment requested',
      body:
          'Your appointment ${appointment.referenceNumber} is pending review.',
    );

    return appointment.id;
  }

  Future<void> updateGnAppointmentStatus(
    String appointmentId,
    String status, {
    String? officerNotes,
    DateTime? scheduledDate,
    List<String>? expectedCurrentStatuses,
  }) async {
    final ref = _db.collection('gn_appointments').doc(appointmentId);
    String userId = '';
    String referenceNumber = appointmentId;

    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) {
        throw StateError('Appointment not found.');
      }

      final data = doc.data();
      final currentStatus = (data?['status'] ?? '').toString();

      if (expectedCurrentStatuses != null &&
          expectedCurrentStatuses.isNotEmpty) {
        final allowed = expectedCurrentStatuses
            .map((value) => value.toLowerCase())
            .toSet();
        if (!allowed.contains(currentStatus.toLowerCase())) {
          throw StateError(
            'This appointment was already updated by another user. Please refresh and try again.',
          );
        }
      }

      userId = data?['userId']?.toString() ?? '';
      referenceNumber = data?['referenceNumber']?.toString() ?? appointmentId;

      final nowIso = DateTime.now().toIso8601String();
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': nowIso,
        'responseAt': nowIso,
      };

      if (officerNotes != null && officerNotes.trim().isNotEmpty) {
        updates['officerNotes'] = officerNotes.trim();
      }

      if (scheduledDate != null) {
        updates['scheduledDate'] = scheduledDate.toIso8601String();
      }

      transaction.update(ref, updates);
    });

    if (userId.isNotEmpty) {
      await _createNotification(
        userId: userId,
        title: 'GN appointment updated',
        body: 'Your appointment $referenceNumber is now $status.',
      );
    }
  }

  Future<void> cancelGnAppointment(String appointmentId) async {
    final ref = _db.collection('gn_appointments').doc(appointmentId);
    String userId = '';
    String referenceNumber = appointmentId;

    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) {
        throw StateError('Appointment not found.');
      }

      final data = doc.data();
      final currentStatus = (data?['status'] ?? '').toString();
      const cancellableStatuses = {'requested', 'approved', 'rescheduled'};
      if (!cancellableStatuses.contains(currentStatus.toLowerCase())) {
        throw StateError('This appointment can no longer be cancelled.');
      }

      userId = data?['userId']?.toString() ?? '';
      referenceNumber = data?['referenceNumber']?.toString() ?? appointmentId;

      transaction.update(ref, {
        'status': 'Cancelled',
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });

    if (userId.isNotEmpty) {
      await _createNotification(
        userId: userId,
        title: 'GN appointment cancelled',
        body: 'Your appointment $referenceNumber has been cancelled.',
      );
    }
  }

  // --------- OFFICER METHODS ---------

  Stream<List<Application>> getAllApplications() {
    debugPrint("FirestoreService: getAllApplications() called");
    return _db
        .collection('applications')
        .snapshots()
        .handleError((e) {
          debugPrint("FirestoreService: Error getting applications: $e");
        })
        .map((snapshot) {
          debugPrint(
            "FirestoreService: Got ${snapshot.docs.length} applications from Firebase",
          );
          final list = snapshot.docs
              .map((doc) {
                try {
                  return Application.fromMap(doc.data(), doc.id);
                } catch (e) {
                  debugPrint(
                    "FirestoreService: Failed to parse Application doc ${doc.id}: $e",
                  );
                  return null;
                }
              })
              .where((app) => app != null)
              .cast<Application>()
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<Complaint>> getAllComplaints() {
    debugPrint("FirestoreService: getAllComplaints() called");
    return _db
        .collection('complaints')
        .snapshots()
        .handleError((e) {
          debugPrint("FirestoreService: Error getting complaints: $e");
        })
        .map((snapshot) {
          debugPrint(
            "FirestoreService: Got ${snapshot.docs.length} complaints from Firebase",
          );
          final list = snapshot.docs
              .map((doc) {
                try {
                  return Complaint.fromMap(doc.data(), doc.id);
                } catch (e) {
                  debugPrint(
                    "FirestoreService: Failed to parse Complaint doc ${doc.id}: $e",
                  );
                  return null;
                }
              })
              .where((c) => c != null)
              .cast<Complaint>()
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> updateApplicationStatus(
    String applicationId,
    String status,
  ) async {
    final doc = await _db.collection('applications').doc(applicationId).get();
    final userId = doc.data()?['userId']?.toString() ?? '';

    await _updateWithOfflineFallback(
      collection: 'applications',
      documentId: applicationId,
      data: {'status': status},
    );

    if (userId.isNotEmpty) {
      await _createNotification(
        userId: userId,
        title: 'Application status updated',
        body: 'Your application $applicationId is now $status.',
      );
    }
  }

  Future<void> updateComplaintStatus(String complaintId, String status) async {
    final doc = await _db.collection('complaints').doc(complaintId).get();
    final userId = doc.data()?['userId']?.toString() ?? '';

    await _updateWithOfflineFallback(
      collection: 'complaints',
      documentId: complaintId,
      data: {'status': status},
    );

    if (userId.isNotEmpty) {
      await _createNotification(
        userId: userId,
        title: 'Complaint status updated',
        body: 'Your complaint $complaintId is now $status.',
      );
    }
  }

  Future<void> recordPaymentSuccess({
    required String applicationId,
    required String paymentId,
    required double amount,
    required String serviceName,
    Map<String, dynamic>? pendingApplicationData,
  }) async {
    final appRef = _db.collection('applications').doc(applicationId);
    final appDoc = await appRef.get();

    final pending = pendingApplicationData ?? const <String, dynamic>{};
    final pendingServiceType = (pending['serviceType'] ?? serviceName)
        .toString();
    final pendingStatus = (pending['status'] ?? 'Submitted').toString();
    final pendingStepRaw = pending['currentStep'];
    final pendingStep = pendingStepRaw is num ? pendingStepRaw.toInt() : 1;

    final rawDocumentUrls = pending['documentUrls'];
    final documentUrls = <String, String>{};
    if (rawDocumentUrls is Map) {
      for (final entry in rawDocumentUrls.entries) {
        documentUrls[entry.key.toString()] = entry.value.toString();
      }
    }

    final userId = appDoc.exists
        ? (appDoc.data()?['userId']?.toString() ?? currentUserId)
        : currentUserId;

    final nowIso = DateTime.now().toIso8601String();

    if (!appDoc.exists) {
      await _setWithOfflineFallback(
        collection: 'applications',
        documentId: applicationId,
        data: {
          'serviceType': pendingServiceType,
          'status': pendingStatus,
          'createdAt': nowIso,
          'userId': userId,
          'currentStep': pendingStep,
          'documentUrls': documentUrls,
          'paymentStatus': 'Paid',
          'paymentId': paymentId,
          'paymentAmount': amount,
          'paymentServiceName': serviceName,
          'paidAt': nowIso,
        },
      );
    } else {
      await _updateWithOfflineFallback(
        collection: 'applications',
        documentId: applicationId,
        data: {
          'paymentStatus': 'Paid',
          'paymentId': paymentId,
          'paymentAmount': amount,
          'paymentServiceName': serviceName,
          'paidAt': nowIso,
        },
      );
    }

    await _setWithOfflineFallback(
      collection: 'payments',
      documentId: paymentId,
      data: {
        'applicationId': applicationId,
        'userId': userId,
        'serviceName': serviceName,
        'amount': amount,
        'status': 'Success',
        'createdAt': nowIso,
      },
    );

    if (userId.isNotEmpty) {
      await _createNotification(
        userId: userId,
        title: 'Payment successful',
        body:
            'Your payment for $serviceName was successful. Transaction: $paymentId',
      );
    }
  }

  Stream<List<UserModel>> getAllUsersStream() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // --------- ROLE-BASED QUERIES ---------

  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final query = await _db
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      return query.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint("Error fetching users by role '$role': $e");
      return [];
    }
  }

  Stream<List<UserModel>> getUsersByRoleStream(String role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList();
        })
        .handleError((e) {
          debugPrint("Error fetching users by role stream '$role': $e");
          return <UserModel>[];
        });
  }

  Stream<List<Application>> getOfficerApplications() {
    return getAllApplications();
  }

  Stream<List<Complaint>> getOfficerComplaints() {
    return getAllComplaints();
  }

  Stream<List<OfficerAlert>> getOfficerAlerts() {
    return _db
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => OfficerAlert.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
}

// Global instance for convenience in pages
final firestoreService = FirestoreService();
