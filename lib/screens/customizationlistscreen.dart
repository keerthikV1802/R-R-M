import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomizeListScreen extends StatefulWidget {
  final String title;       // Lead labels / Lead status
  final String docName;     // "labels" or "status"

  const CustomizeListScreen({
    super.key,
    required this.title,
    required this.docName,
  });

  @override
  State<CustomizeListScreen> createState() => _CustomizeListScreenState();
}

class _CustomizeListScreenState extends State<CustomizeListScreen> {
  List<String> items = [];
  bool loading = true;
  late String org;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    org = userDoc['org'];

    final doc = await FirebaseFirestore.instance
        .collection('organisations')
        .doc(org)
        .collection('customizations')
        .doc(widget.docName)
        .get();

    if (doc.exists && doc.data() != null) {
      items = List<String>.from(doc['list']);
    }

    setState(() => loading = false);
  }

  Future<void> saveData() async {
    await FirebaseFirestore.instance
        .collection('organisations')
        .doc(org)
        .collection('customizations')
        .doc(widget.docName)
        .set({'list': items});
  }

  void showAddDialog() {
    final TextEditingController controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Add New ${widget.title}",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: "Enter name",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  items.add(controller.text.trim());
                  await saveData();
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text("ADD"),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Customize ${widget.title}"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.primaries[
                                item.hashCode % Colors.primaries.length],
                          ),
                          title: Text(item),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              items.removeAt(index);
                              await saveData();
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 🔥 Add button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: showAddDialog,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade900,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "Add New ${widget.title}",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
