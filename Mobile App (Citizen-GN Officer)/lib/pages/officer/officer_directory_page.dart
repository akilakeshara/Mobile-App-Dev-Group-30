import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../models/application.dart';
import '../../models/complaint.dart';
import '../../models/gn_appointment.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/gradient_page_app_bar.dart';

class OfficerDirectoryPage extends StatefulWidget {
  const OfficerDirectoryPage({super.key});

  @override
  State<OfficerDirectoryPage> createState() => _OfficerDirectoryPageState();
}

class _OfficerDirectoryPageState extends State<OfficerDirectoryPage> {
  final TextEditingController _search = TextEditingController();
  String? _expandedId;
  String _sortBy = 'name';

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

  String _scopeLabel(UserModel officer) {
    if (officer.role.toLowerCase() == 'admin') {
      return 'All areas (Admin scope)';
    }

    final parts = [
      officer.gramasewaWasama,
      officer.pradeshiyaSabha,
      officer.district,
      officer.province,
    ].where((value) => value.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return 'No area assignment found';
    }

    return parts.join(' • ');
  }

  List<UserModel> _applySearchAndSort(List<UserModel> users) {
    final query = _search.text.trim().toLowerCase();
    final filtered = users.where((u) {
      if (query.isEmpty) return true;
      final areaText = [
        u.gramasewaWasama,
        u.pradeshiyaSabha,
        u.district,
        u.province,
      ].join(' ').toLowerCase();
      return u.name.toLowerCase().contains(query) ||
          u.nic.toLowerCase().contains(query) ||
          u.phone.toLowerCase().contains(query) ||
          areaText.contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'recent':
          return b.createdAt.compareTo(a.createdAt);
        case 'oldest':
          return a.createdAt.compareTo(b.createdAt);
        case 'nic':
          return a.nic.toLowerCase().compareTo(b.nic.toLowerCase());
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: 'Citizen Directory',
        subtitle: 'Real-time citizen records by your assigned area',
      ),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(firestoreService.currentUserId),
        builder: (context, officerSnapshot) {
          final officer = officerSnapshot.data;

          if (officerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (officer == null) {
            return Center(
              child: Text(
                'Unable to load officer profile.',
                style: GoogleFonts.inter(color: AppColors.mutedForeground),
              ),
            );
          }

          return StreamBuilder<List<UserModel>>(
            stream: firestoreService.getCitizensStream(),
            builder: (context, usersSnapshot) {
              final allUsers = usersSnapshot.data ?? [];
              final scopedUsers = allUsers
                  .where((user) => _matchesOfficerScope(officer, user))
                  .toList();
              final filtered = _applySearchAndSort(scopedUsers);
              final withPhone = scopedUsers
                  .where((u) => u.phone.trim().isNotEmpty)
                  .length;
              final joinedThisMonth = scopedUsers
                  .where(
                    (u) =>
                        u.createdAt.year == DateTime.now().year &&
                        u.createdAt.month == DateTime.now().month,
                  )
                  .length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
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
                            color: AppColors.primary.withAlpha(45),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Citizen Intelligence Desk',
                            style: GoogleFonts.outfit(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Assigned Officer: ${officer.name}',
                            style: GoogleFonts.inter(
                              color: Colors.white.withAlpha(220),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scope: ${_scopeLabel(officer)}',
                            style: GoogleFonts.inter(
                              color: Colors.white.withAlpha(210),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _metricTile(
                                  'Total Citizens',
                                  scopedUsers.length.toString(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _metricTile(
                                  'With Phone',
                                  withPhone.toString(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _metricTile(
                                  'Joined This Month',
                                  joinedThisMonth.toString(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
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
                                hintText: 'Search by name, NIC, phone, or area',
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
                        const SizedBox(width: 10),
                        PopupMenuButton<String>(
                          onSelected: (value) =>
                              setState(() => _sortBy = value),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'name',
                              child: Text('Sort: Name A-Z'),
                            ),
                            PopupMenuItem(
                              value: 'nic',
                              child: Text('Sort: NIC'),
                            ),
                            PopupMenuItem(
                              value: 'recent',
                              child: Text('Sort: Recently Joined'),
                            ),
                            PopupMenuItem(
                              value: 'oldest',
                              child: Text('Sort: Oldest First'),
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
                  const SizedBox(height: 16),
                  Text(
                    '${filtered.length} matched records',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.manage_search_rounded,
                            size: 44,
                            color: AppColors.mutedForeground.withAlpha(150),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No citizens found in your current scope.',
                            style: GoogleFonts.inter(
                              color: AppColors.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filtered.asMap().entries.map((entry) {
                      final index = entry.key;
                      final user = entry.value;
                      final isExpanded = _expandedId == user.id;
                      final joined =
                          '${user.createdAt.day.toString().padLeft(2, '0')}/${user.createdAt.month.toString().padLeft(2, '0')}/${user.createdAt.year}';
                      final area = [
                        user.gramasewaWasama,
                        user.pradeshiyaSabha,
                        user.district,
                        user.province,
                      ].where((value) => value.trim().isNotEmpty).join(' • ');

                      return FadeInUp(
                        duration: const Duration(milliseconds: 420),
                        delay: Duration(milliseconds: 40 * (index % 6)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isExpanded
                                  ? AppColors.primary.withAlpha(100)
                                  : AppColors.border.withAlpha(60),
                              width: isExpanded ? 2 : 1,
                            ),
                          ),
                          child: ExpansionTile(
                            key: ValueKey(user.id),
                            initiallyExpanded: isExpanded,
                            onExpansionChanged: (open) {
                              setState(() {
                                _expandedId = open ? user.id : null;
                              });
                            },
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary.withAlpha(18),
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.outfit(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            title: Text(
                              user.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.foreground,
                              ),
                            ),
                            subtitle: Text(
                              'NIC: ${user.nic}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              20,
                              0,
                              20,
                              18,
                            ),
                            children: [
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              _buildDetailRow(
                                Icons.phone_rounded,
                                'Phone',
                                user.phone.isEmpty ? '-' : user.phone,
                              ),
                              const SizedBox(height: 10),
                              _buildDetailRow(
                                Icons.location_on_rounded,
                                'Area',
                                area.isEmpty ? '-' : area,
                              ),
                              const SizedBox(height: 10),
                              _buildDetailRow(
                                Icons.calendar_today_rounded,
                                'Joined',
                                joined,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.tonal(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: user.nic),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'NIC copied to clipboard',
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Copy NIC'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.tonal(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: user.phone),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Phone copied to clipboard',
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Copy Phone'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () =>
                                      _showCitizenProfileDesk(context, user),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                  child: const Text('Open Profile Desk'),
                                ),
                              ),
                            ],
                          ),
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

  void _showCitizenProfileDesk(BuildContext context, UserModel citizen) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: StreamBuilder<List<Application>>(
                stream: firestoreService.getAllApplications(),
                builder: (context, appsSnapshot) {
                  final userApps =
                      (appsSnapshot.data ?? const <Application>[])
                          .where((a) => a.userId == citizen.id)
                          .toList()
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return StreamBuilder<List<Complaint>>(
                    stream: firestoreService.getAllComplaints(),
                    builder: (context, complaintsSnapshot) {
                      final userComplaints =
                          (complaintsSnapshot.data ?? const <Complaint>[])
                              .where((c) => c.userId == citizen.id)
                              .toList()
                            ..sort(
                              (a, b) => b.createdAt.compareTo(a.createdAt),
                            );

                      return StreamBuilder<List<GnAppointment>>(
                        stream: firestoreService.getOfficerGnAppointments(),
                        builder: (context, gnSnapshot) {
                          final userAppointments =
                              (gnSnapshot.data ?? const <GnAppointment>[])
                                  .where((g) => g.userId == citizen.id)
                                  .toList()
                                ..sort(
                                  (a, b) => b.createdAt.compareTo(a.createdAt),
                                );

                          final totalActivities =
                              userApps.length +
                              userComplaints.length +
                              userAppointments.length;

                          return ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                            children: [
                              Center(
                                child: Container(
                                  width: 44,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppColors.primary
                                        .withAlpha(20),
                                    child: Text(
                                      citizen.name.isNotEmpty
                                          ? citizen.name[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.outfit(
                                        color: AppColors.primary,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          citizen.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.foreground,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'NIC: ${citizen.nic}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildDeskPill(
                                    Icons.call_rounded,
                                    citizen.phone.isEmpty ? '-' : citizen.phone,
                                  ),
                                  _buildDeskPill(
                                    Icons.location_on_rounded,
                                    [
                                              citizen.gramasewaWasama,
                                              citizen.pradeshiyaSabha,
                                              citizen.district,
                                              citizen.province,
                                            ]
                                            .where(
                                              (value) =>
                                                  value.trim().isNotEmpty,
                                            )
                                            .join(' • ')
                                            .isEmpty
                                        ? '-'
                                        : [
                                                citizen.gramasewaWasama,
                                                citizen.pradeshiyaSabha,
                                                citizen.district,
                                                citizen.province,
                                              ]
                                              .where(
                                                (value) =>
                                                    value.trim().isNotEmpty,
                                              )
                                              .join(' • '),
                                  ),
                                  _buildDeskPill(
                                    Icons.badge_rounded,
                                    'Total activities: $totalActivities',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDeskSection(
                                title: 'Recent Applications',
                                count: userApps.length,
                                emptyLabel: 'No applications submitted yet.',
                                children: userApps
                                    .take(4)
                                    .map(
                                      (app) => _buildDeskActivityTile(
                                        icon: Icons.description_rounded,
                                        title: app.serviceType,
                                        subtitle:
                                            'Created ${DateFormat.yMMMd().add_jm().format(app.createdAt)}',
                                        status: app.status,
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                              _buildDeskSection(
                                title: 'Recent Complaints',
                                count: userComplaints.length,
                                emptyLabel: 'No complaints submitted yet.',
                                children: userComplaints
                                    .take(4)
                                    .map(
                                      (item) => _buildDeskActivityTile(
                                        icon: Icons.report_problem_rounded,
                                        title: item.title,
                                        subtitle:
                                            '${item.category} • ${DateFormat.yMMMd().add_jm().format(item.createdAt)}',
                                        status: item.status,
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                              _buildDeskSection(
                                title: 'GN Appointments',
                                count: userAppointments.length,
                                emptyLabel: 'No GN appointments found.',
                                children: userAppointments
                                    .take(4)
                                    .map(
                                      (item) => _buildDeskActivityTile(
                                        icon: Icons.event_available_rounded,
                                        title: item.referenceNumber,
                                        subtitle:
                                            '${item.subject} • ${DateFormat.yMMMd().format(item.preferredDate)}',
                                        status: item.status,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeskPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.mutedForeground),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeskSection({
    required String title,
    required int count,
    required String emptyLabel,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            Text(
              emptyLabel,
              style: GoogleFonts.inter(
                color: AppColors.mutedForeground,
                fontSize: 12.5,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _buildDeskActivityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusBadge(status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.toLowerCase();
    Color color;
    if (normalized.contains('approved') || normalized.contains('completed')) {
      color = const Color(0xFF16A34A);
    } else if (normalized.contains('processing') ||
        normalized.contains('progress') ||
        normalized.contains('rescheduled')) {
      color = const Color(0xFF2563EB);
    } else if (normalized.contains('declined') ||
        normalized.contains('cancel') ||
        normalized.contains('closed')) {
      color = const Color(0xFFDC2626);
    } else {
      color = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(220),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: AppColors.mutedForeground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
