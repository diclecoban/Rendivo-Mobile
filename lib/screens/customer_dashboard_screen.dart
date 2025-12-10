import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'customer_appointments_screen.dart';
import 'customer_discover_screen.dart';
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
      _ProfileTab(session: _session),
      const _SettingsTab(),
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
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    try {
      final appointments =
          await BackendService.instance.fetchCustomerAppointments();
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

  @override
  Widget build(BuildContext context) {
    final user = widget.session.currentUser;

    final fullName = (user?.fullName ?? '').trim();
    final emailPrefix =
        (user?.email ?? '').contains('@') ? user!.email.split('@').first : '';
    final firstName =
        fullName.isNotEmpty ? fullName.split(RegExp(r'\s+')).first : '';
    final greetingName = firstName.isNotEmpty
        ? firstName
        : (emailPrefix.isNotEmpty ? emailPrefix : 'there');
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
                  CircleAvatar(
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryPink,
                      ),
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const _CalendarCard(),
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
   PROFILE / SETTINGS
   ========================= */

class _ProfileTab extends StatelessWidget {
  final SessionService session;

  const _ProfileTab({required this.session});

  @override
  Widget build(BuildContext context) {
    final user = session.currentUser;
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_outline, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Please sign in to see your profile.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: primaryPink,
                child: Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Account',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _ProfileRow(label: 'Role', value: user.role),
          _ProfileRow(label: 'User ID', value: user.id),
          if (session.authToken != null && session.authToken!.isNotEmpty)
            const _ProfileRow(label: 'Token', value: 'Received'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () async {
                // Confirm before logging out
                final doLogout = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Log out',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (doLogout == true) {
                  // Clear session and go back to login screen
                  AuthService.signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.settings_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Settings coming soon.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/* =========================
   UI COMPONENTS (UNCHANGED LOOK)
   ========================= */

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  const _CalendarCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            children: const [
              Icon(Icons.chevron_left),
              Text(
                'October 2024',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _CalendarDayHeader('Sun'),
              _CalendarDayHeader('Mon'),
              _CalendarDayHeader('Tue'),
              _CalendarDayHeader('Wed'),
              _CalendarDayHeader('Thu'),
              _CalendarDayHeader('Fri'),
              _CalendarDayHeader('Sat'),
            ],
          ),
          const SizedBox(height: 8),
          const _CalendarNumberRow(
              numbers: ['29', '30', '1', '2', '3', '4', '5']),
          const _CalendarNumberRow(
              numbers: ['6', '7', '8', '9', '10', '11', '12']),
          const _CalendarNumberRow(
              numbers: ['13', '14', '15', '16', '17', '18', '19']),
          const _CalendarNumberRow(
            numbers: ['20', '21', '22', '23', '24', '25', '26'],
            selectedIndex: 0,
          ),
          const _CalendarNumberRow(
              numbers: ['27', '28', '29', '30', '31', '1', '2']),
        ],
      ),
    );
  }
}

class _CalendarDayHeader extends StatelessWidget {
  final String label;

  const _CalendarDayHeader(this.label);

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

class _CalendarNumberRow extends StatelessWidget {
  final List<String> numbers;
  final int? selectedIndex;

  const _CalendarNumberRow({
    required this.numbers,
    this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(numbers.length, (index) {
        final isSelected = selectedIndex == index;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? primaryPink : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                numbers[index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
      }),
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


