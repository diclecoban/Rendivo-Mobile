import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  final Appointment appointment;

  const AppointmentDetailsScreen({
    super.key,
    required this.appointment,
  });

  @override
  State<AppointmentDetailsScreen> createState() =>
      _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  late Appointment _appointment;
  bool _isActionInProgress = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
  }

  Future<void> _handleCancel() async {
    setState(() => _isActionInProgress = true);
    try {
      await BackendService.instance.cancelAppointment(_appointment.id);
      setState(() {
        _appointment = _appointment.copyWith(status: 'cancelled');
        _isActionInProgress = false;
        _hasChanges = true;
      });
      _showSnack('Appointment cancelled.');
    } on AppException catch (e) {
      setState(() => _isActionInProgress = false);
      _showSnack(e.message);
    } catch (e) {
      setState(() => _isActionInProgress = false);
      _showSnack('Failed to cancel: $e');
    }
  }

  Future<void> _handleReschedule() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _appointment.startAt.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_appointment.startAt),
    );
    if (pickedTime == null) return;

    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final newEnd = newStart.add(
      Duration(
        minutes: _appointment.totalDurationMinutes > 0
            ? _appointment.totalDurationMinutes
            : 30,
      ),
    );

    setState(() => _isActionInProgress = true);
    try {
      await BackendService.instance.rescheduleAppointment(
        appointmentId: _appointment.id,
        startAt: newStart,
        endAt: newEnd,
      );
      setState(() {
        _appointment = _appointment.copyWith(
          startAt: newStart,
          endAt: newEnd,
          status: 'pending',
        );
        _isActionInProgress = false;
        _hasChanges = true;
      });
      _showSnack('Appointment rescheduled.');
    } on AppException catch (e) {
      setState(() => _isActionInProgress = false);
      _showSnack(e.message);
    } catch (e) {
      setState(() => _isActionInProgress = false);
      _showSnack('Failed to reschedule: $e');
    }
  }

  Future<void> _handleEditNotes() async {
    final controller = TextEditingController(text: _appointment.notes);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit notes'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Add notes for this appointment',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() => _isActionInProgress = true);
    try {
      await BackendService.instance.updateAppointmentNotes(
        appointmentId: _appointment.id,
        notes: result,
      );
      setState(() {
        _appointment = _appointment.copyWith(notes: result);
        _isActionInProgress = false;
        _hasChanges = true;
      });
      _showSnack('Notes updated.');
    } on AppException catch (e) {
      setState(() => _isActionInProgress = false);
      _showSnack(e.message);
    } catch (e) {
      setState(() => _isActionInProgress = false);
      _showSnack('Failed to update notes: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text(
            'Appointment Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () {
              Navigator.pop(context, _hasChanges);
            },
          ),
        ),
        body: SafeArea(
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final start = _appointment.startAt;
    final end = _appointment.endAt;
    final staffName = _appointment.staffName ?? 'Team Member';
    final services = _appointment.services;
    final status = _appointment.status;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(status),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DetailsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconTextRow(
                  icon: Icons.calendar_month_outlined,
                  title: 'Date & Time',
                  value: '${_formatDate(start)} - ${_formatTimeRange(start, end)}',
                ),
                const SizedBox(height: 16),
                _IconTextRow(
                  icon: Icons.store_mall_directory_outlined,
                  title: 'Business',
                  value: _appointment.businessName,
                ),
                const SizedBox(height: 16),
                _IconTextRow(
                  icon: Icons.person_outline,
                  title: 'Staff',
                  value: staffName,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Client Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: primaryPink,
                      child: Text(
                        _appointment.customerName.isEmpty
                            ? '?'
                            : _appointment.customerName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _appointment.customerName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_appointment.customerEmail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _appointment.customerEmail,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Breakdown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (services.isEmpty)
                  const Text(
                    'No services listed.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                else
                  ...services.map((service) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PriceRow(
                        label: service.name,
                        amount: _formatPrice(service.price),
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Summary',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _PriceRow(
                  label: 'Total',
                  amount: _formatPrice(_appointment.totalPrice),
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appointment Notes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _appointment.notes.isEmpty
                      ? 'No notes added.'
                      : _appointment.notes,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isActionInProgress ? null : _handleReschedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Reschedule',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _isActionInProgress ? null : _handleEditNotes,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: Colors.grey.shade300),
                backgroundColor: Colors.white,
              ),
              child: const Text(
                'Edit Notes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _isActionInProgress ? null : _handleCancel,
              child: const Text(
                'Cancel Appointment',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

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
      'Dec',
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

  String _formatPrice(num value) => '\$${value.toStringAsFixed(2)}';

  String _initials(String value) {
    final parts = value.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.isEmpty ? '?' : parts.first.characters.first;
    }
    final first = parts.first.characters.first;
    final last = parts.last.characters.first;
    return (first + last).toUpperCase();
  }
}

class _DetailsCard extends StatelessWidget {
  final Widget child;

  const _DetailsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconTextRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _IconTextRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool isBold;

  const _PriceRow({
    required this.label,
    required this.amount,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: style,
          ),
        ),
        Text(
          amount,
          style: style,
        ),
      ],
    );
  }
}
