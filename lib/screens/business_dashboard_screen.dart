import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import 'business_schedule_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import '../widgets/business_bottom_nav.dart';
import 'business_services_screen.dart';
import 'business_staff_screen.dart';
import 'business_appointments_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final _backend = BackendService.instance;
  final _session = SessionService.instance;

  Business? _business;
  bool _loading = false;
  String? _error;
  String? _dashboardStatus;
  String? _statusMessage;
  _DashboardStats? _stats;
  List<_UpcomingAppointment> _upcomingAppointments = [];
  List<_StaffAvailability> _staffAvailability = [];
  List<_PopularService> _popularServices = [];

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    final hasToken =
        _session.authToken != null && _session.authToken!.isNotEmpty;
    if (!hasToken) {
      setState(() {
        _error = 'Please sign in to view your business dashboard.';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dashboard = await _backend.fetchBusinessDashboard();
      final status = dashboard['status']?.toString() ?? 'ready';
      final message = dashboard['message']?.toString();
      final stats = dashboard['stats'] as Map?;
      final upcomingList = dashboard['upcomingAppointments'] as List?;
      final staffList = dashboard['staff'] as List?;
      final popularList = dashboard['popularServices'] as List?;
      setState(() {
        _dashboardStatus = status != 'ready' ? status : null;
        _statusMessage = status != 'ready' ? message : null;
        _stats = stats == null
            ? null
            : _DashboardStats.fromJson(Map<String, dynamic>.from(stats));
        _upcomingAppointments = upcomingList == null
            ? []
            : upcomingList
                .map((item) => _UpcomingAppointment.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ))
                .toList();
        _staffAvailability = staffList == null
            ? []
            : staffList
                .map((item) => _StaffAvailability.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ))
                .toList();
        _popularServices = popularList == null
            ? []
            : popularList
                .map((item) => _PopularService.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ))
                .toList();
      });
      final businessMap = dashboard['business'] as Map?;
      final businessId = businessMap?['id']?.toString();
      if (businessId == null || businessId.isEmpty) {
        throw const AppException('Business not found for this account.');
      }

      final business = await _backend.fetchBusinessById(businessId);
      setState(() {
        _business = business;
      });
    } on AppException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load business data. Please try again.';
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
  bool get _requiresApproval =>
      _dashboardStatus != null && _dashboardStatus != 'ready';

  @override
  Widget build(BuildContext context) {
    final user = _session.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBusiness,
          child: _requiresApproval
              ? _PendingApprovalView(
                  business: _business,
                  status: _dashboardStatus ?? 'pending_approval',
                  statusMessage: _statusMessage,
                  isLoading: _loading,
                )
              : _DashboardContent(
                  business: _business,
                  loading: _loading,
                  error: _error,
                  serviceCount: _serviceCount,
                  staffCount: _staffCount,
                  user: user,
                  stats: _stats,
                  upcomingAppointments: _upcomingAppointments,
                  staffAvailability: _staffAvailability,
                  popularServices: _popularServices,
                ),
        ),
      ),
      bottomNavigationBar: BusinessBottomNav(
        currentIndex: 0,
        isPending: _requiresApproval,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessServicesScreen(
                  isPending: _requiresApproval,
                ),
              ),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessScheduleScreen(
                  isPending: _requiresApproval,
                ),
              ),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessAppointmentsScreen(
                  isPending: _requiresApproval,
                ),
              ),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessStaffScreen(
                  isPending: _requiresApproval,
                ),
              ),
            );
          }
        },
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
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
                '${service.durationMinutes} min Â· \$${service.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String changeText;
  final Color changeColor;
  final bool fullWidth;
  final bool centerText;

  const _StatCard({
    required this.title,
    required this.value,
    required this.changeText,
    required this.changeColor,
    this.fullWidth = false,
    this.centerText = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : 160,
      child: _CardContainer(
        child: Column(
          crossAxisAlignment:
              centerText ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: centerText ? TextAlign.center : TextAlign.left,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: centerText ? TextAlign.center : TextAlign.left,
            ),
            const SizedBox(height: 4),
            Text(
              changeText,
              style: TextStyle(
                fontSize: 11,
                color: changeColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: centerText ? TextAlign.center : TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardStats {
  final int todayAppointments;
  final String appointmentChange;
  final int newClientsThisWeek;
  final String clientChange;
  final String projectedRevenue;
  final String revenueChange;

  const _DashboardStats({
    required this.todayAppointments,
    required this.appointmentChange,
    required this.newClientsThisWeek,
    required this.clientChange,
    required this.projectedRevenue,
    required this.revenueChange,
  });

  factory _DashboardStats.fromJson(Map<String, dynamic> json) {
    return _DashboardStats(
      todayAppointments: int.tryParse(json['todayAppointments']?.toString() ?? '') ?? 0,
      appointmentChange: json['appointmentChange']?.toString() ?? '0',
      newClientsThisWeek: int.tryParse(json['newClientsThisWeek']?.toString() ?? '') ?? 0,
      clientChange: json['clientChange']?.toString() ?? '0',
      projectedRevenue: json['projectedRevenue']?.toString() ?? '0',
      revenueChange: json['revenueChange']?.toString() ?? '0',
    );
  }
}

class _UpcomingAppointment {
  final String id;
  final String service;
  final String staff;
  final String client;
  final String time;
  final String status;

  const _UpcomingAppointment({
    required this.id,
    required this.service,
    required this.staff,
    required this.client,
    required this.time,
    required this.status,
  });

  factory _UpcomingAppointment.fromJson(Map<String, dynamic> json) {
    return _UpcomingAppointment(
      id: json['id']?.toString() ?? '',
      service: json['service']?.toString() ?? 'Service',
      staff: json['staff']?.toString() ?? 'Staff',
      client: json['client']?.toString() ?? 'Client',
      time: json['time']?.toString() ?? '--:--',
      status: json['status']?.toString() ?? '',
    );
  }
}

class _StaffAvailability {
  final String id;
  final String name;
  final String status;
  final String position;

  const _StaffAvailability({
    required this.id,
    required this.name,
    required this.status,
    required this.position,
  });

  factory _StaffAvailability.fromJson(Map<String, dynamic> json) {
    return _StaffAvailability(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Staff',
      status: json['status']?.toString() ?? 'available',
      position: json['position']?.toString() ?? '',
    );
  }
}

class _PopularService {
  final String name;
  final double percentage;

  const _PopularService({
    required this.name,
    required this.percentage,
  });

  factory _PopularService.fromJson(Map<String, dynamic> json) {
    final percentValue = double.tryParse(json['percentage']?.toString() ?? '');
    return _PopularService(
      name: json['name']?.toString() ?? 'Service',
      percentage: percentValue ?? 0,
    );
  }
}

class _StaffRow extends StatelessWidget {
  final StaffMember member;

  const _StaffRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Row(
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
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final Business? business;
  final bool loading;
  final String? error;
  final int serviceCount;
  final int staffCount;
  final AuthUser? user;
  final _DashboardStats? stats;
  final List<_UpcomingAppointment> upcomingAppointments;
  final List<_StaffAvailability> staffAvailability;
  final List<_PopularService> popularServices;

  const _DashboardContent({
    required this.business,
    required this.loading,
    required this.error,
    required this.serviceCount,
    required this.staffCount,
    required this.user,
    required this.stats,
    required this.upcomingAppointments,
    required this.staffAvailability,
    required this.popularServices,
  });

  Future<void> _logout(BuildContext context) async {
    AuthService.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Color _trendColor(String? change) {
    if (change == null || change.isEmpty) return Colors.grey;
    if (change.trim().startsWith('-')) {
      return Colors.redAccent;
    }
    return const Color(0xFF2E7D32);
  }

  String _formatRevenue(String? value) {
    if (value == null || value.isEmpty) return '-';
    return '\$${value}';
  }

  String _statusText(String status) {
    switch (status) {
      case 'busy':
        return 'Busy';
      case 'available':
        return 'Available';
      case 'break':
        return 'On Break';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'busy':
        return Colors.redAccent;
      case 'available':
        return const Color(0xFF2E7D32);
      case 'break':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _progressColor(int index) {
    const colors = [
      Color(0xFFE91E63),
      Color(0xFF7E57C2),
      Color(0xFF26A69A),
      Color(0xFFFFA726),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
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
                      business?.businessName.isNotEmpty == true
                          ? 'Hello, ${business!.businessName}!'
                          : 'Hello${user != null ? ', ${user!.fullName}' : ''}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error == null
                          ? "Here's what's happening with your business."
                          : 'We could not load all data right now.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(userId: user?.id),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none_rounded),
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
                  backgroundColor: primaryPink,
                  child: Text(
                    (business?.businessName.isNotEmpty ?? false)
                        ? business!.businessName[0].toUpperCase()
                        : (user?.fullName.isNotEmpty ?? false)
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
                child: _StatCard(
                  title: 'Total Appointments Today',
                  value: stats?.todayAppointments.toString() ?? '0',
                  changeText:
                      '${stats?.appointmentChange ?? '0'} from yesterday',
                  changeColor: _trendColor(stats?.appointmentChange),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'New Clients This Week',
                  value: stats?.newClientsThisWeek.toString() ?? '0',
                  changeText: '${stats?.clientChange ?? '0'} from last week',
                  changeColor: _trendColor(stats?.clientChange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            title: 'Projected Revenue',
            value: _formatRevenue(stats?.projectedRevenue),
            changeText: '${stats?.revenueChange ?? '0'} from yesterday',
            changeColor: _trendColor(stats?.revenueChange),
            fullWidth: true,
            centerText: true,
          ),
          const SizedBox(height: 16),
          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Staff Availability',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (staffAvailability.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No staff members',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...staffAvailability.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryPink.withOpacity(0.15),
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                color: primaryPink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              member.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(member.status)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusText(member.status),
                              style: TextStyle(
                                fontSize: 11,
                                color: _statusColor(member.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CardContainer(
            child: popularServices.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No service data available',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Popular Services',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...popularServices.asMap().entries.map((entry) {
                        final index = entry.key;
                        final service = entry.value;
                        final percent = service.percentage.clamp(0, 100);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      service.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${percent.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: percent / 100,
                                  minHeight: 6,
                                  backgroundColor:
                                      const Color(0xFFF2EDF4),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                    _progressColor(index),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming Appointments (${upcomingAppointments.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BusinessAppointmentsScreen(isPending: false),
                          ),
                        );
                      },
                      child: const Text('View Appointments'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (upcomingAppointments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No upcoming appointments',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...upcomingAppointments.map(
                    (appointment) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryPink.withOpacity(0.15),
                            child: Text(
                              appointment.client.isNotEmpty
                                  ? appointment.client[0].toUpperCase()
                                  : 'C',
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
                                  '${appointment.service} - ${appointment.staff}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  appointment.client,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            appointment.time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PendingApprovalView extends StatelessWidget {
  final Business? business;
  final String status;
  final String? statusMessage;
  final bool isLoading;

  const _PendingApprovalView({
    required this.business,
    required this.status,
    required this.statusMessage,
    required this.isLoading,
  });

  bool get _isRejected => status == 'rejected';

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && business == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    final headline = _isRejected
        ? 'Your application was rejected'
        : 'Your application is under review';
    final description = statusMessage ??
        (_isRejected
            ? 'Your application was rejected after review. Please contact support for details.'
            : 'The Rendivo team is reviewing your application. You will be notified once it is approved.');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isRejected
                ? const Color(0xFFFFEBEE)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  _isRejected ? Icons.error_outline : Icons.schedule_outlined,
                  color: _isRejected ? Colors.redAccent : Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              if (business?.reviewNotes?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Note: ${business!.reviewNotes!}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (business != null) ...[
          const SizedBox(height: 20),
          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Application Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _PendingInfoRow(
                  label: 'Business name',
                  value: business!.businessName,
                ),
                _PendingInfoRow(
                  label: 'Status',
                  value: _isRejected ? 'Rejected' : 'Pending approval',
                ),
                _PendingInfoRow(
                  label: 'Submitted on',
                  value: _formatDate(business!.createdAt),
                ),
                _PendingInfoRow(
                  label: 'Last update',
                  value: _formatDate(business!.approvedAt ?? business!.rejectedAt),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
class _PendingInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _PendingInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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

