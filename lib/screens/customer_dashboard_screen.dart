import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'customer_appointments_screen.dart';
import 'customer_discover_screen.dart';

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

enum _AppointmentTab { upcoming, history }

class _DashboardBundle {
  final _DashboardData summary;
  final List<Appointment> appointments;

  const _DashboardBundle({
    required this.summary,
    required this.appointments,
  });

  const _DashboardBundle.empty()
      : summary = const _DashboardData.empty(),
        appointments = const [];
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
  late final Future<_DashboardBundle> _future;
  _AppointmentTab _activeTab = _AppointmentTab.upcoming;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardBundle> _load() async {
    final token = widget.session.authToken;
    if (token == null || token.isEmpty) {
      return const _DashboardBundle.empty();
    }

    try {
      final backend = BackendService.instance;
      final map = await backend.fetchCustomerDashboard();
      final appointments = await backend.fetchCustomerAppointments();

      final upcoming = (map['upcomingCount'] is num)
          ? (map['upcomingCount'] as num).toInt()
          : 0;
      final total = (map['totalBookings'] is num)
          ? (map['totalBookings'] as num).toInt()
          : 0;

      _AppointmentLite? next;
      final nextMap = map['nextAppointment'];
      if (nextMap is Map<String, dynamic>) {
        final title = (nextMap['title'] as String?)?.trim() ?? '';
        final startStr = (nextMap['startAt'] as String?)?.trim();
        final endStr = (nextMap['endAt'] as String?)?.trim();

        final startAt = startStr != null ? DateTime.tryParse(startStr) : null;
        final endAt = endStr != null ? DateTime.tryParse(endStr) : null;

        if (title.isNotEmpty && startAt != null && endAt != null) {
          next = _AppointmentLite(title: title, startAt: startAt, endAt: endAt);
        }
      }

      final sortedUpcoming = _filterUpcoming(appointments);
      final fallbackNext = next ?? (sortedUpcoming.isNotEmpty
          ? _AppointmentLite(
              title: sortedUpcoming.first.businessName,
              startAt: sortedUpcoming.first.startAt,
              endAt: sortedUpcoming.first.endAt,
            )
          : null);

      final summary = _DashboardData(
        upcomingCount: upcoming,
        totalBookings: total,
        nextAppointment: fallbackNext,
      );

      return _DashboardBundle(summary: summary, appointments: appointments);
    } catch (_) {
      return const _DashboardBundle.empty();
    }
  }

  List<Appointment> _filterUpcoming(List<Appointment> appointments) {
    final now = DateTime.now();
    final filtered = appointments.where((appointment) {
      final status = appointment.status.toLowerCase();
      final isCancelled = status.contains('cancel');
      return !isCancelled && appointment.startAt.isAfter(now);
    }).toList();
    filtered.sort((a, b) => a.startAt.compareTo(b.startAt));
    return filtered;
  }

  List<Appointment> _filterHistory(List<Appointment> appointments) {
    final now = DateTime.now();
    final filtered = appointments.where((appointment) {
      final status = appointment.status.toLowerCase();
      final isCompleted = status.contains('complete');
      final isPast = appointment.startAt.isBefore(now);
      return isCompleted || isPast;
    }).toList();
    filtered.sort((a, b) => b.startAt.compareTo(a.startAt));
    return filtered;
  }

  void _setActiveTab(_AppointmentTab tab) {
    if (_activeTab == tab) return;
    setState(() => _activeTab = tab);
  }

  String _formatStatusLabel(String status) {
    if (status.isEmpty) return '';
    final normalized = status.toLowerCase();
    return normalized.replaceFirst(
      normalized.isNotEmpty ? normalized[0] : '',
      normalized.isNotEmpty ? normalized[0].toUpperCase() : '',
    );
  }

