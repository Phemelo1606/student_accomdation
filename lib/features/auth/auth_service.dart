import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:student_accomdation/core/app_logger.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> createUser({
    required String email,
    required String password,
    required String role, // 'student', 'landlord', or 'staff'
    Map<String, dynamic>? additionalData,
  }) async {
    final UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user document in Firestore with role
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...?additionalData,
    });

    return userCredential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateUsername({required String username}) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.updateProfile(displayName: username);
      // Also update in Firestore if you store username there
      await _updateUserData({'username': username});
    }
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Role-based access control methods
  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['role'];
    } catch (e) {
      return null;
    }
  }

  Future<bool> isUserStaff() async {
    final role = await getUserRole();
    return role == 'staff';
  }

  Future<bool> isUserLandlord() async {
    final role = await getUserRole();
    return role == 'landlord';
  }

  Future<bool> isUserStudent() async {
    final role = await getUserRole();
    return role == 'student';
  }

  // Get complete user data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data();
    } catch (e) {
      return null;
    }
  }

  // Stream for real-time user data changes
  Stream<DocumentSnapshot> get userDataStream {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  // Check if user has specific permission
  Future<bool> hasPermission(String permission) async {
    final userData = await getUserData();
    final role = userData?['role'];
    final permissions = userData?['permissions'] ?? [];

    // Define role-based permissions
    final rolePermissions = {
      'staff': [
        'view_all_accommodations',
        'manage_accreditation',
        'view_reports'
      ],
      'landlord': [
        'manage_accommodations',
        'view_own_accommodations',
        'manage_rooms'
      ],
      'student': ['view_accommodations', 'apply_accommodation', 'view_profile'],
    };

    // Check if role has the permission
    if (rolePermissions[role]?.contains(permission) == true) {
      return true;
    }

    // Check custom permissions
    return permissions.contains(permission);
  }

  // Update user role (admin/staff only function)
  Future<void> updateUserRole(String userId, String newRole) async {
    // Verify current user is staff/admin
    if (!await isUserStaff()) {
      throw Exception('Insufficient permissions to update user roles');
    }

    await _firestore.collection('users').doc(userId).update({
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete user account and data
  Future<void> deleteUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete user from Firebase Auth
      await user.delete();
    }
  }

  // Verify email
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Check if email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Re-authenticate user for sensitive operations
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }

  // Custom token verification (for advanced use cases)
  Future<void> verifyIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      final idToken = await user.getIdToken(true);
      // You can send this token to your backend for verification
      AppLogger.log('ID Token: $idToken');
    }
  }

  // Helper method to update user data in Firestore
  Future<void> _updateUserData(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
