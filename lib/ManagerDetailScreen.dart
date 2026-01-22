// lib/screens/salesman/manager_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:restaurent_management/screens/salesman/salesman_added_restaurants.dart';


class ManagerDetailScreen extends StatelessWidget {
  final String managerId;
  final String managerName;
  final String orgName;

  const ManagerDetailScreen({
    super.key,
    required this.managerId,
    required this.managerName,
    required this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$managerName's Team")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organisations')
            .doc(orgName)
            .collection('users')
            .where('role', isEqualTo: 'level3') // salespersons
            .where('assignedTo', isEqualTo: managerId) // assigned to this manager
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('No salespersons assigned'));
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
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                title: Text(name),
                subtitle: Text(email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to salesperson's restaurants
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SalespersonRestaurantScreen( salespersonId: docs[i].id,
                        salespersonName: name,
                        orgName: orgName,),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
