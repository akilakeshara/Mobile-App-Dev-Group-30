import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:govease/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const defaultGeneratedPath =
      'assets/data/sri_lanka_administrative_hierarchy.generated.json';
  const defaultTemplatePath =
      'assets/data/sri_lanka_administrative_hierarchy_template.json';

  final configPath = String.fromEnvironment(
    'ADMIN_HIERARCHY_JSON',
    defaultValue: File(defaultGeneratedPath).existsSync()
        ? defaultGeneratedPath
        : defaultTemplatePath,
  );

  try {
    stdout.writeln('Loading hierarchy from: $configPath');

    final file = File(configPath);
    if (!file.existsSync()) {
      stderr.writeln('Hierarchy JSON file not found: $configPath');
      exitCode = 64;
      return;
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('Invalid JSON: root must be an object.');
      exitCode = 64;
      return;
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final data = decoded;
    await FirebaseFirestore.instance
        .collection('config')
        .doc('administrative_hierarchy')
        .set(data, SetOptions(merge: false));

    stdout.writeln('Administrative hierarchy uploaded successfully.');
    exit(0);
  } catch (e, st) {
    stderr.writeln('Failed to seed administrative hierarchy: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}
