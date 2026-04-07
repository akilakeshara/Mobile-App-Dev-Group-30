class OfficerScopePolicy {
  static bool shouldUseFallback({
    required bool allowFallback,
    required bool isAdmin,
    required bool hasAnyRecords,
    required bool hasScopedMatches,
  }) {
    return allowFallback && !isAdmin && hasAnyRecords && !hasScopedMatches;
  }
}

List<String> officerApplicationLifecycleActions(String status) {
  final normalized = status.toLowerCase().trim();
  if (normalized == 'submitted') {
    return const <String>['review', 'start_review', 'reject'];
  }
  if (normalized == 'processing' || normalized == 'verified') {
    return const <String>['review', 'complete', 'reject'];
  }
  if (normalized == 'completed' || normalized == 'rejected') {
    return const <String>['review'];
  }
  return const <String>['review', 'reject'];
}

Map<String, dynamic> buildOfficerActionMetadata({
  required String actorUid,
  String reason = '',
  String source = 'mobile-app',
  required String sessionId,
  required String deviceId,
  DateTime? now,
}) {
  final timestamp = (now ?? DateTime.now()).toIso8601String();
  return {
    'updatedAt': timestamp,
    'responseAt': timestamp,
    'lastActionBy': actorUid,
    'lastActionReason': reason.trim(),
    'lastActionSource': source,
    'lastActionSessionId': sessionId,
    'lastActionDeviceId': deviceId,
    'lastActionAt': timestamp,
  };
}

Map<String, dynamic> buildCertificateMetadataWrite({
  required String reference,
  required String downloadUrl,
  required DateTime issuedAt,
  required String integrityHash,
}) {
  return {
    'certificateGenerated': true,
    'certificateIssuedAt': issuedAt.toIso8601String(),
    'certificateReference': reference,
    'certificateDownloadUrl': downloadUrl,
    'certificateIntegrityHash': integrityHash,
  };
}
