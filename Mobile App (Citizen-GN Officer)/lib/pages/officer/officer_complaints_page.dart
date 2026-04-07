import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../localization/app_localizations.dart';
import '../../models/complaint.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/officer_policy_utils.dart';
import '../../widgets/gradient_page_app_bar.dart';

class OfficerComplaintsPage extends StatefulWidget {
  const OfficerComplaintsPage({super.key});

  @override
  State<OfficerComplaintsPage> createState() => _OfficerComplaintsPageState();
}

class _OfficerComplaintsPageState extends State<OfficerComplaintsPage> {
  static const bool _allowScopeFallback = bool.fromEnvironment(
    'ALLOW_OFFICER_SCOPE_FALLBACK',
    defaultValue: false,
  );

  final TextEditingController _search = TextEditingController();

  String? _expandedId;
  String _statusFilter = 'all';
  String _priorityFilter = 'all';
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

  bool _matchesOfficerScope(UserModel officer, Complaint complaint) {
    if (officer.role.toLowerCase() == 'admin') {
      return true;
    }

    final officerDivision = officer.gramasewaWasama.isNotEmpty 
        ? officer.gramasewaWasama 
        : officer.division;

    if (officerDivision.isEmpty) {
      return false;
    }

    // Direct match with the new metadata field (Most reliable)
    if (complaint.gnDivision.isNotEmpty) {
       if (_normalizeAreaText(complaint.gnDivision) == _normalizeAreaText(officerDivision)) {
         return true;
       }
    }

    // Fallback: If gnDivision is missing (old records), check location text
    final officerAreas = [
      officer.province,
      officer.district,
      officer.pradeshiyaSabha,
      officerDivision,
    ].where((value) => value.trim().isNotEmpty).toList();

    final complaintText = _normalizeAreaText(
      '${complaint.location} ${complaint.landmark}',
    );
    
    if (complaintText.isNotEmpty) {
      for (final area in officerAreas) {
        final normalizedArea = _normalizeAreaText(area);
        if (normalizedArea.isEmpty) continue;
        if (complaintText.contains(normalizedArea) ||
            normalizedArea.contains(complaintText)) {
          return true;
        }
      }
    }

    return false;
  }

