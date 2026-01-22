import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restaurent_management/widgets/restaurant_card.dart';
import 'package:restaurent_management/screens/salesman/RestaurantDetailScreen.dart';

class SalespersonRestaurantScreen extends StatelessWidget {
  final String salespersonId;
  final String salespersonName;
  final String orgName;

  const SalespersonRestaurantScreen({
    super.key,
    required this.salespersonId,
    required this.orgName,
    required this.salespersonName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$salespersonName’s Restaurants"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .where('createdBy', isEqualTo: salespersonId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('No restaurants found'));
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final createdAtTs = d['createdAt'];
              DateTime createdAt = DateTime.now();
              // safe conversions
              if (createdAtTs is Timestamp) {
                createdAt = createdAtTs.toDate();
              } else if (createdAtTs is Map && createdAtTs['_seconds'] != null) {
                createdAt = DateTime.fromMillisecondsSinceEpoch((createdAtTs['_seconds'] as int) * 1000);
              }

              // label might be list or string
              final label = d['label'];
              final labelValue = label is List ? label.cast<String>() : (label?.toString() ?? '');

              return RestaurantCard(
                name: d['name']?.toString() ?? '',
                status: d['status']?.toString() ?? '',
                label: labelValue,
                isImported: d['isImported'] ?? false,
                createdAt: createdAt,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => RestaurantDetailScreen(restaurantId: docs[i].id),
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}
