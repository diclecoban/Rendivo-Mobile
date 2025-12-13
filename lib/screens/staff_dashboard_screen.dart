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

  final Map<String, bool> _weeklyAvailability = {
    'Mon': true,
    'Tue': true,
    'Wed': true,
    'Thu': true,
    'Fri': true,
    'Sat': false,
    'Sun': false,
  };
  TimeOfDay _startOfDay = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endOfDay = const TimeOfDay(hour: 18, minute: 0);
  bool _autoAssignClients = true;

  bool _pushNotifications = true;
  bool _emailSummaries = false;
  bool _autoConfirm = true;
  double _prepBufferMinutes = 15;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final hasToken =
        _session.authToken != null && _session.authToken!.isNotEmpty;
    if (!hasToken) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to view your schedule.';
        _appointments = [];
      });
      return;
    }

    final role = (_session.currentRole ?? '').toLowerCase();
    final isStaff = role == 'staff' || role == 'business_owner';
    if (!isStaff) {
      setState(() {
        _loading = false;
        _error = 'Staff dashboard is available for staff accounts only.';
        _appointments = [];
      });
      return;
    }

    try {
      final data = await _backend.fetchStaffAppointments();
      data.sort((a, b) => a.startAt.compareTo(b.startAt));
      setState(() {
        _appointments = data;
      });
    } on AppException catch (e) {
      setState(() {
        _error = e.message;
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

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startOfDay : _endOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startOfDay = picked;
      } else {
        _endOfDay = picked;
      }
    });
  }

  void _saveAvailability() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Availability saved for your manager.'),
      ),
    );
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings updated.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboardContent(context),
            _buildBookingsContent(context),
            _buildAvailabilityContent(context),
            _buildSettingsContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    final user = _session.currentUser;
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  mainValue: _loading ? '...' : _upcomingCount.toString(),
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
          ..._buildAppointmentsList(limit: 5),
        ],
      ),
    );
  }

  Widget _buildBookingsContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Booking Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerAppointmentsScreen(),
                    ),
                  );
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primaryPink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildAppointmentsList(),
        ],
      ),
    );
  }

  List<Widget> _buildAppointmentsList({int? limit}) {
    if (_loading) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: primaryPink),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ];
    }
    if (_appointments.isEmpty) {
      return [
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
        ),
      ];
    }

    final items = limit != null ? _appointments.take(limit) : _appointments;
    return items
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
        .toList();
  }

  Widget _buildAvailabilityContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Weekly Availability',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ..._weeklyAvailability.entries.map(
          (entry) => SwitchListTile(
            title: Text(entry.key),
            subtitle: Text(
              entry.value ? 'Accepting bookings' : 'Day off',
            ),
            value: entry.value,
            activeColor: primaryPink,
            onChanged: (value) {
              setState(() {
                _weeklyAvailability[entry.key] = value;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(isStart: true),
                child: Text('Start: ${_formatTimeOfDay(_startOfDay)}'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(isStart: false),
                child: Text('End: ${_formatTimeOfDay(_endOfDay)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _autoAssignClients,
          title: const Text('Auto-assign clients'),
          subtitle: const Text('Let the system assign any staff member'),
          activeColor: primaryPink,
          onChanged: (value) {
            if (value == null) return;
            setState(() => _autoAssignClients = value);
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveAvailability,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Save availability',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Push notifications'),
          subtitle: const Text('Alert me when a new booking is assigned'),
          activeColor: primaryPink,
          value: _pushNotifications,
          onChanged: (value) => setState(() => _pushNotifications = value),
        ),
        SwitchListTile(
          title: const Text('Email summaries'),
          subtitle: const Text('Send me a summary every morning'),
          activeColor: primaryPink,
          value: _emailSummaries,
          onChanged: (value) => setState(() => _emailSummaries = value),
        ),
        SwitchListTile(
          title: const Text('Auto-confirm appointments'),
          subtitle: const Text('Automatically confirm new requests'),
          activeColor: primaryPink,
          value: _autoConfirm,
          onChanged: (value) => setState(() => _autoConfirm = value),
        ),
        const SizedBox(height: 16),
        const Text(
          'Preparation buffer (minutes)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Slider(
          value: _prepBufferMinutes,
          min: 0,
          max: 60,
          divisions: 12,
          label: _prepBufferMinutes.round().toString(),
          activeColor: primaryPink,
          onChanged: (value) => setState(() => _prepBufferMinutes = value),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Save settings',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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
                  '$time - $client',
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
