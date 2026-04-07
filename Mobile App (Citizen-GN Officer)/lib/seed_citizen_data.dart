import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:govease/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const userId = String.fromEnvironment(
    'SEED_USER_ID',
    defaultValue: 'anonymous_user',
  );
  const name = String.fromEnvironment(
    'SEED_NAME',
    defaultValue: 'Nimal Perera',
  );
  const nic = String.fromEnvironment('SEED_NIC', defaultValue: '199512345678');
  const phone = String.fromEnvironment(
    'SEED_PHONE',
    defaultValue: '+94771234567',
  );
  const resetFlag = String.fromEnvironment('SEED_RESET', defaultValue: 'false');

  final resetExisting = resetFlag.toLowerCase() == 'true';

  if (userId.trim().isEmpty) {
    stderr.writeln('SEED_USER_ID cannot be empty.');
    await stderr.flush();
    exitCode = 64;
    return;
  }

  try {
    stdout.writeln('Starting seed for userId: $userId');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final seeder = CitizenSeeder(FirebaseFirestore.instance);
    await seeder.seed(
      userId: userId.trim(),
      name: name.trim(),
      nic: nic.trim(),
      phone: phone.trim(),
      resetExisting: resetExisting,
    );

    stdout.writeln('Done. Citizen sample data seeded for userId: $userId');
    await stdout.flush();
    exit(0);
  } catch (e, st) {
    stderr.writeln('Seeding failed: $e');
    stderr.writeln(st);
    await stderr.flush();
    exitCode = 1;
  }
}

class CitizenSeeder {
  CitizenSeeder(this.db);

  final FirebaseFirestore db;

  Future<void> seed({
    required String userId,
    required String name,
    required String nic,
    required String phone,
    required bool resetExisting,
  }) async {
    if (resetExisting) {
      await _deleteUserScopedData('applications', userId);
      await _deleteUserScopedData('complaints', userId);
      stdout.writeln(
        'Existing applications and complaints removed for $userId.',
      );
    }

    final now = DateTime.now();

    await db.collection('citizens').doc(userId).set({
      'id': userId,
      'name': name,
      'nic': nic,
      'phone': phone,
      'role': 'citizen',
      'createdAt': now.subtract(const Duration(days: 120)).toIso8601String(),
    });

    final appBatch = db.batch();
    final appDocs = [
      (
        'APP-SEED-001-$userId',
        {
          'serviceType': 'Birth Certificate Copy',
          'status': 'Processing',
          'createdAt': now.subtract(const Duration(days: 12)).toIso8601String(),
          'userId': userId,
          'currentStep': 3,
        },
      ),
      (
        'APP-SEED-002-$userId',
        {
          'serviceType': 'NIC Renewal',
          'status': 'Submitted',
          'createdAt': now.subtract(const Duration(days: 4)).toIso8601String(),
          'userId': userId,
          'currentStep': 1,
        },
      ),
      (
        'APP-SEED-003-$userId',
        {
          'serviceType': 'Driving License Renewal',
          'status': 'Completed',
          'createdAt': now.subtract(const Duration(days: 27)).toIso8601String(),
          'userId': userId,
          'currentStep': 4,
        },
      ),
    ];

    for (final app in appDocs) {
      final docRef = db.collection('applications').doc(app.$1);
      appBatch.set(docRef, app.$2);
    }
    await appBatch.commit();

    final complaintBatch = db.batch();
    final complaintDocs = [
      (
        'CP-SEED-001-$userId',
        {
          'title': 'Street light not working',
          'category': 'Electricity',
          'description':
              'Street light has been off for 3 nights near the temple junction.',
          'location': 'Kandy Road - Temple Junction',
          'status': 'Open',
          'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'userId': userId,
        },
      ),
      (
        'CP-SEED-002-$userId',
        {
          'title': 'Blocked drainage line',
          'category': 'Infrastructure',
          'description':
              'Drain near bus stand is blocked and causing water overflow.',
          'location': 'Main Bus Stand - North Entrance',
          'status': 'In Progress',
          'createdAt': now.subtract(const Duration(days: 8)).toIso8601String(),
          'userId': userId,
        },
      ),
      (
        'CP-SEED-003-$userId',
        {
          'title': 'Garbage not collected on schedule',
          'category': 'Waste Management',
          'description': 'Waste collection skipped this week in our lane.',
          'location': 'Lake View Lane - Zone B',
          'status': 'Closed',
          'createdAt': now.subtract(const Duration(days: 18)).toIso8601String(),
          'userId': userId,
        },
      ),
    ];

    for (final complaint in complaintDocs) {
      final docRef = db.collection('complaints').doc(complaint.$1);
      complaintBatch.set(docRef, complaint.$2);
    }
    await complaintBatch.commit();
  }

  Future<void> _deleteUserScopedData(String collection, String userId) async {
    final snapshot = await db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    var batch = db.batch();
    var opCount = 0;

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      opCount++;

      if (opCount == 450) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }
  }
}
