import 'package:flutter/material.dart';

import 'package:restaurent_management/screens/customizationscreen.dart';
import 'package:restaurent_management/screens/exportdatascreen.dart';

import 'more/general_settings_screen.dart';

class MoreOptionsScreen extends StatelessWidget {
  const MoreOptionsScreen({super.key});

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
      appBar: AppBar(
        title: const Text("More Options"),
        centerTitle: true,
      ),
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
              icon: Icons.integration_instructions_outlined,
              color: Colors.cyan,
              title: "Manage Integration",
              subtitle: "Facebook, Zapier, Indiamart",
            ),
            _optionTile(
              context,
              icon: Icons.subscriptions_outlined,
              color: Colors.deepPurple,
              title: "Manage Subscription",
              subtitle: "Billing & plans",
            ),
            _optionTile(
              context,
              icon: Icons.groups_outlined,
              color: Colors.indigo,
              title: "Manage Team",
              subtitle: "Add or edit team members",
            ),
            _optionTile(
              context,
              icon: Icons.tune_outlined,
              color: Colors.teal,
              title: "Customization",
              subtitle: "UI & workflow setup",
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
              icon: Icons.account_tree_outlined,
              color: Colors.blueAccent,
              title: "Manage Lead Distribution",
              subtitle: "Assign leads automatically",
            ),
            _optionTile(
  context,
  icon: Icons.file_download,
  color: Colors.lightBlue,
  title: "Export Data",
  subtitle: "Download reports as CSV",
  onTap: () async {
    await exportRestaurantsCSV(context);
  },
),

            _optionTile(
              context,
              icon: Icons.info_outline,
              color: Colors.orange,
              title: "Disclosure",
              subtitle: "Terms & policies",
            ),
            _optionTile(
              context,
              icon: Icons.logout,
              color: Colors.redAccent,
              title: "Logout",
              subtitle: "Sign out from this account",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Logout clicked")),
                );
              },
            ),
            // inside your admin/more options list


          ],
        ),
      ),
    );
  }
}
