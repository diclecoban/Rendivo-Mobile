import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/session_service.dart';
import 'login_screen.dart';

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
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

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
      final data = await _backend.fetchAppointments();
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Appointment> _appointmentsForDate(DateTime date) {
    return _appointments
        .where((appt) => _isSameDay(appt.startAt, date))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  bool _hasAppointment(DateTime date) {
    return _appointments.any((appt) => _isSameDay(appt.startAt, date));
  }

  List<DateTime?> _daysForMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final days = <DateTime?>[];
    for (int i = 0; i < leading; i++) {
      days.add(null);
    }
    for (int day = 1; day <= daysInMonth; day++) {
      days.add(DateTime(month.year, month.month, day));
    }
    return days;
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
  }

  String _monthLabel(DateTime month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[month.month - 1]} ${month.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _session.currentUser;
    final tabs = [
      _buildDashboardTab(user),
      _buildBookingsTab(),
      _buildAvailabilityTab(),
    ];

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
        ],
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
    );
  }

  Widget _buildDashboardTab(AuthUser? user) {
    final todaysAppointments = _appointmentsForDate(_selectedDate);
    return RefreshIndicator(
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
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'logout') {
                      AuthService.signOut();
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  offset: const Offset(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'logout',
                      child: Text(
                        'Log out',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                  child: CircleAvatar(
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
            _buildCalendarCard(),
            const SizedBox(height: 16),
            Text(
              _isSameDay(_selectedDate, DateTime.now())
                  ? "Today's Schedule"
                  : 'Schedule',
              style: const TextStyle(
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
            else if (todaysAppointments.isEmpty)
              const _EmptyState(
                title: 'No appointments scheduled.',
                subtitle: 'New bookings will appear here once scheduled.',
              )
            else
              Column(
                children: todaysAppointments
                    .map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ScheduleCard(
                          appointment: a,
                          timeLabel: _formatTime(a.startAt),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsTab() {
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          const Text(
            'All Bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
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
            const _EmptyState(
              title: 'No bookings yet.',
              subtitle: 'Appointments will show here once created.',
            )
          else
            ..._appointments.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BookingCard(
                  service: a.services.isNotEmpty
                      ? a.services.first.name
                      : a.businessName,
                  time: _formatTime(a.startAt),
                  client:
                      a.customerName.isNotEmpty ? a.customerName : a.customerEmail,
                  status: a.status,
                  date: a.startAt,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityTab() {
    final dayAppointments = _appointmentsForDate(_selectedDate);
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          const Text(
            'Availability',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildCalendarCard(),
          const SizedBox(height: 12),
          const Text(
            'Booked slots',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
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
          else if (dayAppointments.isEmpty)
            const _EmptyState(
              title: 'No bookings for this day.',
              subtitle: 'Select another date to view booked slots.',
            )
          else
            ...dayAppointments.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScheduleCard(
                  appointment: a,
                  timeLabel: _formatTime(a.startAt),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final days = _daysForMonth(_currentMonth);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _monthLabel(_currentMonth),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _CalendarDow('Sun'),
              _CalendarDow('Mon'),
              _CalendarDow('Tue'),
              _CalendarDow('Wed'),
              _CalendarDow('Thu'),
              _CalendarDow('Fri'),
              _CalendarDow('Sat'),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              if (day == null) {
                return const SizedBox.shrink();
              }

              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              final dayDate = DateTime(day.year, day.month, day.day);
              final isPast = dayDate.isBefore(todayDate);
              final isToday = _isSameDay(day, DateTime.now());
              final isSelected = _isSameDay(day, _selectedDate);
              final hasBooking = _hasAppointment(day);

              Color bgColor = Colors.white;
              Color borderColor = Colors.grey.shade300;
              Color textColor = Colors.black87;

              if (isSelected) {
                bgColor = primaryPink.withOpacity(0.12);
                borderColor = primaryPink;
                textColor = primaryPink;
              } else if (isPast) {
                bgColor = const Color(0xFFF3F3F3);
                borderColor = Colors.grey.shade300;
                textColor = Colors.grey.shade500;
              } else if (isToday) {
                bgColor = const Color(0xFFF4F7FF);
                borderColor = const Color(0xFFB2C2FF);
                textColor = const Color(0xFF3755B7);
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = day;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (hasBooking)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryPink,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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
  final DateTime date;

  const _BookingCard({
    required this.service,
    required this.time,
    required this.client,
    required this.status,
    required this.date,
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
                  '${_formatDate(date)} - $time - $client',
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _ScheduleCard extends StatelessWidget {
  final Appointment appointment;
  final String timeLabel;

  const _ScheduleCard({
    required this.appointment,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final services = appointment.services.isNotEmpty
        ? appointment.services.map((s) => s.name).join(', ')
        : 'Service';
    final client = appointment.customerName.isNotEmpty
        ? appointment.customerName
        : appointment.customerEmail;
    final status = appointment.status.toLowerCase();
    final statusColor = status == 'cancelled'
        ? Colors.redAccent
        : status == 'pending'
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
              Icons.access_time,
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
                  client,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeLabel - $services',
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

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _CalendarDow extends StatelessWidget {
  final String label;

  const _CalendarDow(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
