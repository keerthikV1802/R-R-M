// lib/screens/salesman/restaurant_search_list.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:restaurent_management/widgets/restaurant_card.dart';
import 'package:restaurent_management/screens/salesman/RestaurantDetailScreen.dart';

/// This widget displays restaurants filtered by a search query (by name or phone)
class RestaurantSearchList extends StatefulWidget {
  final String searchQuery; // Search query entered by user
  final String currentOrg; // Current organization for filtering

  const RestaurantSearchList({
    super.key,
    required this.searchQuery,
    required this.currentOrg,
  });

  @override
  State<RestaurantSearchList> createState() => RestaurantSearchListState();
}

class RestaurantSearchListState extends State<RestaurantSearchList> {
  // Internal state variables
  List<DocumentSnapshot> _restaurants = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchFirstPage();
  }

  @override
  void didUpdateWidget(covariant RestaurantSearchList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-run search if query changes
    if (oldWidget.searchQuery != widget.searchQuery) {
      _fetchFirstPage();
    }
  }

  /// Build Firestore search query for name/phone "startsWith" search
  Query _buildSearchQuery() {
    Query query = FirebaseFirestore.instance.collection("restaurants");
    
    // Filter by organization
    if (widget.currentOrg.isNotEmpty) {
      query = query.where('org', isEqualTo: widget.currentOrg);
    }

    final searchText = widget.searchQuery.toLowerCase();

    // If search query is a number → search by phone
    if (RegExp(r'^[0-9]+$').hasMatch(searchText)) {
      query = query
          .where('phone', isGreaterThanOrEqualTo: searchText)
          .where('phone', isLessThanOrEqualTo: searchText + '\uf8ff')
          .orderBy('phone')
          .orderBy('createdAt', descending: true);
    } else {
      // Otherwise, search by name (lowercase)
      query = query
          .where('nameLower', isGreaterThanOrEqualTo: searchText)
          .where('nameLower', isLessThanOrEqualTo: searchText + '\uf8ff')
          .orderBy('nameLower')
          .orderBy('createdAt', descending: true);
    }

    return query;
  }

  /// Fetch first page of search results
  Future<void> _fetchFirstPage() async {
    print("🔎 Restaurant search query: ${widget.searchQuery}");

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _restaurants.clear();
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final query = _buildSearchQuery().limit(10);
      final snapshot = await query.get();

      if (!mounted) return;
      setState(() {
        _restaurants = snapshot.docs;
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == 10;
        _isLoading = false;
      });

      print("🔹 First page loaded: ${_restaurants.length} restaurants");
    } catch (e) {
      if (!mounted) return;
      print("❌ Error in search first page: $e");
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  }

  /// Fetch more search results (pagination)
  Future<void> _fetchMore() async {
    if (!_hasMore || _isLoading) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      var query = _buildSearchQuery().limit(10);
      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

      final snapshot = await query.get();

      if (!mounted) return;
      setState(() {
        _restaurants.addAll(snapshot.docs);
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
        _hasMore = snapshot.docs.length == 10;
        _isLoading = false;
      });

      print("🔹 Loaded more: ${snapshot.docs.length}, total: ${_restaurants.length}");
    } catch (e) {
      if (!mounted) return;
      print("❌ Error in search fetchMore: $e");
      setState(() => _isLoading = false);
    }
  }

  /// Public method to refresh search results
  Future<void> refreshList() async {
    await _fetchFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder if search is empty
    if (widget.searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Type to search restaurants...",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Show empty state if no results
    if (!_isLoading && _restaurants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No restaurants found for '${widget.searchQuery}'",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      // Detect scroll to bottom and load more
      onNotification: (scroll) {
        if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200) {
          _fetchMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _restaurants.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading spinner at bottom
          if (index >= _restaurants.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          // Extract restaurant data
          final doc = _restaurants[index];
          final data = doc.data() as Map<String, dynamic>? ?? {};

          final name = (data['name'] ?? '').toString();
          final status = (data['status'] ?? '').toString();
          final label = data['label'];
          final labelText = label is List
              ? (label.isNotEmpty ? label.join(', ') : 'default')
              : (label?.toString() ?? 'default');
          final isImported = data['isImported'] == true;
          final createdAt = (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now();

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusScope.of(context).unfocus(); // Close keyboard
            },
            child: RestaurantCard(
              name: name,
              status: status,
              label: labelText,
              isImported: isImported,
              createdAt: createdAt,
              onTap: () async {
                FocusScope.of(context).unfocus();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantDetailScreen(restaurantId: doc.id),
                  ),
                );
                // Refresh after returning from detail screen
                refreshList();
              },
            ),
          );
        },
      ),
    );
  }
}