import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/appointment_service.dart';
import '../services/backend_service.dart';
import '../services/session_service.dart';

class CustomerBookingScreen extends StatefulWidget {
  final Business business;

  const CustomerBookingScreen({super.key, required this.business});

  @override
  State<CustomerBookingScreen> createState() => _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends State<CustomerBookingScreen> {
  final _backend = BackendService.instance;
  final _session = SessionService.instance;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  List<ServiceItem> _services = [];
  final Set<String> _selectedServiceIds = {};
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final services = await _backend.fetchBusinessServices(widget.business.id);
      setState(() {
        _services = services.isNotEmpty ? services : widget.business.services;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _services = widget.business.services;
        _error = 'Could not load services right now.';
        _isLoading = false;
      });
    }
  }

  List<ServiceItem> get _selectedServices =>
      _services.where((s) => _selectedServiceIds.contains(s.id)).toList();

  double get _totalPrice =>
      _selectedServices.fold(0, (sum, item) => sum + item.price);

  int get _totalDuration =>
      _selectedServices.fold(0, (sum, item) => sum + item.durationMinutes);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  DateTime _combineDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _book() async {
    final user = _session.currentUser;
    if (user == null || _session.authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book an appointment.')),
      );
      return;
    }

    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one service.')),
      );
      return;
    }

    final startAt = _combineDateTime();
    final endAt =
        startAt.add(Duration(minutes: _totalDuration > 0 ? _totalDuration : 30));

    setState(() => _isSubmitting = true);
    try {
      await AppointmentService.createAppointment(
        business: widget.business,
        customer: user,
        services: _selectedServices,
        startAt: startAt,
        endAt: endAt,
        staff: null,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked!')),
      );
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not book: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressParts = [
      widget.business.address.street,
      widget.business.address.city,
      widget.business.address.state,
    ].where((part) => part.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.business.businessName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadServices,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.business.businessType,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.business.businessName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (addressParts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              addressParts,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.business.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            widget.business.phone,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Services',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_selectedServices.isNotEmpty)
                    Text(
                      '${_selectedServices.length} selected',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_services.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _error ?? 'No services available yet.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              else
                ..._services.map((service) {
                  final isSelected = _selectedServiceIds.contains(service.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isSelected ? primaryPink : Colors.grey.shade200,
                        width: isSelected ? 1.4 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) {
                            setState(() {
                              if (isSelected) {
                                _selectedServiceIds.remove(service.id);
                              } else {
                                _selectedServiceIds.add(service.id);
                              }
                            });
                          },
                          activeColor: primaryPink,
                        ),
                        const SizedBox(width: 8),
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
                              const SizedBox(height: 4),
                              Text(
                                '\$${service.price.toStringAsFixed(0)} • ${service.durationMinutes} min',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              if (service.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  service.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),
              const Text(
                'When?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTime,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        _selectedTime.format(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryPink),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Summary',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total'),
                        Text(
                          '\$${_totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Duration'),
                        Text(
                          '${_totalDuration > 0 ? _totalDuration : 30} minutes',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _book,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Book Appointment',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
