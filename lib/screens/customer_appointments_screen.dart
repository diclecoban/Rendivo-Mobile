import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../services/session_service.dart';
import 'appointment_details_screen.dart';

class CustomerAppointmentsScreen extends StatefulWidget {
  const CustomerAppointmentsScreen({super.key});

  @override
  State<CustomerAppointmentsScreen> createState() =>
      _CustomerAppointmentsScreenState();
}

class _CustomerAppointmentsScreenState
    extends State<CustomerAppointmentsScreen> {
  final _backend = BackendService.instance;
  final _session = SessionService.instance;

  bool _isLoading = true;
  String? _error;
  List<Appointment> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (_session.authToken == null) {
      setState(() {
        _error = 'Please sign in to view appointments.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _backend.fetchCustomerAppointments();
      items.sort((a, b) => a.startAt.compareTo(b.startAt));
      setState(() {
        _appointments = items;
        _isLoading = false;
      });
    } on AppException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load appointments: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    try {
      await _backend.cancelAppointment(appointment.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled.')),
        );
        _loadAppointments();
      }
    } on AppException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e')),
      );
    }
  }

  Future<void> _rescheduleAppointment(Appointment appointment) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: appointment.startAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(appointment.startAt),
    );
    if (pickedTime == null) return;

    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final minutes =
        appointment.totalDurationMinutes > 0 ? appointment.totalDurationMinutes : 30;
    final newEnd = newStart.add(Duration(minutes: minutes));

    try {
      await _backend.rescheduleAppointment(
        appointmentId: appointment.id,
        startAt: newStart,
        endAt: newEnd,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment rescheduled.')),
        );
        _loadAppointments();
      }
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reschedule: $e')),
      );
    }
  }

  Future<void> _openDetails(Appointment appointment) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentDetailsScreen(appointment: appointment),
      ),
    );

    if (changed == true) {
      _loadAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Appointments',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAppointments,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _ErrorState(
            message: _error!,
            onRetry: _loadAppointments,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _CalendarStrip(appointments: _appointments),
        const SizedBox(height: 20),
        if (_appointments.isEmpty)
          const _EmptyState(message: 'No appointments yet.')
        else
          ..._appointments.map(
            (appt) => _AppointmentCard(
              appointment: appt,
              onCancel: () => _cancelAppointment(appt),
              onReschedule: () => _rescheduleAppointment(appt),
              onTap: () => _openDetails(appt),
            ),
          ),
      ],
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  final List<Appointment> appointments;

  const _CalendarStrip({required this.appointments});

  bool _hasAppointmentOn(DateTime date) {
    return appointments.any((appt) {
      final start = appt.startAt;
      return start.year == date.year &&
          start.month == date.month &&
          start.day == date.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day + index,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: days.map((date) {
          final hasAppointment = _hasAppointmentOn(date);
          final label = [
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun'
          ][(date.weekday - 1) % 7];
          return Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        hasAppointment ? primaryPink : const Color(0xFFF3F0F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: hasAppointment ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;
  final VoidCallback? onTap;

  const _AppointmentCard({
    required this.appointment,
    required this.onCancel,
    required this.onReschedule,
    this.onTap,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF1F8E4D);
      case 'cancelled':
        return Colors.redAccent;
      default:
        return primaryPink;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = appointment.services.map((s) => s.name).join(', ');
    final status = appointment.status;
    final start = appointment.startAt;
    final end = appointment.endAt;

    final timeLabel =
        '${_formatDate(start)} - ${_formatTimeRange(start, end)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      services.isEmpty ? 'Services' : services,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.businessName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_month_outlined,
                    size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  timeLabel,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'cancelled' ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: status == 'cancelled' ? null : onReschedule,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: primaryPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Reschedule',
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    String formatTime(DateTime time) {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    return '${formatTime(start)} - ${formatTime(end)}';
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Colors.redAccent),
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

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
