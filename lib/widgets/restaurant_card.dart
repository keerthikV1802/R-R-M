import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RestaurantCard extends StatelessWidget {
  final String name;
  final String status;
  final dynamic label; // can be List or String
  final DateTime? createdAt;
  final bool isImported;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.name,
    required this.status,
    required this.label,
    required this.createdAt,
    required this.onTap,
    required this.isImported,
  });

  @override
  Widget build(BuildContext context) {
    final labelText = (label is List)
        ? (label as List).join(', ')
        : (label ?? 'Empty').toString();

    final createdText = createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt!)
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF041033),
                      ),
                    ),
                  ),
                  if (isImported)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Imported",
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (status.isNotEmpty)
                    Chip(
                      label: Text(status),
                      backgroundColor: Colors.blue.shade50,
                      labelStyle: const TextStyle(color: Colors.blue),
                    ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(labelText),
                    backgroundColor: Colors.red.shade50,
                    labelStyle: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Created on: $createdText",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
