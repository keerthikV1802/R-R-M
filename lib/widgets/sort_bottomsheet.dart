import 'package:flutter/material.dart';

class SortBottomSheet extends StatelessWidget {
  final String initialSort; // current selected sort type
  final Function(String) onSelected; // callback when user chooses sort option

  const SortBottomSheet({
    super.key,
    required this.initialSort,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sorts = [
      "default",
      "name",
      "status",
      "label",
      "latest",
    ];

    return ListView(
      shrinkWrap: true,
      children: sorts.map((s) {
        return ListTile(
          title: Text(s.toUpperCase()),
          trailing: s == initialSort
              ? const Icon(Icons.check, color: Colors.blue)
              : null,
          onTap: () => onSelected(s),
        );
      }).toList(),
    );
  }
}
