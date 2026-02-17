import 'package:flutter/material.dart';
import 'package:restaurent_management/assign_level_screen.dart';
import 'package:restaurent_management/screens/salesman/more/organisation_profile_screen.dart';
import '../update_profile_screen.dart';

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  Widget _settingsTile(BuildContext context,
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
          child: Icon(icon, color: color),
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
        title: const Text("General Settings"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                child: Text(
                  "Super admin account for Hh",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              _settingsTile(
                context,
                icon: Icons.person_outline,
                color: Colors.blue,
                title: "My Profile",
                subtitle: "Manage account information",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UpdateProfileScreen(),
                    ),
                  );
                },
              ),
              _settingsTile(
                context,
                icon: Icons.business_outlined,
                color: Colors.indigo,
                title: "My Organisation",
                subtitle: "Manage organisation info",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrganisationProfileScreen(),
                    ),
                  );
                },
              ),
              _settingsTile(
                context,
                icon: Icons.notifications_none_outlined,
                color: Colors.cyan,
                title: "Notifications",
                subtitle: "Leads, Activities Notification",
              ),
              _settingsTile(
                context,
                icon: Icons.delete_outline,
                color: Colors.redAccent,
                title: "Delete My Account",
                subtitle: "Permanently remove this account",
              ),
              const SizedBox(height: 12),
              _settingsTile(
                context,
                icon: Icons.group,
                color: Colors.lightBlue,
                title: "Assign Team",
                subtitle: "Assign level3 users to a level2 manager",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssignLevelScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
