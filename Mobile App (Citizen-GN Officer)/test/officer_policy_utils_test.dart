import 'package:flutter_test/flutter_test.dart';
import 'package:govease/utils/officer_policy_utils.dart';

void main() {
  group('OfficerScopePolicy.shouldUseFallback', () {
    test('returns false when fallback is disabled', () {
      final result = OfficerScopePolicy.shouldUseFallback(
        allowFallback: false,
        isAdmin: false,
        hasAnyRecords: true,
        hasScopedMatches: false,
      );

      expect(result, isFalse);
    });

    test('returns false for admins', () {
      final result = OfficerScopePolicy.shouldUseFallback(
        allowFallback: true,
        isAdmin: true,
        hasAnyRecords: true,
        hasScopedMatches: false,
      );

      expect(result, isFalse);
    });

    test('returns false when scoped matches exist', () {
      final result = OfficerScopePolicy.shouldUseFallback(
        allowFallback: true,
        isAdmin: false,
        hasAnyRecords: true,
        hasScopedMatches: true,
      );

      expect(result, isFalse);
    });

    test('returns true only for explicit non-admin fallback mode', () {
      final result = OfficerScopePolicy.shouldUseFallback(
        allowFallback: true,
        isAdmin: false,
        hasAnyRecords: true,
        hasScopedMatches: false,
      );

      expect(result, isTrue);
    });
  });

  group('buildOfficerActionMetadata', () {
    test('includes actor and audit fields', () {
      final now = DateTime.utc(2026, 4, 5, 10, 30, 0);
      final metadata = buildOfficerActionMetadata(
        actorUid: 'officer-123',
        reason: 'Approved after review',
        sessionId: 'sess-abc',
        deviceId: 'android-officer-123',
        now: now,
      );

      expect(metadata['lastActionBy'], 'officer-123');
      expect(metadata['lastActionReason'], 'Approved after review');
      expect(metadata['lastActionSessionId'], 'sess-abc');
      expect(metadata['lastActionDeviceId'], 'android-officer-123');
      expect(metadata['lastActionAt'], now.toIso8601String());
      expect(metadata['updatedAt'], now.toIso8601String());
      expect(metadata['responseAt'], now.toIso8601String());
    });
  });
}
