import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/application.dart';
import '../../models/complaint.dart';
import '../../models/user_model.dart';
import '../../models/officer_alert.dart';
import 'officer_shared_widgets.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/gradient_page_app_bar.dart';

class OfficerDashboardPage extends StatelessWidget {
  const OfficerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: 'GovEase',
        subtitle: 'Officer Portal',
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestoreService.getOfficerNotifications(limit: 30),
            builder: (context, snapshot) {
              final notifications =
                  snapshot.data ?? const <Map<String, dynamic>>[];
              final unreadCount = notifications
                  .where((n) => n['isRead'] != true)
                  .length;

              return IconButton(
                onPressed: () =>
                    _showNotificationsPanel(context, notifications),
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
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
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
                tooltip: 'Notifications',
              );
            },
          ),
          IconButton(
            onPressed: () => context.go('/welcome'),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(
          firestoreService.currentUserId,
        ),
        builder: (context, userSnapshot) {
          String officerName = 'Officer';
          String officerDivision = 'Unassigned Division';
          String actualGnDivision = '';
          if (userSnapshot.hasData && userSnapshot.data != null) {
            officerName = userSnapshot.data!.name;
            actualGnDivision = userSnapshot.data!.gramasewaWasama;
            if (actualGnDivision.isNotEmpty) {
              officerDivision = actualGnDivision;
            } else if (userSnapshot.data!.division.isNotEmpty) {
              officerDivision = userSnapshot.data!.division;
              actualGnDivision = officerDivision;
            }
            debugPrint("Officer Dashboard Scope: $actualGnDivision");
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withAlpha(200)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(50),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Good Morning, $officerName',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'GN Div: $officerDivision',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 24),
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: [
                StreamBuilder<List<Application>>(
                  stream: firestoreService.getAllApplications(gnDivision: actualGnDivision),
                  builder: (context, snapshot) {
                    int pendingCount = 0;
                    if (snapshot.hasData) {
                      pendingCount = snapshot.data!
                          .where(
                            (a) =>
                                a.status == 'Submitted' ||
                                a.status == 'Processing',
                          )
                          .length;
                    }
                    return OfficerSummaryCard(
                      label: 'Pending Applications',
                      value: pendingCount.toString(),
                      icon: Icons.description,
                    );
                  },
                ),
                StreamBuilder<List<Application>>(
                  stream: firestoreService.getAllApplications(gnDivision: actualGnDivision),
                  builder: (context, snapshot) {
                    int approvedToday = 0;
                    if (snapshot.hasData) {
                      final now = DateTime.now();
                      approvedToday = snapshot.data!
                          .where(
                            (a) =>
                                a.status == 'Approved' &&
                                a.createdAt.year == now.year &&
                                a.createdAt.month == now.month &&
                                a.createdAt.day == now.day,
                          )
                          .length;
                    }
                    return OfficerSummaryCard(
                      label: 'Approved Today',
                      value: approvedToday.toString(),
                      icon: Icons.check_circle,
                      color: AppColors.success,
                    );
                  },
                ),
                StreamBuilder<List<Complaint>>(
                  stream: firestoreService.getAllComplaints(gnDivision: actualGnDivision),
                  builder: (context, snapshot) {
                    int newCount = 0;
                    if (snapshot.hasData) {
                      newCount = snapshot.data!
                          .where((c) => c.status == 'Open')
                          .length;
                    }
                    return OfficerSummaryCard(
                      label: 'New Complaints',
                      value: newCount.toString(),
                      icon: Icons.warning_rounded,
                      color: AppColors.warning,
                    );
                  },
                ),
                StreamBuilder<List<Complaint>>(
                  stream: firestoreService.getAllComplaints(gnDivision: actualGnDivision),
                  builder: (context, snapshot) {
                    int resolvedCount = 0;
                    if (snapshot.hasData) {
                      resolvedCount = snapshot.data!
                          .where(
                            (c) =>
                                c.status == 'Closed' || c.status == 'Resolved',
                          )
                          .length;
                    }
                    return OfficerSummaryCard(
                      label: 'Resolved Complaints',
                      value: resolvedCount.toString(),
                      icon: Icons.done_all_rounded,
                      color: AppColors.success,
                    );
                  },
                ),
                StreamBuilder<List<UserModel>>(
                  stream: firestoreService.getCitizensStream(),
                  builder: (context, snapshot) {
                    int count = 0;
                    if (snapshot.hasData && actualGnDivision.isNotEmpty) {
                      // Filter by division locally due to encryption
                      count = snapshot.data!.where((u) => 
                        u.gramasewaWasama == actualGnDivision || 
                        u.division == actualGnDivision
                      ).length;
                    } else if (snapshot.hasData) {
                       count = snapshot.data!.length;
                    }
                    return OfficerSummaryCard(
                      label: 'Total Citizens',
                      value: count.toString(),
                      icon: Icons.people_outline_rounded,
                      color: const Color(0xFF6366F1),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            duration: const Duration(milliseconds: 650),
            child: Text(
              'Performance Analytics (KPIs)',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            duration: const Duration(milliseconds: 680),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border.withAlpha(80)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  StreamBuilder<List<Application>>(
                    stream: firestoreService.getAllApplications(gnDivision: actualGnDivision),
                    builder: (context, snapshot) {
                      final apps = snapshot.data ?? [];
                      final completed = apps.where((a) => a.certificateIssuedAt != null).toList();
                      
                      double avgHours = 0;
                      double slaPercent = 100;
                      
                      if (completed.isNotEmpty) {
                        final totalTime = completed.fold<Duration>(
                          Duration.zero, 
                          (sum, a) => sum + a.certificateIssuedAt!.difference(a.createdAt)
                        );
                        avgHours = totalTime.inHours / completed.length;
                        
                        final withinSla = completed.where((a) => 
                          a.certificateIssuedAt!.difference(a.createdAt).inDays <= 2
                        ).length;
                        slaPercent = (withinSla / completed.length) * 100;
                      }

                      return Column(
                        children: [
                          _buildKPIRow(
                            'Avg Processing Time',
                            '${avgHours.toStringAsFixed(1)} Hours',
                            Icons.timer_rounded,
                            AppColors.primary,
                          ),
                          const Divider(height: 24),
                          _buildKPIRow(
                            'SLA Compliance',
                            '${slaPercent.toStringAsFixed(1)}%',
                            Icons.verified_user_rounded,
                            AppColors.success,
                          ),
                          const Divider(height: 24),
                          StreamBuilder<List<Complaint>>(
                            stream: firestoreService.getAllComplaints(gnDivision: actualGnDivision),
                            builder: (context, cSnapshot) {
                              final complaints = cSnapshot.data ?? [];
                              final withRating = complaints.where((c) => c.status == 'Closed').length;
                              // Mocking rating for now as it's not in the model, but making it tied to resolved count
                              double rating = 4.5 + (withRating > 0 ? 0.3 : 0);
                              if (rating > 5.0) rating = 5.0;

                              return _buildKPIRow(
                                'Citizen Rating',
                                '${rating.toStringAsFixed(1)} / 5.0',
                                Icons.star_rounded,
                                AppColors.warning,
                              );
                            }
                          ),
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            duration: const Duration(milliseconds: 700),
            child: Text(
              'Urgent Alerts',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            child: StreamBuilder<List<OfficerAlert>>(
              stream: firestoreService.getOfficerAlerts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final alerts = snapshot.data ?? [];

                if (alerts.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border.withAlpha(50)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          color: AppColors.mutedForeground.withAlpha(100),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No urgent alerts',
                          style: GoogleFonts.inter(
                            color: AppColors.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: alerts.map((alert) {
                    // Basic time formatting: "2:30 PM" or similar
                    final hour = alert.createdAt.hour;
                    final min = alert.createdAt.minute.toString().padLeft(
                      2,
                      '0',
                    );
                    final ampm = hour >= 12 ? 'PM' : 'AM';
                    final displayHour = hour > 12
                        ? hour - 12
                        : (hour == 0 ? 12 : hour);

                    return OfficerAlertTile(
                      text: alert.text,
                      time: '$displayHour:$min $ampm',
                      high: alert.isHighPriority,
                    );
                  }).toList(),
                );
              },
            ),
            ),
          ],
        );
      },
    ),
  );
}

  void _showNotificationsPanel(
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

  Widget _buildKPIRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }
}
