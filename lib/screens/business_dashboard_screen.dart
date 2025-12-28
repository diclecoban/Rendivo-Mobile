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
      setState(() {
        _dashboardStatus = status != 'ready' ? status : null;
        _statusMessage = status != 'ready' ? message : null;
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

  const _DashboardContent({
    required this.business,
    required this.loading,
    required this.error,
    required this.serviceCount,
    required this.staffCount,
    required this.user,
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
                child: _KpiCard(
                  title: 'Services',
                  mainValue: loading ? '...' : serviceCount.toString(),
                  trendText: 'Active services',
                  trendColor: Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Staff',
                  mainValue: loading ? '...' : staffCount.toString(),
                  trendText: 'Team members',
                  trendColor: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _KpiCard(
            title: 'Contact',
            mainValue: business?.phone.isNotEmpty == true ? business!.phone : '-',
            trendText: business?.email ?? '',
            trendColor: Colors.grey,
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Services'),
          const SizedBox(height: 8),
          _CardContainer(
            child: loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: primaryPink),
                    ),
                  )
                : error != null
                    ? Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      )
                    : (business?.services.isNotEmpty ?? false)
                        ? Column(
                            children: business!.services
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
          const _SectionTitle('Schedule'),
          const SizedBox(height: 8),
          _CardContainer(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: primaryPink.withOpacity(0.15),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: primaryPink,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Manage staff shifts and availability.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BusinessScheduleScreen(),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Staff'),
          const SizedBox(height: 8),
          _CardContainer(
            child: loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: primaryPink),
                    ),
                  )
                : (business?.staff.isNotEmpty ?? false)
                    ? Column(
                        children: business!.staff
                            .take(5)
                            .map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _StaffRow(member: m),
                              ),
                            )
                            .toList(),
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
        ? 'Başvurunuz reddedildi'
        : 'Başvurunuz inceleniyor';
    final description = statusMessage ??
        (_isRejected
            ? 'Detaylı inceleme sonrası başvurunuz reddedildi. Güncellemeler için destek ekibiyle iletişime geçebilirsiniz.'
            : 'Rendivo ekibi işletme başvurunuzu inceliyor. Onaylandığında bildirim alacaksınız.');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isRejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
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
                  'Not: ${business!.reviewNotes!}',
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
                  'Başvuru özeti',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _PendingInfoRow(
                  label: 'İşletme adı',
                  value: business!.businessName,
                ),
                _PendingInfoRow(
                  label: 'Durum',
                  value: _isRejected ? 'Reddedildi' : 'Onay bekliyor',
                ),
                _PendingInfoRow(
                  label: 'Gönderim tarihi',
                  value: _formatDate(business!.createdAt),
                ),
                _PendingInfoRow(
                  label: 'Son güncelleme',
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
