import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../localization/app_localizations.dart';
import '../../models/application.dart';
import '../../models/user_model.dart';
import '../../services/certificate_issue_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/officer_policy_utils.dart';
import '../../widgets/gradient_page_app_bar.dart';
import 'officer_shared_widgets.dart';

class OfficerApplicationsPage extends StatefulWidget {
  const OfficerApplicationsPage({super.key});

  @override
  State<OfficerApplicationsPage> createState() =>
      _OfficerApplicationsPageState();
}

class _OfficerApplicationsPageState extends State<OfficerApplicationsPage> {
  static const bool _allowScopeFallback = bool.fromEnvironment(
    'ALLOW_OFFICER_SCOPE_FALLBACK',
    defaultValue: false,
  );

  final TextEditingController _search = TextEditingController();

  String _statusFilter = 'all';
  String _sortBy = 'latest';
  final Set<String> _busyIds = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _normalizeAreaText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\bpradeshiya\s+sabha\b'), '')
        .replaceAll(RegExp(r'\bps\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _matchesOfficerScope(UserModel officer, UserModel citizen) {
    if (officer.role.toLowerCase() == 'admin') {
      return true;
    }

    final officerAreas = [
      officer.province,
      officer.district,
      officer.pradeshiyaSabha,
      officer.gramasewaWasama,
      officer.division,
    ].where((value) => value.trim().isNotEmpty).toList();

    if (officerAreas.isEmpty) {
      return false;
    }

    final citizenAreas = [
      citizen.province,
      citizen.district,
      citizen.pradeshiyaSabha,
      citizen.gramasewaWasama,
      citizen.division,
    ].where((value) => value.trim().isNotEmpty).toList();

    for (final officerArea in officerAreas) {
      final normalizedOfficerArea = _normalizeAreaText(officerArea);
      if (normalizedOfficerArea.isEmpty) continue;

      for (final citizenArea in citizenAreas) {
        if (_normalizeAreaText(citizenArea) == normalizedOfficerArea) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isCentralAuthorityService(String serviceType) {
    final normalized = serviceType.toLowerCase();
    return normalized.contains('passport') ||
        normalized.contains('driving license') ||
        normalized.contains('license renewal');
  }

  bool _isGnRelevantService(String serviceType) {
    return !_isCentralAuthorityService(serviceType);
  }

  List<Application> _applyFilters(
    List<Application> apps,
    Map<String, UserModel> usersById,
  ) {
    final query = _search.text.trim().toLowerCase();

    final filtered = apps.where((app) {
      final citizen = usersById[app.userId];
      final citizenName = citizen?.name.toLowerCase() ?? '';
      final citizenNic = citizen?.nic.toLowerCase() ?? '';
      final citizenArea = [
        citizen?.gramasewaWasama ?? '',
        citizen?.pradeshiyaSabha ?? '',
        citizen?.district ?? '',
      ].join(' ').toLowerCase();

      final matchesSearch =
          query.isEmpty ||
          app.serviceType.toLowerCase().contains(query) ||
          app.id.toLowerCase().contains(query) ||
          app.userId.toLowerCase().contains(query) ||
          citizenName.contains(query) ||
          citizenNic.contains(query) ||
          citizenArea.contains(query);

      final matchesStatus =
          _statusFilter == 'all' || app.status.toLowerCase() == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'oldest':
          return a.createdAt.compareTo(b.createdAt);
        case 'status':
          return a.status.toLowerCase().compareTo(b.status.toLowerCase());
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return filtered;
  }

  Future<void> _updateStatus(
    Application app,
    String nextStatus, {
    String? remarks,
  }) async {
    if (_busyIds.contains(app.id)) return;

    setState(() => _busyIds.add(app.id));
    try {
      await firestoreService.updateApplicationStatus(
        app.id,
        nextStatus,
        remarks: remarks,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('officerAppsStatusMoved'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${context.tr('error')}: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(app.id));
      }
    }
  }

  Future<void> _completeWithCertificate(
    Application app,
    UserModel? citizen, {
    required String remarks,
  }) async {
    if (_busyIds.contains(app.id)) return;

    setState(() => _busyIds.add(app.id));
    try {
      final officer = await firestoreService.getUser(
        firestoreService.currentUserId,
      );

      final issued = await certificateIssueService.issueCertificatePdf(
        application: app,
        citizen: citizen,
        approvedBy: officer?.name ?? 'GN Officer',
        remarks: remarks,
      );

      await firestoreService.updateApplicationStatus(
        app.id,
        'Completed',
        remarks: remarks,
      );

      await firestoreService.updateApplicationRef(app.id, {
        ...buildCertificateMetadataWrite(
          reference: issued.reference,
          downloadUrl: issued.downloadUrl,
          issuedAt: issued.issuedAt,
          integrityHash: issued.integrityHash,
        ),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('officerAppsCertificateIssued'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${context.tr('error')}: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(app.id));
      }
    }
  }

  Future<void> _bulkProcess(List<Application> visible) async {
    final candidates = visible
        .where(
          (a) =>
              a.status.toLowerCase() == 'submitted' ||
              a.status.toLowerCase() == 'processing' ||
              a.status.toLowerCase() == 'verified',
        )
        .toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('officerAppsNoPendingInView'))),
      );
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('officerAppsBulkAction')),
          content: Text(context.tr('officerAppsBulkActionPrompt')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('cancel')),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, 'reject'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive.withAlpha(20),
                foregroundColor: AppColors.destructive,
              ),
              child: Text(context.tr('officerAppsBulkReject')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'approve'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              child: Text(context.tr('officerAppsBulkComplete')),
            ),
          ],
        );
      },
    );

    if (action == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final citizens = await firestoreService.getCitizensStream().first;
      final usersById = <String, UserModel>{
        for (final user in citizens) user.id: user,
      };

      for (final app in candidates) {
        if (action == 'approve') {
          final officer = await firestoreService.getUser(
            firestoreService.currentUserId,
          );
          final issued = await certificateIssueService.issueCertificatePdf(
            application: app,
            citizen: usersById[app.userId],
            approvedBy: officer?.name ?? 'GN Officer',
            remarks: 'Completed via bulk GN processing.',
          );

          await firestoreService.updateApplicationStatus(
            app.id,
            'Completed',
            remarks: 'Completed via bulk GN processing.',
          );
          await firestoreService.updateApplicationRef(app.id, {
            'certificateGenerated': true,
            'certificateIssuedAt': issued.issuedAt.toIso8601String(),
            'certificateReference': issued.reference,
            'certificateDownloadUrl': issued.downloadUrl,
            'certificateIntegrityHash': issued.integrityHash,
          });
        } else {
          await firestoreService.updateApplicationStatus(
            app.id,
            'Rejected',
            remarks: 'Rejected via bulk GN processing.',
          );
        }
      }
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('officerAppsBulkDone'))));
  }

  Future<void> _exportCsv(
    List<Application> apps,
    Map<String, UserModel> usersById,
  ) async {
    if (apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('officerAppsNoDataExport'))),
      );
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.writeln(
      'Application ID,Service Type,Status,Citizen Name,Citizen NIC,Area,Created At',
    );

    for (final app in apps) {
      final citizen = usersById[app.userId];
      final name = (citizen?.name ?? 'Unknown').replaceAll(',', ' ');
      final nic = (citizen?.nic ?? '').replaceAll(',', ' ');
      final area = [
        citizen?.gramasewaWasama ?? '',
        citizen?.pradeshiyaSabha ?? '',
        citizen?.district ?? '',
      ].where((v) => v.trim().isNotEmpty).join(' | ').replaceAll(',', ' ');

      csv.writeln(
        '${app.id},${app.serviceType},${app.status},$name,$nic,$area,${app.createdAt.toIso8601String()}',
      );
    }

    await SharePlus.instance.share(
      ShareParams(
        text: csv.toString(),
        subject: 'GovEase GN Applications Export',
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return AppColors.warning;
      case 'processing':
      case 'verified':
        return AppColors.primary;
      case 'rejected':
        return AppColors.destructive;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: context.tr('officerAppsDeskTitle'),
        subtitle: context.tr('officerAppsDeskSubtitle'),
      ),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(firestoreService.currentUserId),
        builder: (context, officerSnapshot) {
          if (officerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final officer = officerSnapshot.data;
          if (officer == null) {
            return Center(
              child: Text(
                context.tr('officerProfileLoadError'),
                style: GoogleFonts.inter(color: AppColors.mutedForeground),
              ),
            );
          }

          return StreamBuilder<List<UserModel>>(
            stream: firestoreService.getCitizensStream(),
            builder: (context, usersSnapshot) {
              final citizens = usersSnapshot.data ?? const <UserModel>[];
              final usersById = <String, UserModel>{
                for (final user in citizens) user.id: user,
              };

              final officerDiv = officer.gramasewaWasama.isNotEmpty 
              ? officer.gramasewaWasama 
              : officer.division;

          return StreamBuilder<List<Application>>(
            stream: firestoreService.getAllApplications(gnDivision: officerDiv),
            builder: (context, appsSnapshot) {
              if (appsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

                  if (appsSnapshot.hasError) {
                    return Center(
                      child: Text(
                        context.tr('officerAppointmentsLoadError'),
                        style: GoogleFonts.inter(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    );
                  }

                  final all = appsSnapshot.data ?? const <Application>[];
                  final gnRelevant = all
                      .where((a) => _isGnRelevantService(a.serviceType))
                      .toList();

                  final scopedMatches = gnRelevant.where((app) {
                    final citizen = usersById[app.userId];
                    if (citizen == null) {
                      return officer.role.toLowerCase() == 'admin';
                    }
                    return _matchesOfficerScope(officer, citizen);
                  }).toList();

                  final fallbackToGn = OfficerScopePolicy.shouldUseFallback(
                    allowFallback: _allowScopeFallback,
                    isAdmin: officer.role.toLowerCase() == 'admin',
                    hasAnyRecords: gnRelevant.isNotEmpty,
                    hasScopedMatches: scopedMatches.isNotEmpty,
                  );

                  final incompleteAreaTaggedCitizens = gnRelevant.where((app) {
                    final citizen = usersById[app.userId];
                    if (citizen == null) {
                      return true;
                    }

                    final areaParts = [
                      citizen.province,
                      citizen.district,
                      citizen.pradeshiyaSabha,
                      citizen.gramasewaWasama,
                      citizen.division,
                    ];
                    return areaParts.every((value) => value.trim().isEmpty);
                  }).length;

                  final scoped = fallbackToGn ? gnRelevant : scopedMatches;
                  final visible = _applyFilters(scoped, usersById);

                  final submittedCount = scoped
                      .where((a) => a.status.toLowerCase() == 'submitted')
                      .length;
                  final processingCount = scoped
                      .where(
                        (a) =>
                            a.status.toLowerCase() == 'processing' ||
                            a.status.toLowerCase() == 'verified',
                      )
                      .length;
                  final completedCount = scoped
                      .where((a) => a.status.toLowerCase() == 'completed')
                      .length;
                  final overdueCount = scoped.where((a) {
                    final pending =
                        a.status.toLowerCase() == 'submitted' ||
                        a.status.toLowerCase() == 'processing' ||
                        a.status.toLowerCase() == 'verified';
                    return pending &&
                        DateTime.now().difference(a.createdAt).inDays >= 7;
                  }).length;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 450),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withAlpha(190),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(42),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('officerAppsCommandCenter'),
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fallbackToGn
                                    ? context.tr('officerAppsScopeFallback')
                                    : context.tr('officerAppsScopeAssigned'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withAlpha(210),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricTile(
                                      context.tr('submitted'),
                                      submittedCount,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricTile(
                                      context.tr('processing'),
                                      processingCount,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricTile(
                                      context.tr('completed'),
                                      completedCount,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricTile(
                                      context.tr('officerAppsOverdue'),
                                      overdueCount,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (incompleteAreaTaggedCitizens > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning.withAlpha(70),
                              ),
                            ),
                            child: Text(
                              '${context.tr('officerScopeDataQualityCheck')}: $incompleteAreaTaggedCitizens ${context.tr('officerAppsMissingAreaTags')} ${context.tr('officerScopeFallbackDisabledNotice')}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.foreground,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      FadeInUp(
                        duration: const Duration(milliseconds: 520),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: TextField(
                                  controller: _search,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: context.tr(
                                      'officerAppsSearchHint',
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: AppColors.primary,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (value) =>
                                  setState(() => _sortBy = value),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'latest',
                                  child: Text(
                                    '${context.tr('sortBy')}: ${context.tr('newestFirst')}',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'oldest',
                                  child: Text(
                                    '${context.tr('sortBy')}: ${context.tr('oldestFirst')}',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'status',
                                  child: Text(
                                    '${context.tr('sortBy')}: ${context.tr('sortStatus')}',
                                  ),
                                ),
                              ],
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OfficerFilterChip(
                            label: context.tr('all'),
                            active: _statusFilter == 'all',
                            onTap: () => setState(() => _statusFilter = 'all'),
                          ),
                          OfficerFilterChip(
                            label: context.tr('submitted'),
                            active: _statusFilter == 'submitted',
                            onTap: () =>
                                setState(() => _statusFilter = 'submitted'),
                          ),
                          OfficerFilterChip(
                            label: context.tr('processing'),
                            active: _statusFilter == 'processing',
                            onTap: () =>
                                setState(() => _statusFilter = 'processing'),
                          ),
                          OfficerFilterChip(
                            label: context.tr('verified'),
                            active: _statusFilter == 'verified',
                            onTap: () =>
                                setState(() => _statusFilter = 'verified'),
                          ),
                          OfficerFilterChip(
                            label: context.tr('completed'),
                            active: _statusFilter == 'completed',
                            onTap: () =>
                                setState(() => _statusFilter = 'completed'),
                          ),
                          OfficerFilterChip(
                            label: context.tr('rejected'),
                            active: _statusFilter == 'rejected',
                            onTap: () =>
                                setState(() => _statusFilter = 'rejected'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${visible.length} ${context.tr('applications')}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _exportCsv(visible, usersById),
                            icon: const Icon(Icons.download_rounded),
                            label: Text(context.tr('officerAppsExportCsv')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (visible.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 42,
                                color: AppColors.mutedForeground.withAlpha(150),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('officerAppsNoResults'),
                                style: GoogleFonts.inter(
                                  color: AppColors.mutedForeground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...visible.asMap().entries.map((entry) {
                          final index = entry.key;
                          final app = entry.value;
                          final busy = _busyIds.contains(app.id);
                          final citizen = usersById[app.userId];
                          final area = [
                            citizen?.gramasewaWasama ?? '',
                            citizen?.pradeshiyaSabha ?? '',
                            citizen?.district ?? '',
                          ].where((v) => v.trim().isNotEmpty).join(' • ');

                          return FadeInUp(
                            duration: const Duration(milliseconds: 420),
                            delay: Duration(milliseconds: 40 * (index % 6)),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      context.push(
                                        '/officer/application-review',
                                        extra: app,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withAlpha(18),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.description_rounded,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      app.serviceType,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppColors
                                                            .foreground,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      DateFormat.yMMMd()
                                                          .add_jm()
                                                          .format(
                                                            app.createdAt,
                                                          ),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .mutedForeground,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _statusColor(
                                                    app.status,
                                                  ).withAlpha(18),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  app.status,
                                                  style: GoogleFonts.inter(
                                                    color: _statusColor(
                                                      app.status,
                                                    ),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            '${context.tr('citizen')}: ${citizen?.name ?? context.tr('officerReviewUnknown')}',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.foreground,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${context.tr('nicNumber')}: ${citizen?.nic ?? '-'}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.mutedForeground,
                                            ),
                                          ),
                                          if (area.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '${context.tr('administrativeArea')}: $area',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              FilledButton.tonal(
                                                onPressed: busy
                                                    ? null
                                                    : () {
                                                        context.push(
                                                          '/officer/application-review',
                                                          extra: app,
                                                        );
                                                      },
                                                child: Text(
                                                  context.tr(
                                                    'officerAppsReview',
                                                  ),
                                                ),
                                              ),
                                              if (app.status.toLowerCase() ==
                                                  'submitted')
                                                FilledButton.tonal(
                                                  onPressed: busy
                                                      ? null
                                                      : () => _updateStatus(
                                                          app,
                                                          'Processing',
                                                          remarks:
                                                              'Taken for GN review.',
                                                        ),
                                                  child: Text(
                                                    context.tr(
                                                      'officerAppsStartReview',
                                                    ),
                                                  ),
                                                ),
                                              if (app.status.toLowerCase() ==
                                                      'processing' ||
                                                  app.status.toLowerCase() ==
                                                      'verified')
                                                FilledButton(
                                                  onPressed: busy
                                                      ? null
                                                      : () => _completeWithCertificate(
                                                          app,
                                                          citizen,
                                                          remarks:
                                                              'Approved by GN officer.',
                                                        ),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.success,
                                                  ),
                                                  child: Text(
                                                    context.tr(
                                                      'actionMarkCompleted',
                                                    ),
                                                  ),
                                                ),
                                              if (app.status.toLowerCase() !=
                                                      'completed' &&
                                                  app.status.toLowerCase() !=
                                                      'rejected')
                                                FilledButton.tonal(
                                                  onPressed: busy
                                                      ? null
                                                      : () => _updateStatus(
                                                          app,
                                                          'Rejected',
                                                          remarks:
                                                              'Rejected by GN officer.',
                                                        ),
                                                  style: FilledButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.destructive,
                                                    backgroundColor: AppColors
                                                        .destructive
                                                        .withAlpha(20),
                                                  ),
                                                  child: Text(
                                                    context.tr(
                                                      'officerAppsReject',
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (busy) ...[
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  context.tr('saving'),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .mutedForeground,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Builder(
        builder: (context) {
          return FloatingActionButton.extended(
            onPressed: () async {
              final officer = await firestoreService.getUser(
                firestoreService.currentUserId,
              );
              if (officer == null || !context.mounted) return;

              final citizens = await firestoreService.getCitizensStream().first;
              final usersById = <String, UserModel>{
                for (final user in citizens) user.id: user,
              };
              final apps = await firestoreService.getAllApplications().first;

              final gnRelevant = apps
                  .where((a) => _isGnRelevantService(a.serviceType))
                  .toList();
              final scoped = gnRelevant.where((app) {
                final citizen = usersById[app.userId];
                if (citizen == null) {
                  return officer.role.toLowerCase() == 'admin';
                }
                return _matchesOfficerScope(officer, citizen);
              }).toList();
              final visible = _applyFilters(scoped, usersById);

              if (!context.mounted) return;
              _bulkProcess(visible);
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(
              Icons.batch_prediction_rounded,
              color: Colors.white,
            ),
            label: Text(
              context.tr('officerAppsBulkAction'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(220),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
