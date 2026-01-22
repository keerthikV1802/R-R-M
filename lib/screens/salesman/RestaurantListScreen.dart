import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:restaurent_management/screens/salesman/RestaurantDetailScreen.dart';
import 'package:restaurent_management/widgets/restaurant_card.dart';

class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  String? role;
  String? org;
  String? uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    uid = user.uid;

    // Read global user doc (should exist thanks to AuthService writing it)
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    setState(() {
      role = data['role']?.toString();
      org = data['org']?.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Level1 (admin) -> show all restaurants (global + imported)
    if (role == 'level1' || role == 'admin') {
      return _combinedView();
    }

    // Level3 (salesperson) -> show restaurants created by self
    if (role == 'level3' || role == 'salesperson') {
      return _singleUserView(uid!);
    }

    // Level2 (manager) -> show restaurants created by salespersons assigned to this manager
    if (role == 'level2') {
      return FutureBuilder<List<String>>(
        future: _getAssignedSalespersonIds(), // fetch assigned salespersons for this manager
        builder: (context, snap) {
          if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final ids = snap.data!;
          if (ids.isEmpty) return const Scaffold(body: Center(child: Text("No assigned salespersons yet.")));
          return _multipleOwnersView(ids);
        },
      );
    }

    return const Scaffold(body: Center(child: Text("No role assigned")));
  }

  Widget _combinedView() {
    // Show combined global + imported (same logic you used previously)
    final stream1 = FirebaseFirestore.instance.collection('restaurants').snapshots();
    final stream2 = FirebaseFirestore.instance.collection('importedrestaurants').snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("My Restaurants"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(stream: stream1, builder: (context, s1) {
        return StreamBuilder<QuerySnapshot>(stream: stream2, builder: (context, s2) {
          if (!s1.hasData || !s2.hasData) return const Center(child: CircularProgressIndicator());
          final docs1 = s1.data!.docs;
          final docs2 = s2.data!.docs;
          final all = [
            ...docs1.map((d) => {...(d.data() as Map<String, dynamic>), "id": d.id, "isImported": false}),
            ...docs2.map((d) => {...(d.data() as Map<String, dynamic>), "id": d.id, "isImported": true}),
          ];
          if (all.isEmpty) return const Center(child: Text("No Restaurants Found"));
          return ListView.builder(
            itemCount: all.length,
            itemBuilder: (context, i) {
              final r = all[i] as Map<String, dynamic>;
              DateTime createdAt = DateTime.now();
              final ca = r['createdAt'];
              if (ca is Timestamp) createdAt = ca.toDate();
              else if (ca is DateTime) createdAt = ca;
              return RestaurantCard(
                name: (r['name'] ?? '').toString(),
                status: (r['status'] ?? '').toString(),
                label: r['label'],
                isImported: r['isImported'] ?? false,
                createdAt: createdAt,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurantId: r['id']))),
              );
            },
          );
        });
      }),
    );
  }

  Widget _singleUserView(String userId) {
    final stream1 = FirebaseFirestore.instance.collection('restaurants').where('createdBy', isEqualTo: userId).snapshots();
    final stream2 = FirebaseFirestore.instance.collection('importedrestaurants').where('createdBy', isEqualTo: userId).snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("My Restaurants"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(stream: stream1, builder: (context, s1) {
        return StreamBuilder<QuerySnapshot>(stream: stream2, builder: (context, s2) {
          if (!s1.hasData || !s2.hasData) return const Center(child: CircularProgressIndicator());
          final docs1 = s1.data!.docs;
          final docs2 = s2.data!.docs;
          final all = [
            ...docs1.map((d) => {...(d.data() as Map<String, dynamic>), "id": d.id, "isImported": false}),
            ...docs2.map((d) => {...(d.data() as Map<String, dynamic>), "id": d.id, "isImported": true}),
          ];
          if (all.isEmpty) return const Center(child: Text("No Restaurants Found"));
          return ListView.builder(
            itemCount: all.length,
            itemBuilder: (context, i) {
              final r = all[i] as Map<String, dynamic>;
              DateTime createdAt = DateTime.now();
              final ca = r['createdAt'];
              if (ca is Timestamp) createdAt = ca.toDate();
              else if (ca is DateTime) createdAt = ca;
              return RestaurantCard(
                name: (r['name'] ?? '').toString(),
                status: (r['status'] ?? '').toString(),
                label: r['label'],
                isImported: r['isImported'] ?? false,
                createdAt: createdAt,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurantId: r['id']))),
              );
            },
          );
        });
      }),
    );
  }

  Widget _multipleOwnersView(List<String> ownerIds) {
    // Firestore 'whereIn' supports up to 10 items — if you have >10 assigned salespersons, you'll need batching.
    final stream = FirebaseFirestore.instance
        .collection('restaurants')
        .where('createdBy', whereIn: ownerIds.length <= 10 ? ownerIds : ownerIds.sublist(0, 10))
        .snapshots();

    final streamImported = FirebaseFirestore.instance
        .collection('importedrestaurants')
        .where('createdBy', whereIn: ownerIds.length <= 10 ? ownerIds : ownerIds.sublist(0, 10))
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("Assigned Restaurants"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(stream: stream, builder: (context, s1) {
        return StreamBuilder<QuerySnapshot>(stream: streamImported, builder: (context, s2) {
          if (!s1.hasData || !s2.hasData) return const Center(child: CircularProgressIndicator());
          final docs1 = s1.data!.docs;
          final docs2 = s2.data!.docs;
          final all = [
            ...docs1.map((d) => {...(d.data() as Map<String, dynamic>), "id": d.id, "isImported": false}),
            ...docs2.map((d) => {...(d.data() as Map<String, dynamic>), "id": d.id, "isImported": true}),
          ];
          if (all.isEmpty) return const Center(child: Text("No Restaurants Found for assigned salespersons"));
          return ListView.builder(
            itemCount: all.length,
            itemBuilder: (context, i) {
              final r = all[i] as Map<String, dynamic>;
              DateTime createdAt = DateTime.now();
              final ca = r['createdAt'];
              if (ca is Timestamp) createdAt = ca.toDate();
              else if (ca is DateTime) createdAt = ca;
              return RestaurantCard(
                name: (r['name'] ?? '').toString(),
                status: (r['status'] ?? '').toString(),
                label: r['label'],
                isImported: r['isImported'] ?? false,
                createdAt: createdAt,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurantId: r['id']))),
              );
            },
          );
        });
      }),
    );
  }

  Future<List<String>> _getAssignedSalespersonIds() async {
    // strategy: find users in org with 'assignedTo' == current manager uid (i.e., salespersons assigned to this manager)
    if (uid == null || org == null) return [];
    final q = await FirebaseFirestore.instance
        .collection('organisations')
        .doc(org)
        .collection('users')
        .where('assignedTo', isEqualTo: uid)
        .where('role', isEqualTo: 'level3')
        .get();

    return q.docs.map((d) => d.id).toList();
  }
}
