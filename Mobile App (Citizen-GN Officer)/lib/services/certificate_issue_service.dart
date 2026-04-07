import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/application.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class CertificateIssueResult {
  final String downloadUrl;
  final String reference;
  final DateTime issuedAt;
  final String integrityHash;

  CertificateIssueResult({
    required this.downloadUrl,
    required this.reference,
    required this.issuedAt,
    required this.integrityHash,
  });
}

class CertificateIssueService {
  Future<CertificateIssueResult> issueCertificatePdf({
    required Application application,
    required UserModel? citizen,
    required String approvedBy,
    String remarks = '',
  }) async {
    final now = DateTime.now();
    final reference = 'CERT-${application.id.toUpperCase()}';
    final integrityHash = await _buildIntegrityHash(
      application: application,
      citizen: citizen,
      approvedBy: approvedBy,
      issuedAt: now,
      reference: reference,
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Center(
              child: pw.Text(
                'GovEase Official Certificate',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Digital Local Government Service Record',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.SizedBox(height: 22),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _row('Certificate Ref', reference),
                  _row('Application ID', application.id),
                  _row('Service', application.serviceType),
                  _row('Status', 'Completed and Approved'),
                  _row('Issued On', now.toIso8601String()),
                  _row('Issued By', approvedBy),
                  _row('Integrity Hash', integrityHash),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Citizen Information',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _row('Name', citizen?.name ?? 'N/A'),
                  _row('NIC', citizen?.nic ?? 'N/A'),
                  _row('Phone', citizen?.phone ?? 'N/A'),
                  _row(
                    'Area',
                    [
                      citizen?.gramasewaWasama ?? '',
                      citizen?.pradeshiyaSabha ?? '',
                      citizen?.district ?? '',
                      citizen?.province ?? '',
                    ].where((v) => v.trim().isNotEmpty).join(' | '),
                  ),
                ],
              ),
            ),
            if (remarks.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text(
                'Officer Remarks',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(remarks.trim()),
            ],
            pw.SizedBox(height: 18),
            pw.Text(
              'This certificate is digitally issued via GovEase and is valid for verification.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ];
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$reference.pdf');
    await file.writeAsBytes(await pdf.save());

    final url = await storageService.uploadDocument(
      file: file,
      applicationId: application.id,
      documentType: 'certificate_${_sanitize(reference)}_issued',
      ownerUserId: application.userId,
    );

    return CertificateIssueResult(
      downloadUrl: url,
      reference: reference,
      issuedAt: now,
      integrityHash: integrityHash,
    );
  }

  Future<String> _buildIntegrityHash({
    required Application application,
    required UserModel? citizen,
    required String approvedBy,
    required DateTime issuedAt,
    required String reference,
  }) async {
    final seed = [
      reference,
      application.id,
      application.serviceType,
      application.userId,
      citizen?.nic ?? '',
      approvedBy,
      issuedAt.toIso8601String(),
    ].join('|');

    final digest = await Sha256().hash(seed.codeUnits);
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String _sanitize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

final certificateIssueService = CertificateIssueService();
