import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../models/complaint.dart';
import '../services/firestore_service.dart';
import '../widgets/gradient_page_app_bar.dart';
import '../localization/app_localizations.dart';

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  String _selectedFilter = 'All';
  String _sortMode = 'newest';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: context.tr('complaints'),
        subtitle: context.tr('complaintsSubtitle'),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _selectedFilter = 'All';
            }),
            icon: const Icon(Icons.filter_alt_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: firestoreService.getUserComplaints(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final complaints = snapshot.data ?? [];
          final filteredComplaints = _applyFilter(complaints);
          final sortedComplaints = _applySort(filteredComplaints);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: _buildHeroBanner(context, complaints),
                ),
                const SizedBox(height: 18),
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: _buildStatsRow(complaints),
                ),
                const SizedBox(height: 18),
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 100),
                  child: _buildFilterChips(complaints),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader(context, context.tr('pastComplaints')),
                const SizedBox(height: 16),
                _buildComplaintsList(sortedComplaints),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, List<Complaint> complaints) {
    final openCount = complaints.where((c) => c.status == 'Open').length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2E8F), Color(0xFF3558E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(55),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.report_problem_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('raiseIssuesCleanly'),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('complaintsHeroSubtitle'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withAlpha(210),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$openCount',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    context.tr('open').toLowerCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withAlpha(210),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/complaints/new'),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                context.tr('lodgeNewComplaint'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonth(int month) {
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
    return months[month - 1];
  }

  Widget _buildStatsRow(List<Complaint> complaints) {
    final total = complaints.length;
    final open = complaints.where((c) => c.status == 'Open').length;
    final closed = complaints.where((c) => c.status == 'Closed').length;

    return Row(
      children: [
        _buildStatCard(context.tr('total'), '$total', AppColors.primary),
        const SizedBox(width: 12),
        _buildStatCard(context.tr('open'), '$open', AppColors.warning),
        const SizedBox(width: 12),
        _buildStatCard(
          context.tr('closed'),
          '$closed',
          const Color(0xFF28A745),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<Complaint> complaints) {
    final filters = <String>['All', 'Open', 'Inspected', 'Closed'];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          final count = filter == 'All'
              ? complaints.length
              : complaints.where((c) => c.status == filter).length;

          return ChoiceChip(
            label: Text('${_localizedStatus(filter, context)} ($count)'),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedFilter = filter),
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.foreground,
              fontSize: 12,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          tooltip: context.tr('sortBy'),
          initialValue: _sortMode,
          onSelected: (value) => setState(() => _sortMode = value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'newest',
              child: Text(context.tr('newestFirst')),
            ),
            PopupMenuItem(
              value: 'priority',
              child: Text(context.tr('priorityFirst')),
            ),
            PopupMenuItem(
              value: 'safety',
              child: Text(context.tr('safetyRiskFirst')),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sort_rounded,
                  size: 16,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text(
                  _sortMode == 'newest'
                      ? context.tr('newestFirst')
                      : _sortMode == 'priority'
                      ? context.tr('priorityFirst')
                      : context.tr('safetyRiskFirst'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintsList(List<Complaint> complaints) {
    if (complaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            context.tr('noComplaintsFound'),
            style: GoogleFonts.inter(color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    return Column(
      children: complaints.asMap().entries.map((entry) {
        final index = entry.key;
        final complaint = entry.value;
        final dateStr =
            '${complaint.createdAt.day} ${_getMonth(complaint.createdAt.month)} ${complaint.createdAt.year}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildComplaintItem(index, complaint, dateStr),
        );
      }).toList(),
    );
  }

  List<Complaint> _applyFilter(List<Complaint> complaints) {
    if (_selectedFilter == 'All') return complaints;
    return complaints.where((c) => c.status == _selectedFilter).toList();
  }

  List<Complaint> _applySort(List<Complaint> complaints) {
    final sorted = List<Complaint>.from(complaints);

    if (_sortMode == 'priority') {
      sorted.sort((a, b) {
        final p = _priorityWeight(
          b.priority,
        ).compareTo(_priorityWeight(a.priority));
        if (p != 0) return p;
        return b.createdAt.compareTo(a.createdAt);
      });
      return sorted;
    }

    if (_sortMode == 'safety') {
      sorted.sort((a, b) {
        if (a.isSafetyRisk == b.isSafetyRisk) {
          return b.createdAt.compareTo(a.createdAt);
        }
        return b.isSafetyRisk ? 1 : -1;
      });
      return sorted;
    }

    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  int _priorityWeight(String priority) {
    switch (priority) {
      case 'Critical':
        return 4;
      case 'High':
        return 3;
      case 'Medium':
        return 2;
      case 'Low':
        return 1;
      default:
        return 0;
    }
  }

  Widget _buildComplaintItem(int index, Complaint complaint, String date) {
    final title = complaint.title;
    final category = complaint.category;
    final status = complaint.status;

    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      delay: Duration(milliseconds: index * 100),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showComplaintDetails(context, complaint, date),
        child: Container(
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category == 'Infrastructure'
                          ? Icons.handyman_outlined
                          : Icons.electrical_services_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.foreground,
                          ),
                        ),
                        Text(
                          category,
                          style: GoogleFonts.inter(
                            color: AppColors.mutedForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (complaint.priority.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildPriorityTag(complaint.priority),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusTag(status),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${context.tr('lastUpdatedOn')} $date',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color bg = AppColors.secondary.withAlpha(26);
    Color txt = AppColors.secondary;
    if (status == 'Closed') {
      bg = const Color(0xFF28A745).withAlpha(26);
      txt = const Color(0xFF28A745);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _localizedStatus(status, context),
        style: GoogleFonts.inter(
          color: txt,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPriorityTag(String priority) {
    Color bg = Colors.orange.withAlpha(30);
    Color txt = Colors.orange.shade800;

    if (priority == 'Low') {
      bg = Colors.green.withAlpha(30);
      txt = Colors.green.shade800;
    } else if (priority == 'High') {
      bg = Colors.deepOrange.withAlpha(30);
      txt = Colors.deepOrange.shade700;
    } else if (priority == 'Critical') {
      bg = Colors.red.withAlpha(30);
      txt = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _localizedPriority(priority, context),
        style: GoogleFonts.inter(
          color: txt,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showComplaintDetails(
    BuildContext context,
    Complaint complaint,
    String date,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  complaint.title,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                _sheetRow(context.tr('category'), complaint.category),
                _sheetRow(
                  context.tr('status'),
                  _localizedStatus(complaint.status, context),
                ),
                _sheetRow(
                  context.tr('priority'),
                  _localizedPriority(complaint.priority, context),
                ),
                _sheetRow(context.tr('updated'), date),
                _sheetRow(context.tr('location'), complaint.location),
                _sheetRow(
                  context.tr('landmark'),
                  complaint.landmark.isEmpty ? '-' : complaint.landmark,
                ),
                _sheetRow(
                  context.tr('incidentDateTime'),
                  _formatIncidentDateTime(complaint.incidentDateTime),
                ),
                _sheetRow(
                  context.tr('safetyRisk'),
                  _yesNo(complaint.isSafetyRisk, context),
                ),
                _sheetRow(
                  context.tr('anonymous'),
                  _yesNo(complaint.isAnonymous, context),
                ),
                _sheetRow(
                  context.tr('followUpAllowed'),
                  _yesNo(complaint.allowFollowUp, context),
                ),
                _sheetRow(
                  context.tr('preferredContact'),
                  complaint.preferredContactMethod,
                ),
                _sheetRow(
                  context.tr('phone'),
                  complaint.contactPhone.isEmpty ? '-' : complaint.contactPhone,
                ),
                _sheetRow(
                  context.tr('email'),
                  complaint.contactEmail.isEmpty ? '-' : complaint.contactEmail,
                ),
                _sheetRow(
                  context.tr('affectedPeople'),
                  complaint.affectedPeople?.toString() ?? '-',
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('description'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  complaint.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (complaint.additionalDetails.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.tr('additionalDetails'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    complaint.additionalDetails,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      context.tr('close'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _yesNo(bool value, BuildContext context) =>
      value ? context.tr('yes') : context.tr('no');

  String _localizedPriority(String value, BuildContext context) {
    switch (value) {
      case 'Low':
        return context.tr('low');
      case 'Medium':
        return context.tr('medium');
      case 'High':
        return context.tr('high');
      case 'Critical':
        return context.tr('critical');
      default:
        return value;
    }
  }

  String _formatIncidentDateTime(DateTime? value) {
    if (value == null) return '-';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  Widget _sheetRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _localizedStatus(String status, BuildContext context) {
    switch (status) {
      case 'All':
        return context.tr('all');
      case 'Open':
        return context.tr('open');
      case 'Inspected':
        return context.tr('inspected');
      case 'Closed':
        return context.tr('closed');
      default:
        return status;
    }
  }
}
