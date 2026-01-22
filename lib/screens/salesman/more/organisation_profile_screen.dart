import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrganisationProfileScreen extends StatefulWidget {
  const OrganisationProfileScreen({super.key});

  @override
  State<OrganisationProfileScreen> createState() =>
      _OrganisationProfileScreenState();
}

class _OrganisationProfileScreenState extends State<OrganisationProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameC = TextEditingController();
  final TextEditingController _currencyC = TextEditingController();
  final TextEditingController _addressC = TextEditingController();
  final TextEditingController _websiteC = TextEditingController();
  final TextEditingController _phoneC = TextEditingController();
  final TextEditingController _descriptionC = TextEditingController();
  final TextEditingController _facebookC = TextEditingController();
  final TextEditingController _instagramC = TextEditingController();
  final TextEditingController _linkedinC = TextEditingController();

  String _selectedTimeZone = "Asia/Kolkata (GMT+05:30)";
  String? _logoPath;
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadOrganisationData();
  }

  Future<void> _loadOrganisationData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Step 1️⃣: Get the user's organisation name
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!userDoc.exists || userDoc.data()?['org'] == null) {
      setState(() => _loading = false);
      return;
    }

    final orgName = userDoc.data()!['org'];

    // Step 2️⃣: Get the user's role inside the organisation's subcollection
    final orgUserDoc = await FirebaseFirestore.instance
        .collection('organisations')
        .doc(orgName)
        .collection('users')
        .doc(uid)
        .get();

    if (orgUserDoc.exists) {
      _isAdmin = orgUserDoc.data()?['role'] == 'admin';
    }

    // Step 3️⃣: Load organisation details
    final orgDoc = await FirebaseFirestore.instance
        .collection('organisations')
        .doc(orgName)
        .get();

    if (orgDoc.exists) {
      final data = orgDoc.data()!;
      setState(() {
        _nameC.text = data['name'] ?? '';
        _currencyC.text = data['currency'] ?? '';
        _addressC.text = data['address'] ?? '';
        _websiteC.text = data['website'] ?? '';
        _phoneC.text = data['phone'] ?? '';
        _descriptionC.text = data['description'] ?? '';
        _facebookC.text = data['facebook'] ?? '';
        _instagramC.text = data['instagram'] ?? '';
        _linkedinC.text = data['linkedin'] ?? '';
        _selectedTimeZone = data['timezone'] ?? "Asia/Kolkata (GMT+05:30)";
      });
    }

    setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    if (!_isAdmin) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logo picker coming soon!")),
    );
  }

  Future<void> _saveProfile() async {
  if (!_isAdmin) return;
  if (_formKey.currentState!.validate()) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final orgName = userDoc.data()?['org'];
    if (orgName == null) return;

    final orgRef =
        FirebaseFirestore.instance.collection('organisations').doc(orgName);

    final orgDoc = await orgRef.get();
    final currentData = orgDoc.data() ?? {};
    final currentName = currentData['name'] ?? '';
    final newName = _nameC.text.trim();

    final updates = {
      'currency': _currencyC.text.trim(),
      'address': _addressC.text.trim(),
      'website': _websiteC.text.trim(),
      'phone': _phoneC.text.trim(),
      'description': _descriptionC.text.trim(),
      'facebook': _facebookC.text.trim(),
      'instagram': _instagramC.text.trim(),
      'linkedin': _linkedinC.text.trim(),
      'timezone': _selectedTimeZone,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 🧩 Check if the name changed
    if (newName != currentName) {
      int counter = 1;

      // Find next available version field
      while (currentData.containsKey('updated_name_$counter')) {
        counter++;
      }

      updates['updated_name_$counter'] = newName; // keep track
      updates['name'] = newName; // update current name
    }

    await orgRef.set(updates, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Organisation profile updated successfully!"),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFD),
        title: const Text(
          "Organisation Profile",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: AbsorbPointer(
          absorbing: !_isAdmin, // 🔹 Disable input fields if not admin
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text("Select Logo"),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isAdmin ? _pickLogo : null,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.blue.shade200, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: _logoPath == null
                        ? const Icon(Icons.add, color: Colors.blueAccent, size: 32)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(_logoPath!, fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                _textField("Organisation name", _nameC, required: true),

                const SizedBox(height: 16),

                const Text("Time-Zone"),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedTimeZone,
                  decoration: _inputDecoration(""),
                  items: const [
                    DropdownMenuItem(
                        value: "Asia/Kolkata (GMT+05:30)",
                        child: Text("Asia/Kolkata (GMT+05:30)")),
                    DropdownMenuItem(
                        value: "America/New_York (GMT-05:00)",
                        child: Text("America/New_York (GMT-05:00)")),
                    DropdownMenuItem(
                        value: "Europe/London (GMT+00:00)",
                        child: Text("Europe/London (GMT+00:00)")),
                  ],
                  onChanged:
                      _isAdmin ? (val) => setState(() => _selectedTimeZone = val!) : null,
                ),
                const SizedBox(height: 16),

                _textField("Currency", _currencyC),
                _textField("Address", _addressC),
                _textField("Website", _websiteC),
                _textField("Phone number", _phoneC, icon: Icons.phone),
                _textField("Description", _descriptionC, maxLines: 3),
                const Text("Socials"),
                const SizedBox(height: 8),
                _textField("Facebook", _facebookC),
                _textField("Instagram", _instagramC),
                _textField("LinkedIn", _linkedinC),

                const SizedBox(height: 30),

                if (_isAdmin)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2A66),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Save",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(
  String label,
  TextEditingController controller, {
  bool required = false,
  IconData? icon,
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(label, icon: icon),
      validator: required
          ? (v) => v == null || v.isEmpty ? "Enter $label" : null
          : null,
    ),
  );
}


  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
    );
  }
}
