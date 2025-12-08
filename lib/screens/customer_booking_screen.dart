import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/appointment_service.dart';

class CustomerBookingScreen extends StatefulWidget {
  final String businessDocId;
  final Map<String, dynamic> businessData;

  const CustomerBookingScreen({
    required this.businessDocId,
    required this.businessData,
    super.key,
  });

  @override
  State<CustomerBookingScreen> createState() => _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends State<CustomerBookingScreen> {
  int _currentStep = 0;
  final Set<int> _selectedServiceIndices = {};
  List<Map<String, dynamic>> _services = [];

  List<_StaffMember> _staffMembers = [];
  bool _staffLoading = true;
  String? _staffError;

  _StaffMember? _selectedStaff;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _prepareServices();
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _loadStaff();
  }

  void _prepareServices() {
    final rawServices =
        (widget.businessData['services'] as List<dynamic>?) ?? const [];
    _services = rawServices.map((service) {
      final map = Map<String, dynamic>.from(service as Map);
      final duration = map['duration'];
      return {
        'id': map['id']?.toString() ?? map['name'] ?? UniqueKey().toString(),
        'name': map['name'] ?? 'Service',
        'price': map['price'] ?? 0,
        'duration': duration is int
            ? duration
            : duration is num
                ? duration.toInt()
                : 30,
        'description': map['description'] ?? '',
      };
    }).toList();
  }

  Future<void> _loadStaff() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('staff_members')
          .where('businessDocId', isEqualTo: widget.businessDocId)
          .where('isActive', isEqualTo: true)
          .get();

      final staff = <_StaffMember>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        String? name;
        final userId = data['userId'] as String?;
        if (userId != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          final userData = userDoc.data();
          name = (userData?['fullName'] as String?)?.trim();
          final first = (userData?['firstName'] as String? ?? '').trim();
          final last = (userData?['lastName'] as String? ?? '').trim();
          if ((name == null || name.isEmpty) &&
              (first.isNotEmpty || last.isNotEmpty)) {
            name = [first, last].where((part) => part.isNotEmpty).join(' ');
          }
        }

