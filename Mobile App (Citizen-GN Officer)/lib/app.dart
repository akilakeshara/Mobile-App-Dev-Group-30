import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../pages/splash_page.dart';
import '../pages/welcome_page.dart';
import '../pages/login_page.dart';
import '../pages/signup_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/applications_page.dart';
import '../pages/application_details_page.dart';
import '../pages/complaints_page.dart';
import '../pages/new_complaint_page.dart';
import '../pages/service_application_page.dart';
import '../pages/certificate_wallet_page.dart';
import '../pages/profile_page.dart';
import '../pages/waste_collection_schedule_page.dart';
import '../pages/gn_appointment_page.dart';
import '../pages/officer_portal_page.dart';
import '../pages/officer/officer_application_review_page.dart';
import '../pages/payment_checkout_page.dart';
import '../pages/govease_chatbot_page.dart';
import '../models/application.dart';
import '../widgets/bottom_nav.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../utils/role_utils.dart';
import '../localization/app_localizations.dart';

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/signup', builder: (_, _) => const SignUpPage()),
    GoRoute(
      path: '/officer',
      builder: (_, _) => const _RoleProtectedOfficerPortal(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
        GoRoute(
          path: '/applications',
          builder: (_, _) => const ApplicationsPage(),
        ),
        GoRoute(
          path: '/applications/details',
          builder: (context, state) {
            final app = state.extra as Application;
            return ApplicationDetailsPage(application: app);
          },
        ),
        GoRoute(path: '/complaints', builder: (_, _) => const ComplaintsPage()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
        GoRoute(
          path: '/waste-collection',
          builder: (_, _) => const WasteCollectionSchedulePage(),
        ),
        GoRoute(
          path: '/chatbot',
          builder: (_, _) => const GovEaseChatbotPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/complaints/new',
      builder: (_, _) => const NewComplaintPage(),
    ),
    GoRoute(
      path: '/services/certificate',
      builder: (_, _) => const ServiceApplicationPage(),
    ),
    GoRoute(
      path: '/certificates/wallet',
      builder: (_, _) => const CertificateWalletPage(),
    ),
    GoRoute(
      path: '/gn-appointment',
      builder: (_, _) => const GnAppointmentPage(),
    ),
    GoRoute(
      path: '/officer/application-review',
      builder: (context, state) {
        final app = state.extra as Application;
        return OfficerApplicationReviewPage(application: app);
      },
    ),
    GoRoute(
      path: '/payment/checkout',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>;
        return PaymentCheckoutPage(
          serviceName: extras['serviceName'],
          amount: extras['amount'],
          applicationId: extras['applicationId'],
          pendingApplicationData:
              extras['pendingApplication'] as Map<String, dynamic>?,
        );
      },
    ),
  ],
);

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/applications')) return 1;
    if (location.startsWith('/complaints')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNav(
        currentIndex: _calculateSelectedIndex(context),
      ),
    );
  }
}

class GovEaseApp extends StatelessWidget {
  const GovEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: languageService,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'GovEase',
          theme: AppTheme.theme,
          routerConfig: _router,
          locale: languageService.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

/// Role-protected wrapper for officer portal
/// Ensures only officers and admins can access the officer portal
class _RoleProtectedOfficerPortal extends StatelessWidget {
  const _RoleProtectedOfficerPortal();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserRole?>(
      stream: authService.getCurrentUserRoleStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data;
        final hasAccess = role?.isOfficer == true || role?.isAdmin == true;

        if (!hasAccess) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('accessDenied'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('officerOnlyPortal'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.go('/'),
                      child: Text(context.tr('goToHome')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const OfficerPortalPage();
      },
    );
  }
}
