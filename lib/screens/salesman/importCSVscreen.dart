// lib/screens/salesman/import_csv_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  bool _isLoading = false;

  Future<Map<String, String>> _getCurrentImporterInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    String name = 'importer';
    String role = 'import';
    String org = '';

    if (uid.isEmpty) return {'uid': '', 'name': name, 'role': role, 'org': org};

    final g = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (g.exists) {
      final d = g.data()!;
      name = (d['name'] ?? '').toString();
      role = (d['role'] ?? '').toString();
      org = (d['org'] ?? '').toString();
      return {'uid': uid, 'name': name, 'role': role, 'org': org};
    }

    // fallback search inside organisations
    final orgs = await FirebaseFirestore.instance.collection('organisations').get();
    for (final orgDoc in orgs.docs) {
      final u = await orgDoc.reference.collection('users').doc(uid).get();
      if (u.exists) {
        final ud = u.data()!;
        name = (ud['name'] ?? '').toString();
        role = (ud['role'] ?? '').toString();
        org = orgDoc.id;
        // also write global doc for faster access later
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'name': name,
          'email': ud['email'] ?? '',
          'role': role,
          'org': org,
          'joinedAt': ud['joinedAt'] ?? FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        break;
      }
    }

    return {'uid': uid, 'name': name, 'role': role, 'org': org};
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;

    // Try multiple common formats
    try {
      // ISO-like
      final dt = DateTime.tryParse(s);
      if (dt != null) return dt;
      // Try common dd/MM/yyyy or dd-MM-yyyy
      final formats = ['dd/MM/yyyy', 'd/M/yyyy', 'dd-MM-yyyy', 'yyyy-MM-dd'];
      for (final f in formats) {
        try {
          final parsed = DateFormat(f).parseStrict(s);
          return parsed;
        } catch (_) {}
      }
      // Try milliseconds as number
      final millis = int.tryParse(s);
      if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (_) {}
    return null;
  }

  Future<void> _pickCsvAndImport() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

      Uint8List? bytes = result.files.first.bytes;
      final filename = result.files.first.name.replaceAll('.csv.csv', '.csv');

      // Fallback (Android sometimes returns path only)
      if (bytes == null) {
        final path = result.files.first.path;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          bytes = await file.readAsBytes();
        }
      }

      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not read file bytes.")),
        );
        setState(() => _isLoading = false);
        return;
      }

      final csvString = utf8.decode(bytes);
      final csvTable = const CsvToListConverter(eol: '\n').convert(csvString);

      if (csvTable.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("CSV is empty.")),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Build header map (safe, lower-case)
      final rawHeader = csvTable.first.map((h) => h.toString()).toList();
      final header = rawHeader.map((h) => h.toLowerCase().trim()).toList();
      final indexOf = <String, int>{};
      for (var i = 0; i < header.length; i++) indexOf[header[i]] = i;

      // Common alternative names -> canonical field name
      String getCell(List<dynamic> row, List<String> candidates) {
        for (final c in candidates) {
          final key = c.toLowerCase();
          if (indexOf.containsKey(key)) {
            final idx = indexOf[key]!;
            if (idx < row.length) return row[idx]?.toString() ?? '';
          }
        }
        return '';
      }

      // importer info
      final importer = await _getCurrentImporterInfo();
      final importerUid = importer['uid'] ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      final importerName = importer['name'] ?? 'importer';
      final importerRole = importer['role'] ?? 'import';
      final importerOrg = importer['org'] ?? '';

      int importedCount = 0;
      final batch = FirebaseFirestore.instance.batch();

      // Start from second row (skip header)
      for (final row in csvTable.skip(1)) {
        // Defensive: ensure row is list
        final r = row as List<dynamic>;

        // Map fields by trying many possible headers
        final name = getCell(r, ['name', 'restaurant', 'restaurant name']);
        final email = getCell(r, ['email', 'email address']);
        final phone = getCell(r, ['phone', 'phone number', 'mobile']);
        final address = getCell(r, ['address', 'addr']);
        final org = getCell(r, ['org', 'organisation', 'organization'])?.isNotEmpty == true
            ? getCell(r, ['org', 'organisation', 'organization'])
            : importerOrg;
        final status = getCell(r, ['status']) ?? '';
        final label = getCell(r, ['label', 'labels', 'category']) ?? '';
        final leadDateRaw = getCell(r, ['leaddate', 'lead_date', 'date', 'lead date']);
        final leadDate = _tryParseDate(leadDateRaw);

        // Prepare data map
        final data = <String, dynamic>{
          'name': name,
          'email': email,
          'phone': phone,
          'address': address,
          'org': org,
          'status': status.isNotEmpty ? status : 'Sales',
          // keep label as string for now (your UI handles both list and string)
          'label': label.isNotEmpty ? label : 'default',
          'isImported': true,
          'createdBy': importerUid,
          'createdByName': importerName,
          'createdByRole': importerRole,
          'createdByEmail': FirebaseAuth.instance.currentUser?.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (leadDate != null) {
          data['leadDate'] = Timestamp.fromDate(leadDate);
        }

        // Add document
        final docRef = FirebaseFirestore.instance.collection('importedrestaurants').doc();
        batch.set(docRef, {...data, 'id': docRef.id});

        importedCount++;
      }

      // Commit batch
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Imported $importedCount rows from $filename")),
      );
    } catch (e, st) {
      debugPrint('CSV import error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Import failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Import CSV")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text("Upload CSV File"),
                onPressed: _pickCsvAndImport,
              ),
      ),
    );
  }
}
