import 'package:flutter_test/flutter_test.dart';
import 'package:govease/utils/officer_policy_utils.dart';

void main() {
  test('buildCertificateMetadataWrite returns required certificate fields', () {
    final issuedAt = DateTime.utc(2026, 4, 5, 12, 0, 0);

    final payload = buildCertificateMetadataWrite(
      reference: 'CERT-APP-123',
      downloadUrl: 'https://example.com/cert.pdf',
      issuedAt: issuedAt,
      integrityHash: 'hash-abc-123',
    );

    expect(payload['certificateGenerated'], isTrue);
    expect(payload['certificateIssuedAt'], issuedAt.toIso8601String());
    expect(payload['certificateReference'], 'CERT-APP-123');
    expect(payload['certificateDownloadUrl'], 'https://example.com/cert.pdf');
    expect(payload['certificateIntegrityHash'], 'hash-abc-123');
  });
}
