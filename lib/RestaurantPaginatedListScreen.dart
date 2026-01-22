// lib/screens/salesman/restaurant_paginated_list.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:restaurent_management/RestaurantSearchList.dart';
import 'package:restaurent_management/widgets/restaurant_card.dart';
import 'package:restaurent_management/screens/salesman/RestaurantDetailScreen.dart';

class RestaurantPaginatedListScreen extends StatefulWidget {
  const RestaurantPaginatedListScreen({super.key});

  @override
  State<RestaurantPaginatedListScreen> createState() =>
      RestaurantPaginatedListScreenState();
}

class RestaurantPaginatedListScreenState
    extends State<RestaurantPaginatedListScreen> with WidgetsBindingObserver {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey<RestaurantSearchListState> _searchListKey =
      GlobalKey<RestaurantSearchListState>();

  List<Map<String, dynamic>> _items = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _shouldRefreshOnResume = false;
  bool _isSearchFocused = false;
  String searchQuery = "";

  // filters
  String? selectedStatus; // null => All
  String? selectedLabel; // null => All

  String currentOrg = '';

  // user profile related
  String? _role;
  String? _uid;
  bool _profileLoaded = false;
  List<String> _assignedSalespersonIds = [];

  // Known status->labels (loaded from user customizations, fallback defaults)
  Map<String, List<String>> statusWithLabels = {
    'Sales': ['default'],
    'After Sales': ['default'],
    'Contingency': ['default'],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to search focus changes (guard with mounted)
_searchFocusNode.addListener(() {
  if (!mounted) return;
  setState(() {
    _isSearchFocused = _searchFocusNode.hasFocus;
  });
});


    // Load profile first, then fetch data
    _loadCurrentUserOrgAndCustomizations().then((_) {
      _fetchFirstPage();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 80 &&
          !_isLoading &&
          _hasMore) {
        _fetchMore();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed && _shouldRefreshOnResume) {
      _fetchFirstPage();
      _shouldRefreshOnResume = false;
    }
  }

  Future<void> _loadCurrentUserOrgAndCustomizations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to continue')),
        );
      }
      return;
    }

    _uid = uid;

    try {
      // Try global users collection first
      final global =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (global.exists) {
        _role = (global.data()?['role'] ?? '').toString();
        currentOrg = (global.data()?['org'] ?? '').toString();
      } else {
        // Fallback: search organisations for the user doc
        final orgs =
            await FirebaseFirestore.instance.collection('organisations').get();
        for (final d in orgs.docs) {
          final u = await d.reference.collection('users').doc(uid).get();
          if (u.exists) {
            currentOrg = d.id;
            _role = (u.data()?['role'] ?? '').toString();
            // Write back a global user doc for convenience (merge)
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'uid': uid,
              'name': u.data()?['name'] ?? '',
              'email': u.data()?['email'] ?? '',
              'role': u.data()?['role'] ?? '',
              'org': d.id,
            }, SetOptions(merge: true));
            break;
          }
        }
      }

      // load status->labels if present under organisation user customisations
      if (currentOrg.isNotEmpty) {
        try {
          final customRef = FirebaseFirestore.instance
              .collection('organisations')
              .doc(currentOrg)
              .collection('users')
              .doc(uid)
              .collection('customisations')
              .doc('statuswithlabel');

          final customDoc = await customRef.get();
          if (customDoc.exists) {
            final data = customDoc.data()!;
            statusWithLabels = {
              'Sales': List<String>.from(data['sales'] ?? []),
              'After Sales': List<String>.from(data['aftersales'] ?? []),
              'Contingency': List<String>.from(data['contingency'] ?? []),
            };
          }
        } catch (e) {
          debugPrint('Error loading customizations: $e');
          // keep defaults on error
        }
      }

      // If manager (level2), fetch assigned salespersons
      if ((_role ?? '').toString() == 'level2') {
        _assignedSalespersonIds = await _getAssignedSalespersonIds(uid, currentOrg);
      }
    } catch (e, st) {
      debugPrint('load customizations error: $e\n$st');
    }

    if (mounted) {
      setState(() {
        _profileLoaded = true;
      });
    }
  }

  // Fetch assigned salespersons for a manager from org users subcollection
  Future<List<String>> _getAssignedSalespersonIds(String uid, String org) async {
    if (org.isEmpty) return [];
    try {
      final q = await FirebaseFirestore.instance
          .collection('organisations')
          .doc(org)
          .collection('users')
          .where('assignedTo', isEqualTo: uid)
          .where('role', isEqualTo: 'level3')
          .get();

      return q.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('error fetching assigned salespersons: $e');
      return [];
    }
  }

  // Add nameLower field when saving/updating restaurants for search
  Future<void> _ensureSearchFields() async {
    final restaurants = await FirebaseFirestore.instance
        .collection('restaurants')
        .where('org', isEqualTo: currentOrg)
        .get();

    for (var doc in restaurants.docs) {
      final data = doc.data();
      if (!data.containsKey('nameLower')) {
        await doc.reference.update({
          'nameLower': (data['name'] ?? '').toString().toLowerCase(),
        });
      }
    }
  }

  // Build Firestore query. Only status & org & ordering used server-side.
  Query _buildQuery({DocumentSnapshot? startAfter}) {
    Query q = FirebaseFirestore.instance.collection('restaurants');

    // Always restrict to organisation if we know it
    if (currentOrg.isNotEmpty) {
      q = q.where('org', isEqualTo: currentOrg);
    }

    // Role-based owner filtering:
final role = _role ?? '';
if (role == 'level3' || role == 'salesperson') {
  // salesperson: only their own restaurants
  if (_uid != null) q = q.where('createdBy', isEqualTo: _uid);
} else if (role == 'level2') {
  // manager: restaurants by assigned salespersons + restaurants created by the manager themself
  final uid = _uid; // local final so Dart can promote after null-check

  if (uid == null) {
    // no uid -> nothing visible
    q = q.where('createdBy', isEqualTo: '__NO_ONE__');
  } else {
    // combine assigned salespersons and manager uid
    final combined = <String>[];
    combined.addAll(_assignedSalespersonIds);
    if (!combined.contains(uid)) combined.add(uid);

    // Firestore whereIn supports up to 10 items. If more, trim for now.
    // TODO: If you need full coverage for >10 owners, perform multiple queries (batch whereIn) and merge results.
    final listForQuery = combined.isEmpty
        ? <String>['__NO_ONE__'] // ensure we never pass an empty list to whereIn
        : (combined.length <= 10 ? combined : combined.sublist(0, 10));

    q = q.where('createdBy', whereIn: listForQuery);
  }
} else {
  // level1/admin -> no owner restriction (all restaurants in org)
}


    // Only apply server-side status filter for known statuses
    if (selectedStatus != null &&
        selectedStatus!.isNotEmpty &&
        selectedStatus != '__OTHERS_STATUS__') {
      q = q.where('status', isEqualTo: selectedStatus);
    }

    // order by createdAt (newest first)
    q = q.orderBy('createdAt', descending: true);

    if (startAfter != null) q = q.startAfterDocument(startAfter);

    return q.limit(_pageSize);
  }

  Future<void> _fetchFirstPage() async {
    _items = [];
    _lastDoc = null;
    _hasMore = true;
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
  if (!_hasMore || _isLoading) return;

  // mark loading only if mounted (avoid setState after dispose)
  if (mounted) {
    setState(() => _isLoading = true);
  } else {
    // if we're already disposed, don't continue
    return;
  }

  try {
    final q = _buildQuery(startAfter: _lastDoc);
    final snap = await q.get();
    final docs = snap.docs;

    final pageItems = docs.map((d) {
      final data = d.data();
      final map = <String, dynamic>{};
      if (data is Map<String, dynamic>) {
        map.addAll(data);
      } else if (data is Map) {
        map.addAll(Map<String, dynamic>.from(data));
      }
      map['id'] = d.id;
      return map;
    }).toList();

    // If selectedStatus is '__OTHERS_STATUS__', include only items whose status is NOT one of known statuses
    List<Map<String, dynamic>> afterStatusFiltering;
    if (selectedStatus == '__OTHERS_STATUS__') {
      final knownStatuses = statusWithLabels.keys.toSet();
      afterStatusFiltering = pageItems.where((m) {
        final s = (m['status'] ?? '').toString();
        return !knownStatuses.contains(s);
      }).toList();
    } else {
      afterStatusFiltering = pageItems;
    }

    // Now apply label filtering
    List<Map<String, dynamic>> filtered;
    if (selectedLabel == null || selectedLabel!.isEmpty) {
      filtered = afterStatusFiltering;
    } else if (selectedLabel == '__OTHERS__') {
      final known = _getKnownLabelsForSelectedStatus();
      filtered = afterStatusFiltering.where((m) {
        final lab = m['label'];
        if (lab == null) return true;
        if (lab is String) return !known.contains(lab);
        if (lab is List) {
          for (final l in lab) {
            if (known.contains(l)) return false;
          }
          return true;
        }
        return true;
      }).toList();
    } else {
      filtered = afterStatusFiltering.where((m) {
        final lab = m['label'];
        if (lab == null) return false;
        if (lab is String) return lab == selectedLabel;
        if (lab is List) return lab.contains(selectedLabel);
        return false;
      }).toList();
    }

    // Only update state if still mounted
    if (!mounted) return;
    setState(() {
      _items.addAll(filtered);
      _lastDoc = docs.isNotEmpty ? docs.last : _lastDoc;
      _hasMore = docs.length == _pageSize;
    });
  } catch (e, st) {
    debugPrint('fetchPage error: $e\n$st');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading restaurants: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}


  Future<void> _fetchMore() => _fetchPage();

  // Public method to refresh the list (called from parent widget)
  Future<void> refreshList() async {
    debugPrint("🔄 refreshList() called - fetching first page");
    await _fetchFirstPage();
  }

  // Helpers to build dropdowns ------------------------------------------------

  // return known labels list for currently selected status
  List<String> _getKnownLabelsForSelectedStatus() {
    if ((selectedStatus ?? '').isEmpty || selectedStatus == '__OTHERS_STATUS__') {
      final set = <String>{};
      for (final v in statusWithLabels.values) {
        set.addAll(v);
      }
      return set.toList();
    }
    return statusWithLabels[selectedStatus] ?? [];
  }

  // Build list for label dropdown, dependent on selectedStatus.
  // 'All' -> '', 'Others' -> '__OTHERS__'
  List<DropdownMenuItem<String>> _labelDropdownItems() {
    final known = _getKnownLabelsForSelectedStatus();
    final items = <DropdownMenuItem<String>>[];
    items.add(const DropdownMenuItem(value: '', child: Text('All')));
    for (final l in known) {
      items.add(DropdownMenuItem(value: l, child: Text(l)));
    }
    items.add(const DropdownMenuItem(value: '__OTHERS__', child: Text('Others')));
    return items;
  }

  // When status is changed
  void _onStatusChanged(String? rawValue) {
    setState(() {
      if (rawValue == null || rawValue.isEmpty) {
        selectedStatus = null;
      } else {
        selectedStatus = rawValue;
      }
      // reset label whenever status changes
      selectedLabel = null;
    });
    // restart pagination
    _fetchFirstPage();
  }

  // ----------------------------- Build UI ------------------------------------

  @override
  Widget build(BuildContext context) {
    // Wait until profile is loaded so we don't fetch without role/org filters
    if (!_profileLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final statusItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('All')),
      const DropdownMenuItem(value: 'Sales', child: Text('Sales')),
      const DropdownMenuItem(value: 'After Sales', child: Text('After Sales')),
      const DropdownMenuItem(value: 'Contingency', child: Text('Contingency')),
      const DropdownMenuItem(value: '__OTHERS_STATUS__', child: Text('Others')),
    ];

    final labelItems = _labelDropdownItems();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: "Search by name or phone",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: Colors.black, width: 1),
                  ),
                  suffixIcon: _isSearchFocused
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            if (_searchController.text.isEmpty) {
                              FocusScope.of(context).unfocus();
                            } else {
                              setState(() {
                                searchQuery = "";
                                _searchController.clear();
                              });
                              FocusScope.of(context).unfocus();
                            }
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => searchQuery = value.toLowerCase());
                },
                onTap: () {
                  _searchFocusNode.requestFocus();
                },
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Show filters only when NOT searching
            if (searchQuery.isEmpty) ...[
              // top filter row
              Container(
                color: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedStatus ?? '',
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: false,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        dropdownColor: Colors.white,
                        items: statusItems,
                        onChanged: _onStatusChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedLabel ?? '',
                        decoration: InputDecoration(
                          labelText: 'Label',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: false,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        dropdownColor: Colors.white,
                        items: labelItems,
                        onChanged: (v) {
                          setState(() {
                            selectedLabel = (v == null || v.isEmpty) ? null : v;
                          });
                          _fetchFirstPage();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // list - show search results or paginated list
            Expanded(
              child: searchQuery.isNotEmpty
                  ? RestaurantSearchList(
                      key: _searchListKey,
                      searchQuery: searchQuery,
                      currentOrg: currentOrg,
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchFirstPage,
                      child: _items.isEmpty && !_isLoading
                          ? ListView(
                              children: const [
                                SizedBox(height: 100),
                                Center(
                                  child: Text(
                                    'No restaurants found',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                ),
                              ],
                            )
                          : _buildRestaurantList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Extracted list building logic
  Widget _buildRestaurantList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index == _items.length) {
          if (_isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (!_hasMore && _items.isNotEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No more restaurants',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        }

        final item = _items[index];
        final name = (item['name'] ?? '').toString();
        final status = (item['status'] ?? '').toString();
        final label = item['label'];
        final labelText = label is List
            ? (label.isNotEmpty ? label.join(', ') : 'default')
            : (label?.toString() ?? 'default');
        final isImported = item['isImported'] == true;
        final createdAt = (item['createdAt'] is Timestamp)
            ? (item['createdAt'] as Timestamp).toDate()
            : DateTime.now();

        return RestaurantCard(
          name: name,
          status: status,
          label: labelText,
          isImported: isImported,
          createdAt: createdAt,
          onTap: () async {
            // Wait for the detail screen to return
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RestaurantDetailScreen(restaurantId: item['id']),
              ),
            );
            // Refresh the list when coming back
            refreshList();
          },
        );
      },
    );
  }
}
