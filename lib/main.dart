import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restaurent_management/screens/admin/admin_dashboard.dart';

// Screens
import 'screens/authentication/login_screen.dart';
import 'package:restaurent_management/screens/salesman/salesman_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Make sure firebase_options.dart exists if you used FlutterFire CLI
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Visit Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// 🔹 AuthWrapper decides where to go based on auth state and role
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If not logged in → go to LoginScreen
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // If logged in → fetch Firestore role
        final User user = snapshot.data!;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snap.hasData || !snap.data!.exists) {
  return const LoginScreen(); // fallback if Firestore doc missing
}

// Explicitly cast after ensuring snap.data! isn’t null
final doc = snap.data!;
final data = doc.data() as Map<String, dynamic>? ?? {};
final role = data['role'] ?? 'guest'; // default value if missing

if (role == 'admin') {
  return const AdminDashboardScreen();
} else if (role == 'sales') {
  return const SalesDashboardScreen();
} else {
  return const LoginScreen(); // fallback for unknown role
}

          },
        );
      },
    );
  }
}
