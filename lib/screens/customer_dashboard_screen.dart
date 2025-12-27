import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/session_service.dart';
import 'customer_appointments_screen.dart';
import 'customer_discover_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../services/backend_service.dart';


class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  final _session = SessionService.instance;
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _DashboardHome(session: _session),
      const CustomerDiscoverScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
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
            icon: Icon(Icons.explore_outlined),
            label: 'Discover',
          ),
        ],
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      body: SafeArea(child: tabs[_currentIndex]),
    );
  }
}

/* =========================
   BACKEND MODELS + API
   ========================= */

class _DashboardData {
  final int upcomingCount;
  final int totalBookings;
  final _AppointmentLite? nextAppointment;

  const _DashboardData({
    required this.upcomingCount,
    required this.totalBookings,
    required this.nextAppointment,
  });

  const _DashboardData.empty()
      : upcomingCount = 0,
        totalBookings = 0,
        nextAppointment = null;
}

class _AppointmentLite {
  final String title;
  final DateTime startAt;
  final DateTime endAt;

  const _AppointmentLite({
    required this.title,
    required this.startAt,
    required this.endAt,
  });
}

/* =========================
   DASHBOARD HOME
   ========================= */

class _DashboardHome extends StatefulWidget {
  final SessionService session;

  const _DashboardHome({required this.session});

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  late final Future<_DashboardData> _future;
  List<Appointment> _appointments = [];
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    try {
      final appointments =
          await BackendService.instance.fetchCustomerAppointments();
      if (mounted) {
        setState(() {
          _appointments = appointments;
        });
      }
      final now = DateTime.now();
      final upcoming = appointments
          .where(
            (a) =>
                a.startAt.isAfter(now) &&
                a.status.toLowerCase() != 'cancelled',
          )
          .toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));

      _AppointmentLite? next;
      if (upcoming.isNotEmpty) {
        final first = upcoming.first;
        final title = first.services.isNotEmpty
            ? first.services.map((s) => s.name).join(', ')
            : first.businessName;
        next = _AppointmentLite(
          title: title,
          startAt: first.startAt,
          endAt: first.endAt,
        );
      }

      return _DashboardData(
        upcomingCount: upcoming.length,
        totalBookings: appointments.length,
        nextAppointment: next,
      );
    } catch (_) {
      return const _DashboardData.empty();
    }
  }

  String _monthAbbr(int month) {
    const m = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    if (month < 1 || month > 12) return '';
    return m[month - 1];
  }

  String _formatTimeRange(
      BuildContext context, DateTime startAt, DateTime endAt) {
    final loc = MaterialLocalizations.of(context);
    final s = TimeOfDay.fromDateTime(startAt.toLocal());
    final e = TimeOfDay.fromDateTime(endAt.toLocal());
    final sStr = loc.formatTimeOfDay(s);
    final eStr = loc.formatTimeOfDay(e);
    return '$sStr - $eStr';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  Future<void> _logout(BuildContext context) async {
    AuthService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.currentUser;

    final fullName = (user?.fullName ?? '').trim();
    final emailValue = (user?.email ?? '').trim();
    final greetingName =
        fullName.isNotEmpty ? fullName : (emailValue.isNotEmpty ? emailValue : 'there');
    final avatarLetter = (fullName.isNotEmpty
            ? fullName[0]
            : (user?.email ?? '').trim().isNotEmpty
                ? user!.email.trim()[0]
                : '?')
        .toUpperCase();

    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data ?? const _DashboardData.empty();

        // ✅ stats from backend
        final upcomingValue = data.upcomingCount.toString();
        final totalBookingsValue = data.totalBookings.toString();

        // ✅ next appointment (nullable)
        final next = data.nextAppointment;

        final nextTitle = next?.title ?? '';
        final dayLabel =
            (next != null) ? _monthAbbr(next.startAt.toLocal().month) : '';
        final dateNumber =
            (next != null) ? next.startAt.toLocal().day.toString() : '';
        final timeRange = (next != null)
            ? _formatTimeRange(context, next.startAt, next.endAt)
            : '';

        return SingleChildScrollView(
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
                          'Hello, $greetingName!',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Welcome back',
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
                        _logout(context);
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
                      backgroundImage: null,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: primaryPink,
                        child: Text(
                          avatarLetter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ✅ counts from backend
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Upcoming',
                      value: upcomingValue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Total Bookings',
                      value: totalBookingsValue,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _DiscoverCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerDiscoverScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Appointments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Upcoming',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primaryPink,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CustomerAppointmentsScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Booking History',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _CalendarCard(
                currentMonth: _currentMonth,
                selectedDate: _selectedDate,
                days: _daysForMonth(_currentMonth),
                hasAppointment: _hasAppointment,
                onSelectDate: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                onChangeMonth: _changeMonth,
                monthLabel: _monthLabel(_currentMonth),
              ),
              const SizedBox(height: 16),

              // ✅ this title becomes EMPTY (and hidden) if there is no appointment
              if (nextTitle.isNotEmpty) ...[
                Text(
                  nextTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _AppointmentCard(
                  dayLabel: dayLabel,
                  dateNumber: dateNumber,
                  title: nextTitle,
                  time: timeRange,
                  actions: const ['Reschedule', 'Cancel'],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Open the My Appointments tab to view full appointment details.',
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

/* =========================
   UI COMPONENTS (UNCHANGED LOOK)
   ========================= */

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final DateTime currentMonth;
  final DateTime selectedDate;
  final List<DateTime?> days;
  final bool Function(DateTime date) hasAppointment;
  final ValueChanged<DateTime> onSelectDate;
  final void Function(int delta) onChangeMonth;
  final String monthLabel;

  const _CalendarCard({
    required this.currentMonth,
    required this.selectedDate,
    required this.days,
    required this.hasAppointment,
    required this.onSelectDate,
    required this.onChangeMonth,
    required this.monthLabel,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => onChangeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => onChangeMonth(1),
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
              final isSelected = _isSameDay(day, selectedDate);
              final hasBooking = hasAppointment(day);

              Color bgColor = Colors.white;
              Color borderColor = Colors.grey.shade300;
              Color textColor = Colors.black87;

              if (hasBooking) {
                bgColor = primaryPink;
                borderColor = primaryPink;
                textColor = Colors.white;
              }

              if (isSelected) {
                bgColor = hasBooking ? primaryPink : primaryPink.withOpacity(0.12);
                borderColor = primaryPink;
                textColor = hasBooking ? Colors.white : primaryPink;
              } else if (isPast && !hasBooking) {
                bgColor = const Color(0xFFF3F3F3);
                borderColor = Colors.grey.shade300;
                textColor = Colors.grey.shade500;
              } else if (isToday && !hasBooking) {
                bgColor = const Color(0xFFF4F7FF);
                borderColor = const Color(0xFFB2C2FF);
                textColor = const Color(0xFF3755B7);
              }

              return GestureDetector(
                onTap: () => onSelectDate(day),
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
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final String dayLabel;
  final String dateNumber;
  final String title;
  final String time;
  final List<String> actions;
  final VoidCallback? onTap;

  const _AppointmentCard({
    required this.dayLabel,
    required this.dateNumber,
    required this.title,
    required this.time,
    required this.actions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        child: Row(
          children: [
            Container(
              width: 46,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayLabel,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    dateNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: actions.map((text) {
                final isPrimary = text.toLowerCase() == 'reschedule';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPrimary ? primaryPink : Colors.redAccent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DiscoverCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBE9FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: primaryPink,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover Businesses',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Browse nearby salons and book your next service.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Browse',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

