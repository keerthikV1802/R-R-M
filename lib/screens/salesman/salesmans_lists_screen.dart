import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restaurent_management/screens/salesman/salesman_optionssheet.dart';

class SalespersonListScreen extends StatelessWidget {
  const SalespersonListScreen({super.key});

  Future<String?> _getAdminOrg() async {
    final uid = /* current user uid */ 
        (await FirebaseFirestore.instance.app.options) == null ? null : null;
    // simpler: read from global 'users' doc for current user
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return null;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
    return userDoc.data()?['org'];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getAdminOrg(),
      builder: (context, orgSnapshot) {
        if (!orgSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final orgName = orgSnapshot.data;
        if (orgName == null) {
          return const Scaffold(body: Center(child: Text("No organization found")));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Team"),
            centerTitle: true,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('organisations')
                .doc(orgName)
                .collection('users')
                // fetch both managers(level2) and salespersons(level3)
                .where('role', whereIn: ['level2', 'level3'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No team members found."));
              }

              final docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final d = docs[index].data() as Map<String, dynamic>;
                  final name = d['name'] ?? 'Unnamed';
                  final email = d['email'] ?? '—';
                  final role = d['role'] ?? '—';
                  final joinedAt = (d['joinedAt'] as Timestamp?)?.toDate();

                  return ListTile(
                    leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                    title: Text(name),
                    subtitle: Text("$email • $role"),
                    trailing: const Icon(Icons.more_vert),
                    onTap: () {
                      // open options sheet. pass both id & org so sheet can allow assign/unassign
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        builder: (_) => SalespersonOptionsSheet(
                          salespersonId: docs[index].id,
                          salespersonName: name,
                          orgName: orgName!,
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
