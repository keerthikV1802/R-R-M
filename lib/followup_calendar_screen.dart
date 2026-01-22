// lib/screens/salesman/followup_calendar_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurent_management/add_followup_screen.dart';
import 'package:restaurent_management/screens/salesman/RestaurantDetailScreen.dart';

class FollowUpCalendarScreen extends StatefulWidget {
  const FollowUpCalendarScreen({super.key});

  @override
  State<FollowUpCalendarScreen> createState() => _FollowUpCalendarScreenState();
}

class _FollowUpCalendarScreenState extends State<FollowUpCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  DateTime _currentWeekStart = DateTime.now(); // Track current week
  List<Map<String, dynamic>> _followUps = [];
  Map<String, int> _followUpCounts = {};
  bool _isLoading = false;
  String currentOrg = '';

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
    _loadUserOrgAndFetchFollowUps();
    _debugFirestoreData();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  // Debug method to check Firestore data
  Future<void> _debugFirestoreData() async {
    if (currentOrg.isEmpty) return;

    try {
      // Check all follow-ups for current organization
      final allFollowUps = await FirebaseFirestore.instance
          .collection('followups')
          .where('org', isEqualTo: currentOrg)
          .get();

      debugPrint('🔍 DEBUG: Total follow-ups in Firestore for org: ${allFollowUps.docs.length}');
      
      for (var doc in allFollowUps.docs) {
        final data = doc.data();
        debugPrint('📄 ID: ${doc.id}');
        debugPrint('   Restaurant: ${data['restaurantName']}');
        debugPrint('   Date: ${data['followUpDate']}');
        debugPrint('   Created By: ${data['createdBy']}');
        debugPrint('   Description: ${data['description']}');
      }
    } catch (e) {
      debugPrint('❌ Debug error: $e');
    }
  }

  Future<void> _loadUserOrgAndFetchFollowUps() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        currentOrg = userDoc.data()?['org'] ?? '';
      }

      if (mounted) {
        setState(() {});
        await _fetchFollowUpCountsForMonth(_currentMonth);
        _fetchFollowUpsForDate(_selectedDate);
      }
    } catch (e) {
      debugPrint('Error loading org: $e');
    }
  }

    Future<void> _fetchFollowUpCountsForMonth(DateTime month) async {
    if (currentOrg.isEmpty) return;

    try {
      // Build UTC month range (safer for Firestore Timestamp comparisons)
      final startOfMonthUtc = DateTime.utc(month.year, month.month, 1, 0, 0, 0);
      final endOfMonthUtc = DateTime.utc(month.year, month.month + 1, 1, 0, 0, 0)
          .subtract(const Duration(seconds: 1));

      debugPrint('📅 Fetching follow-up counts for month: ${DateFormat('MMMM yyyy').format(month)}');
      debugPrint('🔍 Query: org=$currentOrg (ALL USERS)');
      debugPrint('📆 UTC Date range: $startOfMonthUtc to $endOfMonthUtc');

      final snapshot = await FirebaseFirestore.instance
          .collection('followups')
          .where('org', isEqualTo: currentOrg)
          .where('followUpDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonthUtc))
          .where('followUpDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonthUtc))
          .get();

      debugPrint('✅ Found ${snapshot.docs.length} follow-ups for the month (all users)');

      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['followUpDate'] is Timestamp) {
          final utcDate = (data['followUpDate'] as Timestamp).toDate().toUtc();
          // convert to local for the UI key so the dot appears on user's local date
          final localDate = utcDate.toLocal();
          final dateKey = DateFormat('yyyy-MM-dd').format(localDate);
          counts[dateKey] = (counts[dateKey] ?? 0) + 1;
        }
      }

      if (mounted) setState(() => _followUpCounts = counts);
    } catch (e) {
      debugPrint('❌ Error fetching follow-up counts: $e');
    }
  }


    Future<void> _fetchFollowUpsForDate(DateTime date) async {
    if (currentOrg.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Build UTC day range for the selected local date
      // Convert the local date's midnight to the equivalent UTC midnight instant:
      final localMidnight = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final startOfDayUtc = localMidnight.toUtc();
      final endOfDayUtc = localMidnight.add(const Duration(hours: 23, minutes: 59, seconds: 59)).toUtc();

      debugPrint('📅 Fetching follow-ups for date: ${DateFormat('yyyy-MM-dd').format(date)}');
      debugPrint('🔍 Query: org=$currentOrg (ALL USERS)');
      debugPrint('📆 UTC range: $startOfDayUtc to $endOfDayUtc');

      final snapshot = await FirebaseFirestore.instance
          .collection('followups')
          .where('org', )
          .where('followUpDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDayUtc))
          .where('followUpDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDayUtc))
          .orderBy('followUpDate')
          .get();

      debugPrint('✅ Found ${snapshot.docs.length} follow-ups for this date (all users)');

      if (!mounted) return;

      setState(() {
        _followUps = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching follow-ups: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _onDateSelected(DateTime date) {
    setState(() => _selectedDate = date);
    _fetchFollowUpsForDate(date);
  }

  void _previousMonth() {
    final newMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    setState(() => _currentMonth = newMonth);
    _fetchFollowUpCountsForMonth(newMonth);
  }

  void _nextMonth() {
    final newMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    setState(() => _currentMonth = newMonth);
    _fetchFollowUpCountsForMonth(newMonth);
  }

  // NEW: Navigate to previous week
  void _previousWeek() {
    final newWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    setState(() {
      _currentWeekStart = newWeekStart;
      _selectedDate = newWeekStart;
      
      // Update month if week crosses month boundary
      if (newWeekStart.month != _currentMonth.month || 
          newWeekStart.year != _currentMonth.year) {
        _currentMonth = newWeekStart;
        _fetchFollowUpCountsForMonth(newWeekStart);
      }
    });
    _fetchFollowUpsForDate(newWeekStart);
  }

  // NEW: Navigate to next week
  void _nextWeek() {
    final newWeekStart = _currentWeekStart.add(const Duration(days: 7));
    setState(() {
      _currentWeekStart = newWeekStart;
      _selectedDate = newWeekStart;
      
      // Update month if week crosses month boundary
      if (newWeekStart.month != _currentMonth.month || 
          newWeekStart.year != _currentMonth.year) {
        _currentMonth = newWeekStart;
        _fetchFollowUpCountsForMonth(newWeekStart);
      }
    });
    _fetchFollowUpsForDate(newWeekStart);
  }

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _currentMonth = today;
      _selectedDate = today;
      _currentWeekStart = _getWeekStart(today);
    });
    _fetchFollowUpCountsForMonth(today);
    _fetchFollowUpsForDate(today);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final followUpCount = _followUpCounts[selectedDateKey] ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              debugPrint('🔄 Manual refresh triggered');
              await _debugFirestoreData();
              await _fetchFollowUpCountsForMonth(_currentMonth);
              _fetchFollowUpsForDate(_selectedDate);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Profile avatar section with follow-up count
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    if (followUpCount > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          child: Center(
                            child: Text(
                              followUpCount > 99 ? '99+' : '$followUpCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCalendarHeader(),
              ],
            ),
          ),

          // Week navigation controls - NEW
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: _previousWeek,
                  tooltip: 'Previous Week',
                ),
                Text(
                  '${DateFormat('MMM d').format(_currentWeekStart)} - ${DateFormat('MMM d, yyyy').format(_currentWeekStart.add(const Duration(days: 6)))}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  onPressed: _nextWeek,
                  tooltip: 'Next Week',
                ),
              ],
            ),
          ),

          // Calendar grid - single week view
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _buildCalendarGrid(),
          ),

          const SizedBox(height: 8),

          // Follow-ups section
          Expanded(
            child: Container(
              color: Colors.white,
              child: _buildFollowUpsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
        ),
        Text(
          DateFormat('MMMM yyyy').format(_currentMonth),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
        ),
        const SizedBox(width: 16),
        TextButton(
          onPressed: _goToToday,
          child: const Text('Today'),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    // Use the current week start instead of calculating from selected date
    final startOfWeek = _currentWeekStart;
    
    final days = <Widget>[];
    final today = DateTime.now();

    // Weekday headers
    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    for (final day in weekdays) {
      days.add(
        Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
      );
    }

    // Days of the week
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final hasFollowUps = _followUpCounts.containsKey(dateKey) && 
                           _followUpCounts[dateKey]! > 0;
      
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isSelected = date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;

      days.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              _onDateSelected(date);
              // Update current month if date is in different month
              if (date.month != _currentMonth.month || date.year != _currentMonth.year) {
                setState(() => _currentMonth = date);
                _fetchFollowUpCountsForMonth(date);
              }
            },
            child: Container(
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue
                    : isToday
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (hasFollowUps)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: days.sublist(0, 7)), // Weekday headers
        const SizedBox(height: 8),
        Row(children: days.sublist(7)), // Week days
      ],
    );
  }

  Widget _buildFollowUpsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_followUps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No follow-ups available on this date',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddFollowUpScreen(
                      currentOrg: currentOrg,
                      preSelectedDate: _selectedDate,
                    ),
                  ),
                );
                if (result == true) {
                  await _fetchFollowUpCountsForMonth(_currentMonth);
                  _fetchFollowUpsForDate(_selectedDate);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('+ Follow-up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Follow-ups (${_followUps.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddFollowUpScreen(
                        currentOrg: currentOrg,
                        preSelectedDate: _selectedDate,
                      ),
                    ),
                  );
                  if (result == true) {
                    await _fetchFollowUpCountsForMonth(_currentMonth);
                    _fetchFollowUpsForDate(_selectedDate);
                  }
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _followUps.length,
            itemBuilder: (context, index) {
              final followUp = _followUps[index];
              return _buildFollowUpCard(followUp);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUpCard(Map<String, dynamic> followUp) {
    final restaurantName = followUp['restaurantName'] ?? 'Unknown';
    final description = followUp['description'] ?? 'No description';
    final time = followUp['followUpDate'] is Timestamp
        ? DateFormat('hh:mm a')
            .format((followUp['followUpDate'] as Timestamp).toDate())
        : '';
    final restaurantId = followUp['restaurantId'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (restaurantId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RestaurantDetailScreen(restaurantId: restaurantId),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                onPressed: () {
                  if (restaurantId.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(restaurantId: restaurantId),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}