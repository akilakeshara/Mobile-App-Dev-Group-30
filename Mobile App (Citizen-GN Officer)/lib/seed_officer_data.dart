import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:govease/firebase_options.dart';
import 'package:govease/utils/input_validators.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const docIdOverride = String.fromEnvironment(
    'SEED_OFFICER_DOC_ID',
    defaultValue: '',
  );
  const officerId = String.fromEnvironment(
    'SEED_OFFICER_ID',
    defaultValue: 'GN-2026-0101',
  );
  const name = String.fromEnvironment(
    'SEED_OFFICER_NAME',
    defaultValue: 'Demo Officer',
  );
  const nic = String.fromEnvironment(
    'SEED_OFFICER_NIC',
    defaultValue: '199001234567',
  );
  const phone = String.fromEnvironment(
    'SEED_OFFICER_PHONE',
    defaultValue: '+94701285090',
  );

  try {
    debugPrint('Seeding officer demo profile into Firestore...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }

    final currentUid = auth.currentUser?.uid ?? '';
    final docId = docIdOverride.trim().isNotEmpty
        ? docIdOverride.trim()
        : currentUid;

    if (docId.isEmpty || officerId.trim().isEmpty) {
      stderr.writeln(
        'SEED_OFFICER_ID is required and user must be signed in or SEED_OFFICER_DOC_ID must be provided.',
      );
      debugPrint(
        'SEED_OFFICER_ID is required and user must be signed in or SEED_OFFICER_DOC_ID must be provided.',
      );
      exitCode = 64;
      return;
    }

    final db = FirebaseFirestore.instance;
    final now = DateTime.now().toIso8601String();

    await db.collection('officers').doc(docId).set({
      'id': docId,
      'name': name.trim(),
      'nic': InputValidators.normalizeNic(nic),
      'nicNormalized': InputValidators.normalizeNic(nic),
      'phone': phone.trim(),
      'phoneNormalized': InputValidators.normalizePhoneToLocal(phone),
      'role': 'officer',
      'officerId': InputValidators.normalizeOfficerId(officerId),
      'officerIdNormalized': InputValidators.normalizeOfficerId(officerId),
      'division': 'Wellampitiya',
      'province': 'Western',
      'district': 'Colombo',
      'pradeshiyaSabha': 'Kolonnawa PS',
      'gramasewaWasama': 'Wellampitiya',
      'preferredLanguage': 'en',
      'profileImageUrl': '',
      'createdAt': now,
      'seedTag': 'officer-demo',
      'updatedAt': now,
    }, SetOptions(merge: true));

    debugPrint('Officer demo seeded successfully.');
    debugPrint('authUid: $currentUid');
    debugPrint('docId: $docId');
    debugPrint('officerId: ${InputValidators.normalizeOfficerId(officerId)}');
    debugPrint('phone: ${phone.trim()}');
    exit(0);
  } catch (e, st) {
    debugPrint('Officer seeding failed: $e');
    debugPrint(st.toString());
    exitCode = 1;
  }
}
