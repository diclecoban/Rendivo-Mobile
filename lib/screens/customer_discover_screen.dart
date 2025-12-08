import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'customer_booking_screen.dart';

class CustomerDiscoverScreen extends StatefulWidget {
  const CustomerDiscoverScreen({super.key});

  @override
  State<CustomerDiscoverScreen> createState() => _CustomerDiscoverScreenState();
}

class _CustomerDiscoverScreenState extends State<CustomerDiscoverScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'All';
  final List<String> _categories = const [
    'All',
    'Hair & Beauty',
    'Spa & Wellness',
    'Nails',
    'Makeup'
  ];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _businesses = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredBusinesses = [];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final snapshot =
          await FirebaseFirestore.instance.collection('businesses').get();

      setState(() {
        _businesses = snapshot.docs;
        _filteredBusinesses = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load businesses: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredBusinesses = _businesses.where((doc) {
        final data = doc.data();
        final businessName =
            (data['businessName'] as String? ?? '').toLowerCase();
        final city =
            ((data['address']?['city']) as String? ?? '').toLowerCase();
        final tags = (data['services'] as List<dynamic>?)
                ?.map((item) => (item['name'] as String?)?.toLowerCase() ?? '')
                .join(' ') ??
            '';
        final type = (data['businessType'] as String? ?? '').toLowerCase();

        final matchesQuery = query.isEmpty ||
            businessName.contains(query) ||
            city.contains(query) ||
            tags.contains(query);
        final matchesCategory = _selectedCategory == 'All' ||
            type.contains(_selectedCategory.toLowerCase());

        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  Future<void> _onRefresh() async {
    await _loadBusinesses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Find salons and spas near you',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or city...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey.shade500,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, index) {
                    final label = _categories[index];
                    final isSelected = label == _selectedCategory;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = label;
                        });
                        _applyFilters();
                      },
                      selectedColor: primaryPink.withOpacity(0.18),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? primaryPink : Colors.black87,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey.shade300,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.grey.shade200,
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _categories.length,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nearby Businesses',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_filteredBusinesses.length} found',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorState(
                  message: _error!,
                  onRetry: _loadBusinesses,
                )
              else if (_filteredBusinesses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No businesses found.\nTry another search term.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ..._filteredBusinesses.map((doc) {
                  final data = doc.data();
                  final address =
                      (data['address'] as Map<String, dynamic>?) ?? {};
                  final services =
                      (data['services'] as List<dynamic>?) ?? const [];

                  return _BusinessCard(
                    name: data['businessName'] ?? 'Business',
                    type: data['businessType'] ?? '',
                    location: [
                      address['street'],
                      address['city'],
                      address['state']
                    ]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(', '),
                    phone: data['phone'] ?? '',
                    services: services
                        .map((item) => item['name'] as String?)
                        .whereType<String>()
                        .toList(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerBookingScreen(
                            businessDocId: doc.id,
                            businessData: data,
                          ),
                        ),
                      );
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final String name;
  final String type;
  final String location;
  final String phone;
  final List<String> services;
  final VoidCallback onTap;

  const _BusinessCard({
    required this.name,
    required this.type,
    required this.location,
    required this.phone,
    required this.services,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (type.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              type,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
          if (services.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.take(3).map((service) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6E9F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    service,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B4D6D),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Book Now',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
