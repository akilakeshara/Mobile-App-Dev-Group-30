import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../utils/role_utils.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

  Future<UserRole?> _resolveRoleForUid(String uid) async {
    final officer = await _firestore.getOfficerByUid(uid);
    if (officer != null) {
      final officerRole = RoleExtension.fromString(officer.role);
      if (officerRole.isOfficer || officerRole.isAdmin) {
        return officerRole;
      }
    }

    final userModel = await _firestore.getUser(uid);
    if (userModel != null) {
      return RoleExtension.fromString(userModel.role);
    }

    return null;
  }

  // Get current user's role as a stream
  Stream<UserRole?> getCurrentUserRoleStream() {
    return _auth.authStateChanges().asyncExpand((user) async* {
      if (user == null) {
        yield null;
      } else {
        yield await _resolveRoleForUid(user.uid);
      }
    });
  }

  // Get current user's role as a future
  Future<UserRole?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    return _resolveRoleForUid(user.uid);
  }

  // Get current user as a stream
  Stream<UserModel?> getCurrentUserStream() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(null);
      }
      return _firestore.getUserStream(user.uid);
    });
  }

  // Check if current user has a specific role
  Future<bool> hasRole(UserRole role) async {
    final currentRole = await getCurrentUserRole();
    return currentRole == role;
  }

  // Check if current user has any of the specified roles
  Future<bool> hasAnyRole(List<UserRole> roles) async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null) return false;
    return roles.contains(currentRole);
  }

  // Check if current user is officer or admin
  Future<bool> isOfficerOrAdmin() async {
    final currentRole = await getCurrentUserRole();
    if (currentRole == null) return false;
    return currentRole.isOfficer || currentRole.isAdmin;
  }

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  // Get current UID
  String? get currentUid => _auth.currentUser?.uid;

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user by UID
  Future<UserModel?> getUserById(String uid) {
    return _firestore.getUser(uid);
  }

  // Get stream of user by UID
  Stream<UserModel?> getUserStreamById(String uid) {
    return _firestore.getUserStream(uid);
  }

  // Update user role (admin only in production)
  Future<void> updateUserRole(String uid, String newRole) async {
    try {
      RoleExtension.fromString(newRole); // This will validate the role
      await _firestore.updateUserRole(uid, newRole);
      debugPrint('Updated user $uid role to $newRole');
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }
}

// Global instance for convenience
final authService = AuthService();
