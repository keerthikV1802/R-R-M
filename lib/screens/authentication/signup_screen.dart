import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isOrgMode = false;
  String? _selectedOrg;
  bool _loading = false;

  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _orgNameC = TextEditingController();
  final _phoneC = TextEditingController();

  Future<List<String>> _getExistingOrgs() async {
    final snapshot = await FirebaseFirestore.instance.collection('organisations').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    try {
      final userCred = await auth.createUserWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passwordC.text.trim(),
      );
      final user = userCred.user;
      if (user == null) return;

      final orgName = _isOrgMode ? _orgNameC.text.trim() : _selectedOrg;

      if (orgName == null || orgName.isEmpty) {
        throw Exception("Please select or enter an organisation name");
      }

      if (_isOrgMode) {
        await firestore.collection('organisations').doc(orgName).set({
          'name': orgName,
          'phone': _phoneC.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final role = _isOrgMode ? 'admin' : 'salesperson';

      await firestore.collection('organisations').doc(orgName)
          .collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': _nameC.text.trim(),
        'email': _emailC.text.trim(),
        'role': role,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': _nameC.text.trim(),
        'email': _emailC.text.trim(),
        'role': role,
        'org': orgName,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registered successfully under $orgName")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _modeButton("In Organisation", false),
                    _modeButton("As Organisation", true),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _input(_nameC, "Full Name", Icons.person_outline),
                    const SizedBox(height: 16),
                    _input(_emailC, "Email", Icons.email_outlined),
                    const SizedBox(height: 16),
                    _input(_passwordC, "Password", Icons.lock_outline,
                        obscure: true),
                    const SizedBox(height: 16),
                    _isOrgMode
                        ? _input(_orgNameC, "Organisation Name", Icons.business_outlined)
                        : FutureBuilder<List<String>>(
                            future: _getExistingOrgs(),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              return DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: "Select Organisation",
                                  prefixIcon: Icon(Icons.business_outlined),
                                ),
                                items: snap.data!
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) => _selectedOrg = v,
                                validator: (v) => v == null ? "Select organisation" : null,
                              );
                            },
                          ),
                    const SizedBox(height: 16),
                    if (_isOrgMode)
                      _input(_phoneC, "Phone Number", Icons.phone),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Register",
                                style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String label, bool mode) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isOrgMode = mode),
        child: Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isOrgMode == mode ? Colors.deepPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _isOrgMode == mode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, IconData i,
      {bool obscure = false}) {
    return TextFormField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(i),
        border: const OutlineInputBorder(),
      ),
      validator: (v) => v == null || v.isEmpty ? "Enter $label" : null,
    );
  }
}
