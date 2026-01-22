import 'package:flutter/material.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameC = TextEditingController(text: "Gg");
  final TextEditingController _phoneC = TextEditingController(text: "7639174856");
  final TextEditingController _emailC = TextEditingController(text: "Keerthikk1807@gmail.com");
  final TextEditingController _companyC = TextEditingController(text: "Hh");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Update Profile"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 55, color: Colors.grey),
              ),
              const SizedBox(height: 25),

              _inputField("Name", _nameC, requiredField: true),
              const SizedBox(height: 16),

              _inputField("Contact number", _phoneC,
                  prefix: "+91", keyboardType: TextInputType.phone),
              const SizedBox(height: 16),

              _inputField("Email", _emailC, readOnly: true, suffix: "Verified"),
              const SizedBox(height: 16),

              _inputField("Company Name", _companyC, requiredField: true),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Profile updated!")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF041033),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "SAVE",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller,
      {String? prefix,
      String? suffix,
      bool readOnly = false,
      bool requiredField = false,
      TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label${requiredField ? ' *' : ''}",
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          validator: (value) {
            if (requiredField && (value == null || value.trim().isEmpty)) {
              return "Please enter $label";
            }
            return null;
          },
          decoration: InputDecoration(
            prefixText: prefix != null ? "$prefix  " : null,
            suffixText: suffix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
      ],
    );
  }
}