  Widget _buildAppointmentList({
    required BuildContext context,
    required List<Appointment> appointments,
    required bool isHistory,
  }) {
    if (appointments.isEmpty) {
      final text = isHistory ? 'Burası boş.' : 'No upcoming appointments yet.';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          text,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    return Column(
      children: appointments.map((appointment) {
        final start = appointment.startAt.toLocal();
        final end = appointment.endAt.toLocal();
        final title =
            appointment.businessName.isNotEmpty ? appointment.businessName : 'Appointment';
        final time = _formatTimeRange(context, start, end);
        final displayTime = isHistory
            ? '$time · ${_formatStatusLabel(appointment.status)}'
            : time;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AppointmentCard(
            dayLabel: _monthAbbr(start.month),
            dateNumber: start.day.toString(),
            title: title,
            time: displayTime,
            actions: isHistory ? const [] : const ['Reschedule', 'Cancel'],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerAppointmentsScreen(),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
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
    return '$sStr – $eStr';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.currentUser;

    final fullName = (user?.fullName ?? '').trim();
    final firstName =
        fullName.isNotEmpty ? fullName.split(RegExp(r'\s+')).first : '';
    final greetingName = firstName.isNotEmpty ? firstName : 'there';
    final avatarLetter = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return FutureBuilder<_DashboardBundle>(
      future: _future,
      builder: (context, snap) {
        final payload = snap.data ?? const _DashboardBundle.empty();
        final data = payload.summary;
        final appointments = payload.appointments;
        final upcomingAppointments = _filterUpcoming(appointments);
        final historyAppointments = _filterHistory(appointments);

        // ✅ stats from backend
        final upcomingValue = data.upcomingCount.toString();
        final totalBookingsValue = data.totalBookings.toString();

        // ✅ next appointment (nullable)

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
                          'Hey, $greetingName!',
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
              Container(
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setActiveTab(_AppointmentTab.upcoming),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: _activeTab == _AppointmentTab.upcoming
                                ? primaryPink.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Upcoming',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _activeTab == _AppointmentTab.upcoming
                                  ? primaryPink
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setActiveTab(_AppointmentTab.history),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: _activeTab == _AppointmentTab.history
                                ? primaryPink.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Booking History',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _activeTab == _AppointmentTab.history
                                  ? primaryPink
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _CalendarStrip(
                next: data.nextAppointment,
              ),
              const SizedBox(height: 16),

              _buildAppointmentList(
                context: context,
                appointments: _activeTab == _AppointmentTab.history
                    ? historyAppointments
                    : upcomingAppointments,
                isHistory: _activeTab == _AppointmentTab.history,
              ),
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

  void _showPasswordResetDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: const Text(
          'A self-service reset flow is coming soon. For now, use the "Forgot your password?" link on the login screen or contact support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

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

    final trimmedName = user.fullName.trim();
    final parts = trimmedName.isNotEmpty
        ? trimmedName.split(RegExp(r'\s+')).where((value) => value.isNotEmpty).toList()
        : const <String>[];
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

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
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
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
            'Personal Details',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          _ProfileReadOnlyField(label: 'First name', value: firstName),
          const SizedBox(height: 10),
          _ProfileReadOnlyField(label: 'Last name', value: lastName),
          const SizedBox(height: 12),
          const Text(
            'Security',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _PasswordCard(
            onReset: () => _showPasswordResetDialog(context),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () async {
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

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _pushReminders = true;
  bool _emailUpdates = false;
  bool _calendarSync = false;
  String _theme = 'System default';

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preferences',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              title: 'Notifications',
              children: [
                _SettingsSwitchTile(
                  title: 'Push reminders',
                  subtitle: 'Get notified before upcoming appointments',
                  value: _pushReminders,
                  onChanged: (value) => setState(() => _pushReminders = value),
                ),
                const Divider(height: 0),
                _SettingsSwitchTile(
                  title: 'Email updates',
                  subtitle: 'Receive booking confirmations via email',
                  value: _emailUpdates,
                  onChanged: (value) => setState(() => _emailUpdates = value),
                ),
                const Divider(height: 0),
                _SettingsSwitchTile(
                  title: 'Calendar sync',
                  subtitle: 'Send appointments to your default calendar',
                  value: _calendarSync,
                  onChanged: (value) => setState(() => _calendarSync = value),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SettingsCard(
              title: 'Appearance',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: DropdownButtonFormField<String>(
                    value: _theme,
                    decoration: const InputDecoration(
                      labelText: 'Theme',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'System default', child: Text('System default')),
                      DropdownMenuItem(value: 'Light', child: Text('Light')),
                      DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _theme = value);
                      _showSnack('Theme preference saved: $value');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SettingsCard(
              title: 'Privacy & data',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Clear search history'),
                  subtitle: const Text('Remove recently viewed businesses from this device'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSnack('Search history cleared.'),
                ),
                const Divider(height: 0),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Download my data'),
                  subtitle: const Text('Request a copy of appointments and profile info'),
                  trailing: const Icon(Icons.file_download_outlined),
                  onTap: () => _showSnack('Data export request submitted.'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SettingsCard(
              title: 'Help',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contact support'),
                  subtitle: const Text('support@rendivo.com'),
                  trailing: const Icon(Icons.email_outlined),
                  onTap: () => _showSnack('Support will reach out soon.'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================
   UI COMPONENTS (UNCHANGED LOOK)
   ========================= */

class _ProfileReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryPink),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  final VoidCallback onReset;

  const _PasswordCard({required this.onReset});

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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password reset',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Update your password to keep your account secure.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryPink,
                side: const BorderSide(color: primaryPink),
              ),
              child: const Text('Reset password'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      value: value,
      activeColor: primaryPink,
      onChanged: onChanged,
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

class _CalendarStrip extends StatelessWidget {
  final _AppointmentLite? next;

  const _CalendarStrip({this.next});

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthName(int month) {
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
    return (month >= 1 && month <= 12) ? names[month - 1] : '';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final nextDate = next?.startAt;
    final days = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day + index),
    );

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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_monthName(today.month)} ${today.year}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (nextDate != null)
                Text(
                  'Next: ${_monthName(nextDate.month)} ${nextDate.day}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: days.map((date) {
              final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final label = labels[(date.weekday - 1) % 7];
              final isSelected = nextDate != null && _isSameDay(date, nextDate);

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? primaryPink : const Color(0xFFF3F0F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
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

