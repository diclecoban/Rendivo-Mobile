import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../services/session_service.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  BackendService _backend = BackendService.instance;
  final SessionService _session = SessionService.instance;

  Business? _business;
  bool _loading = false;
  String? _error;
  bool _noBusiness = false;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  @visibleForTesting
  void overrideBackend(BackendService backend) {
    _backend = backend;
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    setState(() {
      _loading = true;
      _error = null;
      _noBusiness = false;
    });

    final role = (_session.currentRole ?? '').toLowerCase();
    if (role != 'business_owner') {
      setState(() {
        _loading = false;
        _business = null;
        _error = 'Business dashboard is available for business owners only.';
      });
      return;
    }

    try {
      final businesses = await _backend.fetchMyBusinesses();
      final selected = businesses.isNotEmpty ? businesses.first : null;

      setState(() {
        _business = selected;
        _noBusiness = selected == null;
      });
    } catch (e) {
      setState(() {
        _error = e is AppException ? e.message : e.toString();
        _business = null;
        _noBusiness = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  int get _serviceCount => _business?.services.length ?? 0;
  int get _staffCount => _business?.staff.length ?? 0;

  void _openStaffSchedule(StaffMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StaffScheduleScreen(member: member),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _session.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBusiness,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: _buildDashboardContent(user),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(AuthUser? user) {
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusMessage(message: _error!),
        ],
      );
    }

    if (_noBusiness && !_loading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusMessage(
            message: 'You have not created a business yet. Finish the owner onboarding to see insights.',
          ),
        ],
      );
    }

    final business = _business;
    if (business == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: primaryPink),
        ),
      );
    }

    final greeting = business.businessName.isNotEmpty
        ? 'Hello, ${business.businessName}!'
        : 'Hello${user != null ? ', ${user.fullName}' : ''}!';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Here's what's happening with your business.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: primaryPink,
              child: Text(
                business.businessName.isNotEmpty
                    ? business.businessName[0].toUpperCase()
                    : (user?.fullName.isNotEmpty ?? false)
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
                title: 'Services',
                mainValue: _loading ? '...' : _serviceCount.toString(),
                trendText: 'Active services',
                trendColor: Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Staff',
                mainValue: _loading ? '...' : _staffCount.toString(),
                trendText: 'Team members',
                trendColor: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _KpiCard(
          title: 'Contact',
          mainValue: business.phone.isNotEmpty ? business.phone : '-',
          trendText: business.email,
          trendColor: Colors.grey,
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: 'Services',
          actionLabel: business.services.isNotEmpty ? 'Manage' : null,
          onAction: business.services.isNotEmpty
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service management coming soon.'),
                    ),
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        _CardContainer(
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: primaryPink),
                  ),
                )
              : business.services.isNotEmpty
                  ? Column(
                      children: business.services
                          .take(5)
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ServiceRow(service: s),
                            ),
                          )
                          .toList(),
                    )
                  : const Text(
                      'No services yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: 'Team Members',
          actionLabel: business.staff.isNotEmpty ? 'Add staff' : null,
          onAction: business.staff.isNotEmpty
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invite staff flow coming soon.'),
                    ),
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        _CardContainer(
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: primaryPink),
                  ),
                )
              : business.staff.isNotEmpty
                  ? ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final member = business.staff[index];
                        return _StaffRow(
                          member: member,
                          onTap: () => _openStaffSchedule(member),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: business.staff.length,
                    )
                  : const Text(
                      'No staff listed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
        ),
        const SizedBox(height: 24),
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
    return _CardContainer(
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
          const SizedBox(height: 8),
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

class _CardContainer extends StatelessWidget {
  final Widget child;

  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryPink,
              ),
            ),
          ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final ServiceItem service;

  const _ServiceRow({required this.service});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: primaryPink.withOpacity(0.15),
          child: const Icon(
            Icons.content_cut,
            size: 16,
            color: primaryPink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${service.durationMinutes} min · \$${service.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaffRow extends StatelessWidget {
  final StaffMember member;
  final VoidCallback? onTap;

  const _StaffRow({required this.member, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: primaryPink.withOpacity(0.15),
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: primaryPink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  member.role,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;

  const _StatusMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: primaryPink),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffScheduleScreen extends StatefulWidget {
  final StaffMember member;

  const _StaffScheduleScreen({required this.member});

  @override
  State<_StaffScheduleScreen> createState() => _StaffScheduleScreenState();
}

class _StaffScheduleScreenState extends State<_StaffScheduleScreen> {
  late Future<List<Appointment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Appointment>> _load() {
    return BackendService.instance.fetchStaffAppointments(
      staffId: widget.member.id,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
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
    final local = date.toLocal();
    final month = months[local.month - 1];
    return '$month ${local.day}, ${local.year}';
  }

  String _formatTimeRange(BuildContext context, Appointment appointment) {
    final localizations = MaterialLocalizations.of(context);
    final start = TimeOfDay.fromDateTime(appointment.startAt.toLocal());
    final end = TimeOfDay.fromDateTime(appointment.endAt.toLocal());
    final startStr = localizations.formatTimeOfDay(start);
    final endStr = localizations.formatTimeOfDay(end);
    return '$startStr - $endStr';
  }

  Widget _buildAppointmentCard(BuildContext context, Appointment appointment) {
    final services = appointment.services.isNotEmpty
        ? appointment.services.map((s) => s.name).join(', ')
        : appointment.businessName;
    final customer = appointment.customerName.isNotEmpty
        ? appointment.customerName
        : appointment.customerEmail;
    final status = appointment.status;
    final statusColor = status.toLowerCase() == 'cancelled'
        ? Colors.redAccent
        : status.toLowerCase() == 'pending'
            ? Colors.orange
            : Colors.green;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(appointment.startAt),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            services,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimeRange(context, appointment),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Client: $customer',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.member.name.isNotEmpty
        ? widget.member.name
        : 'Staff schedule';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<List<Appointment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryPink));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? [];

          if (data.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  Text(
                    'No appointments for this staff member yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) =>
                  _buildAppointmentCard(context, data[index]),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: data.length,
            ),
          );
        },
      ),
    );
  }
}
