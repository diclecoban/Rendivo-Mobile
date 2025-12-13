import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import 'customer_booking_screen.dart';

class CustomerDiscoverScreen extends StatefulWidget {
  const CustomerDiscoverScreen({super.key});

  @override
  State<CustomerDiscoverScreen> createState() =>
      _CustomerDiscoverScreenState();
}

class _CustomerDiscoverScreenState extends State<CustomerDiscoverScreen> {
  final _searchController = TextEditingController();
  final _backend = BackendService.instance;

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

  static const Map<String, List<String>> _categoryKeywords = {
    'hair & beauty': ['hair', 'beauty', 'salon', 'barber'],
    'spa & wellness': ['spa', 'wellness', 'relax'],
    'nails': ['nail', 'manicure', 'pedicure'],
    'makeup': ['makeup', 'cosmetic', 'artist'],
  };

  List<Business> _businesses = [];
  List<Business> _filteredBusinesses = [];

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
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final snapshot = await _backend.fetchBusinesses();
      if (!mounted) return;

      setState(() {
        _businesses = snapshot;
        _filteredBusinesses = _filterBusinesses(snapshot);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load businesses: $e';
        _isLoading = false;
      });
    }
  }

  List<Business> _filterBusinesses(List<Business> source) {
    final query = _searchController.text.toLowerCase().trim();
    final normalizedCategory = _selectedCategory.toLowerCase();

    bool matchesCategory(Business business) {
      if (normalizedCategory == 'all') return true;
      final type = business.businessType.toLowerCase();
      final serviceTags = business.services
          .map((service) => service.name.toLowerCase())
          .join(' ');
      final keywords = _categoryKeywords[normalizedCategory];
      if (keywords != null && keywords.isNotEmpty) {
        return keywords.any(
          (keyword) => type.contains(keyword) || serviceTags.contains(keyword),
        );
      }
      return type.contains(normalizedCategory);
    }

    return source.where((business) {
      final name = business.businessName.toLowerCase();
      final city = business.address.city.toLowerCase();
      final tags = business.services
          .map((service) => service.name.toLowerCase())
          .join(' ');

      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          city.contains(query) ||
          tags.contains(query);

      return matchesQuery && matchesCategory(business);
    }).toList();
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      _filteredBusinesses = _filterBusinesses(_businesses);
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
            physics: const AlwaysScrollableScrollPhysics(),
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
                  const Text(
                    'Nearby Businesses',
                    style: TextStyle(
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
                ..._filteredBusinesses.map((business) {
                  return _BusinessCard(
                    business: business,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerBookingScreen(business: business),
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
  final Business business;
  final VoidCallback onTap;

  const _BusinessCard({
    required this.business,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final addressParts = [
      business.address.street,
      business.address.city,
      business.address.state,
    ].where((value) => value.isNotEmpty).join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
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
                business.businessName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (business.businessType.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  business.businessType,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
              if (addressParts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        addressParts,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              if (business.phone.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone_outlined,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      business.phone,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ],
              if (business.services.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: business.services.take(3).map((service) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6E9F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        service.name,
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
        ),
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
