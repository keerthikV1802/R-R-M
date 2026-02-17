import 'package:flutter/material.dart';
import 'package:restaurent_management/screens/customizationscreen.dart';
import 'package:restaurent_management/screens/salesman/more/general_settings_screen.dart';

class AdminMoreOptionsScreen extends StatelessWidget {
  const AdminMoreOptionsScreen({super.key});

  Widget _optionTile(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("$title coming soon...")),
              );
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: ListView(
          children: [
            _optionTile(
              context,
              icon: Icons.settings_outlined,
              color: Colors.blue,
              title: "General Settings",
              subtitle: "My Account, Notifications",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GeneralSettingsScreen(),
                  ),
                );
              },
            ),
            _optionTile(
              context,
              icon: Icons.tune_outlined,
              color: Colors.teal,
              title: "Customization",
              subtitle: "Workflow setup, status & labels",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomizationScreen(),
                  ),
                );
              },
            ),
            _optionTile(
              context,
              icon: Icons.info_outline,
              color: Colors.orange,
              title: "Disclosure",
              subtitle: "Terms & policies",
            ),
          ],
        ),
      ),
    );
  }
}
