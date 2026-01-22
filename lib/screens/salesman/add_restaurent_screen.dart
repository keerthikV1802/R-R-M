// add_restaurant_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddRestaurantScreen extends StatefulWidget {
  const AddRestaurantScreen({super.key});

  @override
  State<AddRestaurantScreen> createState() => _AddRestaurantScreenState();
}

class _AddRestaurantScreenState extends State<AddRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameC = TextEditingController();
  final TextEditingController _phoneC = TextEditingController();
  final TextEditingController _emailC = TextEditingController();
  final TextEditingController _addressC = TextEditingController();
  final TextEditingController _followUpDescC = TextEditingController();
  final TextEditingController _clientNameC = TextEditingController();
  final TextEditingController _budgetC = TextEditingController(); // NEW: budget controller

  DateTime? _selectedDate;
  DateTime? _followUpDate;
  TimeOfDay? _followUpTime;
  bool _loading = false;
  String? _error;
  bool _addFollowUp = false;

  final List<String> _statusOptions = ['Sales', 'After Sales', 'Contingency'];
  Map<String, List<String>> _statusWithLabels = {
    'Sales': [],
    'After Sales': [],
    'Contingency': [],
  };
  String? _selectedStatus;
  String? _selectedLabel;

  String get _dateText {
    if (_selectedDate == null) return 'Select date';
    return DateFormat.yMMMMd().format(_selectedDate!);
  }

  String get _followUpDateText {
    if (_followUpDate == null) return 'Select follow-up date';
    return DateFormat.yMMMMd().format(_followUpDate!);
  }

  String get _followUpTimeText {
    if (_followUpTime == null) return '09:00 AM'; // Default display
    return _followUpTime!.format(context);
  }

  @override
  void initState() {
    super.initState();
    _followUpTime = const TimeOfDay(hour: 9, minute: 0); // Set default time to 9 AM
    _selectedDate = DateTime.now(); // Default to current date
    _initCustomisations();
  }

  Future<void> _initCustomisations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final org = userDoc.data()?['org'] ?? '';

      final customRef = FirebaseFirestore.instance
          .collection('organisations')
          .doc(org)
          .collection('users')
          .doc(user.uid)
          .collection('customisations')
          .doc('statuswithlabel');

      final customDoc = await customRef.get();

      if (!customDoc.exists) {
        await customRef.set({
          'sales': ["hot1", "cold1", "warm1"],
          'aftersales': ["hot2", "cold2", "warm2"],
          'contingency': ["hot3", "cold3", "warm3"],
        });
      }

      final data = (await customRef.get()).data() ?? {};

      setState(() {
        _statusWithLabels = {
          'Sales': List<String>.from(data['sales'] ?? ['hot1', 'cold1', 'warm1'])
              .where((e) => e != 'default')
              .toList(),
          'After Sales': List<String>.from(data['aftersales'] ?? ['hot2', 'cold2', 'warm2'])
              .where((e) => e != 'default')
              .toList(),
          'Contingency': List<String>.from(data['contingency'] ?? ['hot3', 'cold3', 'warm3'])
              .where((e) => e != 'default')
              .toList(),
        };

        _selectedStatus = _selectedStatus ?? 'Sales';
        final labels = _statusWithLabels[_selectedStatus] ?? ['default'];
        _selectedLabel = _selectedLabel ?? (labels.isNotEmpty ? labels.first : 'default');
      });
    } catch (e) {
      debugPrint('initCustomisations error: $e');
      setState(() {
        _statusWithLabels = {
          'Sales': ['hot1', 'cold1', 'warm1'],
          'After Sales': ['hot2', 'cold2', 'warm2'],
          'Contingency': ['hot3', 'cold3', 'warm3'],
        };
        _selectedStatus = _selectedStatus ?? 'Sales';
        _selectedLabel = _selectedLabel ?? _statusWithLabels[_selectedStatus]!.first;
      });
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _addressC.dispose();
    _followUpDescC.dispose();
    _clientNameC.dispose();
    _budgetC.dispose(); // Dispose budget controller
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      setState(() => _followUpDate = picked);
    }
  }

  Future<void> _pickFollowUpTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _followUpTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _followUpTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate follow-up fields if checkbox is checked (description now optional)
    if (_addFollowUp) {
      if (_followUpDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select follow-up date'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // Time has default value, so no need to validate
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No logged-in user");

      debugPrint('🔐 Current user: ${user.uid}');

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) throw Exception("User not found");
      final userData = userDoc.data()!;
      final orgName = userData['org'] ?? 'unknown_org';
      final creatorName = userData['name'] ?? user.email ?? 'Unknown';
      final creatorRole = userData['role'] ?? 'salesperson';
      final ownerLevel2 = userData['reportsTo'];

      debugPrint('🏢 Organization: $orgName');
      debugPrint('👤 User: $creatorName ($creatorRole)');

      final customRef = FirebaseFirestore.instance
          .collection('organisations')
          .doc(orgName)
          .collection('users')
          .doc(user.uid)
          .collection('customisations')
          .doc('statuswithlabel');

      final customDoc = await customRef.get();
      if (!customDoc.exists) {
        await customRef.set({
          'sales': ["hot1", "cold1", "warm1"],
          'aftersales': ["hot2", "cold2", "warm2"],
          'contingency': ["hot3", "cold3", "warm3"],
        });
      }

      final chosenStatus = _selectedStatus ?? 'Sales';
      final chosenLabel = _selectedLabel ?? (_statusWithLabels[chosenStatus]?.first ?? 'default');

      final restaurantData = {
        'name': _nameC.text.trim(),
        'nameLower': _nameC.text.trim().toLowerCase(),
        'phone': _phoneC.text.trim(),
        'email': _emailC.text.trim(),
        'address': _addressC.text.trim(),
        'clientName': _clientNameC.text.trim(),
        'estimatedBudget': _budgetC.text.trim(), // NEW: save budget
        'leadDate':
            _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
        'status': chosenStatus,
        'label': [chosenLabel],
        'org': orgName,
        'createdBy': user.uid,
        'createdByName': creatorName,
        'createdByRole': creatorRole,
        'createdByEmail': user.email,
        'ownerLevel2': ownerLevel2 ?? null,
        'isImported': false,
        'oldUid': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final orgUserRef = FirebaseFirestore.instance
          .collection('organisations')
          .doc(orgName)
          .collection('users')
          .doc(user.uid)
          .collection('restaurants')
          .doc();

      await orgUserRef.set({
        ...restaurantData,
        'id': orgUserRef.id,
      });

      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(orgUserRef.id)
          .set({
        ...restaurantData,
        'id': orgUserRef.id,
      });

      debugPrint('✅ Restaurant saved: ${orgUserRef.id}');

      // Add follow-up if requested
      if (_addFollowUp) {
        debugPrint('📝 Attempting to save follow-up...');
        debugPrint('   Description: ${_followUpDescC.text.trim()}');
        debugPrint('   Date: $_followUpDate');
        debugPrint('   Time: $_followUpTime');

        final followUpDateTime = DateTime(
          _followUpDate!.year,
          _followUpDate!.month,
          _followUpDate!.day,
          _followUpTime!.hour,
          _followUpTime!.minute,
        );

        debugPrint('   Combined DateTime: $followUpDateTime');

        final followUpData = {
          'restaurantId': orgUserRef.id,
          'restaurantName': _nameC.text.trim(),
          'description': _followUpDescC.text.trim(), // Can be empty now
          'followUpDate': Timestamp.fromDate(followUpDateTime),
          'org': orgName,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        };

        debugPrint('   Follow-up data: $followUpData');

        final followUpRef = await FirebaseFirestore.instance
            .collection('followups')
            .add(followUpData);

        debugPrint('✅ Follow-up saved with ID: ${followUpRef.id}');
        debugPrint('   Org: $orgName');
        debugPrint('   CreatedBy: ${user.uid}');
        debugPrint('   FollowUpDate: ${Timestamp.fromDate(followUpDateTime)}');
      } else {
        debugPrint('⚠️ Follow-up checkbox not checked, skipping...');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      debugPrint("✅ Restaurant added successfully, returning true");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_addFollowUp
              ? 'Restaurant and follow-up added successfully!'
              : 'Restaurant added successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('❌ Error saving: $e');
      if (!mounted) return;
      setState(() => _error = 'Save failed: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F7),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.arrow_back, color: Colors.blue),
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            'Add New Lead',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _label('Client Organisation Name', required: true),
                  const SizedBox(height: 6),
                  _roundedInput(
                    controller: _nameC,
                    hint: 'Enter Client Organisation Name',
                    textInputAction: TextInputAction.next,
                    prefix: const Icon(Icons.person_outline,
                        color: Color(0xFF2E9AFF)),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Please enter name' : null,
                  ),
                  const SizedBox(height: 16),

                  _label('Phone Number', required: true),
                  const SizedBox(height: 6),
                  _roundedInput(
                    controller: _phoneC,
                    hint: 'Enter phone number',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    prefix: const Icon(Icons.phone, color: Color(0xFF2E9AFF)),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter phone';
                      if (v.trim().length < 6) return 'Enter valid phone';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _label('Email Address'),
                  const SizedBox(height: 6),
                  _roundedInput(
                    controller: _emailC,
                    hint: 'abc@gmail.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefix: const Icon(Icons.email_outlined,
                        color: Color(0xFF2E9AFF)),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                        return 'Enter valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _label('Date', required: true),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: _roundedInput(
                        controller: TextEditingController(text: _dateText),
                        hint: 'Select date',
                        suffix: IconButton(
                          icon: const Icon(Icons.calendar_today,
                              color: Color(0xFF2E9AFF)),
                          onPressed: _pickDate,
                        ),
                        validator: (_) => _selectedDate == null
                            ? 'Please select date'
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _label('Address'),
                  const SizedBox(height: 6),
                  _roundedInput(
                    controller: _addressC,
                    hint: 'Add address',
                    textInputAction: TextInputAction.next,
                    suffix: const Icon(Icons.add_location_alt_outlined,
                        color: Color(0xFF2E9AFF)),
                  ),

                  const SizedBox(height: 16),

                  _label('Client Name'),
                  const SizedBox(height: 6),
                  _roundedInput(
                    controller: _clientNameC,
                    hint: 'Enter client name (person to contact)',
                    textInputAction: TextInputAction.next,
                    prefix: const Icon(Icons.person, color: Color(0xFF2E9AFF)),
                  ),

                  const SizedBox(height: 16),

                  // NEW: Estimated Budget field
                  _label('Estimated Budget'),
                  const SizedBox(height: 6),
                  _roundedInput(
                    controller: _budgetC,
                    hint: 'Enter estimated budget',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    prefix: const Icon(Icons.currency_rupee, color: Color(0xFF2E9AFF)),
                  ),

                  const SizedBox(height: 16),

                  _label('Status', required: true),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    items: _statusOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedStatus = v;
                        final options = _statusWithLabels[_selectedStatus] ?? ['default'];
                        _selectedLabel = options.isNotEmpty ? options.first : 'default';
                      });
                    },
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Please select status' : null,
                  ),

                  const SizedBox(height: 12),

                  _label('Label', required: true),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final options = _statusWithLabels[_selectedStatus] ?? ['default'];
                    if ((_selectedLabel == null || !_selectedLabel!.isNotEmpty) && options.isNotEmpty) {
                      _selectedLabel = options.first;
                    } else if (!options.contains(_selectedLabel)) {
                      _selectedLabel = options.isNotEmpty ? options.first : 'default';
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedLabel,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      items: options
                          .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedLabel = v;
                        });
                      },
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Please select label' : null,
                    );
                  }),

                  const SizedBox(height: 22),

                  // Follow-up section (optional)
                  Container(
                    decoration: BoxDecoration(
                      color: _addFollowUp ? Colors.blue.shade50 : Colors.white,
                      border: Border.all(
                        color: _addFollowUp ? Colors.blue : Colors.grey.shade300,
                        width: _addFollowUp ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _addFollowUp,
                              onChanged: (value) {
                                setState(() => _addFollowUp = value ?? false);
                              },
                            ),
                            const Expanded(
                              child: Text(
                                'Add Follow-up Reminder',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_addFollowUp)
                              const Icon(Icons.notifications_active,
                                  color: Colors.blue, size: 20),
                          ],
                        ),
                        if (_addFollowUp) ...[
                          const Divider(),
                          const SizedBox(height: 8),
                          _label('Follow-up Description'), // Now optional
                          const SizedBox(height: 6),
                          _roundedInput(
                            controller: _followUpDescC,
                            hint: 'Enter follow-up notes (optional)',
                            textInputAction: TextInputAction.done,
                            prefix: const Icon(Icons.note,
                                color: Color(0xFF2E9AFF)),
                          ),
                          const SizedBox(height: 12),
                          _label('Follow-up Date', required: true),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickFollowUpDate,
                            child: AbsorbPointer(
                              child: _roundedInput(
                                controller: TextEditingController(
                                    text: _followUpDateText),
                                hint: 'Select follow-up date',
                                suffix: IconButton(
                                  icon: const Icon(Icons.calendar_today,
                                      color: Color(0xFF2E9AFF)),
                                  onPressed: _pickFollowUpDate,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _label('Follow-up Time'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickFollowUpTime,
                            child: AbsorbPointer(
                              child: _roundedInput(
                                controller: TextEditingController(
                                    text: _followUpTimeText),
                                hint: 'Select time (default 9:00 AM)',
                                suffix: IconButton(
                                  icon: const Icon(Icons.access_time,
                                      color: Color(0xFF2E9AFF)),
                                  onPressed: _pickFollowUpTime,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        elevation: 6,
                        backgroundColor: const Color(0xFF041033),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'SAVE',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: Text(
          text + (required ? ' *' : ''),
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: required ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _roundedInput({
    required TextEditingController controller,
    String? hint,
    Widget? prefix,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: prefix)
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }
}