import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../localization/app_localizations.dart';
import '../../models/application.dart';
import '../../services/firestore_service.dart';
import '../../services/certificate_issue_service.dart';
import '../../utils/officer_policy_utils.dart';
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
  final _remarksController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  String _normalizeFieldKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<String> _serviceTemplateKeys(String serviceType) {
    final normalized = serviceType.toLowerCase();

    if (normalized.contains('birth')) {
      return [
        'fullname',
        'dateofbirth',
        'gender',
        'birthplace',
        'fathername',
        'mothername',
      ];
    }
    if (normalized.contains('death')) {
      return [
        'fullname',
        'dateofdeath',
        'placeofdeath',
        'causeofdeath',
        'reportername',
      ];
    }
    if (normalized.contains('marriage')) {
      return [
        'groomname',
        'bridename',
        'marriagedate',
        'marriageplace',
        'registrarname',
      ];
    }
    if (normalized.contains('nic')) {
      return ['fullname', 'nic', 'dateofbirth', 'address', 'occupation'];
    }

    return ['fullname', 'nic', 'phone', 'address', 'reason', 'notes'];
  }

  String _labelForField(String key) {
    const labels = <String, String>{
      'fullname': 'Full Name',
      'dateofbirth': 'Date of Birth',
      'dateofdeath': 'Date of Death',
      'birthplace': 'Birth Place',
      'placeofdeath': 'Place of Death',
      'causeofdeath': 'Cause of Death',
      'fathername': 'Father Name',
      'mothername': 'Mother Name',
      'groomname': 'Groom Name',
      'bridename': 'Bride Name',
      'marriagedate': 'Marriage Date',
      'marriageplace': 'Marriage Place',
      'registrarname': 'Registrar Name',
      'nic': 'NIC',
      'phone': 'Phone',
      'address': 'Address',
      'occupation': 'Occupation',
      'reason': 'Reason',
      'notes': 'Notes',
    };

    final normalized = _normalizeFieldKey(key);
    if (labels.containsKey(normalized)) {
      return labels[normalized]!;
    }

    final words = key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'));

    return words
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  List<MapEntry<String, String>> _structuredFormRows() {
    final data = widget.application.formData;
    if (data.isEmpty) {
      return const <MapEntry<String, String>>[];
    }

    final rows = <MapEntry<String, String>>[];
    final consumed = <String>{};
    final byNormalized = <String, MapEntry<String, String>>{};

    for (final entry in data.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      byNormalized[_normalizeFieldKey(entry.key)] = MapEntry(entry.key, value);
    }

    for (final templateKey in _serviceTemplateKeys(
      widget.application.serviceType,
    )) {
      final entry = byNormalized[templateKey];
      if (entry == null) continue;
      consumed.add(entry.key);
      rows.add(MapEntry(_labelForField(entry.key), entry.value));
    }

    for (final entry in data.entries) {
      if (consumed.contains(entry.key)) continue;
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      rows.add(MapEntry(_labelForField(entry.key), value));
    }

    return rows;
  }

  Future<void> _openDocument(String url) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      throw StateError('officerReviewInvalidDocumentUrl');
    }

    final launched = await launchUrl(
      parsed,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw StateError('officerReviewOpenDocumentFailed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final payloadRows = _structuredFormRows();
    final documentEntries = widget.application.documentUrls.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .toList();

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
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 96,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.tr('officerReviewApplicationApproved'),
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('officerReviewCertificateSent'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.mutedForeground,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(5),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.qr_code_2_rounded,
                            size: 80,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${context.tr('officerReviewCertificate')} #${widget.application.id.substring(0, 8)}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          context.tr('officerReviewBackToApplications'),
                        ),
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
        title: Text(
          context.tr('officerReviewApplicationDetails'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: _officerSection(
              context,
              title: context.tr('officerReviewCitizenDetails'),
              child: Column(
                children: [
                  OfficerInfoRow(
                    label: context.tr('officerReviewApplicantId'),
                    value: widget.application.userId.isNotEmpty
                        ? widget.application.userId.substring(0, 8)
                        : context.tr('officerReviewUnknown'),
                    icon: Icons.person_rounded,
                  ),
                  OfficerInfoRow(
                    label: context.tr('officerReviewSubmittedDate'),
                    value: widget.application.createdAt.toString().split(
                      ' ',
                    )[0],
                    icon: Icons.calendar_today_rounded,
                  ),
                  OfficerInfoRow(
                    label: context.tr('officerReviewContactContext'),
                    value: context.tr('officerReviewContactContextHint'),
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
              title: context.tr('officerReviewServiceRequest'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.application.serviceType,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (payloadRows.isEmpty)
                    Text(
                      context.tr('officerReviewNoPayloadFound'),
                      style: GoogleFonts.inter(
                        color: AppColors.mutedForeground,
                        height: 1.5,
                      ),
                    )
                  else
                    ...payloadRows.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OfficerInfoRow(
                          label: row.key,
                          value: row.value,
                          icon: Icons.label_rounded,
                        ),
                      ),
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
              title: context.tr('officerReviewUploadedDocuments'),
              child: documentEntries.isEmpty
                  ? Text(
                      context.tr('officerReviewNoDocumentsFound'),
                      style: GoogleFonts.inter(
                        color: AppColors.mutedForeground,
                        height: 1.4,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: documentEntries.map((entry) {
                        final label = _labelForField(entry.key);
                        final isImage = RegExp(
                          r'\.(png|jpg|jpeg|webp)$',
                          caseSensitive: false,
                        ).hasMatch(entry.value);

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            try {
                              await _openDocument(entry.value);
                            } catch (e) {
                              if (!context.mounted) return;
                              final errorKey = e is StateError
                                  ? e.message.toString()
                                  : 'officerReviewOpenDocumentFailed';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${context.tr('error')}: ${context.tr(errorKey)}',
                                  ),
                                ),
                              );
                            }
                          },
                          child: OfficerDocChip(name: label, isImage: isImage),
                        );
                      }).toList(),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            child: _officerSection(
              context,
              title: context.tr('officerReviewOfficerRemarks'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _remarksController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: context.tr('officerReviewRemarksHint'),
                      hintStyle: GoogleFonts.inter(
                        color: AppColors.mutedForeground,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: Text(
                          context.tr('officerReviewMissingDocs'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _remarksController.text = context.tr(
                          'officerReviewMissingDocsText',
                        ),
                      ),
                      ActionChip(
                        label: Text(
                          context.tr('officerReviewAddressMismatch'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _remarksController.text = context.tr(
                          'officerReviewAddressMismatchText',
                        ),
                      ),
                      ActionChip(
                        label: Text(
                          context.tr('officerReviewApprovedOk'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _remarksController.text = context.tr(
                          'officerReviewApprovedOkText',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet:
          widget.application.status == 'Submitted' ||
              widget.application.status == 'Processing'
          ? FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _isProcessing
                              ? null
                              : () async {
                                  setState(() => _isProcessing = true);
                                  await firestoreService
                                      .updateApplicationStatus(
                                        widget.application.id,
                                        'Rejected',
                                        remarks: _remarksController.text.trim(),
                                      );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.destructive.withAlpha(
                              20,
                            ),
                            foregroundColor: AppColors.destructive,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  context.tr('rejected'),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isProcessing
                              ? null
                              : () async {
                                  setState(() => _isProcessing = true);
                                  try {
                                    final officer = await firestoreService
                                        .getUser(
                                          firestoreService.currentUserId,
                                        );
                                    final citizen = await firestoreService
                                        .getCitizenByUid(
                                          widget.application.userId,
                                        );

                                    final issued = await certificateIssueService
                                        .issueCertificatePdf(
                                          application: widget.application,
                                          citizen: citizen,
                                          approvedBy:
                                              officer?.name ?? 'GN Officer',
                                          remarks: _remarksController.text
                                              .trim(),
                                        );

                                    await firestoreService
                                        .updateApplicationStatus(
                                          widget.application.id,
                                          'Completed',
                                          remarks: _remarksController.text
                                              .trim(),
                                        );
                                    await firestoreService.updateApplicationRef(
                                      widget.application.id,
                                      buildCertificateMetadataWrite(
                                        reference: issued.reference,
                                        downloadUrl: issued.downloadUrl,
                                        issuedAt: issued.issuedAt,
                                        integrityHash: issued.integrityHash,
                                      ),
                                    );

                                    if (!mounted) return;
                                    setState(() {
                                      _status = 'approved';
                                      _isProcessing = false;
                                    });
                                  } catch (e) {
                                    if (!mounted) return;
                                    setState(() => _isProcessing = false);
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${this.context.tr('error')}: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  context.tr('actionApprove'),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
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
                    child: Text(
                      '${context.tr('rejected')} - ${context.tr('officerReviewBackToApplications')}',
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
          BoxShadow(
            color: Colors.black.withAlpha(3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
