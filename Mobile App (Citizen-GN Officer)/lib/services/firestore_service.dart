import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/complaint.dart';
import '../models/application.dart';
import '../models/gn_appointment.dart';
import '../models/user_model.dart';
import '../models/officer_alert.dart';
import '../utils/input_validators.dart';
import '../utils/officer_policy_utils.dart';
import 'offline_sync_queue_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _actionSessionId =
      'sess-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  static bool _offlineSyncInitialized = false;
  static const String _citizensCollection = 'citizens';
  static const String _officersCollection = 'officers';
  UserModel? _currentUser;

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

  String _actionDeviceId() {
    final platform = defaultTargetPlatform.name;
    final actor = currentUserId.trim().isEmpty ? 'unknown' : currentUserId;
    return '$platform-$actor';
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

  bool _isOfficerRole(String role) {
    final normalizedRole = role.toLowerCase();
    return normalizedRole == 'officer' || normalizedRole == 'admin';
  }

  String _collectionForRole(String role) {
    return _isOfficerRole(role) ? _officersCollection : _citizensCollection;
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final cDoc = await _db.collection(_citizensCollection).doc(uid).get();
      if (cDoc.exists && cDoc.data() != null) {
        return UserModel.fromMap(cDoc.data()!, cDoc.id);
      }

      final oDoc = await _db.collection(_officersCollection).doc(uid).get();
      if (oDoc.exists && oDoc.data() != null) {
        return UserModel.fromMap(oDoc.data()!, oDoc.id);
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
    return null;
  }

  Future<String?> _getUserCollection(String uid) async {
    final cDoc = await _db.collection(_citizensCollection).doc(uid).get();
    if (cDoc.exists) return _citizensCollection;
    final oDoc = await _db.collection(_officersCollection).doc(uid).get();
    if (oDoc.exists) return _officersCollection;
    return null;
  }

  Stream<UserModel?> getUserStream(String uid) async* {
    final col = await _getUserCollection(uid);
    if (col == null) {
      yield null;
      return;
    }
    yield* _db.collection(col).doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> deleteUser(String documentId, String role) async {
    final collection = _collectionForRole(role);
    await _db.collection(collection).doc(documentId).delete();
  }

  Future<void> createUser(UserModel user) async {
    final data = user.toMap();
    data['nicNormalized'] = InputValidators.normalizeNic(user.nic);
    data['phoneNormalized'] = InputValidators.normalizePhoneToLocal(user.phone);
    await _setWithOfflineFallback(
      collection: _collectionForRole(user.role),
      documentId: user.id,
      data: data,
    );
  }

  Future<void> updateUser(UserModel user) async {
    final data = user.toMap();
    data['nicNormalized'] = InputValidators.normalizeNic(user.nic);
    data['phoneNormalized'] = InputValidators.normalizePhoneToLocal(user.phone);
    await _updateWithOfflineFallback(
      collection: _collectionForRole(user.role),
      documentId: user.id,
      data: data,
    );
  }

  Future<void> mergeUserFields(String uid, Map<String, dynamic> data) async {
    final collection = await _getUserCollection(uid);
    if (collection == null) return;
    await _setWithOfflineFallback(
      collection: collection,
      documentId: uid,
      data: data,
      merge: true,
    );
  }

  Future<void> updateUserPreferredLanguage(
    String uid,
    String languageCode,
  ) async {
    final user = await getUser(uid);
    if (user == null) return;
    await _setWithOfflineFallback(
      collection: _collectionForRole(user.role),
      documentId: uid,
      data: {'preferredLanguage': languageCode},
      merge: true,
    );
  }

  Future<void> updateUserProfilePhoto(
    String uid,
    String profileImageUrl,
  ) async {
    final user = await getUser(uid);
    if (user == null) return;
    await _setWithOfflineFallback(
      collection: _collectionForRole(user.role),
      documentId: uid,
      data: {'profileImageUrl': profileImageUrl},
      merge: true,
    );
  }

  Future<UserModel?> getCitizenByNic(String nic) async {
    final normalizedNic = InputValidators.normalizeNic(nic);
    if (normalizedNic.isEmpty) return null;

    try {
      final query = await _db
          .collection(_citizensCollection)
          .where('nicNormalized', isEqualTo: normalizedNic)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return UserModel.fromMap(doc.data(), doc.id);
      }

      final legacyCandidates = [normalizedNic, normalizedNic.toLowerCase()];
      final legacyQuery = await _db
          .collection(_citizensCollection)
          .where('nic', whereIn: legacyCandidates)
          .limit(5)
          .get();

      for (final doc in legacyQuery.docs) {
        final data = doc.data();
        final model = UserModel.fromMap(data, doc.id);
        await _db.collection(_citizensCollection).doc(doc.id).set({
          ...data,
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

  Future<UserModel?> getCitizenByUid(String uid) async {
    if (uid.trim().isEmpty) {
      return null;
    }

    try {
      final doc = await _db.collection(_citizensCollection).doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('Error fetching citizen by UID: $e');
      return null;
    }
  }

  Future<UserModel?> getCitizenByPhone(String phone) async {
    final normalizedPhone = InputValidators.normalizePhoneToLocal(phone);
    final e164Phone = InputValidators.toE164SriLankanPhone(phone);
    if (normalizedPhone.isEmpty && e164Phone.isEmpty) return null;

    try {
      final query = await _db
          .collection(_citizensCollection)
          .where('phoneNormalized', isEqualTo: normalizedPhone)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return UserModel.fromMap(doc.data(), doc.id);
      }

      final legacyCandidates = <String>{
        normalizedPhone,
        e164Phone,
      }.where((value) => value.isNotEmpty).toList();
      if (legacyCandidates.isEmpty) return null;

      final legacyQuery = await _db
          .collection(_citizensCollection)
          .where('phone', whereIn: legacyCandidates)
          .limit(5)
          .get();

      for (final doc in legacyQuery.docs) {
        final data = doc.data();
        final model = UserModel.fromMap(data, doc.id);
        await _db.collection(_citizensCollection).doc(doc.id).set({
          ...data,
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
      final query = await _db
          .collection(_officersCollection)
          .where('officerIdNormalized', isEqualTo: normalizedOfficerId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return UserModel.fromMap(doc.data(), doc.id);
      }

      final legacyCandidates = <String>{
        normalizedOfficerId,
        normalizedOfficerId.toLowerCase(),
      }.toList();

      final legacyQuery = await _db
          .collection(_officersCollection)
          .where('officerId', whereIn: legacyCandidates)
          .limit(5)
          .get();

      for (final doc in legacyQuery.docs) {
        final data = doc.data();
        await _db.collection(_officersCollection).doc(doc.id).set({
          ...data,
          'officerIdNormalized': normalizedOfficerId,
        }, SetOptions(merge: true));
        return UserModel.fromMap(data, doc.id);
      }
    } catch (e) {
      debugPrint('Error finding officer by officer ID: $e');
    }

    return null;
  }

  Future<UserModel?> getOfficerByUid(String uid) async {
    if (uid.trim().isEmpty) {
      return null;
    }

    try {
      final doc = await _db.collection(_officersCollection).doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('Error fetching officer by UID: $e');
      return null;
    }
  }

  Future<void> mergeOfficerFields(String uid, Map<String, dynamic> data) async {
    if (uid.trim().isEmpty) {
      return;
    }

    await _setWithOfflineFallback(
      collection: _officersCollection,
      documentId: uid,
      data: data,
      merge: true,
    );
  }

  Future<Map<String, dynamic>?> lookupCitizenIdentity({
    required String nic,
    required String phone,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('lookupCitizenIdentity');
      final res = await callable.call({
        'nic': InputValidators.normalizeNic(nic),
        'phone': InputValidators.normalizePhoneToLocal(phone),
      });
      final data = Map<String, dynamic>.from((res.data as Map?) ?? {});
      return data;
    } catch (e) {
      debugPrint('Error looking up citizen identity: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkCitizenRegistration({
    required String nic,
    required String phone,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('checkCitizenRegistration');
      final res = await callable.call({
        'nic': InputValidators.normalizeNic(nic),
        'phone': InputValidators.normalizePhoneToLocal(phone),
      });
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } catch (e) {
      debugPrint('Error checking citizen registration: $e');
      return null;
    }
  }

  Future<UserModel?> lookupOfficerIdentity(String officerId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('lookupOfficerIdentity');
      final res = await callable.call({
        'officerId': InputValidators.normalizeOfficerId(officerId),
      });
      final data = Map<String, dynamic>.from((res.data as Map?) ?? {});
      if (data['found'] != true) {
        return null;
      }

      return UserModel(
        id: (data['uid'] ?? '').toString(),
        name: (data['name'] ?? '').toString(),
        nic: (data['nic'] ?? '').toString(),
        phone: (data['phone'] ?? '').toString(),
        role: (data['role'] ?? 'officer').toString(),
        division: (data['division'] ?? '').toString(),
        province: (data['province'] ?? '').toString(),
        district: (data['district'] ?? '').toString(),
        pradeshiyaSabha: (data['pradeshiyaSabha'] ?? '').toString(),
        gramasewaWasama: (data['gramasewaWasama'] ?? '').toString(),
        preferredLanguage: (data['preferredLanguage'] ?? 'en').toString(),
        profileImageUrl: (data['profileImageUrl'] ?? '').toString(),
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error looking up officer identity: $e');
      return null;
    }
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('setUserRoleSecure');

    await callable.call({'targetUid': uid, 'targetRole': newRole});
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

      final rawHierarchy = configData;

      // Build candidates for searching
      final candidates = _buildLookupCandidates(
        user.pradeshiyaSabha,
        fallback: [user.gramasewaWasama, user.division],
      );

      // Deep search method to find the node anywhere in the JSON tree
      Map? foundAreaNode;
      int bestScore = -1;

      void deepSearch(dynamic node) {
        if (node is! Map) return;

        for (final entry in node.entries) {
          final key = entry.key.toString().toLowerCase();

          // Check for matches
          for (final candidate in candidates) {
            if (candidate.isEmpty) continue;
            final cand = candidate.toLowerCase();
            
            if (key == cand || key.contains(cand) || cand.contains(key)) {
              if (entry.value is Map) {
                final match = entry.value as Map;
                
                // Score the match based on entries
                int score = 0;
                if (match['entries'] != null && (match['entries'] as List).isNotEmpty) {
                  score = 100; // Found entries! Highest priority.
                } else if (key == cand) {
                  score = 50; // Exact match but empty.
                } else {
                  score = 10; // Partial match but empty.
                }

                if (score > bestScore) {
                  bestScore = score;
                  foundAreaNode = match;
                }
              }
            }
          }

          // Recurse into children, avoiding the 'entries' array itself
          if (entry.value is Map && entry.key != 'entries') {
            deepSearch(entry.value);
          }
        }
      }

      deepSearch(rawHierarchy);

      if (foundAreaNode == null) {
        // Collect some top level structure info for debugging
        String dbInfo = "";
        try {
            if (rawHierarchy.containsKey('Western') && rawHierarchy['Western'] is Map) {
                var w = rawHierarchy['Western'] as Map;
                if (w.containsKey('Colombo') && w['Colombo'] is Map) {
                    var c = w['Colombo'] as Map;
                    dbInfo = c.keys.join(",");
                }
            }
        } catch(e) {}

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
          'debug_info': 'Cands: ${candidates.join("|")}. DB Colombo keys: $dbInfo',
        };
      }

      return _normalizeWasteCollectionSchedule(
        foundAreaNode!,
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

      final myEntries = areaNode['entries'];
      if (myEntries is List) {
        for (final item in myEntries) {
          if (item is Map) {
            addEntry(item['day'] ?? item['date'] ?? item['label'], item);
          }
        }
      } else if (myEntries is Map) {
        for (final entry in myEntries.entries) {
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
      'debug_info': 'Node found with ${entries.length} entries. Rawkeys: ${areaNode is Map ? areaNode.keys.join(",") : "Not map"}',
    };
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

  Stream<List<Map<String, dynamic>>> getCitizenNotifications({int limit = 20}) {
    return getUserNotifications(limit: limit);
  }

  Stream<List<Map<String, dynamic>>> getOfficerNotifications({int limit = 20}) {
    return getUserNotifications(limit: limit);
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

  Stream<List<Application>> getUserApplications() async* {
    final box = Hive.box('cacheBox');
    final cacheKey = 'user_applications_$currentUserId';

    // Serve from local read-cache first
    if (box.containsKey(cacheKey)) {
      try {
        final cachedData = jsonDecode(box.get(cacheKey));
        final list = (cachedData as List)
            .map((map) => Application.fromMap(map, map['id']))
            .toList();
        yield list;
      } catch (e) {
        debugPrint('Cache read error: $e');
      }
    }

    yield* _db
        .collection('applications')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Application.fromMap(doc.data(), doc.id))
              .toList();

          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Update local read-cache
          try {
            final dataToCache = list.map((a) {
              var map = a.toMap();
              map['id'] = a.id;
              // serialize dates for json
              map['createdAt'] = a.createdAt.toIso8601String();
              return map;
            }).toList();
            box.put(cacheKey, jsonEncode(dataToCache));
          } catch (_) {}

          return list;
        });
  }

  Future<void> addApplication(Application app) async {
    final data = await _enrichWithDivision(app.toMap());
    await _setWithOfflineFallback(
      collection: 'applications',
      documentId: app.id,
      data: data,
    );
  }

  Future<Map<String, dynamic>> _enrichWithDivision(
    Map<String, dynamic> data,
  ) async {
    final enriched = Map<String, dynamic>.from(data);

    try {
      if (currentUserId == 'anonymous_user') {
        debugPrint(
          "FirestoreService: Not enriching document - user is anonymous.",
        );
        return enriched;
      }

      // Check if division is already set and not encrypted
      final existingDiv =
          (enriched['gnDivision'] ?? enriched['gramasewaWasama'] ?? '')
              .toString();
      if (existingDiv.isNotEmpty && !existingDiv.startsWith('ENC:')) {
        return enriched;
      }

      // Use cached user if available, otherwise fetch
      UserModel? user = _currentUser;
      if (user == null || user.id != currentUserId) {
        user = await getUser(currentUserId);
        if (user != null) {
          _currentUser = user;
        }
      }

      if (user != null) {
        final div =
            user.gramasewaWasama.isNotEmpty ? user.gramasewaWasama : user.division;

        if (div.isNotEmpty) {
          enriched['gnDivision'] = div;
          enriched['gramasewaWasama'] = div; // Ensure both variants for compatibility
        }
        
        if (user.pradeshiyaSabha.isNotEmpty) {
           enriched['pradeshiyaSabha'] = user.pradeshiyaSabha;
        }

        debugPrint(
            "FirestoreService: Enriched document with division: $div | PS: ${user.pradeshiyaSabha}");

      }
    } catch (e) {
      debugPrint("FirestoreService: Warning: Failed to enrich with division: $e");
      // Continue anyway, better have a record without division than no record at all
    }

    return enriched;
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
    final data = await _enrichWithDivision(complaint.toMap());
    await _setWithOfflineFallback(
      collection: 'complaints',
      documentId: complaint.id,
      data: data,
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
    // If the officer has a specific GN division (gramasewaWasama), only show
    // appointments from that exact division — strict scope for GN officers.
    final officerGnDivision = officer.gramasewaWasama.trim();
    if (officerGnDivision.isNotEmpty) {
      final appointmentGnDivision = appointment.gramasewaWasama.trim();
      if (appointmentGnDivision.isEmpty) {
        // Appointment has no GN division tagged — don't show to this officer.
        return false;
      }
      return _normalizeAreaText(appointmentGnDivision) ==
          _normalizeAreaText(officerGnDivision);
    }

    // Fallback: officer has no GN division — match on broader areas
    // (pradeshiyaSabha, district, province).
    final officerAreas = [
      officer.province,
      officer.district,
      officer.pradeshiyaSabha,
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
      if (normalizedOfficerArea.isEmpty) continue;
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
    final data = await _enrichWithDivision(appointment.toMap());
    await _setWithOfflineFallback(
      collection: 'gn_appointments',
      documentId: appointment.id,
      data: data,
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
    String? actingOfficerId,
    String? actingOfficerName,
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
      final assignedOfficerId = (data?['assignedOfficerId'] ?? '')
          .toString()
          .trim();

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
      final updates = <String, dynamic>{'status': status, 'updatedAt': nowIso};

      final actingId = (actingOfficerId ?? '').trim();
      final actorUid = actingId.isNotEmpty ? actingId : currentUserId;
      updates.addAll(
        buildOfficerActionMetadata(
          actorUid: actorUid,
          reason: officerNotes ?? '',
          sessionId: _actionSessionId,
          deviceId: _actionDeviceId(),
        ),
      );

      if (actingId.isNotEmpty) {
        if (assignedOfficerId.isNotEmpty && assignedOfficerId != actingId) {
          throw StateError(
            'This appointment is already handled by another officer.',
          );
        }
        updates['assignedOfficerId'] = actingId;
        if ((actingOfficerName ?? '').trim().isNotEmpty) {
          updates['assignedOfficerName'] = actingOfficerName!.trim();
        }
      }

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

  Stream<List<Application>> getAllApplications({String? gnDivision}) {
    debugPrint("FirestoreService: getAllApplications() called with gnDivision=$gnDivision");
    // Removing exact where filter to perform robust normalized local filtering
    return _db.collection('applications')
        .snapshots()
        .map((snapshot) {
          final normalizedSearch = gnDivision != null ? _normalizeAreaText(gnDivision) : null;
          
          final list = snapshot.docs
              .map((doc) {
                try {
                  final app = Application.fromMap(doc.data(), doc.id);
                  // Apply regional filtering locally if gnDivision specified
                  if (normalizedSearch != null) {
                    final appDiv = _normalizeAreaText(app.gnDivision.isNotEmpty ? app.gnDivision : (doc.data()['gramasewaWasama'] ?? '').toString());
                    if (appDiv != normalizedSearch) return null;
                  }
                  return app;
                } catch (e) {
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

  Stream<List<Complaint>> getAllComplaints({String? gnDivision}) {
    debugPrint("FirestoreService: getAllComplaints() called with gnDivision=$gnDivision");
    // Optimized regional isolation with normalized local filtering
    return _db.collection('complaints')
        .snapshots()
        .map((snapshot) {
          final normalizedSearch = gnDivision != null ? _normalizeAreaText(gnDivision) : null;

          final list = snapshot.docs
              .map((doc) {
                try {
                  final c = Complaint.fromMap(doc.data(), doc.id);
                  // Apply regional filtering locally if gnDivision specified
                  if (normalizedSearch != null) {
                    final cDiv = _normalizeAreaText(c.gnDivision.isNotEmpty ? c.gnDivision : (doc.data()['gramasewaWasama'] ?? '').toString());
                    if (cDiv != normalizedSearch) return null;
                  }
                  return c;
                } catch (e) {
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

  Future<void> updateApplicationRef(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await _updateWithOfflineFallback(
      collection: 'applications',
      documentId: documentId,
      data: data,
    );
  }

  Future<void> rateGNAppointment(
    String appointmentId,
    int rating,
    String feedback,
  ) async {
    await _updateWithOfflineFallback(
      collection: 'gn_appointments',
      documentId: appointmentId,
      data: {'rating': rating, 'feedback': feedback},
    );
  }

  Future<void> updateApplicationStatus(
    String applicationId,
    String status, {
    String? remarks,
  }) async {
    final doc = await _db.collection('applications').doc(applicationId).get();
    final userId = doc.data()?['userId']?.toString() ?? '';

    int currentStep = 1;
    switch (status) {
      case 'Submitted':
        currentStep = 1;
        break;
      case 'Verified':
        currentStep = 2;
        break;
      case 'Processing':
        currentStep = 3;
        break;
      case 'Completed':
        currentStep = 4;
        break;
      case 'Rejected':
        currentStep = 0; // or special handling
        break;
      default:
        currentStep = 1;
    }

    final updateData = <String, dynamic>{
      'status': status,
      'currentStep': currentStep,
      ...buildOfficerActionMetadata(
        actorUid: currentUserId,
        reason: remarks ?? '',
        sessionId: _actionSessionId,
        deviceId: _actionDeviceId(),
      ),
    };
    if (remarks != null && remarks.isNotEmpty) {
      updateData['officerRemarks'] = remarks;
    }

    await _updateWithOfflineFallback(
      collection: 'applications',
      documentId: applicationId,
      data: updateData,
    );

    if (userId.isNotEmpty) {
      await _createNotification(
        userId: userId,
        title: 'Application status updated',
        body: 'Your application $applicationId is now $status.',
      );
    }
  }

  Future<Application?> getApplicationByCertificateReference(
    String reference,
  ) async {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) return null;

    try {
      final query = await _db
          .collection('applications')
          .where('certificateReference', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return Application.fromMap(doc.data(), doc.id);
      }
    } catch (e) {
      debugPrint('Error finding certificate reference: $e');
    }

    return null;
  }

  Future<Map<String, dynamic>?> verifyCertificateReferenceSecure(
    String reference,
  ) async {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) return null;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('verifyCertificateReference');
      final res = await callable.call({'reference': trimmed});
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } catch (e) {
      debugPrint('Error verifying certificate reference securely: $e');
      return null;
    }
  }

  Future<void> updateComplaintStatus(
    String complaintId,
    String status, {
    String? reason,
  }) async {
    await _updateWithOfflineFallback(
      collection: 'complaints',
      documentId: complaintId,
      data: {
        'status': status,
        ...buildOfficerActionMetadata(
          actorUid: currentUserId,
          reason: reason ?? '',
          sessionId: _actionSessionId,
          deviceId: _actionDeviceId(),
        ),
      },
    );

    final doc = await _db.collection('complaints').doc(complaintId).get();
    final userId = doc.data()?['userId']?.toString() ?? '';

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
    final userId = currentUserId;
    final nowIso = DateTime.now().toIso8601String();

    try {
      debugPrint(
        "FirestoreService: Recording payment success for $applicationId (Payment: $paymentId)",
      );

      // Create or update the application document without reading first (to avoid read permission errors)
      // If it's new, the merge true will act like a creation.
      // We'll prepare the data fields common to both.
      
      final applicationData = await _enrichWithDivision({
        'serviceType': serviceName,
        'status': 'Submitted',
        'userId': userId,
        'paid': true,
        'paymentId': paymentId,
        'paymentAmount': amount,
        'paymentAt': nowIso,
        'lastPaymentSyncAt': nowIso,
        if (pendingApplicationData != null) ...pendingApplicationData,
        ...buildOfficerActionMetadata(
          actorUid: userId,
          reason: 'Payment successful for $serviceName',
          sessionId: _actionSessionId,
          deviceId: _actionDeviceId(),
        ),
      });

      // Use a set with merge instead of read-then-write
      await _setWithOfflineFallback(
        collection: 'applications',
        documentId: applicationId,
        data: applicationData,
        merge: true,
      );

      debugPrint(
        "FirestoreService: Successfully saved application $applicationId to database via merge write.",
      );

      debugPrint(
        "FirestoreService: Successfully saved application $applicationId to database.",
      );

      // Create notification
      await _createNotification(
        userId: userId,
        title: 'Application Submitted',
        body:
            'Your application for $serviceName has been successfully submitted.',
      );
    } catch (e) {
      debugPrint("FirestoreService: CRITICAL ERROR in recordPaymentSuccess: $e");
      rethrow;
    }
  }

  Stream<List<UserModel>> getCitizensStream() {
    return _db.collection(_citizensCollection).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<UserModel>> getAllUsersStream() {
    return getCitizensStream();
  }

  // --------- ROLE-BASED QUERIES ---------

  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final query = await _db
          .collection(_collectionForRole(role))
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
        .collection(_collectionForRole(role))
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
