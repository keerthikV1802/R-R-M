import 'package:flutter/material.dart';
import 'package:restaurent_management/screens/salesman/salesman_added_restaurants.dart';
 // step 3

class SalespersonOptionsSheet extends StatelessWidget {
  final String salespersonId;
  final String salespersonName;
  final String orgName;

  const SalespersonOptionsSheet({
    super.key,
    required this.salespersonId,
    required this.salespersonName,
    required this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          runSpacing: 8,
          children: [
            Center(
              child: Text(
                salespersonName,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text("See Profile"),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to profile view
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text("Restaurants"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalespersonRestaurantScreen(salespersonId: salespersonId,
                      orgName: orgName,
                      salespersonName: salespersonName,),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt_outlined),
              title: const Text("Tasks"),
              onTap: () {
                // TODO: open tasks later
              },
            ),
          ],
        ),
      ),
    );
  }
}
