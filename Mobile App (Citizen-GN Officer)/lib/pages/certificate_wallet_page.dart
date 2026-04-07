import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/application.dart';
import '../services/firestore_service.dart';
import '../widgets/gradient_page_app_bar.dart';

class CertificateWalletPage extends StatelessWidget {
  const CertificateWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GradientPageAppBar(
        title: 'Certificate Wallet',
        subtitle: 'Your approved certificates',
      ),
      body: StreamBuilder<List<Application>>(
        stream: firestoreService.getUserApplications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final apps = snapshot.data ?? [];
          final certificates = apps
              .where(
                (app) =>
                    app.status == 'Completed' &&
                    (app.certificateGenerated ||
                        app.certificateDownloadUrl.trim().isNotEmpty ||
                        app.serviceType.toLowerCase().contains('certificate')),
              )
              .toList();

          if (certificates.isEmpty) {
            return Center(
              child: Text(
                context.tr('walletNoCertificates'),
                style: GoogleFonts.inter(color: AppColors.mutedForeground),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: certificates.length,
            itemBuilder: (context, index) {
              final cert = certificates[index];
              return FadeInUp(
                delay: Duration(milliseconds: index * 100),
                child: _buildCertificateCard(context, cert),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCertificateCard(BuildContext context, Application cert) {
    final reference = cert.certificateReference.trim().isNotEmpty
        ? cert.certificateReference
        : cert.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF28A745).withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified, color: Color(0xFF28A745)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert.serviceType,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${context.tr('walletRef')}: $reference',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    if (cert.certificateIssuedAt != null)
                      Text(
                        '${context.tr('walletIssued')}: ${cert.certificateIssuedAt!.toLocal().toString().split('.')[0]}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  cert.certificateIntegrityHash.isNotEmpty
                      ? '${context.tr('walletIntegrity')}: ${cert.certificateIntegrityHash.substring(0, 16)}...'
                      : '${context.tr('walletIntegrity')}: ${context.tr('walletNotAvailable')}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _verifyReferenceDialog(context, reference),
                icon: const Icon(Icons.verified_user_rounded, size: 18),
                label: Text(context.tr('walletValidate')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionIcon(
                Icons.qr_code_2_rounded,
                context.tr('walletVerifyQr'),
                () => _showQR(context, cert),
              ),
              _actionIcon(
                Icons.download_rounded,
                context.tr('walletDownload'),
                () => _downloadPDF(context, cert),
              ),
              _actionIcon(
                Icons.share_rounded,
                context.tr('walletShare'),
                () => _shareCertificate(cert),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQR(BuildContext context, Application cert) {
    final reference = cert.certificateReference.trim().isNotEmpty
        ? cert.certificateReference
        : cert.id;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('walletVerifyCertificate')),
        content: SizedBox(
          width: 200,
          height: 200,
          child: QrImageView(
            data:
                'ref=$reference|app=${cert.id}|hash=${cert.certificateIntegrityHash}',
            version: QrVersions.auto,
            size: 200.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _shareCertificate(Application cert) async {
    final link = cert.certificateDownloadUrl.trim();
    await SharePlus.instance.share(
      ShareParams(
        text: link.isNotEmpty
            ? 'My ${cert.serviceType} certificate: $link'
            : 'My ${cert.serviceType} Certificate: gov_ease_cert_${cert.id}',
      ),
    );
  }

  Future<void> _downloadPDF(BuildContext context, Application cert) async {
    final link = cert.certificateDownloadUrl.trim();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Header(level: 0, child: pw.Text('GovEase Certificate')),
                pw.Text(cert.serviceType, style: pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
                pw.Text('Reference: ${cert.id}'),
                pw.SizedBox(height: 40),
                pw.Text('This is a verified certificate issued by GovEase.'),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Certificate_${cert.id}.pdf',
    );
  }

  Future<void> _verifyReferenceDialog(BuildContext context, String seed) async {
    final controller = TextEditingController(text: seed);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('walletValidateCertificate')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: context.tr('walletCertificateReference'),
              hintText: 'CERT-APP-XXXX',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('close')),
            ),
            FilledButton(
              onPressed: () async {
                final ref = controller.text.trim();
                if (ref.isEmpty) return;

                final result = await firestoreService
                    .verifyCertificateReferenceSecure(ref);
                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);
                showDialog<void>(
                  context: context,
                  builder: (resultDialogContext) {
                    final valid = result?['verified'] == true;
                    final serviceType = (result?['serviceType'] ?? '')
                        .toString();
                    return AlertDialog(
                      title: Text(
                        valid
                            ? context.tr('walletCertificateVerified')
                            : context.tr('walletCertificateNotVerified'),
                      ),
                      content: Text(
                        valid
                            ? '${context.tr('walletReferenceValidFor')} $serviceType. ${context.tr('walletCertificateActive')}'
                            : context.tr('walletNoActiveCertificate'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(resultDialogContext),
                          child: Text(context.tr('done')),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Text(context.tr('walletValidate')),
            ),
          ],
        );
      },
    );
  }
}
