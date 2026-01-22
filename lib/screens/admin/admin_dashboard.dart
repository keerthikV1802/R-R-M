// admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:restaurent_management/RestaurantPaginatedListScreen.dart';
import 'package:restaurent_management/followup_calendar_screen.dart';
import 'package:restaurent_management/manager_list_screen.dart';
import 'package:restaurent_management/screens/salesman/RestaurantListScreen.dart';
import 'package:restaurent_management/screens/salesman/more/general_settings_screen.dart';

import 'package:restaurent_management/services/auth_service.dart';
import 'package:restaurent_management/screens/authentication/login_screen.dart';
import 'package:restaurent_management/screens/salesman/add_restaurent_screen.dart';
import 'package:restaurent_management/screens/salesman/importCSVscreen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    "Restaurants",
    "Sales Team",
    "Dashboard",
    "Calender",
    "More",
  ];

  // keep your GlobalKey typed to the State you want to access
  final GlobalKey<RestaurantPaginatedListScreenState> _leadsPageKey =
      GlobalKey<RestaurantPaginatedListScreenState>();

  List<Widget> get _pages => [
        // Use the StatefulWidget here, not the State class:
        RestaurantPaginatedListScreen(key: _leadsPageKey),
        const ManagerListScreen(),
        const Center(child: Text("SOON.....")),
        const FollowUpCalendarScreen(),
        const GeneralSettingsScreen(),
      ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final authService = AuthService();
      await authService.logout();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ---------- NEW: show add options bottom sheet (same behaviour as Sales screen) ----------
  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Create New Restaurant",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.description_outlined,
                      color: Colors.blueAccent),
                ),
                title: const Text("Add via Form"),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet

                  // Open add restaurant screen and wait for result
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddRestaurantScreen(),
                    ),
                  );

                  // If AddRestaurantScreen returned true, refresh list
                  if (result == true && mounted) {
                    try {
                      _leadsPageKey.currentState?.refreshList();
                    } catch (e, st) {
                      debugPrint('Error refreshing leads page: $e\n$st');
                    }
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.file_upload_outlined,
                      color: Colors.blueAccent),
                ),
                title: const Text("Import CSV File"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImportCsvScreen()),
                  );
                },
              ),
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
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _pages[_selectedIndex],

      // Floating action button now visible for ALL users on Leads tab
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOptions(context),
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Add Restaurant",
                  style: TextStyle(color: Colors.white)),
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            label: 'Restaurants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Sales Team',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calender',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_outlined),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
