import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomizeStatusWithLabelScreen extends StatefulWidget {
  const CustomizeStatusWithLabelScreen({super.key});

  @override
  State<CustomizeStatusWithLabelScreen> createState() =>
      _CustomizeStatusWithLabelScreenState();
}

class _CustomizeStatusWithLabelScreenState
    extends State<CustomizeStatusWithLabelScreen> {
  late String org;
  late String uid;

  Map<String, List<String>> data = {};

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    uid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    org = userDoc['org'];

    final doc = await FirebaseFirestore.instance
        .collection('organisations')
        .doc(org)
        .collection('users')
        .doc(uid)
        .collection('customisations')
        .doc('statuswithlabel')
        .get();

    if (!doc.exists) {
      // Default values for new users
      await doc.reference.set({
        'Sales': ["default"],
        'After Sales': ["default"],
        'Contigency': ["default"],
      });
    }

    data = Map<String, List<String>>.from(
      doc.data()!.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
    );

    setState(() => loading = false);
  }

  Future<void> save() async {
    await FirebaseFirestore.instance
        .collection('organisations')
        .doc(org)
        .collection('users')
        .doc(uid)
        .collection('customisations')
        .doc('statuswithlabel')
        .set(data);
  }

  // ---------------------------------------------------------------------
  // ADD NEW STATUS
  // ---------------------------------------------------------------------
  void addStatus() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Add new Status",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: "Status name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  String name = controller.text.trim();

                  if (name.isEmpty) return;

                  if (!data.containsKey(name)) {
                    data[name] = ["default"];
                    await save();
                    setState(() {});
                  }

                  Navigator.pop(context);
                },
                child: const Text("ADD STATUS"),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // ADD NEW LABEL UNDER STATUS
  // ---------------------------------------------------------------------
  void addItem(String category) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Add new label in $category"),
              const SizedBox(height: 12),
              TextField(controller: controller),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;

                  data[category]!.add(controller.text.trim());

                  await save();
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text("ADD LABEL"),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Status with Labels"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: addStatus, // <-- NEW STATUS BUTTON
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: data.keys
                  .map(
                    (status) => buildCategory(status),
                  )
                  .toList(),
            ),
    );
  }

  Widget buildCategory(String title) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- Status Header ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => addItem(title),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        data.remove(title);
                        await save();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ---------- Labels List ----------
            Column(
              children: data[title]!
                  .map(
                    (item) => ListTile(
                      title: Text(item),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          data[title]!.remove(item);
                          await save();
                          setState(() {});
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
