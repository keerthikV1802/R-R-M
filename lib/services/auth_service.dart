import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:restaurent_management/screens/admin/admin_dashboard.dart';
import 'package:restaurent_management/screens/salesman/salesman_dashboard.dart';


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 🔹 Login with Email & Password
  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// 🔹 Common helper to write global user doc
  Future<void> _writeGlobalUserDoc({
    required String uid,
    required String name,
    required String email,
    required String role,
    required String orgName,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'org': orgName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 🔹 Register As Organisation (Admin)
  Future<User?> registerAsOrganisation({
    required String orgName,
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = result.user;
      if (user == null) throw Exception("Failed to create user");

      final orgRef = _firestore.collection('organisations').doc(orgName);
      await orgRef.set({
        'name': orgName.trim(),
        'phone': phone?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await orgRef.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await _writeGlobalUserDoc(
        uid: user.uid,
        name: name,
        email: email,
        role: 'admin',
        orgName: orgName,
      );

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// 🔹 Register In Organisation (Salesperson)
  Future<User?> registerInOrganisation({
    required String orgName,
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = result.user;
      if (user == null) throw Exception("Failed to create user");

      final orgRef = _firestore.collection('organisations').doc(orgName);
      final orgDoc = await orgRef.get();
      if (!orgDoc.exists) throw Exception("Organisation not found");

      await orgRef.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'role': 'salesperson',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await _writeGlobalUserDoc(
        uid: user.uid,
        name: name,
        email: email,
        role: 'salesperson',
        orgName: orgName,
      );

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  Future<User?> signInWithGoogle(BuildContext context) async {
  try {
    // Start Google Sign-In
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;

    // Firebase credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return null;

    // ✅ Check global Firestore 'users' for existing account
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      final role = data['role'] ?? '';
      

      if (!context.mounted) return user;

      // 🔹 Navigate by role
      if (role == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          (route) => false,
        );
      } else if (role == 'salesperson') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SalesDashboardScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid role assigned.')),
        );
      }
    } else {
      // ❌ Not registered user
      if (!context.mounted) return user;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account not registered. Please register first.')),
      );
      await _googleSignIn.signOut();
      await _auth.signOut();
    }

    return user;
  } catch (e) {
    debugPrint("🔥 Google Sign-In error: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In failed: $e")),
      );
    }
    return null;
  }
}




  /// 🔹 Logout current user
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// 🔹 Get Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// 🔹 Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 🔹 Get user profile (role + org)
  Future<Map<String, String>?> getUserProfile(String uid) async {
    final globalDoc = await _firestore.collection('users').doc(uid).get();
    if (globalDoc.exists) {
      final data = globalDoc.data()!;
      if (data['role'] != null && data['org'] != null) {
        return {'role': data['role'], 'org': data['org']};
      }
    }

    // fallback search in orgs
    final orgs = await _firestore.collection('organisations').get();
    for (final orgDoc in orgs.docs) {
      final userDoc = await orgDoc.reference.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final u = userDoc.data()!;
        await _writeGlobalUserDoc(
          uid: uid,
          name: u['name'] ?? '',
          email: u['email'] ?? '',
          role: u['role'] ?? '',
          orgName: orgDoc.id,
        );
        return {'role': u['role'], 'org': orgDoc.id};
      }
    }
    return null;
  }

  /// 🔹 Error handler
  String _handleFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email already registered.';
      case 'invalid-email':
        return 'Invalid email.';
      case 'weak-password':
        return 'Weak password.';
      default:
        return e.message ?? 'Unknown error.';
    }
  }
}
