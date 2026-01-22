// lib/screens/salesman/manager_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:restaurent_management/ManagerDetailScreen.dart';


class ManagerListScreen extends StatelessWidget {
  const ManagerListScreen({super.key});

  Future<String?> _getAdminOrg() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists ? (doc.data()?['org'] as String?) : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getAdminOrg(),
      builder: (context, orgSnap) {
        if (orgSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final org = orgSnap.data;
        if (org == null) {
          return const Scaffold(body: Center(child: Text('Organization not found')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Managers'),
            centerTitle: true,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('organisations')
                .doc(org)
                .collection('users')
                .where('role', isEqualTo: 'level2') // managers
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(child: Text('No managers found'));
              }

              final docs = snap.data!.docs;
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final name = (d['name'] ?? 'Unnamed').toString();
                  final email = (d['email'] ?? '').toString();
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                    ),
                    title: Text(name),
                    subtitle: Text(email),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManagerDetailScreen(managerId: docs[i].id,
                            managerName: name,
                            orgName: org,),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