  List<Complaint> _applyFilters(List<Complaint> complaints) {
    final query = _search.text.trim().toLowerCase();

    final filtered = complaints.where((item) {
      final matchesSearch =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.id.toLowerCase().contains(query);

      final matchesStatus =
          _statusFilter == 'all' || item.status.toLowerCase() == _statusFilter;
      final matchesPriority =
          _priorityFilter == 'all' ||
          item.priority.toLowerCase() == _priorityFilter;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'oldest':
          return a.createdAt.compareTo(b.createdAt);
        case 'priority':
          return _priorityWeight(
            b.priority,
          ).compareTo(_priorityWeight(a.priority));
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return filtered;
  }

  int _priorityWeight(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      default:
        return 1;
    }
  }

  Future<void> _openMap(String locationQuery) async {
    if (locationQuery.trim().isEmpty) return;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationQuery)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callReporter(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.parse('tel:$trimmed');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _updateStatus(
    Complaint complaint,
    String newStatus, {
    String reason = '',
  }) async {
    if (_busyIds.contains(complaint.id)) return;

    setState(() => _busyIds.add(complaint.id));
    try {
      await firestoreService.updateComplaintStatus(
        complaint.id,
        newStatus,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('officerComplaintsStatusUpdated'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${context.tr('error')}: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(complaint.id));
      }
    }
  }

  Future<void> _exportReport(List<Complaint> complaints) async {
    if (complaints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('officerAppsNoDataExport'))),
      );
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.writeln(
      'Complaint ID,Category,Priority,Status,Title,Location,User ID,Created At',
    );

    for (final c in complaints) {
      final safeTitle = c.title.replaceAll(',', ' ');
      final safeLocation = c.location.replaceAll(',', ' ');
      csv.writeln(
        '${c.id},${c.category},${c.priority},${c.status},$safeTitle,$safeLocation,${c.userId},${c.createdAt.toIso8601String()}',
      );
    }

    await SharePlus.instance.share(
      ShareParams(text: csv.toString(), subject: 'GovEase Complaints Export'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: context.tr('officerComplaintsDeskTitle'),
        subtitle: context.tr('officerComplaintsDeskSubtitle'),
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

          final officerDiv = officer.gramasewaWasama.isNotEmpty 
              ? officer.gramasewaWasama 
              : officer.division;

          return StreamBuilder<List<Complaint>>(
            stream: firestoreService.getAllComplaints(gnDivision: officerDiv),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    context.tr('officerAppointmentsLoadError'),
                    style: GoogleFonts.inter(color: AppColors.mutedForeground),
                  ),
                );
              }

              final all = snapshot.data ?? const <Complaint>[];
              final scopedMatches = all
                  .where((item) => _matchesOfficerScope(officer, item))
                  .toList();
              final fallbackToAll = OfficerScopePolicy.shouldUseFallback(
                allowFallback: _allowScopeFallback,
                isAdmin: officer.role.toLowerCase() == 'admin',
                hasAnyRecords: all.isNotEmpty,
                hasScopedMatches: scopedMatches.isNotEmpty,
              );
              final scoped = fallbackToAll ? all : scopedMatches;
              final visible = _applyFilters(scoped);

              final incompleteLocationTags = all
                  .where(
                    (item) =>
                        item.location.trim().isEmpty &&
                        item.landmark.trim().isEmpty,
                  )
                  .length;

              final openCount = scoped
                  .where((c) => c.status.toLowerCase() == 'open')
                  .length;
              final activeCount = scoped
                  .where(
                    (c) =>
                        c.status.toLowerCase() == 'inspected' ||
                        c.status.toLowerCase() == 'in progress',
                  )
                  .length;
              final escalatedCount = scoped
                  .where((c) => c.status.toLowerCase() == 'escalated')
                  .length;
              final highPriority = scoped
                  .where((c) => c.priority.toLowerCase() == 'high')
                  .length;

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
                            color: AppColors.primary.withAlpha(40),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('officerComplaintsCommandCenter'),
                            style: GoogleFonts.outfit(
                              fontSize: 25,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${context.tr('officer')}: ${officer.name}',
                            style: GoogleFonts.inter(
                              color: Colors.white.withAlpha(220),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fallbackToAll
                                ? context.tr('officerComplaintsScopeFallback')
                                : context.tr('officerComplaintsScopeAssigned'),
                            style: GoogleFonts.inter(
                              color: Colors.white.withAlpha(205),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricTile(
                                  context.tr('open'),
                                  openCount,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMetricTile(
                                  context.tr('inProgress'),
                                  activeCount,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMetricTile(
                                  context.tr('officerComplaintsEscalated'),
                                  escalatedCount,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMetricTile(
                                  context.tr('officerComplaintsHighPriority'),
                                  highPriority,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (incompleteLocationTags > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warning.withAlpha(70),
                        ),
                      ),
                      child: Text(
                        '${context.tr('officerScopeDataQualityCheck')}: $incompleteLocationTags ${context.tr('officerComplaintsMissingLocationTags')} ${context.tr('officerScopeFallbackDisabledNotice')}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.foreground,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
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
                                  'officerComplaintsSearchHint',
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: AppColors.primary,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
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
                              value: 'priority',
                              child: Text(
                                '${context.tr('sortBy')}: ${context.tr('highestPriority')}',
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
                      _buildFilterChip(
                        context.tr('all'),
                        _statusFilter == 'all',
                        () => setState(() => _statusFilter = 'all'),
                      ),
                      _buildFilterChip(
                        context.tr('open'),
                        _statusFilter == 'open',
                        () => setState(() => _statusFilter = 'open'),
                      ),
                      _buildFilterChip(
                        context.tr('inspected'),
                        _statusFilter == 'inspected',
                        () => setState(() => _statusFilter = 'inspected'),
                      ),
                      _buildFilterChip(
                        context.tr('officerComplaintsEscalated'),
                        _statusFilter == 'escalated',
                        () => setState(() => _statusFilter = 'escalated'),
                      ),
                      _buildFilterChip(
                        context.tr('closed'),
                        _statusFilter == 'closed',
                        () => setState(() => _statusFilter = 'closed'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPriorityChip(context.tr('anyPriority'), 'all'),
                      _buildPriorityChip(context.tr('high'), 'high'),
                      _buildPriorityChip(context.tr('medium'), 'medium'),
                      _buildPriorityChip(context.tr('low'), 'low'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${visible.length} ${context.tr('complaints')} ${context.tr('status')}'
                              .replaceAll(
                                'status',
                                context.tr('officerComplaintsFound'),
                              ),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _exportReport(visible),
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
                            Icons.search_off_rounded,
                            size: 42,
                            color: AppColors.mutedForeground.withAlpha(150),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('officerComplaintsNoMatch'),
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
                      final item = entry.value;
                      return FadeInUp(
                        duration: const Duration(milliseconds: 420),
                        delay: Duration(milliseconds: 40 * (index % 6)),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildComplaintCard(item),
                        ),
                      );
                    }),
                ],
              );
            },
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
              fontSize: 19,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: Colors.white.withAlpha(220),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool active, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withAlpha(28),
      labelStyle: GoogleFonts.inter(
        color: active ? AppColors.primary : AppColors.foreground,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildPriorityChip(String label, String value) {
    final selected = _priorityFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _priorityFilter = value),
      selectedColor: AppColors.secondary.withAlpha(24),
      labelStyle: GoogleFonts.inter(
        color: selected ? AppColors.secondary : AppColors.foreground,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildComplaintCard(Complaint item) {
    final expanded = _expandedId == item.id;
    final busy = _busyIds.contains(item.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: expanded ? AppColors.primary.withAlpha(90) : AppColors.border,
          width: expanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        key: ValueKey(item.id),
        initiallyExpanded: expanded,
        onExpansionChanged: (open) {
          setState(() {
            _expandedId = open ? item.id : null;
          });
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _statusColor(item.status).withAlpha(18),
          child: Icon(
            _statusIcon(item.status),
            color: _statusColor(item.status),
          ),
        ),
        title: Text(
          item.title.isEmpty ? item.description : item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge(item.status, _statusColor(item.status)),
              _buildBadge(item.priority, _priorityColor(item.priority)),
              if (item.isSafetyRisk)
                _buildBadge(context.tr('safetyRisk'), const Color(0xFFDC2626)),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildInfoLine(
            Icons.category_rounded,
            '${item.category} ${context.tr('complaintTitle').toLowerCase()}',
          ),
          const SizedBox(height: 8),
          _buildInfoLine(
            Icons.schedule_rounded,
            DateFormat.yMMMd().add_jm().format(item.createdAt),
          ),
          const SizedBox(height: 8),
          _buildInfoLine(Icons.location_on_rounded, item.location),
          if (item.landmark.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoLine(
              Icons.place_rounded,
              '${context.tr('landmark')}: ${item.landmark}',
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.foreground,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: busy ? null : () => _openMap(item.location),
                icon: const Icon(Icons.map_rounded),
                label: Text(context.tr('officerComplaintsMap')),
              ),
              if (!item.isAnonymous && item.contactPhone.trim().isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: busy
                      ? null
                      : () => _callReporter(item.contactPhone),
                  icon: const Icon(Icons.call_rounded),
                  label: Text(context.tr('officerComplaintsCall')),
                ),
              if ((item.status.toLowerCase() == 'open') && !busy)
                FilledButton.tonal(
                  onPressed: () => _updateStatus(
                    item,
                    'Inspected',
                    reason: 'Marked inspected after field review.',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warning.withAlpha(25),
                    foregroundColor: AppColors.warning,
                  ),
                  child: Text(context.tr('officerComplaintsMarkInspected')),
                ),
              if (item.status.toLowerCase() != 'closed' && !busy)
                FilledButton.tonal(
                  onPressed: () => _updateStatus(
                    item,
                    'Escalated',
                    reason: 'Escalated for higher-level handling.',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626).withAlpha(22),
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: Text(context.tr('officerComplaintsEscalate')),
                ),
              if (item.status.toLowerCase() != 'closed' && !busy)
                FilledButton(
                  onPressed: () => _updateStatus(
                    item,
                    'Closed',
                    reason: 'Complaint resolved and closed by officer.',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: Text(context.tr('close')),
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('saving'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.error_outline_rounded;
      case 'inspected':
      case 'in progress':
        return Icons.search_rounded;
      case 'escalated':
        return Icons.priority_high_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return AppColors.warning;
      case 'inspected':
      case 'in progress':
        return AppColors.primary;
      case 'escalated':
        return const Color(0xFFDC2626);
      default:
        return AppColors.success;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF0F766E);
    }
  }
}
