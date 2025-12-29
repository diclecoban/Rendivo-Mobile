import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_snackbar.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../widgets/business_bottom_nav.dart';
import 'business_dashboard_screen.dart';
import 'business_schedule_screen.dart';
import 'business_staff_screen.dart';
import 'business_appointments_screen.dart';

class BusinessServicesScreen extends StatefulWidget {
  final bool? isPending;

  const BusinessServicesScreen({
    super.key,
    this.isPending,
  });

  @override
  State<BusinessServicesScreen> createState() =>
      _BusinessServicesScreenState();
}

class _BusinessServicesScreenState extends State<BusinessServicesScreen> {
  final _backend = BackendService.instance;

  static const List<String> _predefinedServices = [
    'Haircut',
    'Hair Coloring',
    'Blowdry & Styling',
    'Beard Trim',
    'Manicure',
    'Pedicure',
    'Gel Nails',
    'Facial',
    'Waxing',
    'Eyebrow Shaping',
    'Eyelash Extensions',
    'Makeup',
    'Massage',
    'General Consultation',
    'Dental Checkup',
    'Dental Cleaning',
    'Teeth Whitening',
    'Physiotherapy Session',
    'Blood Test',
    'X-Ray',
    'Vaccination',
    'Health Screening',
    'Eye Exam',
    'Personal Training',
    'Group Fitness Class',
    'Yoga Session',
    'Pilates',
    'Spinning Class',
    'Boxing Training',
    'Swimming Lesson',
    'Nutrition Consultation',
    'Fitness Assessment',
    'Legal Consultation',
    'Accounting Service',
    'Tax Preparation',
    'Business Consulting',
    'Financial Planning',
    'Marketing Consultation',
    'IT Support',
    'Career Coaching',
    'Math Tutoring',
    'English Tutoring',
    'Science Tutoring',
    'Language Lesson',
    'Music Lesson',
    'Art Class',
    'Test Prep',
    'Online Course',
    'Dog Grooming',
    'Cat Grooming',
    'Pet Bath',
    'Nail Trimming',
    'Vet Consultation',
    'Pet Training',
    'Dog Walking',
    'Pet Sitting',
    'Car Wash',
    'Interior Detailing',
    'Exterior Detailing',
    'Full Detailing',
    'Oil Change',
    'Tire Change',
    'Vehicle Inspection',
    'Car Repair',
    'Portrait Session',
    'Event Photography',
    'Wedding Photography',
    'Product Photography',
    'Video Editing',
    'Studio Session',
    'Photo Retouching',
    'Individual Therapy',
    'Couples Therapy',
    'Family Therapy',
    'Life Coaching',
    'Career Counseling',
    'Stress Management',
    'Mental Health Consultation',
    'Other',
  ];

  List<String> _availableServices = [];
  String _businessType = '';
  List<ServiceItem> _services = [];
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  bool _isPendingApproval = false;

  @override
  void initState() {
    super.initState();
    _isPendingApproval = widget.isPending ?? false;
    _checkApprovalAndLoadServices();
  }

  Future<void> _checkApprovalAndLoadServices() async {
    Map<String, dynamic>? dashboard;
    Map<String, dynamic>? business;
    if (widget.isPending != null) {
      try {
        dashboard = await _backend.fetchBusinessDashboard();
        final businessRaw = dashboard['business'];
        business = businessRaw is Map
            ? Map<String, dynamic>.from(businessRaw)
            : null;
        final type = business?['businessType']?.toString() ?? '';
        if (mounted) {
          setState(() => _businessType = type);
        }
      } catch (_) {
        // Ignore business metadata failures for pending approval flow.
      }
      await _loadAvailableServices(useBusinessType: false);
      await _loadServices();
      return;
    }

    try {
      dashboard = await _backend.fetchBusinessDashboard();
      final businessRaw = dashboard['business'];
      business =
          businessRaw is Map ? Map<String, dynamic>.from(businessRaw) : null;
      final status =
          business?['approvalStatus']?.toString().toLowerCase() ?? '';
      final type = business?['businessType']?.toString() ?? '';

      if (status == 'pending') {
        if (mounted) {
          setState(() => _isPendingApproval = true);
        }
      } else if (status == 'rejected') {
        if (mounted) {
          setState(() {
            _error =
                'Your business application has been rejected. Please contact support.';
          });
        }
        return;
      }
      if (mounted) {
        setState(() => _businessType = type);
      }
    } catch (_) {
      // If approval check fails, still attempt to load services.
    }

    await _loadAvailableServices(useBusinessType: false);
    await _loadServices();
  }

