// ROLE-BASED IMPLEMENTATION EXAMPLES
// Reference guide for using role-based features in GovEase

// Example 1: Role-based UI in a page
// import 'package:firebase_auth/firebase_auth.dart';
// import '../services/firestore_service.dart';
// import '../widgets/role_based_widget.dart';
// import '../utils/role_utils.dart';

/*
class RoleBasedDashboardPage extends StatelessWidget {
  const RoleBasedDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUid == null) {
      return const Center(child: Text('Not authenticated'));
    }

    return StreamBuilder(
      stream: firestoreService.getUserStream(currentUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (user == null) {
          return const Center(child: Text('User not found'));
        }

        return RoleBasedBuilder(
          user: user,
          citizenWidget: const CitizenDashboard(),
          officerWidget: const OfficerDashboard(),
          adminWidget: const AdminDashboard(),
        );
      },
    );
  }
}
*/

// Example 2: Route protection
// In app.dart routes:
/*
GoRoute(
  path: '/officer',
  builder: (context, state) {
    return StreamBuilder(
      stream: authService.getCurrentUserRoleStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final role = snapshot.data;
        if (role != UserRole.officer && role != UserRole.admin) {
          return const Center(
            child: Text('Access Denied: Officer role required'),
          );
        }

        return const OfficerPortalPage();
      },
    );
  },
),
*/

// Example 3: Feature flags based on role
/*
class ApplicationsPage extends StatelessWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: authService.getCurrentUserStream(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = userSnapshot.data;
        if (user == null) return const Center(child: Text('Not authenticated'));

        final isOfficer = RoleExtension.fromString(user.role).isOfficer;

        // Show different applications based on role
        final applicationsStream = isOfficer
            ? firestoreService.getOfficerApplications()
            : firestoreService.getUserApplications();

        return StreamBuilder(
          stream: applicationsStream,
          builder: (context, appSnapshot) {
            if (!appSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final applications = appSnapshot.data ?? [];
            if (applications.isEmpty) {
              return const Center(child: Text('No applications'));
            }

            return ListView.builder(
              itemCount: applications.length,
              itemBuilder: (context, index) {
                return ApplicationCard(application: applications[index]);
              },
            );
          },
        );
      },
    );
  }
}
*/

// Example 4: Using RoleGuard widget
/*
class SensitiveFeature extends StatelessWidget {
  final UserModel user;

  const SensitiveFeature({required this.user});

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: user,
      allowedRoles: [UserRole.officer, UserRole.admin],
      child: const OfficerOnlyFeatureWidget(),
      fallback: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('This feature is only available to officers'),
          ],
        ),
      ),
    );
  }
}
*/

// Example 5: Role-based data fetching
/*
Future<void> initOfficerFeatures() async {
  // Get all officers
  final officers = await firestoreService.getUsersByRole('officer');
  print('Number of officers: ${officers.length}');

  // Get all applications (for officers)
  final apps = await firestoreService.getAllApplications().first;
  print('Number of applications: ${apps.length}');

  // Check if current user is officer
  final isOfficer = await authService.isOfficerOrAdmin();
  if (isOfficer) {
    print('Current user is officer or admin');
  }
}
*/

// Example 6: Update user role (admin function)
/*
Future<void> promoteToOfficer(String userId) async {
  try {
    await authService.updateUserRole(userId, 'officer');
    print('User promoted to officer');
  } catch (e) {
    print('Error promoting user: $e');
  }
}
*/

// Example 7: Comprehensive page with role checking
/*
class ComprehensiveRoleAwarePage extends StatefulWidget {
  const ComprehensiveRoleAwarePage({super.key});

  @override
  State<ComprehensiveRoleAwarePage> createState() =>
      _ComprehensiveRoleAwarePageState();
}

class _ComprehensiveRoleAwarePageState
    extends State<ComprehensiveRoleAwarePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role-Aware Dashboard'),
      ),
      body: StreamBuilder(
        stream: authService.getCurrentUserStream(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || userSnapshot.data == null) {
            return const Center(child: Text('Not authenticated'));
          }

          final user = userSnapshot.data!;
          final role = RoleExtension.fromString(user.role);

          return SingleChildScrollView(
            child: Column(
              children: [
                // User info
                ListTile(
                  title: Text(user.name),
                  subtitle: Text('Role: ${role.value}'),
                  leading: const Icon(Icons.person),
                ),
                const Divider(),

                // Role-based sections
                if (role.isCitizen) ...[
                  ListTile(
                    title: const Text('My Applications'),
                    leading: const Icon(Icons.description),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('My Complaints'),
                    leading: const Icon(Icons.report),
                    onTap: () {},
                  ),
                ],
                if (role.isOfficer) ...[
                  ListTile(
                    title: const Text('All Applications'),
                    leading: const Icon(Icons.list),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('All Complaints'),
                    leading: const Icon(Icons.assignment),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('Officer Directory'),
                    leading: const Icon(Icons.group),
                    onTap: () {},
                  ),
                ],
                if (role.isAdmin) ...[
                  ListTile(
                    title: const Text('Admin Panel'),
                    leading: const Icon(Icons.admin_panel_settings),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('User Management'),
                    leading: const Icon(Icons.people),
                    onTap: () {},
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
*/
