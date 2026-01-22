import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> exportRestaurantsCSV(BuildContext context) async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Exporting... Please wait")),
    );

    // Fetch restaurants
    final query = await FirebaseFirestore.instance
        .collection('restaurants')
        .get();

    if (query.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No restaurants found!")),
      );
      return;
    }

    // Create CSV rows
    List<List<dynamic>> csvData = [
      [
        "docId",
        "name",
        "email",
        "phone",
        "address",
        "status",
        "label",
        "leadDate",
        "createdAt",
        "createdBy",
        "createdByEmail",
        "createdByName",
        "createdByRole",
        "org"
      ]
    ];

    for (var doc in query.docs) {
      final d = doc.data();

      csvData.add([
        doc.id,
        d["name"] ?? "",
        d["email"] ?? "",
        d["phone"] ?? "",
        d["address"] ?? "",
        d["status"] ?? "",
        (d["label"] is List) ? d["label"].join("|") : d["label"] ?? "",
        d["leadDate"]?.toDate().toIso8601String() ?? "",
        d["createdAt"]?.toDate().toIso8601String() ?? "",
        d["createdBy"] ?? "",
        d["createdByEmail"] ?? "",
        d["createdByName"] ?? "",
        d["createdByRole"] ?? "",
        d["org"] ?? "",
      ]);
    }

    // Convert to CSV string
    String csv = const ListToCsvConverter().convert(csvData);

    // Convert to bytes
    Uint8List bytes = Uint8List.fromList(utf8.encode(csv));

    // Save to downloads folder
    final fileName =
        "restaurants_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv";

    await FileSaver.instance.saveAs(
      name: fileName,
      bytes: bytes,
      ext: "csv",
      mimeType: MimeType.csv,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("CSV Export Successful! File saved.")),
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Export failed: $e")),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Export Data")),
      body: Center(
        child: ElevatedButton(
  onPressed: () => exportRestaurantsCSV(context),
  child: const Text("Download Restaurants CSV"),
)

      ),
    );
  }