  Future<void> _loadAvailableServices({bool useBusinessType = false}) async {
    final resolvedType = useBusinessType ? _businessType : null;
    try {
      final services =
          await _backend.fetchAvailableServices(businessType: resolvedType);
      final merged = <String>[];
      final seen = <String>{};
      for (final item in _predefinedServices) {
        if (seen.add(item)) merged.add(item);
      }
      for (final item in services) {
        if (seen.add(item)) merged.add(item);
      }
      if (!mounted) return;
      setState(() {
        _availableServices = merged;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableServices = _predefinedServices;
      });
    }
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _backend.fetchOwnerServices();
      setState(() {
        _services = items;
      });
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to load services.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openServiceEditor({ServiceItem? service}) async {
    final isPending = _isPendingApproval;
    if (isPending) return;
    if (_availableServices.isEmpty) {
      await _loadAvailableServices();
    }

    final nameController =
        TextEditingController(text: service?.name ?? '');
    final descriptionController =
        TextEditingController(text: service?.description ?? '');
    final durationController = TextEditingController(
      text: service != null ? service.durationMinutes.toString() : '',
    );
    final priceController = TextEditingController(
      text: service != null ? service.price.toStringAsFixed(2) : '',
    );

    String? selectedName = service?.name.isNotEmpty == true
        ? service!.name
        : null;
    final dropdownServices = List<String>.from(_availableServices);
    if (service != null &&
        service.name.isNotEmpty &&
        !dropdownServices.contains(service.name)) {
      dropdownServices.insert(0, service.name);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveService() async {
              final customName = nameController.text.trim();
              final name = selectedName == 'Other' && customName.isNotEmpty
                  ? customName
                  : selectedName?.trim() ?? '';
              final durationText = durationController.text.trim();
              final priceText = priceController.text.trim();
              if (name.isEmpty || durationText.isEmpty || priceText.isEmpty) {
                _showSnack('Please fill in all required fields.');
                return;
              }
              if (service == null &&
                  selectedName != 'Other' &&
                  !dropdownServices.contains(name)) {
                _showSnack('Please select a service name from the list.');
                return;
              }

              final duration = int.tryParse(durationText);
              final price = double.tryParse(priceText);
              if (duration == null || price == null) {
                _showSnack('Please enter valid duration and price.');
                return;
              }

              setState(() => _submitting = true);
              try {
                if (service == null) {
                  await _backend.createService(
                    name: name,
                    description: descriptionController.text.trim(),
                    price: price,
                    durationMinutes: duration,
                  );
                } else {
                  await _backend.updateService(
                    id: service.id,
                    name: name,
                    description: descriptionController.text.trim(),
                    price: price,
                    durationMinutes: duration,
                  );
                }
                if (!mounted) return;
                Navigator.pop(context);
                await _loadServices();
              } on AppException catch (e) {
                _showSnack(e.message);
              } catch (e) {
                _showSnack('Failed to save service.');
              } finally {
                if (mounted) {
                  setState(() => _submitting = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          service == null
                              ? 'Add New Service'
                              : 'Edit Service',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedName,
                      items: dropdownServices
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Service name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          selectedName = value;
                        });
                        if (value != 'Other') {
                          nameController.text = '';
                        }
                      },
                    ),
                    if (selectedName == 'Other') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Custom name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration (min)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              prefixText: '\$',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : saveService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _submitting
                              ? 'Saving...'
                              : service == null
                                  ? 'Add Service'
                                  : 'Update Service',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteService(ServiceItem service) async {
    final isPending = _isPendingApproval;
    if (isPending) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete service?'),
        content: Text('Delete "${service.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      await _backend.deleteService(service.id);
      await _loadServices();
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to delete service.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackbar.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _isPendingApproval;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Manage Services',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isPending ? null : () => _openServiceEditor(),
            icon: const Icon(Icons.add),
            tooltip: 'Add service',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadServices,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Services',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed:
                                  isPending ? null : () => _openServiceEditor(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add New'),
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
                        if (_services.isEmpty)
                          const Text(
                            'No services yet. Add your first service to get started!',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        else
                          ..._services.map(
                            (service) => _ServiceCard(
                              service: service,
                              onEdit: isPending
                                  ? null
                                  : () => _openServiceEditor(
                                        service: service,
                                      ),
                              onDelete: isPending
                                  ? null
                                  : () => _deleteService(service),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
      bottomNavigationBar: BusinessBottomNav(
        currentIndex: 1,
        isPending: isPending,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessScheduleScreen(isPending: isPending),
              ),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessStaffScreen(isPending: isPending),
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
}

class _ServiceCard extends StatelessWidget {
  final ServiceItem service;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ServiceCard({
    required this.service,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
            radius: 18,
            backgroundColor: primaryPink.withOpacity(0.15),
            child: const Icon(
              Icons.content_cut,
              size: 18,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (service.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      service.description,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${service.durationMinutes} min · \$${service.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}
