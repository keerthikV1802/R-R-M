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

  Map<String, List<Map<String, dynamic>>> statusWithLabels = {};
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
        'Sales': ["default"],
        'After Sales': ["default"],
        'Contingency': ["default"],
      });
    }

    final data = (await customRef.get()).data() ?? {};
    statusWithLabels = data.map((key, value) {
      List<Map<String, dynamic>> list = List<dynamic>.from(value).map((e) {
        if (e is String) {
          return {"name": e, "hasDesc": false, "isMandatory": false};
        }
        return Map<String, dynamic>.from(e as Map);
      }).toList();
      return MapEntry(key, list);
    });
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
            final dynamicStatusOptions = statusWithLabels.keys.toList();
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
                    itemCount: dynamicStatusOptions.length,
                    itemBuilder: (context, index) {
                      final s = dynamicStatusOptions[index];
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.blue),
                        title: Text(s),
                        onTap: () async {
                          final newStatus = s;
                          final options = statusWithLabels[newStatus] ?? [];
                          final newLabels = options.isNotEmpty ? [options.first['name']] : ["default"];

                          await FirebaseFirestore.instance
                              .collection('restaurants')
                              .doc(widget.restaurantId)
                              .update({
                            'status': newStatus,
                            'label': newLabels,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

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
    final descC = TextEditingController(text: restaurantData?['labelDescription'] ?? '');

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
                    value: statusWithLabels.keys.contains(selectedStatus) ? selectedStatus : (statusWithLabels.keys.isNotEmpty ? statusWithLabels.keys.first : "Sales"),
                    decoration: const InputDecoration(
                      labelText: "Status",
                      border: OutlineInputBorder(),
                    ),
                    items: (statusWithLabels.keys.isNotEmpty ? statusWithLabels.keys.toList() : ["Sales", "After Sales", "Contingency"])
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
                      List<Map<String, dynamic>> options = statusWithLabels[selectedStatus] ?? [];
                      if (options.isEmpty) {
                        options = [{"name": "default", "hasDesc": false, "isMandatory": false}];
                      }
                      
                      final currentConfig = options.firstWhere(
                        (e) => e['name'] == selectedLabel,
                        orElse: () => {"name": "default", "hasDesc": false, "isMandatory": false},
                      );

                      return Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: options.any((l) => l['name'].toString() == selectedLabel) ? selectedLabel : (options.isNotEmpty ? options.first['name'].toString() : null),
                            decoration: const InputDecoration(
                              labelText: "Label",
                              border: OutlineInputBorder(),
                            ),
                            items: options.map((l) => DropdownMenuItem<String>(
                                  value: l['name'].toString(),
                                  child: Text(l['name'].toString()),
                                )).toList(),
                            onChanged: (v) {
                              setStateModal(() {
                                selectedLabel = v ?? options.first['name'].toString();
                              });
                            },
                          ),
                          if (currentConfig['hasDesc'] == true) ...[
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: descC,
                              decoration: InputDecoration(
                                labelText: "Description for $selectedLabel",
                                border: const OutlineInputBorder(),
                                hintText: currentConfig['isMandatory'] == true ? "Required" : "Optional",
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      List<Map<String, dynamic>> options = statusWithLabels[selectedStatus] ?? [];
                      final config = options.firstWhere((e) => e['name'] == selectedLabel, orElse: () => {});
                      
                      if (config['hasDesc'] == true && config['isMandatory'] == true && descC.text.trim().isEmpty) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Description is mandatory for this label")));
                         return;
                      }

                      await _updateField('status', selectedStatus);
                      await _updateField('label', selectedLabel);
                      await _updateField('labelDescription', descC.text.trim());
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
    final Map<String, String?> result = {
      'creatorName': null,
      'creatorRole': null,
      'managerName': null,
    };

    if (createdByUid == null || createdByUid.isEmpty) return result;

    try {
      final g = await FirebaseFirestore.instance.collection('users').doc(createdByUid).get();
      if (g.exists) {
        final gd = g.data()!;
        result['creatorName'] = (gd['name'] ?? '').toString();
        result['creatorRole'] = (gd['role'] ?? '').toString();

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

    final children = <Widget>[
      ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.green),
        title: const Text("Created On"),
        subtitle: Text(createdText),
      ),
    ];

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
          final labelDescription = (data['labelDescription'] ?? '').toString();
          final createdAt = (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : null;
          final createdByUid = (data['createdBy'] ?? '').toString();
          final restaurantOrg = (data['org'] ?? currentUserOrg).toString();

          final clientName = (data['clientName'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          final address = (data['address'] ?? '').toString();
          final leadDate = (data['leadDate'] is Timestamp) ? (data['leadDate'] as Timestamp).toDate() : null;
          final estimatedBudget = (data['estimatedBudget'] ?? '').toString();

          return FutureBuilder<Map<String, String?>>(
            future: _fetchCreatorAndManagerNames(createdByUid.isEmpty ? null : createdByUid, restaurantOrg),
            builder: (context, creatorSnap) {
              final creatorInfo = creatorSnap.data;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (labelDescription.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueGrey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.description, size: 16, color: Colors.blueGrey),
                                SizedBox(width: 6),
                                Text("Description", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(labelDescription, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
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
                    DefaultTabController(
                      length: 5,
                      child: Column(
                        children: [
                          const TabBar(
                            isScrollable: true,
                            labelColor: Colors.blueAccent,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.blueAccent,
                            tabs: [
                              Tab(text: "Timeline"),
                              Tab(text: "Task"),
                              Tab(text: "Notes"),
                              Tab(text: "Info"),
                              Tab(text: "Follow-ups"),
                            ],
                          ),
                          SizedBox(
                            height: 350,
                            child: TabBarView(
                              children: [
                                _timelineTab(createdAt, creatorInfo),
                                _tasksTab(),
                                const Center(child: Text("No notes yet")),
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
                                      if (labelDescription.isNotEmpty)
                                        ListTile(
                                          leading: const Icon(Icons.label_important_outline, color: Colors.blueGrey),
                                          title: const Text("Label Description"),
                                          subtitle: Text(labelDescription),
                                        ),
                                      if (clientName.isEmpty && phone.isEmpty && email.isEmpty && address.isEmpty && leadDate == null && estimatedBudget.isEmpty && labelDescription.isEmpty)
                                        const Center(child: Text("No additional info")),
                                    ],
                                  ),
                                ),
                                _followUpsTab(name),
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

  Widget _followUpsTab(String restaurantName) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: () => _showAddFollowUpDialog(restaurantName),
            icon: const Icon(Icons.add),
            label: const Text("Add Follow-up"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('followups')
                .where('restaurantId', isEqualTo: widget.restaurantId)
                .orderBy('followUpDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No follow-ups found"));
              }

              final docs = snapshot.data!.docs;

              // Categorize follow-ups
              final pendingDocs = docs.where((d) {
                final s = (d.data() as Map<String, dynamic>)['status'] ?? 'pending';
                return s == 'pending';
              }).toList();
              final completedDocs = docs.where((d) {
                final s = (d.data() as Map<String, dynamic>)['status'] ?? 'pending';
                return s == 'completed';
              }).toList();

              return ListView(
                children: [
                  if (pendingDocs.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text('Pending', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                    ...pendingDocs.map((doc) => _followUpCard(doc)),
                  ],
                  if (completedDocs.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('Completed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                    ...completedDocs.map((doc) => _followUpCard(doc)),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddFollowUpDialog(String restaurantName) async {
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Follow-up for $restaurantName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter follow-up notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Date'),
                      subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 0)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Time'),
                      subtitle: Text(selectedTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;

                    final followUpDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    await FirebaseFirestore.instance.collection('followups').add({
                      'restaurantId': widget.restaurantId,
                      'restaurantName': restaurantName,
                      'description': descriptionController.text.trim(),
                      'followUpDate': Timestamp.fromDate(followUpDateTime),
                      'org': currentUserOrg,
                      'createdBy': uid,
                      'createdAt': FieldValue.serverTimestamp(),
                      'status': 'pending',
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Follow-up added successfully!')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Follow-up card (used by categorized display) ──
  Widget _followUpCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final date = (d['followUpDate'] as Timestamp).toDate();
    final desc = d['description'] ?? '';
    final status = d['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
          status == 'completed' ? Icons.check_circle : Icons.schedule,
          color: status == 'completed' ? Colors.green : Colors.orange,
        ),
        title: Text(DateFormat('MMM d, yyyy  hh:mm a').format(date)),
        subtitle: desc.isNotEmpty ? Text(desc) : null,
        trailing: Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: status == 'completed' ? Colors.green : Colors.orange,
          ),
        ),
      ),
    );
  }

  // ── Tasks tab ──
  Widget _tasksTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('No data'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> tasks = data['tasks'] ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () => _showAddTaskDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (tasks.isEmpty)
              const Expanded(child: Center(child: Text('No tasks yet')))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index] as Map<String, dynamic>;
                    final title = task['title'] ?? '';
                    final status = task['status'] ?? 'pending';
                    final isDone = status == 'completed';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: IconButton(
                          icon: Icon(
                            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isDone ? Colors.green : Colors.grey,
                          ),
                          onPressed: () => _toggleTaskStatus(index, tasks),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? Colors.grey : Colors.black,
                          ),
                        ),
                        trailing: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDone ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _toggleTaskStatus(int index, List<dynamic> tasks) async {
    final updated = List<dynamic>.from(tasks);
    final task = Map<String, dynamic>.from(updated[index] as Map);
    task['status'] = task['status'] == 'completed' ? 'pending' : 'completed';
    updated[index] = task;

    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .update({'tasks': updated});
  }

  Future<void> _showAddTaskDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter task description',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('restaurants')
                  .doc(widget.restaurantId)
                  .update({
                'tasks': FieldValue.arrayUnion([
                  {'title': text, 'status': 'pending'}
                ]),
              });

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

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