// lib/screens/salesman/RestaurantDetailScreen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantId;
  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  Map<String, dynamic>? restaurantData;
  String currentUserRole = ''; // level1/level2/level3 or ''
  String currentUserOrg = '';

  final List<Map<String, dynamic>> statusOptions = [
    {'name': 'Sales', 'color': Colors.blue},
    {'name': 'After Sales', 'color': Colors.purple},
    {'name': 'contigency', 'color': Colors.orange},
  ];

  Map<String, List<String>> statusWithLabels = {};
  Map<String, List<String>> statusLabelMap = {
    "Sales": ["default"],
    "After Sales": ["default"],
    "contigency": ["default"],
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
    _loadCustomizations();
  }

  Future<void> _loadCurrentUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final d = userDoc.data()!;
      setState(() {
        currentUserRole = (d['role'] ?? '').toString();
        currentUserOrg = (d['org'] ?? '').toString();
      });
      return;
    }

    // fallback: find under organisations
    final orgs = await FirebaseFirestore.instance.collection('organisations').get();
    for (final orgDoc in orgs.docs) {
      final u = await orgDoc.reference.collection('users').doc(uid).get();
      if (u.exists) {
        final ud = u.data()!;
        setState(() {
          currentUserRole = (ud['role'] ?? '').toString();
          currentUserOrg = orgDoc.id;
        });
        // write global user doc for future fast lookups
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'name': ud['name'] ?? '',
          'email': ud['email'] ?? '',
          'role': ud['role'] ?? '',
          'org': orgDoc.id,
          'joinedAt': ud['joinedAt'] ?? FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        break;
      }
    }
  }

  Future<void> _loadCustomizations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final org = userDoc.data()?['org'] ?? '';

    final customRef = FirebaseFirestore.instance
        .collection('organisations')
        .doc(org)
        .collection('users')
        .doc(uid)
        .collection('customisations')
        .doc('statuswithlabel');

    final customDoc = await customRef.get();
    if (!customDoc.exists) {
      await customRef.set({
        'sales': ["default", "hot1", "cold1", "warm1"],
        'aftersales': ["default", "hot2", "cold2", "warm2"],
        'contigency': ["default", "hot3", "cold3", "warm3"],
      });
    }

    final data = (await customRef.get()).data() ?? {};
    statusWithLabels = {
      'Sales': List<String>.from(data['sales'] ?? []),
      'After Sales': List<String>.from(data['aftersales'] ?? []),
      'Contingency': List<String>.from(data['contigency'] ?? []),
    };
    setState(() {});
  }

  Future<void> _updateField(String field, dynamic value) async {
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .update({field: value, 'updatedAt': FieldValue.serverTimestamp()});
  }

  void _showStatusSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  "Select status",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: statusOptions.length,
                    itemBuilder: (context, index) {
                      final s = statusOptions[index];
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: s['color']),
                        title: Text(s['name']),
                        onTap: () async {
                          final newStatus = s['name'];
                          final newLabels = statusLabelMap[newStatus] ?? [];

                          await FirebaseFirestore.instance
                              .collection('restaurants')
                              .doc(widget.restaurantId)
                              .update({
                            'status': newStatus,
                            'label': newLabels,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStatusWithLabelSelector(String currentStatus, String currentLabel) {
    String selectedStatus = currentStatus;
    String selectedLabel = currentLabel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select Status + Label",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  // STATUS
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: "Status",
                      border: OutlineInputBorder(),
                    ),
                    items: ["Sales", "After Sales", "Contingency"]
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setStateModal(() {
                        selectedStatus = v!;
                        selectedLabel = "default";
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  // LABEL dropdown (safe)
                  Builder(
                    builder: (context) {
                      List<String> options = statusWithLabels[selectedStatus] ?? [];
                      if (options.isEmpty) {
                        options = ["default"];
                        statusWithLabels[selectedStatus] = options;
                      }
                      if (selectedLabel.isEmpty || !options.contains(selectedLabel)) {
                        selectedLabel = options.first;
                      }

                      return DropdownButtonFormField<String>(
                        value: selectedLabel,
                        decoration: const InputDecoration(
                          labelText: "Label",
                          border: OutlineInputBorder(),
                        ),
                        items: options.map((l) => DropdownMenuItem<String>(
                              value: l,
                              child: Text(l),
                            )).toList(),
                        onChanged: (v) {
                          setStateModal(() {
                            selectedLabel = v ?? options.first;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await _updateField('status', selectedStatus);
                      await _updateField('label', selectedLabel);
                      Navigator.pop(context);
                    },
                    child: const Text("Save"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, String?>> _fetchCreatorAndManagerNames(String? createdByUid, String restaurantOrg) async {
  // explicitly type values as String? (nullable)
  final Map<String, String?> result = {
    'creatorName': null,
    'creatorRole': null,
    'managerName': null,
  };

  if (createdByUid == null || createdByUid.isEmpty) return result;

  try {
    // try global users first
    final g = await FirebaseFirestore.instance.collection('users').doc(createdByUid).get();
    if (g.exists) {
      final gd = g.data()!;
      result['creatorName'] = (gd['name'] ?? '').toString();
      result['creatorRole'] = (gd['role'] ?? '').toString();

      // check assignedTo under organisation users
      final orgUser = await FirebaseFirestore.instance
          .collection('organisations')
          .doc(restaurantOrg)
          .collection('users')
          .doc(createdByUid)
          .get();

      if (orgUser.exists) {
        final od = orgUser.data()!;
        final assignedTo = (od['assignedTo'] ?? '').toString();
        if (assignedTo.isNotEmpty) {
          final m = await FirebaseFirestore.instance
              .collection('organisations')
              .doc(restaurantOrg)
              .collection('users')
              .doc(assignedTo)
              .get();
          if (m.exists) {
            result['managerName'] = (m.data()?['name'] ?? '').toString();
          }
        }
      }
      return result;
    }

    // fallback: try organisation user doc
    final u = await FirebaseFirestore.instance
        .collection('organisations')
        .doc(restaurantOrg)
        .collection('users')
        .doc(createdByUid)
        .get();

    if (u.exists) {
      final ud = u.data()!;
      result['creatorName'] = (ud['name'] ?? '').toString();
      result['creatorRole'] = (ud['role'] ?? '').toString();
      final assignedTo = (ud['assignedTo'] ?? '').toString();
      if (assignedTo.isNotEmpty) {
        final m = await FirebaseFirestore.instance
            .collection('organisations')
            .doc(restaurantOrg)
            .collection('users')
            .doc(assignedTo)
            .get();
        if (m.exists) result['managerName'] = (m.data()?['name'] ?? '').toString();
      }
    }
  } catch (e) {
    debugPrint('fetchCreatorAndManagerNames error: $e');
  }

  return result;
}


  Widget _timelineTab(DateTime? createdAt, Map<String, String?>? creatorInfo) {
    final createdText = createdAt != null
        ? DateFormat('MMM d, yyyy  hh:mm a').format(createdAt)
        : "Unknown";

    // default widget shows created on
    final children = <Widget>[
      ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.green),
        title: const Text("Created On"),
        subtitle: Text(createdText),
      ),
    ];

    // Decide what extra info to show based on currentUserRole
    // level3 -> only created date (no extra)
    // level2 -> show salesperson name (creator) if exists
    // level1 -> show salesperson + manager names
    if (currentUserRole == 'level2' || currentUserRole == 'level1') {
      final creatorName = creatorInfo?['creatorName'];
      if (creatorName != null && creatorName.isNotEmpty) {
        children.add(ListTile(
          leading: const Icon(Icons.person, color: Colors.blue),
          title: const Text("Salesperson"),
          subtitle: Text(creatorName),
        ));
      }
    }

    if (currentUserRole == 'level1') {
      final managerName = creatorInfo?['managerName'];
      if (managerName != null && managerName.isNotEmpty) {
        children.add(ListTile(
          leading: const Icon(Icons.supervisor_account, color: Colors.purple),
          title: const Text("Manager"),
          subtitle: Text(managerName),
        ));
      }
    }

    return ListView(padding: const EdgeInsets.all(12), children: children);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Restaurant Details"),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(widget.restaurantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Restaurant not found."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Unnamed';
          final status = data['status'] ?? 'Empty';
          final labels = (data['label'] ?? ['Empty']) is List
              ? List<String>.from(data['label'])
              : [data['label'].toString()];
          final createdAt = (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : null;
          final createdByUid = (data['createdBy'] ?? '').toString();
          final restaurantOrg = (data['org'] ?? currentUserOrg).toString();

          // Read fields for Info tab
          final clientName = (data['clientName'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          final address = (data['address'] ?? '').toString();
          final leadDate = (data['leadDate'] is Timestamp) ? (data['leadDate'] as Timestamp).toDate() : null;
          
          // NEW: Read estimated budget
          final estimatedBudget = (data['estimatedBudget'] ?? '').toString();

          // load creator/manager info via FutureBuilder
          return FutureBuilder<Map<String, String?>>(
            future: _fetchCreatorAndManagerNames(createdByUid.isEmpty ? null : createdByUid, restaurantOrg),
            builder: (context, creatorSnap) {
              final creatorInfo = creatorSnap.data;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A2342),
                                ),
                              ),
                              // NEW: Display estimated budget under the name
                              if (estimatedBudget.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.currency_rupee, size: 16, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(
                                      estimatedBudget,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.info_outline, color: Colors.redAccent),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Combined Status + Label editor (single chip)
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            _showStatusWithLabelSelector(status, labels.isNotEmpty ? labels[0] : "default");
                          },
                          child: Chip(
                            label: Row(
                              children: [
                                Text("$status  --  ${labels.isEmpty ? 'default' : labels.join(', ')}"),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 14),
                              ],
                            ),
                            backgroundColor: Colors.blue.shade100,
                            labelStyle: const TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 34),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _ActionButton(icon: Icons.call, color: Colors.blue),
                        _ActionButton(icon: Icons.message, color: Colors.pink),
                        _ActionButton(icon: Icons.email, color: Colors.amber),
                        _ActionButton(icon: Icons.clean_hands_outlined, color: Colors.green),
                        _ActionButton(icon: Icons.description, color: Colors.grey),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Tabs: timeline uses creatorInfo to show names depending on currentUserRole
                    DefaultTabController(
                      length: 4,
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: Colors.blueAccent,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.blueAccent,
                            tabs: [
                              Tab(text: "Timeline"),
                              Tab(text: "Task"),
                              Tab(text: "Notes"),
                              Tab(text: "Info"),
                            ],
                          ),
                          SizedBox(
                            height: 250,
                            child: TabBarView(
                              children: [
                                _timelineTab(createdAt, creatorInfo),
                                const Center(child: Text("No tasks yet")),
                                const Center(child: Text("No notes yet")),
                                // Info tab: show details including client name
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ListView(
                                    children: [
                                      if (clientName.isNotEmpty)
                                        ListTile(
                                          leading: const Icon(Icons.person_outline, color: Colors.blue),
                                          title: const Text("Client Name"),
                                          subtitle: Text(clientName),
                                        ),
                                      if (phone.isNotEmpty)
                                        ListTile(
                                          leading: const Icon(Icons.phone, color: Colors.green),
                                          title: const Text("Phone"),
                                          subtitle: Text(phone),
                                        ),
                                      if (email.isNotEmpty)
                                        ListTile(
                                          leading: const Icon(Icons.email, color: Colors.amber),
                                          title: const Text("Email"),
                                          subtitle: Text(email),
                                        ),
                                      if (address.isNotEmpty)
                                        ListTile(
                                          leading: const Icon(Icons.location_on, color: Colors.red),
                                          title: const Text("Address"),
                                          subtitle: Text(address),
                                        ),
                                      if (leadDate != null)
                                        ListTile(
                                          leading: const Icon(Icons.event, color: Colors.purple),
                                          title: const Text("Lead Date"),
                                          subtitle: Text(DateFormat.yMMMMd().format(leadDate)),
                                        ),
                                      if (estimatedBudget.isNotEmpty)
                                        ListTile(
                                          leading: const Icon(Icons.currency_rupee, color: Colors.green),
                                          title: const Text("Estimated Budget"),
                                          subtitle: Text(estimatedBudget),
                                        ),
                                      if (clientName.isEmpty && phone.isEmpty && email.isEmpty && address.isEmpty && leadDate == null && estimatedBudget.isEmpty)
                                        const Center(child: Text("No additional info")),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Action button widget unchanged
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _ActionButton({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 28),
    );
  }
}