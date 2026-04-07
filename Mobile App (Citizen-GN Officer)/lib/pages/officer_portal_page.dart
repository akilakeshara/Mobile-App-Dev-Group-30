import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

import '../theme/app_theme.dart';
import 'officer/officer_applications_page.dart';
import 'officer/officer_complaints_page.dart';
import 'officer/officer_gn_appointments_page.dart';
import 'officer/officer_dashboard_page.dart';
import 'officer/officer_directory_page.dart';

class OfficerPortalPage extends StatefulWidget {
  const OfficerPortalPage({super.key});

  @override
  State<OfficerPortalPage> createState() => _OfficerPortalPageState();
}

class _OfficerPortalPageState extends State<OfficerPortalPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final compactNav = screenWidth < 430;

    final pages = [
      const OfficerDashboardPage(),
      const OfficerApplicationsPage(),
      const OfficerComplaintsPage(),
      const OfficerGnAppointmentsPage(),
      const OfficerDirectoryPage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withAlpha(20), AppColors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: SizedBox(key: ValueKey<int>(_index), child: pages[_index]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compactNav ? 10 : 16,
              vertical: compactNav ? 6 : 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(
                  0,
                  Icons.dashboard_rounded,
                  'Dashboard',
                  compactNav,
                ),
                _buildNavItem(1, Icons.description_rounded, 'Apps', compactNav),
                _buildNavItem(
                  2,
                  Icons.location_on_rounded,
                  'Complaints',
                  compactNav,
                ),
                _buildNavItem(
                  3,
                  Icons.event_available_rounded,
                  'Appointments',
                  compactNav,
                ),
                _buildNavItem(4, Icons.people_rounded, 'Directory', compactNav),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool compactNav,
  ) {
    bool isSelected = _index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _index = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.symmetric(
            horizontal: compactNav ? 0 : 10,
            vertical: compactNav ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withAlpha(25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.mutedForeground,
                size: compactNav ? 22 : 24,
              ),
              if (isSelected && !compactNav) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: FadeInRight(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
