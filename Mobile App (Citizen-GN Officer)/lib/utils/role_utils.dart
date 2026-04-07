enum UserRole { citizen, officer, admin }

extension RoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.citizen:
        return 'citizen';
      case UserRole.officer:
        return 'officer';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'officer':
        return UserRole.officer;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.citizen;
    }
  }

  bool get isOfficer => this == UserRole.officer;
  bool get isAdmin => this == UserRole.admin;
  bool get isCitizen => this == UserRole.citizen;
}
