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
  List<String> _availableServices = [];
  List<String> _selectedServices = [];

  final List<String> _categories = const [
    'All',
    'Hair & Beauty',
    'Spa & Wellness',
    'Nails',
    'Makeup'
  ];

  List<Business> _businesses = [];
  List<Business> _filteredBusinesses = [];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _fetchAvailableServices();
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

      final snapshot = await _backend.fetchBusinesses();

      setState(() {
        _businesses = snapshot;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = 'Unable to load businesses: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAvailableServices() async {
    try {
      final category = _selectedCategory == 'All'
          ? null
          : _selectedCategory;
      final services =
          await _backend.fetchAvailableServices(businessType: category);
      if (!mounted) return;
      setState(() {
        _availableServices = services;
        if (_availableServices.isNotEmpty) {
          final allowed = _availableServices
              .map((item) => item.toLowerCase())
              .toSet();
          _selectedServices = _selectedServices
              .where((item) => allowed.contains(item.toLowerCase()))
              .toList();
        }
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _availableServices = [];
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    final selectedServices = _selectedServices
        .map((service) => service.toLowerCase())
        .toSet();

    setState(() {
      _filteredBusinesses = _businesses.where((business) {
        final name = business.businessName.toLowerCase();
        final city = business.address.city.toLowerCase();
        final tags = business.services
            .map((service) => service.name.toLowerCase())
            .join(' ');
        final type = business.businessType.toLowerCase();

        final matchesQuery = query.isEmpty ||
            name.contains(query) ||
            city.contains(query) ||
            tags.contains(query);
        final matchesCategory =
            _selectedCategory == 'All' ||
                type.contains(_selectedCategory.toLowerCase());
        final matchesServices = selectedServices.isEmpty ||
            business.services.any(
              (service) => selectedServices.contains(
                service.name.toLowerCase(),
              ),
            );

        return matchesQuery && matchesCategory && matchesServices;
      }).toList();
    });
  }

  Future<void> _openServiceFilterModal() async {
    final tempSelected = List<String>.from(_selectedServices);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Services',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (_selectedCategory != 'All') ...[
                    const SizedBox(height: 4),
                    Text(
                      'Showing services for: $_selectedCategory',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF886385),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_availableServices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No services available yet. Try selecting a different category.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    )
                  else
                    SizedBox(
                      height: 400,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 3.6,
                        ),
                        itemCount: _availableServices.length,
                        itemBuilder: (context, index) {
                          final service = _availableServices[index];
                          final isSelected = tempSelected.contains(service);
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  tempSelected.remove(service);
                                } else {
                                  tempSelected.add(service);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFEF5FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFDF84DC)
                                      : const Color(0xFFE5DCE4),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (_) {
                                      setModalState(() {
                                        if (isSelected) {
                                          tempSelected.remove(service);
                                        } else {
                                          tempSelected.add(service);
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFFDF84DC),
                                  ),
                                  Expanded(
                                    child: Text(
                                      service,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF181117),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(tempSelected.clear);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedServices = tempSelected;
                            });
                            _applyFilters();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Services',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openServiceFilterModal,
                    icon: const Icon(Icons.tune, size: 16),
                    label: Text(
                      _selectedServices.isEmpty
                          ? 'All services'
                          : '${_selectedServices.length} selected',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryPink,
                    ),
                  ),
                ],
              ),
              if (_selectedServices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedServices.map((service) {
                    return Chip(
                      label: Text(service, style: const TextStyle(fontSize: 11)),
                      onDeleted: () {
                        setState(() {
                          _selectedServices.remove(service);
                        });
                        _applyFilters();
                      },
                      deleteIconColor: Colors.grey.shade600,
                      backgroundColor: const Color(0xFFF6E9F7),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