        staff.add(
          _StaffMember(
            id: doc.id,
            name: name?.isNotEmpty == true ? name! : 'Team Member',
            role: data['position'] as String? ?? 'Staff',
          ),
        );
      }

      setState(() {
        _staffMembers = staff;
        _staffLoading = false;
      });
    } catch (e) {
      setState(() {
        _staffError = 'Unable to load staff ($e)';
        _staffLoading = false;
      });
    }
  }

  List<TimeOfDay> get _timeSlots {
    final slots = <TimeOfDay>[];
    for (int hour = 9; hour <= 18; hour++) {
      slots.add(TimeOfDay(hour: hour, minute: 0));
      if (hour < 18) {
        slots.add(TimeOfDay(hour: hour, minute: 30));
      }
    }
    return slots;
  }

  double get _totalPrice {
    return _selectedServiceIndices.fold<double>(
      0,
      (sum, index) {
        final price = _services[index]['price'];
        if (price is num) return sum + price.toDouble();
        if (price is String) {
          final parsed = double.tryParse(price);
          return sum + (parsed ?? 0);
        }
        return sum;
      },
    );
  }

  int get _totalDuration {
    return _selectedServiceIndices.fold<int>(
      0,
      (sum, index) {
        final duration = _services[index]['duration'];
        if (duration is int) return sum + duration;
        if (duration is num) return sum + duration.toInt();
        return sum + 30;
      },
    );
  }

  bool get _canContinueStep {
    if (_currentStep == 0) {
      return _selectedServiceIndices.isNotEmpty;
    } else if (_currentStep == 1) {
      final hasStaffOptions = _staffMembers.isNotEmpty;
      final staffValid = hasStaffOptions ? _selectedStaff != null : true;
      return staffValid && _selectedDate != null && _selectedTime != null;
    }
    return true;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minuteLabel = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minuteLabel $period';
  }

  DateTime? get _appointmentStart {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  DateTime? get _appointmentEnd {
    final start = _appointmentStart;
    if (start == null) return null;
    return start.add(Duration(minutes: _totalDuration));
  }

  Future<void> _submitBooking() async {
    if (!_canContinueStep) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book an appointment.')),
      );
      return;
    }

    final start = _appointmentStart;
    final end = _appointmentEnd;
    if (start == null || end == null) return;

    setState(() => _submitting = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final customerName =
          userData?['fullName'] ?? userData?['firstName'] ?? user.email ?? '';

      final selectedServices =
          _selectedServiceIndices.map((index) => _services[index]).toList();

      await AppointmentService.createAppointment(
        businessDocId: widget.businessDocId,
        appointmentData: {
          'businessId': widget.businessData['businessId'] ?? '',
          'businessName': widget.businessData['businessName'] ?? '',
          'customerId': user.uid,
          'customerName': customerName,
          'services': selectedServices,
          'serviceNames':
              selectedServices.map((service) => service['name']).toList(),
          'totalPrice': _totalPrice,
          'totalDurationMinutes': _totalDuration,
          'staffId': _selectedStaff?.id,
          'staffName': _selectedStaff?.name,
          'appointmentDate': Timestamp.fromDate(start),
          'startAt': Timestamp.fromDate(start),
          'endAt': Timestamp.fromDate(end),
          'status': 'pending',
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment requested successfully.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _goNextStep() {
    if (!_canContinueStep) return;
    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    } else {
      _submitBooking();
    }
  }

  void _goPreviousStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _currentStep -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.businessData['businessName'] ?? 'Book Appointment',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _StepIndicator(currentStep: _currentStep),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentStep == 0) _buildServicesStep(),
                    if (_currentStep == 1) _buildStaffAndTimeStep(),
                    if (_currentStep == 2) _buildConfirmationStep(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goPreviousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentStep == 2
                          ? (_submitting ? null : _submitBooking)
                          : (_canContinueStep ? _goNextStep : null),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: primaryPink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _currentStep == 2
                          ? (_submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Confirm Booking',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ))
                          : const Text(
                              'Continue',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesStep() {
    if (_services.isEmpty) {
      return const _EmptyState(
        message: 'This business has not listed services yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Services',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        ..._services.asMap().entries.map((entry) {
          final index = entry.key;
          final service = entry.value;
          final isSelected = _selectedServiceIndices.contains(index);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? primaryPink : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ListTile(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedServiceIndices.remove(index);
                  } else {
                    _selectedServiceIndices.add(index);
                  }
                });
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                service['name'] ?? 'Service',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${service['duration']} min',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if ((service['description'] as String?)?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        service['description'],
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87),
                      ),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatPrice(service['price']),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? primaryPink : Colors.grey.shade400,
                    size: 22,
                  ),
                ],
              ),
            ),
          );
        }),
        if (_selectedServiceIndices.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(_totalPrice),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Duration',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalDuration min',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStaffAndTimeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Specialist',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        if (_staffLoading)
          const Center(child: CircularProgressIndicator())
        else if (_staffError != null)
          _ErrorState(
            message: _staffError!,
            onRetry: _loadStaff,
          )
        else if (_staffMembers.isEmpty)
          const _EmptyState(
            message:
                'No staff listed. Any available specialist will be assigned.',
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _staffMembers.map((member) {
              final isSelected = _selectedStaff?.id == member.id;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStaff = member);
                },
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.42,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? primaryPink : Colors.transparent,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: primaryPink.withOpacity(0.15),
                        child: Text(
                          member.initials,
                          style: const TextStyle(
                            color: primaryPink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.role,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 24),
        Text(
          'Pick a Date',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: CalendarDatePicker(
            initialDate: _selectedDate ?? DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 120)),
            onDateChanged: (date) {
              setState(() => _selectedDate = date);
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Pick a Time',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _timeSlots.map((slot) {
            final isSelected = _selectedTime != null && slot == _selectedTime;
            return ChoiceChip(
              label: Text(_formatTimeOfDay(slot)),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedTime = slot);
              },
              selectedColor: primaryPink,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConfirmationStep() {
    final services =
        _selectedServiceIndices.map((index) => _services[index]).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & Confirm',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        _SummaryCard(
          title: 'Business',
          children: [
            Text(
              widget.businessData['businessName'] ?? 'Business',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (widget.businessData['address']?['street'] as String? ?? '')
                  .toString(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryCard(
          title: 'Services',
          children: services
              .map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          service['name'] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        _formatPrice(service['price']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          footer: Column(
            children: [
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatPrice(_totalPrice),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SummaryCard(
          title: 'Schedule',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Date',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  _selectedDate == null
                      ? '––'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Time',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  _selectedTime == null
                      ? '––'
                      : _formatTimeOfDay(_selectedTime!),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Duration',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  '$_totalDuration min',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryCard(
          title: 'Specialist',
          children: [
            if (_selectedStaff != null)
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: primaryPink.withOpacity(0.12),
                    child: Text(
                      _selectedStaff!.initials,
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
                        _selectedStaff!.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedStaff!.role,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              )
            else
              const Text(
                'Any available specialist will be assigned.',
                style: TextStyle(fontSize: 13),
              ),
          ],
        ),
      ],
    );
  }

  String _formatPrice(dynamic price) {
    if (price is num) {
      return '\$${price.toStringAsFixed(0)}';
    }
    if (price is String) {
      final parsed = double.tryParse(price);
      if (parsed != null) {
        return '\$${parsed.toStringAsFixed(0)}';
      }
    }
    return '\$0';
  }
}

class _StaffMember {
  final String id;
  final String name;
  final String role;

  const _StaffMember({
    required this.id,
    required this.name,
    required this.role,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    final first = parts.first.characters.first;
    final last = parts.last.characters.first;
    return (first + last).toUpperCase();
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index == 2 ? 0 : 6,
              left: index == 0 ? 0 : 6,
            ),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? primaryPink : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? footer;

  const _SummaryCard({
    required this.title,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Colors.redAccent),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
