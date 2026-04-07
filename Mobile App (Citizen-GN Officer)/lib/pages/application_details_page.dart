import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../models/application.dart';
import '../models/service_type.dart';
import '../services/payment_service.dart';
import '../services/firestore_service.dart';
import '../widgets/gradient_page_app_bar.dart';
import '../utils/translation_util.dart';

class ApplicationDetailsPage extends StatelessWidget {
  final Application application;

  const ApplicationDetailsPage({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    final serviceType = getServiceType(application.serviceType);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: application.serviceType,
        subtitle: 'Application details and status',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reference and Status Card
            FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: _buildHeaderCard(),
            ),
            const SizedBox(height: 28),

            // Service Overview
            if (serviceType != null) ...[
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 100),
                child: _buildServiceOverview(serviceType),
              ),
              const SizedBox(height: 28),
            ],

            // Form Data
            if (application.formData.isNotEmpty) ...[
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 200),
                child: _buildFormDataSection(serviceType),
              ),
              const SizedBox(height: 28),
            ],

            // Uploaded Documents
            if (application.documentUrls.isNotEmpty) ...[
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 300),
                child: _buildDocumentsSection(serviceType),
              ),
              const SizedBox(height: 28),
            ],

            // Status Timeline
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 400),
              child: application.status.toLowerCase().contains('failed') ? _buildFailedPaymentCard(context, serviceType!) : _buildStatusTimeline(),
            ),
            const SizedBox(height: 28),
            
            // Officer Remarks
            if (application.officerRemarks.isNotEmpty) ...[
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 450),
                child: _buildOfficerRemarks(),
              ),
              const SizedBox(height: 28),
            ],

            // Action Buttons
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 500),
              child: _buildActionButtons(context),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedPaymentCard(BuildContext context, ServiceType service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
              const SizedBox(width: 12),
              Text(
                'Payment Failed',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF991B1B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your previous payment attempt was unsuccessful. Please check your payment method and try again to proceed with the application.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF7F1D1D),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final Map<String, String> userInfo = {
                  'firstName': application.formData['fullName']?.split(' ').first ?? 'Citizen',
                  'lastName': application.formData['fullName']?.split(' ').last ?? 'User',
                  'email': application.formData['email'] ?? 'test@example.com',
                  'phone': application.formData['phone'] ?? '0771234567',
                  'address': application.formData['address'] ?? 'Colombo 01',
                  'city': 'Colombo',
                };
                
                paymentService.startPayment(
                  context: context,
                  orderId: application.id,
                  amount: service.fee,
                  itemName: service.name,
                  userInfo: userInfo,
                  onSuccess: (paymentId) async {
                    // Update application status to Submitted since payment succeeded
                    final updatedData = {
                      'status': 'Submitted',
                      'paymentId': paymentId,
                      'updatedAt': DateTime.now().toIso8601String(),
                    };
                    await firestoreService.updateApplicationRef(application.id, updatedData);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful! Application submitted.')));
                    }
                  },
                  onDismissed: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment cancelled')));
                  },
                  onError: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
                  },
                );
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry Payment of LKR ${service.fee}'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    Color statusBg = AppColors.secondary.withAlpha(26);
    Color statusTxt = AppColors.secondary;
    String statusIcon = '⏳';

    if (application.status == 'Completed') {
      statusBg = const Color(0xFF28A745).withAlpha(26);
      statusTxt = const Color(0xFF28A745);
      statusIcon = '✓';
    } else if (application.status == 'Rejected') {
      statusBg = AppColors.destructive.withAlpha(26);
      statusTxt = AppColors.destructive;
      statusIcon = '✗';
    } else if (application.status == 'Pending Action') {
      statusBg = Colors.orangeAccent.withAlpha(26);
      statusTxt = Colors.orangeAccent;
      statusIcon = '!';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reference ID',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      application.id,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusTxt.withAlpha(100), width: 1),
                ),
                child: Row(
                  children: [
                    Text(
                      statusIcon,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: statusTxt,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      application.status,
                      style: GoogleFonts.inter(
                        color: statusTxt,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  'Submitted',
                  _formatDate(application.createdAt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoRow(
                  'Progress',
                  '${application.currentStep} / 4',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceOverview(ServiceType serviceType) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    serviceType.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Information',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      serviceType.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildDetailCard(
                  '💰 ${serviceType.fee}',
                  'Processing Fee',
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailCard(
                  '⏰ ${serviceType.processingTime}',
                  'Processing Time',
                  const Color(0xFF3558E1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(100), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormDataSection(ServiceType? serviceType) {
    final formFields = serviceType?.formFields ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          Text(
            'Submitted Information',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: formFields.map((field) {
              final value = application.formData[field.id] ?? 'Not provided';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildFormDataItem(field.label, value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormDataItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(ServiceType? serviceType) {
    final requiredDocs = serviceType?.requiredDocuments ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          Text(
            'Attached Documents',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: List.generate(application.documentUrls.length, (index) {
              final docKey = 'doc_$index';
              final docUrl = application.documentUrls[docKey];
              final docName = index < requiredDocs.length
                  ? requiredDocs[index]
                  : 'Document ${index + 1}';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDocumentItem(docName, docUrl, index),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(String name, String? url, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF28A745).withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF28A745).withAlpha(100),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF28A745).withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF28A745),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Uploaded • Document ${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF28A745).withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '✓ Attached',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF28A745),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerRemarks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Officer Remarks',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: TranslationUtil.translateForUser(application.officerRemarks),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('Translating...');
              }
              return Text(
                snapshot.data ?? application.officerRemarks,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.foreground,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final steps = ['Submitted', 'Verified', 'Processing', 'Finalized'];
    final currentStepIndex = application.currentStep - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          Text(
            'Application Progress',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(steps.length, (i) {
              final isCompleted = i < currentStepIndex;
              final isCurrent = i == currentStepIndex;

              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted || isCurrent
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    color: isCurrent
                                        ? Colors.white
                                        : AppColors.mutedForeground,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              steps[i],
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isCompleted
                                  ? 'Completed'
                                  : isCurrent
                                  ? 'In Progress'
                                  : 'Pending',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isCompleted
                                    ? const Color(0xFF28A745)
                                    : isCurrent
                                    ? AppColors.primary
                                    : AppColors.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (i < steps.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        top: 8,
                        bottom: 8,
                      ),
                      child: SizedBox(
                        height: 24,
                        child: VerticalDivider(
                          color: isCompleted
                              ? AppColors.primary
                              : AppColors.border,
                          width: 2,
                          thickness: 2,
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _shareApplication(context),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(
              'Share Application',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _exportAsPDF(context),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(
              'Download as PDF',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareApplication(BuildContext context) async {
    final text = '''
GovEase Application Details
Service: ${application.serviceType}
Reference ID: ${application.id}
''';
    await SharePlus.instance.share(ShareParams(text: text, subject: 'GovEase Application Status'));
  }

  Future<void> _exportAsPDF(BuildContext context) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text('GovEase Application Report')),
              pw.SizedBox(height: 20),
              pw.Text('Service: ${application.serviceType}', style: pw.TextStyle(fontSize: 18)),
              pw.Text('Reference ID: ${application.id}'),
              pw.Text('Status: ${application.status}'),
              pw.Text('Submitted: ${_formatDate(application.createdAt)}'),
              pw.Text('Progress: ${application.currentStep} / 4'),
              pw.SizedBox(height: 20),
              pw.Text('Form Data:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              for (var entry in application.formData.entries)
                pw.Text('${entry.key}: ${entry.value}'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'GovEase_Application_${application.id}.pdf',
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
