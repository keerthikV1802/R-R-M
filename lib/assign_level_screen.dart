// assign_level_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AssignLevelScreen extends StatefulWidget {
  const AssignLevelScreen({super.key});

  @override
  State<AssignLevelScreen> createState() => _AssignLevelScreenState();
}

class _AssignLevelScreenState extends State<AssignLevelScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _orgId;
  String? _selectedLevel2Uid; // currently selected level2 (manager)
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Future<void> _loadOrg() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // read global user doc to get org
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!mounted) return;
    setState(() {
      _orgId = userDoc.data()?['org']?.toString() ?? '';
    });
  }

  // Assign a level3 user to level2
  Future<void> _assignLevel3ToLevel2({
    required String level3Uid,
    required String level2Uid,
  }) async {
    final org = _orgId!;
    final level3Ref = _firestore
        .collection('organisations')
        .doc(org)
        .collection('users')
        .doc(level3Uid);

    final level2Ref = _firestore
        .collection('organisations')
        .doc(org)
        .collection('users')
        .doc(level2Uid);

    final prev = await level3Ref.get();
    final prevAssignedTo = prev.data()?['assignedTo'] as String?;

    final batch = _firestore.batch();

    // set level3.assignedTo = level2Uid
    batch.set(level3Ref, {'assignedTo': level2Uid}, SetOptions(merge: true));

    // add to level2.team array (optional cache)
    batch.set(level2Ref, {
      'team': FieldValue.arrayUnion([level3Uid])
    }, SetOptions(merge: true));

    // If previously assigned to another level2, remove from that team's array
    if (prevAssignedTo != null && prevAssignedTo != level2Uid) {
      final prevLevel2Ref = _firestore
          .collection('organisations')
          .doc(org)
          .collection('users')
          .doc(prevAssignedTo);
      batch.set(prevLevel2Ref, {
        'team': FieldValue.arrayRemove([level3Uid])
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // Unassign a level3 from the given level2
  Future<void> _unassignLevel3FromLevel2({
    required String level3Uid,
    required String level2Uid,
  }) async {
    final org = _orgId!;
    final level3Ref = _firestore
        .collection('organisations')
        .doc(org)
        .collection('users')
        .doc(level3Uid);

    final level2Ref = _firestore
        .collection('organisations')
        .doc(org)
        .collection('users')
        .doc(level2Uid);

    final batch = _firestore.batch();

    // remove assignedTo field from level3
    batch.set(level3Ref, {
      'assignedTo': FieldValue.delete()
    }, SetOptions(merge: true));

    // remove from level2.team array
    batch.set(level2Ref, {
      'team': FieldValue.arrayRemove([level3Uid])
    }, SetOptions(merge: true));

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    if (_orgId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Assign Team")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final orgRef = _firestore.collection('organisations').doc(_orgId);

    return Scaffold(
      appBar: AppBar(title: const Text("Assign Level3 → Level2")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // LEVEL2 selector (dropdown)
            StreamBuilder<QuerySnapshot>(
              stream: orgRef.collection('users').where('role', isEqualTo: 'level2').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const ListTile(
                    title: Text("No Level2 users found"),
                  );
                }

                final items = docs.map((d) => MapEntry(d.id, d.data() as Map<String, dynamic>)).toList();

                return DropdownButtonFormField<String>(
                  value: _selectedLevel2Uid,
                  decoration: const InputDecoration(labelText: "Select Level2 (Manager)"),
                  items: items.map((e) {
                    final uid = e.key;
                    final m = e.value;
                    final label = (m['name'] ?? m['email'] ?? uid).toString();
                    return DropdownMenuItem(value: uid, child: Text(label));
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedLevel2Uid = v;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            // LEVEL3 list with checkboxes
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: orgRef.collection('users').where('role', isEqualTo: 'level3').snapshots(),
                builder: (context, snap3) {
                  if (!snap3.hasData) return const Center(child: CircularProgressIndicator());
                  final level3Docs = snap3.data!.docs;

                  if (level3Docs.isEmpty) {
                    return const Center(child: Text("No level3 users found"));
                  }

                  return ListView.separated(
                    itemCount: level3Docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final doc = level3Docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final uid = doc.id;
                      final name = (data['name'] ?? data['email'] ?? uid).toString();
                      final assignedTo = data['assignedTo']?.toString();

                      final isAssignedToSelected = (_selectedLevel2Uid != null) && (assignedTo == _selectedLevel2Uid);

                      return ListTile(
                        title: Text(name),
                        subtitle: Text(assignedTo == null ? 'Unassigned' : 'Assigned to: $assignedTo'),
                        trailing: _selectedLevel2Uid == null
                            ? const Text("Select manager above")
                            : Checkbox(
                                value: isAssignedToSelected,
                                onChanged: (val) async {
                                  setState(() => _loading = true);
                                  try {
                                    if (val == true) {
                                      await _assignLevel3ToLevel2(level3Uid: uid, level2Uid: _selectedLevel2Uid!);
                                    } else {
                                      // unassign only if currently assigned to this selected manager
                                      if (assignedTo == _selectedLevel2Uid) {
                                        await _unassignLevel3FromLevel2(level3Uid: uid, level2Uid: _selectedLevel2Uid!);
                                      }
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                                  } finally {
                                    if (mounted) setState(() => _loading = false);
                                  }
                                },
                              ),
                      );
                    },
                  );
                },
              ),
            ),

            if (_loading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
