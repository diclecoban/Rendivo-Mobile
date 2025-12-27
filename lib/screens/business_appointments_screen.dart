import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../widgets/business_bottom_nav.dart';
import 'business_dashboard_screen.dart';
import 'business_schedule_screen.dart';
import 'business_services_screen.dart';
import 'business_staff_screen.dart';

class BusinessAppointmentsScreen extends StatefulWidget {
  final bool? isPending;

  const BusinessAppointmentsScreen({
    super.key,
    this.isPending,
  });

  @override
  State<BusinessAppointmentsScreen> createState() =>
      _BusinessAppointmentsScreenState();
}

class _BusinessAppointmentsScreenState
    extends State<BusinessAppointmentsScreen> {
  final _backend = BackendService.instance;

  List<Appointment> _appointments = [];
  bool _loading = false;
  String? _error;
  String _statusFilter = 'all';
  String _sortOrder = 'desc';
  String? _cancellingId;

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
    try {
      final items = await _backend.fetchAppointments();
      setState(() {
        _appointments = items;
      });
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to load appointments.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Appointment> get _filteredAppointments {
    final items = _appointments.where((appointment) {
      if (_statusFilter == 'all') return true;
      return appointment.status == _statusFilter;
    }).toList();

    items.sort((a, b) {
      final timeA = a.startAt;
      final timeB = b.startAt;
      return _sortOrder == 'desc'
          ? timeB.compareTo(timeA)
          : timeA.compareTo(timeB);
    });

    return items;
  }

  Future<void> _confirmCancel(Appointment appointment) async {
    if (appointment.status == 'cancelled') return;
    setState(() => _cancellingId = appointment.id);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text(
          'Are you sure you want to cancel this appointment? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      setState(() => _cancellingId = null);
      return;
    }

    try {
      await _backend.cancelAppointment(appointment.id);
      setState(() {
        _appointments = _appointments
            .map(
              (item) => item.id == appointment.id
                  ? item.copyWith(status: 'cancelled')
                  : item,
            )
            .toList();
        _cancellingId = null;
      });
    } on AppException catch (e) {
      _showSnack(e.message);
      setState(() => _cancellingId = null);
    } catch (e) {
      _showSnack('Failed to cancel appointment.');
      setState(() => _cancellingId = null);
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
    final isPending = widget.isPending ?? false;
    final filtered = _filteredAppointments;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Appointments',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAppointments,
          child: _loading
              ? ListView(
                  children: const [
                    SizedBox(height: 160),
                    Center(
                      child: CircularProgressIndicator(color: primaryPink),
                    ),
                  ],
                )
              : _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Manage all your business appointments',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _statusFilter,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'confirmed',
                                    child: Text('Confirmed'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cancelled',
                                    child: Text('Cancelled'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _statusFilter = value);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _sortOrder,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'desc',
                                    child: Text('Newest'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'asc',
                                    child: Text('Oldest'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _sortOrder = value);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Sort',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (filtered.isEmpty)
                          const Text(
                            'No appointments found.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        else
                          ...filtered.map(
                            (appointment) => _AppointmentCard(
                              appointment: appointment,
                              isCancelling:
                                  _cancellingId == appointment.id,
                              onCancel: isPending
                                  ? null
                                  : () => _confirmCancel(appointment),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
      bottomNavigationBar: BusinessBottomNav(
        currentIndex: 4,
        isPending: isPending,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessServicesScreen(isPending: isPending),
              ),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessStaffScreen(isPending: isPending),
              ),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessScheduleScreen(isPending: isPending),
              ),
            );
          }
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool isCancelling;
  final VoidCallback? onCancel;

  const _AppointmentCard({
    required this.appointment,
    required this.isCancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = appointment.status;
    final isCancelled = status == 'cancelled';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _IconText(
                icon: Icons.calendar_today_outlined,
                text: _formatDate(appointment.startAt),
              ),
              _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.schedule,
            label: 'Time',
            value:
                '${_formatTime(appointment.startAt)} - ${_formatTime(appointment.endAt)}',
          ),
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Customer',
            value: appointment.customerName,
          ),
          _InfoRow(
            icon: Icons.people_outline,
            label: 'Staff',
            value: appointment.staffName ?? 'Staff',
          ),
          _InfoRow(
            icon: Icons.list_alt_outlined,
            label: 'Services',
            value: appointment.services.isNotEmpty
                ? appointment.services.map((s) => s.name).join(', ')
                : 'Service',
          ),
          _InfoRow(
            icon: Icons.attach_money,
            label: 'Price',
            value: '\$${appointment.totalPrice.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isCancelled || isCancelling ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isCancelled ? 'Cancelled' : 'Cancel Appointment',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconText({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = const Color(0xFF1F8E4D);
        break;
      case 'cancelled':
        color = Colors.redAccent;
        break;
      default:
        color = primaryPink;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
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
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
