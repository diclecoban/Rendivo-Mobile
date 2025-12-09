import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../services/session_service.dart';
import 'customer_appointments_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final _backend = BackendService.instance;
  final _session = SessionService.instance;

  List<Appointment> _appointments = [];
  bool _loading = false;
  String? _error;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final hasToken =
        _session.authToken != null && _session.authToken!.isNotEmpty;
    if (!hasToken) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _backend.fetchCustomerAppointments();
      data.sort((a, b) => a.startAt.compareTo(b.startAt));
      setState(() {
        _appointments = data;
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

  String _greeting() {
    final user = _session.currentUser;
    if (user == null) return 'Welcome';
    if (user.fullName.trim().isNotEmpty) {
      final parts = user.fullName.trim().split(' ');
      return 'Hello, ${parts.first}!';
    }
    return 'Hello, ${user.email}';
  }

  int get _upcomingCount {
    final now = DateTime.now();
    return _appointments
        .where(
          (a) =>
              a.startAt.isAfter(now) &&
              a.status.toLowerCase() != 'cancelled',
        )
        .length;
  }

  int get _todayCount {
    final now = DateTime.now();
    return _appointments
        .where((a) =>
            a.startAt.year == now.year &&
            a.startAt.month == now.month &&
            a.startAt.day == now.day)
        .length;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final user = _session.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: primaryPink,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_outlined),
            label: 'Availability',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerAppointmentsScreen(),
              ),
            );
          }
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAppointments,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Here's what's on your schedule.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: primaryPink,
                      child: Text(
                        (user?.fullName.isNotEmpty ?? false)
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
                        title: 'Today',
                        mainValue: _loading ? '...' : _todayCount.toString(),
                        trendText: 'Bookings today',
                        trendColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: 'Upcoming',
                        mainValue:
                            _loading ? '...' : _upcomingCount.toString(),
                        trendText: 'Future bookings',
                        trendColor: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Text(
                  'Upcoming Bookings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: primaryPink),
                    ),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                else if (_appointments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'No bookings yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'New bookings will appear here once scheduled.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: _appointments
                        .take(5)
                        .map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BookingCard(
                              service: a.services.isNotEmpty
                                  ? a.services.first.name
                                  : a.businessName,
                              time: _formatTime(a.startAt),
                              client: a.customerName.isNotEmpty
                                  ? a.customerName
                                  : a.customerEmail,
                              status: a.status,
                            ),
                          ),
                        )
                        .toList(),
                  ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
          const SizedBox(height: 6),
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

class _BookingCard extends StatelessWidget {
  final String service;
  final String time;
  final String client;
  final String status;

  const _BookingCard({
    required this.service,
    required this.time,
    required this.client,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final statusColor = lower == 'cancelled'
        ? Colors.redAccent
        : lower == 'pending'
            ? Colors.orange
            : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: primaryPink.withOpacity(0.12),
            ),
            child: const Icon(
              Icons.event,
              size: 18,
              color: primaryPink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$time · $client',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
