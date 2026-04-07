import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/application.dart';
import '../../services/firestore_service.dart';
import 'officer_shared_widgets.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class OfficerApplicationReviewPage extends StatefulWidget {
  const OfficerApplicationReviewPage({required this.application, super.key});

  final Application application;

  @override
  State<OfficerApplicationReviewPage> createState() =>
      _OfficerApplicationReviewPageState();
}

class _OfficerApplicationReviewPageState
    extends State<OfficerApplicationReviewPage> {
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    if (_status == 'approved') {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, size: 96, color: AppColors.success),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Application Approved',
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.foreground),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A secure QR-coded certificate has been generated and sent to the citizen app.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppColors.mutedForeground, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 15, offset: const Offset(0, 8)),
                        ],
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 80, color: AppColors.primary),
                          const SizedBox(height: 8),
                          Text('Certificate #${widget.application.id.substring(0, 8)}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to Applications'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Application Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: _officerSection(
              context,
              title: 'Citizen Details',
              child: Column(
                children: [
                  OfficerInfoRow(
                    label: 'Applicant ID',
                    value: widget.application.userId.isNotEmpty ? widget.application.userId.substring(0, 8) : 'Unknown',
                    icon: Icons.person_rounded,
                  ),
                  OfficerInfoRow(
                    label: 'Submitted Date',
                    value: widget.application.createdAt.toString().split(' ')[0],
                    icon: Icons.calendar_today_rounded,
                  ),
                  const OfficerInfoRow(
                    label: 'Contact Context',
                    value: 'View full profile for contact details',
                    icon: Icons.contact_page_rounded,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: _officerSection(
              context,
              title: 'Service Request',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.application.serviceType,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Data payload dynamically captured from submission forms. Data model varies per service type.',
                    style: GoogleFonts.inter(color: AppColors.mutedForeground, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 16),
          FadeInUp(
            duration: const Duration(milliseconds: 700),
            child: _officerSection(
              context,
              title: 'Uploaded Documents',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  OfficerDocChip(name: 'Identity Document', isImage: true),
                  OfficerDocChip(name: 'Supporting Proof'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            child: _officerSection(
              context,
              title: 'Officer Remarks',
              child: TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add comments or reasons for your decision...',
                  hintStyle: GoogleFonts.inter(color: AppColors.mutedForeground),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: widget.application.status == 'Submitted' || widget.application.status == 'Processing'
          ? FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, -5)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () async {
                            await firestoreService.updateApplicationStatus(widget.application.id, 'Rejected');
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.destructive.withAlpha(20),
                            foregroundColor: AppColors.destructive,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await firestoreService.updateApplicationStatus(widget.application.id, 'Approved');
                            setState(() => _status = 'approved');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text('Approve', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.destructive.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: AppColors.destructive,
                    ),
                    child: const Text(
                      'Application Rejected - Back to Applications',
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _officerSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withAlpha(100)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
