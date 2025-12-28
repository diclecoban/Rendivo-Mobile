import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_snackbar.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../widgets/business_bottom_nav.dart';
import 'business_dashboard_screen.dart';
import 'business_schedule_screen.dart';
import 'business_services_screen.dart';
import 'business_appointments_screen.dart';

class BusinessStaffScreen extends StatefulWidget {
  final bool? isPending;

  const BusinessStaffScreen({
    super.key,
    this.isPending,
  });

  @override
  State<BusinessStaffScreen> createState() => _BusinessStaffScreenState();
}

class _BusinessStaffScreenState extends State<BusinessStaffScreen> {
  final _backend = BackendService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<StaffProfile> _staff = [];
  bool _loading = false;
  String? _error;
  String _businessId = '';
  String _statusFilter = 'all';
  String _roleFilter = 'all';
  bool _copySuccess = false;

  final List<String> _defaultRoles = const [
    'Senior Stylist',
    'Junior Stylist',
    'Massage Therapist',
    'Nail Technician',
  ];

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dashboard = await _backend.fetchBusinessDashboard();
      final businessMap = dashboard['business'] as Map?;
      final businessId = businessMap?['id']?.toString();
      if (businessId != null && businessId.isNotEmpty) {
        final business = await _backend.fetchBusinessById(businessId);
        setState(() {
          _businessId = business.businessId;
        });
      }

      final staff = await _backend.fetchOwnerStaffProfiles();
      setState(() {
        _staff = staff;
      });
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to load staff.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<String> get _roles {
    final roles = <String>{..._defaultRoles};
    for (final member in _staff) {
      final role = member.position.trim();
      if (role.isNotEmpty) roles.add(role);
    }
    final sorted = roles.toList()..sort();
    return ['All', ...sorted];
  }

  List<StaffProfile> get _filteredStaff {
    final query = _searchController.text.trim().toLowerCase();
    return _staff.where((member) {
      final name = member.displayName.toLowerCase();
      final role = member.position.toLowerCase();
      final matchesSearch =
          query.isEmpty || name.contains(query) || role.contains(query);
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active' && member.isActive) ||
          (_statusFilter == 'inactive' && !member.isActive);
      final matchesRole = _roleFilter == 'all' ||
          _roleFilter == 'All' ||
          member.position == _roleFilter;
      return matchesSearch && matchesStatus && matchesRole;
    }).toList();
  }

  Future<void> _copyBusinessId() async {
    if (_businessId.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _businessId));
    setState(() => _copySuccess = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copySuccess = false);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackbar.show(context, message);
  }

  Future<void> _showAddStaffInfo() async {
    if (widget.isPending ?? false) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Staff Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share your Business ID with staff members so they can join your team.',
            ),
            const SizedBox(height: 12),
            _BusinessIdRow(
              businessId: _businessId,
              onCopy: _copyBusinessId,
              showSuccess: _copySuccess,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(StaffProfile member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove staff member?'),
        content: Text(
          'Remove ${member.displayName} from your team? This action is not reversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _showSnack('Removing staff is not supported yet.');
    }
  }

  Future<void> _showStaffDetails(StaffProfile member) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _StaffDetailDialog(member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.isPending ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Manage Your Team',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: isPending ? null : _showAddStaffInfo,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add staff member',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStaffData,
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
                  : _buildContent(),
        ),
      ),
      bottomNavigationBar: BusinessBottomNav(
        currentIndex: 2,
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
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessScheduleScreen(isPending: isPending),
              ),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessAppointmentsScreen(
                  isPending: isPending,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildContent() {
    final filtered = _filteredStaff;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Staff Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            ElevatedButton.icon(
              onPressed: widget.isPending ?? false ? null : _showAddStaffInfo,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Staff'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search by name or role...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _statusFilter,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: 'inactive',
                    child: Text('Inactive'),
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
                value: _roleFilter == 'all' ? 'All' : _roleFilter,
                isExpanded: true,
                items: _roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(
                          role,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _roleFilter = value == 'All' ? 'all' : value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Role',
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
            'No staff members found. Add staff members by sharing your Business ID.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          ...filtered.map(
            (member) => _StaffCard(
              member: member,
              onView: () => _showStaffDetails(member),
              onDelete: () => _confirmDelete(member),
            ),
          ),
        const SizedBox(height: 16),
        _BusinessIdCard(
          businessId: _businessId,
          onCopy: _copyBusinessId,
          showSuccess: _copySuccess,
        ),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  final StaffProfile member;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _StaffCard({
    required this.member,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(member.displayName);
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: primaryPink.withOpacity(0.15),
            child: Text(
              initials,
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
                  member.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.position.isNotEmpty
                      ? member.position
                      : 'Staff Member',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                _StatusBadge(isActive: member.isActive),
              ],
            ),
          ),
          IconButton(
            onPressed: onView,
            icon: const Icon(Icons.visibility_outlined, size: 20),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF1F8E4D) : Colors.grey;
    final label = isActive ? 'Active' : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessIdCard extends StatelessWidget {
  final String businessId;
  final VoidCallback onCopy;
  final bool showSuccess;

  const _BusinessIdCard({
    required this.businessId,
    required this.onCopy,
    required this.showSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Text(
            'Business ID',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share this ID with staff members when they sign up.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _BusinessIdRow(
            businessId: businessId,
            onCopy: onCopy,
            showSuccess: showSuccess,
          ),
        ],
      ),
    );
  }
}

class _BusinessIdRow extends StatelessWidget {
  final String businessId;
  final VoidCallback onCopy;
  final bool showSuccess;

  const _BusinessIdRow({
    required this.businessId,
    required this.onCopy,
    required this.showSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              businessId.isNotEmpty ? businessId : '-',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: businessId.isEmpty ? null : onCopy,
          icon: Icon(
            showSuccess ? Icons.check_circle_outline : Icons.copy,
            color: showSuccess ? const Color(0xFF1F8E4D) : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _StaffDetailDialog extends StatelessWidget {
  final StaffProfile member;

  const _StaffDetailDialog({
    required this.member,
  });

  @override
  Widget build(BuildContext context) {
    final user = member.user;
    return AlertDialog(
      title: const Text('Staff Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: primaryPink.withOpacity(0.15),
                child: Text(
                  _initials(member.displayName),
                  style: const TextStyle(
                    color: primaryPink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    member.position.isNotEmpty
                        ? member.position
                        : 'Staff Member',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Email',
            value: user?.email.isNotEmpty == true ? user!.email : 'N/A',
          ),
          _DetailRow(
            label: 'Phone',
            value: user?.phone.isNotEmpty == true ? user!.phone : 'N/A',
          ),
          _DetailRow(
            label: 'Status',
            value: member.isActive ? 'Active' : 'Inactive',
          ),
          _DetailRow(
            label: 'Joined',
            value: member.joinedAt != null ? _formatDate(member.joinedAt!) : 'N/A',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
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

String _initials(String value) {
  final parts = value.trim().split(' ');
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  final first = parts.first.characters.first;
  final last = parts.last.characters.first;
  return (first + last).toUpperCase();
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
  final month = months[date.month - 1];
  return '$month ${date.day}, ${date.year}';
}
