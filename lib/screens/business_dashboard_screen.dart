import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../services/session_service.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final _backend = BackendService.instance;
  final _session = SessionService.instance;

  Business? _business;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final businesses = await _backend.fetchBusinesses();

      // If user is logged in, try to pick business by email match; otherwise pick first.
      final email = _session.currentEmail?.toLowerCase();
      Business? match;
      if (email != null) {
        match = businesses
            .where((b) => b.email.toLowerCase() == email)
            .toList()
            .cast<Business?>()
            .firstOrNull;
      }
      match ??= businesses.isNotEmpty ? businesses.first : null;

      setState(() {
        _business = match;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  int get _serviceCount => _business?.services.length ?? 0;
  int get _staffCount => _business?.staff.length ?? 0;

  @override
  Widget build(BuildContext context) {
    final user = _session.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBusiness,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _business?.businessName.isNotEmpty == true
                                ? 'Hello, ${_business!.businessName}!'
                                : 'Hello${user != null ? ', ${user.fullName}' : ''}!',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Here's what's happening with your business.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: primaryPink,
                      child: Text(
                        (_business?.businessName.isNotEmpty ?? false)
                            ? _business!.businessName[0].toUpperCase()
                            : (user?.fullName.isNotEmpty ?? false)
                                ? user!.fullName[0].toUpperCase()
                                : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Services',
                        mainValue: _loading ? '...' : _serviceCount.toString(),
                        trendText: 'Active services',
                        trendColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: 'Staff',
                        mainValue: _loading ? '...' : _staffCount.toString(),
                        trendText: 'Team members',
                        trendColor: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _KpiCard(
                  title: 'Contact',
                  mainValue:
                      _business?.phone.isNotEmpty == true ? _business!.phone : '-',
                  trendText: _business?.email ?? '',
                  trendColor: Colors.grey,
                ),

                const SizedBox(height: 16),

                _SectionTitle('Services'),
                const SizedBox(height: 8),
                _CardContainer(
                  child: _loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(color: primaryPink),
                          ),
                        )
                      : _error != null
                          ? Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            )
                          : (_business?.services.isNotEmpty ?? false)
                              ? Column(
                                  children: _business!.services
                                      .take(5)
                                      .map(
                                        (s) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _ServiceRow(service: s),
                                        ),
                                      )
                                      .toList(),
                                )
                              : const Text(
                                  'No services yet.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                ),

                const SizedBox(height: 16),

                _SectionTitle('Staff'),
                const SizedBox(height: 8),
                _CardContainer(
                  child: _loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(color: primaryPink),
                          ),
                        )
                      : (_business?.staff.isNotEmpty ?? false)
                          ? Column(
                              children: _business!.staff
                                  .take(5)
                                  .map(
                                    (m) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _StaffRow(member: m),
                                    ),
                                  )
                                  .toList(),
                            )
                          : const Text(
                              'No staff listed.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String mainValue;
  final String trendText;
  final Color trendColor;

  const _KpiCard({
    required this.title,
    required this.mainValue,
    required this.trendText,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mainValue,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trendText,
            style: TextStyle(
              fontSize: 11,
              color: trendColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;

  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final ServiceItem service;

  const _ServiceRow({required this.service});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: primaryPink.withOpacity(0.15),
          child: const Icon(
            Icons.content_cut,
            size: 16,
            color: primaryPink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${service.durationMinutes} min · \$${service.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaffRow extends StatelessWidget {
  final StaffMember member;

  const _StaffRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: primaryPink.withOpacity(0.15),
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: primaryPink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                member.role,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
