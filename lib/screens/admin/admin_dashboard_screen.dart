import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../models/app_models.dart';
import '../../services/backend_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _backend = BackendService.instance;

  bool _isLoading = true;
  String? _error;
  List<BusinessApplication> _pendingApplications = [];
  String? _actioningBusinessId;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _backend.fetchPendingBusinessApplications();
      setState(() {
        _pendingApplications = items;
      });
    } on AppException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _error = 'Bekleyen isletme kayitlari getirilemedi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDecision(
    BusinessApplication application, {
    required bool approve,
  }) async {
    String? notes;
    if (!approve) {
      notes = await _promptNotes();
      if (notes == null && !mounted) {
        return;
      }
      if (notes == null) {
        return;
      }
    }

    setState(() => _actioningBusinessId = application.id);
    try {
      await _backend.reviewBusinessApplication(
        businessId: application.id,
        approve: approve,
        notes: notes,
      );
      setState(() {
        _pendingApplications.removeWhere((item) => item.id == application.id);
      });
      if (!mounted) return;
      AppSnackbar.show(
        context,
        approve
            ? '${application.businessName} onaylandi.'
            : '${application.businessName} reddedildi.',
      );
    } on AppException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Islem tamamlanamadi. Lutfen tekrar deneyin.',
      );
    } finally {
      if (mounted) {
        setState(() => _actioningBusinessId = null);
      }
    }
  }

  Future<String?> _promptNotes() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Red gerekcesi (opsiyonel)'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Isletme sahibine gosterilecek mesaj',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgec'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: const Text(
          'Admin Paneli',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadApplications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadApplications,
          child: body,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _StatusCard(
            color: Colors.red.shade50,
            title: 'Bir sorun olustu',
            message: _error!,
            icon: Icons.error_outline,
          ),
        ],
      );
    }

    if (_pendingApplications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _StatusCard(
            color: Color(0xFFE7F7EF),
            title: 'Bekleyen kayit yok',
            message:
                'Tum isletme basvurulari degerlendirildi. Yeni kayitlar geldiginde burada goreceksiniz.',
            icon: Icons.verified_user_outlined,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingApplications.length,
      itemBuilder: (context, index) {
        final application = _pendingApplications[index];
        final isActioning = _actioningBusinessId == application.id;
        return _BusinessApplicationCard(
          application: application,
          isProcessing: isActioning,
          onApprove: () => _handleDecision(application, approve: true),
          onReject: () => _handleDecision(application, approve: false),
        );
      },
    );
  }
}

class _BusinessApplicationCard extends StatelessWidget {
  final BusinessApplication application;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _BusinessApplicationCard({
    required this.application,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primaryPink.withOpacity(0.12),
                child: Text(
                  application.businessName.isNotEmpty
                      ? application.businessName[0].toUpperCase()
                      : '?',
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
                      application.businessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      application.businessType.isNotEmpty
                          ? application.businessType
                          : 'Isletme',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Beklemede',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Isletme Sahibi',
            value: application.ownerName,
          ),
          _InfoRow(
            label: 'E-posta',
            value: application.ownerEmail,
          ),
          if (application.ownerPhone?.isNotEmpty == true)
            _InfoRow(
              label: 'Telefon',
              value: application.ownerPhone!,
            ),
          if (application.city?.isNotEmpty == true)
            _InfoRow(
              label: 'Sehir',
              value: application.city!,
            ),
          _InfoRow(
            label: 'Basvuru Tarihi',
            value: _formatDate(application.submittedAt),
          ),
          if (application.reviewNotes?.isNotEmpty == true)
            _InfoRow(
              label: 'Notlar',
              value: application.reviewNotes!,
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isProcessing ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reddet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isProcessing ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Onayla'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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

class _StatusCard extends StatelessWidget {
  final Color color;
  final String title;
  final String message;
  final IconData icon;

  const _StatusCard({
    required this.color,
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(
              icon,
              color: primaryPink,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
