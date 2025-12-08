import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>>? appointmentRef;
  final Map<String, dynamic>? appointmentData;

  const AppointmentDetailsScreen({
    super.key,
    this.appointmentRef,
    this.appointmentData,
  });

  @override
  State<AppointmentDetailsScreen> createState() =>
      _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = false;
  String? _error;
  bool _isActionInProgress = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _data = widget.appointmentData;
    if (_data == null && widget.appointmentRef != null) {
      _fetchAppointment();
    }
  }

  Future<void> _fetchAppointment() async {
    final ref = widget.appointmentRef;
    if (ref == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        setState(() {
          _error = 'Appointment not found.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _data = snapshot.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load appointment: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> get _safeData => _data ?? {};

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  List<dynamic> get _services =>
      (_safeData['services'] as List<dynamic>?) ??
      (_safeData['serviceNames'] as List<dynamic>?) ??
      const [];

  int get _durationMinutes =>
      (_safeData['totalDurationMinutes'] as num?)?.toInt() ?? 60;

  double? get _totalPrice => (_safeData['totalPrice'] as num?)?.toDouble();

  String get _status => (_safeData['status'] as String?) ?? 'pending';

  String _statusLabel(String status) => status.isEmpty
      ? 'Pending'
      : status[0].toUpperCase() + status.substring(1);

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

  Future<void> _handleCancel() async {
    final ref = widget.appointmentRef;
    if (ref == null) {
      _showSnack('Appointment reference missing.');
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel appointment?'),
            content: const Text(
              'Are you sure you want to cancel this appointment? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cancel Appointment'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isActionInProgress = true);
    try {
      await ref.update({'status': 'cancelled'});
      setState(() {
        _data = {
          ..._safeData,
          'status': 'cancelled',
        };
        _isActionInProgress = false;
        _hasChanges = true;
      });
      _showSnack('Appointment cancelled.');
    } catch (e) {
      setState(() => _isActionInProgress = false);
      _showSnack('Failed to cancel: $e');
    }
  }

  Future<void> _handleReschedule() async {
    final ref = widget.appointmentRef;
    if (ref == null) {
      _showSnack('Appointment reference missing.');
      return;
    }

    final currentStart = _parseDate(_safeData['startAt']);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentStart ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: currentStart != null
          ? TimeOfDay.fromDateTime(currentStart)
          : const TimeOfDay(hour: 10, minute: 0),
    );
    if (pickedTime == null) return;

    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final newEnd = newStart.add(Duration(minutes: _durationMinutes));

    setState(() => _isActionInProgress = true);
    try {
      await ref.update({
        'appointmentDate': Timestamp.fromDate(newStart),
        'startAt': Timestamp.fromDate(newStart),
        'endAt': Timestamp.fromDate(newEnd),
        'status': 'pending',
      });
      setState(() {
        _data = {
          ..._safeData,
          'appointmentDate': Timestamp.fromDate(newStart),
          'startAt': Timestamp.fromDate(newStart),
          'endAt': Timestamp.fromDate(newEnd),
          'status': 'pending',
        };
        _isActionInProgress = false;
        _hasChanges = true;
      });
      _showSnack('Appointment rescheduled.');
    } catch (e) {
      setState(() => _isActionInProgress = false);
      _showSnack('Failed to reschedule: $e');
    }
  }

  Future<void> _handleEditNotes() async {
    final ref = widget.appointmentRef;
    if (ref == null) {
      _showSnack('Appointment reference missing.');
      return;
    }

    final controller =
        TextEditingController(text: _safeData['notes'] as String? ?? '');
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
      await ref.update({'notes': result});
      setState(() {
        _data = {
          ..._safeData,
          'notes': result,
        };
        _isActionInProgress = false;
        _hasChanges = true;
      });
      _showSnack('Notes updated.');
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _data == null
                      ? const Center(
                          child: Text('Appointment data unavailable.'),
                        )
                      : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final start = _parseDate(_safeData['startAt']);
    final end = _parseDate(_safeData['endAt']);
    final staffName = _safeData['staffName'] as String? ?? 'Team Member';
    final customerName = _safeData['customerName'] as String? ?? 'Customer';
    final customerEmail = _safeData['customerEmail'] as String? ?? '';
    final notes = _safeData['notes'] as String? ?? '';

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
                color: _statusColor(_status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel(_status),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(_status),
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
                  value: start == null
                      ? 'TBD'
                      : '${_formatDate(start)}${end != null ? ' · ${_formatTimeRange(start, end)}' : ''}',
                ),
                const SizedBox(height: 16),
                _IconTextRow(
                  icon: Icons.store_mall_directory_outlined,
                  title: 'Business',
                  value: _safeData['businessName'] as String? ?? 'Business',
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
                        customerName.isEmpty
                            ? '?'
                            : customerName[0].toUpperCase(),
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
                            customerName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (customerEmail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              customerEmail,
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
                if (_services.isEmpty)
                  const Text(
                    'No services listed.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                else
                  ..._services.map((service) {
                    if (service is Map<String, dynamic>) {
                      final name = service['name'] ?? 'Service';
                      final price = service['price'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PriceRow(
                          label: name.toString(),
                          amount: price is num
                              ? _formatPrice(price)
                              : (price?.toString() ?? ''),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PriceRow(
                        label: service.toString(),
                        amount: '',
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
                if (_totalPrice != null)
                  _PriceRow(
                    label: 'Total',
                    amount: _formatPrice(_totalPrice!),
                    isBold: true,
                  )
                else
                  const Text(
                    'Total amount not available.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  notes.isEmpty ? 'No notes added.' : notes,
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
