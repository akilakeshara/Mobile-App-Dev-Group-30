import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/application.dart';
import '../models/gn_appointment.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../localization/app_localizations.dart';
import 'gn_appointment_page.dart';
import 'waste_collection_schedule_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Stream<UserModel?> _userStream;
  late Stream<List<Application>> _headerApplicationsStream;
  late Stream<List<Application>> _activeApplicationsStream;
  late Stream<List<Map<String, dynamic>>> _notificationsStream;

  @override
  void initState() {
    super.initState();
    final uid = firestoreService.currentUserId;
    _userStream = firestoreService.getUserStream(uid);
    _headerApplicationsStream = firestoreService.getUserApplications();
    _activeApplicationsStream = firestoreService.getUserApplications();
    _notificationsStream = firestoreService.getCitizenNotifications(limit: 30);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 380 ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: _buildDateTimeCard(),
                  ),
                  const SizedBox(height: 14),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    child: _buildHeroOverviewCard(context),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 100),
                    child: _buildQuickActions(context),
                  ),
                  const SizedBox(height: 18),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 150),
                    child: _buildWasteCollectionCard(context),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 180),
                    child: _buildGnAppointmentCard(context),
                  ),
                  const SizedBox(height: 28),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 200),
                    child: _buildSectionHeader(
                      context,
                      context.tr('activeApplications'),
                      () => context.go('/applications'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 300),
                    child: _buildActiveApplications(context),
                  ),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeCard() {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final localeTag = Localizations.localeOf(context).toLanguageTag();
        final use24Hour = MediaQuery.of(context).alwaysUse24HourFormat;
        final timePattern = use24Hour ? 'HH:mm:ss' : 'hh:mm:ss a';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMMEEEEd(localeTag).format(now),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat(timePattern, localeTag).format(now),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatUtcOffset(now),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatUtcOffset(DateTime dateTime) {
    final offset = dateTime.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 8,
      shadowColor: AppColors.primary.withAlpha(80),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    const Color(0xFF2948C9),
                    const Color(0xFF1E3AA0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            // Decorative circles for professional look
            Positioned(
              right: -80,
              top: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: 30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -80,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 30,
              bottom: 20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Row(
          children: [
            Image.asset(
              'assets/images/GovEaseLoGo.png',
              height: 42,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.account_balance,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'GovEase',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 0.8,
                shadows: [
                  Shadow(
                    color: Colors.black.withAlpha(30),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _notificationsStream,
          builder: (context, snapshot) {
            final notifications =
                snapshot.data ?? const <Map<String, dynamic>>[];
            final unreadCount = notifications
                .where((n) => n['isRead'] != true)
                .length;

            return IconButton(
              onPressed: () => _showNotificationsSheet(context, notifications),
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 1,
                        top: 1,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 14),
                          height: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 18),
      ],
    );
  }

  Widget _buildHeroOverviewCard(BuildContext context) {
    final greeting = _greetingByTime();

    return StreamBuilder<UserModel?>(
      stream: _userStream,
      builder: (context, snapshot) {
        String name = 'Citizen';
        if (snapshot.hasData && snapshot.data != null) {
          name = snapshot.data!.name;
        }

        return StreamBuilder<List<Application>>(
          stream: _headerApplicationsStream,
          builder: (context, appSnapshot) {
            final apps = appSnapshot.data ?? const <Application>[];
            final total = apps.length;
            final processing = apps
                .where((app) => app.status != 'Completed')
                .length;
            final completed = apps
                .where((app) => app.status == 'Completed')
                .length;
            final completionRate = total == 0
                ? 0
                : ((completed / total) * 100).round();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B2E8F), Color(0xFF3558E1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(70),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _todayLabel(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.push('/services/certificate'),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(44),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(36, 36),
                          padding: const EdgeInsets.all(7),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    greeting,
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(220),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeroStat(
                          context.tr('applications'),
                          '$total',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHeroStat(
                          context.tr('inProgress'),
                          '$processing',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHeroStat(
                          context.tr('completion'),
                          '$completionRate%',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(220),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 760 ? 4 : 2;
    final actionAspect = width < 370
        ? 1.35
        : (crossAxisCount == 4 ? 1.9 : 1.55);

    final actions = [
      _QuickActionItem(
        title: context.tr('applyService'),
        subtitle: context.tr('certificateAndApprovals'),
        icon: Icons.description_outlined,
        iconBg: const Color(0xFFEAF0FF),
        iconColor: AppColors.primary,
        onTap: () => context.push('/services/certificate'),
      ),
      _QuickActionItem(
        title: context.tr('newComplaintTitleShort'),
        subtitle: context.tr('reportLocalIssue'),
        icon: Icons.report_problem_outlined,
        iconBg: const Color(0xFFFFF0EA),
        iconColor: const Color(0xFFE26627),
        onTap: () => context.push('/complaints/new'),
      ),
      _QuickActionItem(
        title: context.tr('trackStatus'),
        subtitle: context.tr('seeAllApplications'),
        icon: Icons.track_changes_outlined,
        iconBg: const Color(0xFFE9FAF3),
        iconColor: const Color(0xFF1D9F6E),
        onTap: () => context.go('/applications'),
      ),
      _QuickActionItem(
        title: context.tr('myProfile'),
        subtitle: context.tr('updateCitizenDetails'),
        icon: Icons.person_outline_rounded,
        iconBg: const Color(0xFFF1EEFF),
        iconColor: const Color(0xFF5B4CC4),
        onTap: () => context.go('/profile'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('quickActions'),
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('quickActionsSubtitle'),
          style: GoogleFonts.inter(
            color: AppColors.mutedForeground,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: actions.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: actionAspect,
          ),
          itemBuilder: (context, index) {
            final item = actions[index];
            return InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border.withAlpha(140)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.iconColor, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.mutedForeground,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FeaturePill(
              icon: Icons.security_outlined,
              label: context.tr('secureDocs'),
            ),
            _FeaturePill(
              icon: Icons.bolt_outlined,
              label: context.tr('fastUpdates'),
            ),
            _FeaturePill(
              icon: Icons.verified_outlined,
              label: context.tr('verifiedService'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWasteCollectionCard(BuildContext context) {
    final uid = firestoreService.currentUserId;

    return FutureBuilder<Map<String, dynamic>?>(
      future: firestoreService.getWasteCollectionScheduleForUser(uid),
      builder: (context, snapshot) {
        final schedule = snapshot.data;
        final entries = schedule == null
            ? const <Map<String, dynamic>>[]
            : List<Map<String, dynamic>>.from(schedule['entries'] ?? const []);
        final nextEntry = entries.isNotEmpty ? entries.first : null;
        final areaLabel = schedule?['areaLabel']?.toString().trim() ?? '';
        final route = schedule?['route']?.toString().trim() ?? '';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1D4ED8).withAlpha(34),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -24,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(10),
                  ),
                ),
              ),
              Positioned(
                left: 160,
                bottom: -28,
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyanAccent.withAlpha(12),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.delete_sweep_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('wasteCollectionTitle'),
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('wasteCollectionSubtitle'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withAlpha(220),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildWastePreviewPill(
                    icon: Icons.location_on_outlined,
                    label: areaLabel.isEmpty
                        ? context.tr('yourArea')
                        : areaLabel,
                  ),
                  const SizedBox(height: 10),
                  _buildWastePreviewPill(
                    icon: Icons.schedule_rounded,
                    label: nextEntry == null
                        ? context.tr('noWasteScheduleYet')
                        : _formatWastePreview(nextEntry),
                  ),
                  if (route.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildWastePreviewPill(
                      icon: Icons.alt_route_rounded,
                      label: route,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WasteCollectionSchedulePage(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1D4ED8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: Text(
                        context.tr('viewWasteSchedule'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGnAppointmentCard(BuildContext context) {
    return StreamBuilder<List<GnAppointment>>(
      stream: firestoreService.getUserGnAppointments(),
      builder: (context, snapshot) {
        final appointments = List<GnAppointment>.from(
          snapshot.data ?? const [],
        );
        appointments.sort((a, b) => a.preferredDate.compareTo(b.preferredDate));
        final upcomingAppointments = appointments.where((appointment) {
          final status = appointment.status.toLowerCase();
          return status != 'cancelled' &&
              status != 'canceled' &&
              status != 'completed';
        }).toList();
        final nextAppointment = upcomingAppointments.isNotEmpty
            ? upcomingAppointments.first
            : null;
        final upcomingCount = upcomingAppointments.length;
        final localeTag = Localizations.localeOf(context).toLanguageTag();

        void openAppointmentPage() {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const GnAppointmentPage(showUpcomingFirst: true),
            ),
          );
        }

        return GestureDetector(
          onTap: openAppointmentPage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF052E2B), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withAlpha(32),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -22,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(10),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.meeting_room_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('bookGnAppointment'),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('bookGnAppointmentSubtitle'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withAlpha(220),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildWastePreviewPill(
                      icon: Icons.schedule_rounded,
                      label: nextAppointment == null
                          ? context.tr('noAppointmentsYet')
                          : '${nextAppointment.referenceNumber} • ${DateFormat.yMMMd(localeTag).format(nextAppointment.preferredDate)}',
                    ),
                    const SizedBox(height: 10),
                    _buildWastePreviewPill(
                      icon: Icons.track_changes_rounded,
                      label:
                          '$upcomingCount ${context.tr('plannedAppointments')}',
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: openAppointmentPage,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          upcomingCount > 0
                              ? context.tr('upcomingAppointments')
                              : context.tr('bookAppointmentAction'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWastePreviewPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    VoidCallback onSeeAll,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            context.tr('seeAll'),
            style: GoogleFonts.inter(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveApplications(BuildContext context) {
    return StreamBuilder<List<Application>>(
      stream: _activeApplicationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final apps = snapshot.data ?? [];
        if (apps.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(22),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('noActiveApplicationsYet'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('startFirstRequest'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.mutedForeground,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 180,
                  child: ElevatedButton(
                    onPressed: () => context.push('/services/certificate'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.tr('applyNow'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final sortedApps = [...apps]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final recentApps = sortedApps.take(3).toList();

        return Column(
          children: recentApps.map((app) {
            final progress = (app.currentStep / 4.0).clamp(0.0, 1.0).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildApplicationCard(
                context: context,
                title: app.serviceType,
                id: 'Ref: ${_shortRef(app.id)}',
                status: app.status,
                progress: progress,
                createdAt: app.createdAt,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatWastePreview(Map<String, dynamic> entry) {
    final day = (entry['day'] ?? '').toString().trim();
    final time = (entry['time'] ?? '').toString().trim();
    final notes = (entry['notes'] ?? '').toString().trim();
    final parts = <String>[];
    if (day.isNotEmpty) parts.add(day);
    if (time.isNotEmpty) parts.add(time);
    final prefix = parts.isEmpty ? '' : parts.join(' • ');
    if (notes.isEmpty) {
      return prefix.isEmpty ? '' : prefix;
    }
    if (prefix.isEmpty) {
      return notes;
    }
    return '$prefix • $notes';
  }

  Widget _buildApplicationCard({
    required BuildContext context,
    required String title,
    required String id,
    required String status,
    required double progress,
    required DateTime createdAt,
  }) {
    final statusColor = _statusForeground(status);
    final statusBg = _statusBackground(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withAlpha(160)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    id,
                    style: GoogleFonts.inter(
                      color: AppColors.mutedForeground,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.mutedForeground.withAlpha(220),
              ),
              const SizedBox(width: 6),
              Text(
                'Updated ${_formatDate(createdAt)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/applications'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  'View',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  String _greetingByTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
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
    return '${date.day} ${months[date.month - 1]}';
  }

  String _shortRef(String id) {
    if (id.isEmpty) return 'N/A';
    final short = id.length <= 8 ? id : id.substring(0, 8);
    return short.toUpperCase();
  }

  Color _statusForeground(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF1D9F6E);
      case 'Processing':
        return AppColors.secondary;
      case 'Verified':
        return const Color(0xFF4B7BE5);
      case 'Submitted':
        return const Color(0xFFE57A2A);
      default:
        return AppColors.mutedForeground;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFFE9FAF3);
      case 'Processing':
        return const Color(0xFFE7F6FD);
      case 'Verified':
        return const Color(0xFFE9EEFF);
      case 'Submitted':
        return const Color(0xFFFFF3E8);
      default:
        return const Color(0xFFF1F3F6);
    }
  }

  void _showNotificationsSheet(
    BuildContext context,
    List<Map<String, dynamic>> notifications,
  ) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withAlpha(110),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        if (notifications.isEmpty) {
          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32), top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 30, offset: const Offset(0, 15)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(color: AppColors.mutedForeground.withAlpha(20), shape: BoxShape.circle),
                        child: Icon(Icons.notifications_off_rounded, color: AppColors.mutedForeground, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You\'re all caught up!',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.foreground),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No new alerts at the moment.',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedForeground, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withAlpha(30), blurRadius: 40, offset: const Offset(0, 20)),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 50, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text('Notifications', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.foreground)),
                          const Spacer(),
                          if (notifications.any((n) => n['isRead'] != true))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                '${notifications.where((n) => n['isRead'] != true).length} New',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          final isRead = item['isRead'] == true;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: isRead ? Colors.transparent : AppColors.primary.withAlpha(10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isRead ? Colors.transparent : AppColors.primary.withAlpha(30), width: 1),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                final id = item['id']?.toString();
                                if (id != null && id.isNotEmpty && !isRead) {
                                  await firestoreService.markNotificationAsRead(id);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isRead)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6, right: 12),
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                      ),
                                    if (isRead) const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title']?.toString() ?? 'Notification',
                                            style: GoogleFonts.inter(
                                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                                              fontSize: 15,
                                              color: isRead ? AppColors.foreground : AppColors.primary,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item['body']?.toString() ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: isRead ? AppColors.mutedForeground : const Color(0xFF4B5563),
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
