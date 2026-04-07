import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/role_utils.dart';

class RoleBasedBuilder extends StatelessWidget {
  final Widget? citizenWidget;
  final Widget? officerWidget;
  final Widget? adminWidget;
  final Widget? defaultWidget;
  final UserModel? user;

  const RoleBasedBuilder({
    super.key,
    this.citizenWidget,
    this.officerWidget,
    this.adminWidget,
    this.defaultWidget,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) return defaultWidget ?? Container();

    final role = RoleExtension.fromString(user!.role);
    switch (role) {
      case UserRole.officer:
        return officerWidget ?? defaultWidget ?? Container();
      case UserRole.admin:
        return adminWidget ?? defaultWidget ?? Container();
      case UserRole.citizen:
        return citizenWidget ?? defaultWidget ?? Container();
    }
  }
}

class RoleGuard extends StatelessWidget {
  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget? fallback;
  final UserModel? user;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) return fallback ?? Container();

    final userRole = RoleExtension.fromString(user!.role);
    if (allowedRoles.contains(userRole)) {
      return child;
    }

    return fallback ??
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to view this page.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
  }
}
