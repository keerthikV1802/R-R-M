import 'package:flutter/material.dart';
import 'package:restaurent_management/screens/CustomizeStatusWithLabelScreen.dart';




class CustomizationScreen extends StatelessWidget {
  const CustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F7),
      appBar: AppBar(
        title: const Text("Customization"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            
            const SizedBox(height: 16),
            
            _item(
  title: "Status with Labels",
  subtitle: "Sales → hot, cold, warm etc",
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const CustomizeStatusWithLabelScreen(),
    ),
  ),
),

          ],
        ),
      ),
    );
  }

  Widget _item({required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
            const Icon(Icons.arrow_forward_ios_rounded),
          ],
        ),
      ),
    );
  }
}
