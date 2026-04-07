import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../models/application.dart';
import '../services/firestore_service.dart';
import '../widgets/gradient_page_app_bar.dart';
import '../localization/app_localizations.dart';
import '../widgets/govease_shimmer_loader.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  String _selectedFilter = 'All';
  late Stream<List<Application>> _applicationsStream;

  @override
  void initState() {
    super.initState();
    _applicationsStream = firestoreService.getUserApplications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: context.tr('myApplicationsTitle'),
        subtitle: context.tr('myApplicationsSubtitle'),
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
      body: StreamBuilder<List<Application>>(
        stream: _applicationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: GovEaseShimmerLoader(isList: true, listCount: 4, height: 120),
            );
          }

          final apps = snapshot.data ?? [];
          final filteredApps = _applyFilter(apps);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: _buildHeaderCard(apps),
                ),
                const SizedBox(height: 20),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: _buildStatsRow(apps),
                ),
                const SizedBox(height: 18),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 100),
                  child: _buildFilterChips(apps),
                ),
                const SizedBox(height: 20),
                _buildApplicationsList(filteredApps),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(List<Application> apps) {
    final active = apps.where((a) => a.status != 'Completed').length;
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.assignment_rounded,
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
                  context.tr('everythingInOnePlace'),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('monitorSubmissionsProgress'),
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
                '$active',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                context.tr('active').toLowerCase(),
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
    );
  }

  Widget _buildFilterChips(List<Application> apps) {
    final filters = <String>['All', 'Submitted', 'Processing', 'Completed'];

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
              ? apps.length
              : apps.where((a) => a.status == filter).length;

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

  List<Application> _applyFilter(List<Application> apps) {
    if (_selectedFilter == 'All') return apps;
    return apps.where((app) => app.status == _selectedFilter).toList();
  }

  Widget _buildApplicationsList(List<Application> apps) {
    if (apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            context.tr('noApplicationsFound'),
            style: GoogleFonts.inter(color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    return Column(
      children: apps.asMap().entries.map((entry) {
        final index = entry.key;
        final app = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildApplicationItem(app, index),
        );
      }).toList(),
    );
  }

  Widget _buildStatsRow(List<Application> apps) {
    final total = apps.length;
    final done = apps.where((a) => a.status == 'Completed').length;
    final active = total - done;

    return Row(
      children: [
        _buildStatCard(context.tr('total'), '$total', AppColors.primary),
        const SizedBox(width: 12),
        _buildStatCard(context.tr('active'), '$active', AppColors.secondary),
        const SizedBox(width: 12),
        _buildStatCard(context.tr('done'), '$done', const Color(0xFF28A745)),
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

  Widget _buildApplicationItem(Application app, int index) {
    final title = app.serviceType;
    final id = 'Ref: ${app.id.substring(0, 8).toUpperCase()}';
    final status = app.status;
    final currentStep = app.currentStep;
    final createdAt = app.createdAt;

    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      delay: Duration(milliseconds: index * 100),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        id,
                        style: GoogleFonts.inter(
                          color: AppColors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusTag(status),
              ],
            ),
            const SizedBox(height: 24),
            _buildStepper(currentStep),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text(
                  '${context.tr('appliedOn')} ${_formatDate(createdAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      context.push('/applications/details', extra: app),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    context.tr('viewDetails'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color bg = AppColors.secondary.withAlpha(26);
    Color txt = AppColors.secondary;
    if (status == 'Completed') {
      bg = const Color(0xFF28A745).withAlpha(26);
      txt = const Color(0xFF28A745);
    }
    if (status == 'Rejected') {
      bg = AppColors.destructive.withAlpha(26);
      txt = AppColors.destructive;
    }
    if (status == 'Pending Action') {
      bg = Colors.orangeAccent.withAlpha(26);
      txt = Colors.orangeAccent;
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

  Widget _buildStepper(int currentStep) {
    final steps = [
      context.tr('submitted'),
      context.tr('verified'),
      context.tr('processing'),
      context.tr('finalizing'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (i) {
        bool isActive = i <= (currentStep - 1);
        bool isCurrent = i == (currentStep - 1);
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isActive ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(76),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? (i < (currentStep - 1)
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ))
                          : null,
                    ),
                  ),
                  if (i < 3)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isActive && i < (currentStep - 1)
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                steps[i],
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _localizedStatus(String status, BuildContext context) {
    switch (status) {
      case 'All':
        return context.tr('all');
      case 'Submitted':
        return context.tr('submitted');
      case 'Processing':
        return context.tr('processing');
      case 'Completed':
        return context.tr('completed');
      case 'Rejected':
        return context.tr('rejected');
      case 'Pending Action':
        return context.tr('pendingAction');
      default:
        return status;
    }
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
