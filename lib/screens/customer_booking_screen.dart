import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_snackbar.dart';
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

  List<StaffMember> _staffMembers = [];
  bool _staffLoading = true;
  String? _staffError;
  StaffMember? _selectedStaff;

  DateTime? _selectedDate;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Set<String> _bookedDays = {};
  Map<String, List<AvailabilitySlot>> _bookedSlotsByDate = {};
  Map<String, List<AvailabilitySlot>> _shiftSlotsByDate = {};
  DateTime? _selectedSlotStart;
  bool _availabilityLoading = false;
  String? _availabilityError;

  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadStaff();
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

  Future<void> _loadStaff() async {
    try {
      setState(() {
        _staffLoading = true;
        _staffError = null;
      });
      final staff = await _backend.fetchBusinessStaff(widget.business.id);
      setState(() {
        _staffMembers = staff.isNotEmpty ? staff : widget.business.staff;
        _staffLoading = false;
      });
    } catch (_) {
      setState(() {
        _staffMembers = widget.business.staff;
        _staffError = 'Could not load staff right now.';
        _staffLoading = false;
      });
    }
  }

  Future<void> _loadAvailabilityForMonth(DateTime month) async {
    final staffId = _selectedStaff?.id;
    if (staffId == null) {
      setState(() {
        _focusedMonth = month;
        _availabilityLoading = false;
        _availabilityError = null;
        _bookedDays = {};
        _bookedSlotsByDate = {};
        _shiftSlotsByDate = {};
        _selectedSlotStart = null;
      });
      return;
    }

    setState(() {
      _availabilityLoading = true;
      _availabilityError = null;
      _focusedMonth = month;
      _selectedSlotStart = null;
    });

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    try {
      final availability = await _backend.fetchBusinessAvailability(
        businessId: widget.business.id,
        startDate: start,
        endDate: end,
        staffId: staffId,
      );

      if (!mounted || _selectedStaff?.id != staffId) return;

      final map = <String, List<AvailabilitySlot>>{};
      for (final slot in availability.bookedSlots) {
        final key = _formatDateKey(slot.startAt);
        map.putIfAbsent(key, () => []).add(slot);
      }
      final shiftMap = <String, List<AvailabilitySlot>>{};
      for (final slot in availability.shiftSlots) {
        final key = _formatDateKey(slot.startAt);
        shiftMap.putIfAbsent(key, () => []).add(slot);
      }

      setState(() {
        _bookedDays = availability.bookedDays.toSet();
        _bookedSlotsByDate = map;
        _shiftSlotsByDate = shiftMap;
        _availabilityLoading = false;

        if (_selectedDate != null) {
          final availSlots = _availableSlotsForDay(_selectedDate!);
          final hasSelectedSlot = _selectedSlotStart != null &&
              availSlots.any(
                (slot) => _selectedSlotStart!.isAtSameMomentAs(slot),
              );
          if (!hasSelectedSlot) {
            _selectedSlotStart = null;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availabilityError = 'Could not load availability.';
        _availabilityLoading = false;
      });
    }
  }

  List<ServiceItem> get _selectedServices =>
      _services.where((s) => _selectedServiceIds.contains(s.id)).toList();

  double get _totalPrice =>
      _selectedServices.fold(0, (sum, item) => sum + item.price);

  int get _totalDuration =>
      _selectedServices.fold(0, (sum, item) => sum + item.durationMinutes);

  int get _effectiveDuration => _totalDuration > 0 ? _totalDuration : 30;

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _formatDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<AvailabilitySlot> _bookedSlotsForDate(DateTime date) {
    return _bookedSlotsByDate[_formatDateKey(date)] ?? [];
  }

  List<AvailabilitySlot> _shiftSlotsForDate(DateTime date) {
    return _shiftSlotsByDate[_formatDateKey(date)] ?? [];
  }

  List<DateTime> _standardSlotsForDay(DateTime date) {
    final shifts = _shiftSlotsForDate(date);
    if (shifts.isEmpty) return [];

    final stepMinutes = _effectiveDuration;
    final slots = <DateTime>[];
    for (final shift in shifts) {
      final start = shift.startAt.toLocal();
      final end = shift.endAt.toLocal();
      var cursor = DateTime(
        start.year,
        start.month,
        start.day,
        start.hour,
        start.minute,
      );
      final limit = DateTime(
        end.year,
        end.month,
        end.day,
        end.hour,
        end.minute,
      );
      while (cursor.isBefore(limit)) {
        final slotEnd = cursor.add(Duration(minutes: _effectiveDuration));
        if (!slotEnd.isAfter(limit)) {
          slots.add(cursor);
        }
        cursor = cursor.add(Duration(minutes: stepMinutes));
      }
    }
    return slots;
  }

  bool _isBookedSlot(DateTime start) {
    final end = start.add(Duration(minutes: _effectiveDuration));
    return _bookedSlotsForDate(start).any((slot) {
      final s = slot.startAt.toLocal();
      final e = slot.endAt.toLocal();
      return start.isBefore(e) && end.isAfter(s);
    });
  }

  List<DateTime> _availableSlotsForDay(DateTime date) {
    return _standardSlotsForDay(date)
        .where((s) => !_isBookedSlot(s))
        .toList();
  }

  void _handleStaffSelection(StaffMember member) {
    if (_selectedStaff?.id == member.id) return;
    setState(() {
      _selectedStaff = member;
      _selectedDate = null;
      _selectedSlotStart = null;
      _bookedDays = {};
      _bookedSlotsByDate = {};
      _shiftSlotsByDate = {};
      _availabilityError = null;
    });
    _loadAvailabilityForMonth(_focusedMonth);
  }

  Future<void> _book() async {
    final user = _session.currentUser;
    if (user == null || _session.authToken == null) {
      AppSnackbar.show(
        context,
        'Please log in to book an appointment.',
      );
      return;
    }

    if (_selectedServices.isEmpty) {
      AppSnackbar.show(context, 'Select at least one service.');
      return;
    }

    final staff = _selectedStaff;
    if (staff == null) {
      AppSnackbar.show(context, 'Select a staff member to continue.');
      return;
    }

    if (_selectedDate == null) {
      AppSnackbar.show(context, 'Select a date to continue.');
      return;
    }

    final start = _selectedSlotStart;
    if (start == null) {
      AppSnackbar.show(context, 'Select an available time slot.');
      return;
    }

    final end = start.add(Duration(minutes: _effectiveDuration));

    setState(() => _isSubmitting = true);
    try {
      await AppointmentService.createAppointment(
        business: widget.business,
        customer: user,
        services: _selectedServices,
        startAt: start,
        endAt: end,
        staff: staff,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Appointment booked!');
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Could not book: $e');
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
          onRefresh: () async {
            await _loadServices();
            await _loadStaff();
            if (_selectedStaff != null) {
              await _loadAvailabilityForMonth(_focusedMonth);
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildBusinessCard(addressParts),
              const SizedBox(height: 20),
              _buildServicesSection(),
              const SizedBox(height: 16),
              _buildStaffSection(),
              const SizedBox(height: 16),
              _buildScheduleSection(),
              const SizedBox(height: 16),
              _buildNotesField(),
              const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 16),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessCard(String addressParts) {
    return Container(
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
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            widget.business.businessName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
    );
  }

  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Services',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                  color: isSelected ? primaryPink : Colors.grey.shade200,
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
                        _selectedSlotStart = null;
                        if (_selectedServiceIds.isEmpty) {
                          _selectedStaff = null;
                          _selectedDate = null;
                          _bookedDays = {};
                          _bookedSlotsByDate = {};
                          _shiftSlotsByDate = {};
                          _availabilityError = null;
                          _availabilityLoading = false;
                        }
                      });
                      if (_selectedServiceIds.isNotEmpty && _selectedStaff != null) {
                        _loadAvailabilityForMonth(_focusedMonth);
                      }
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
      ],
    );
  }

  Widget _buildStaffSection() {
    final canSelectStaff = _selectedServiceIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Professional',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (!canSelectStaff)
          _SequenceNotice(
            message: 'Choose at least one service to see available staff.',
          )
        else if (_staffLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_staffError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _staffError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              TextButton(
                onPressed: _loadStaff,
                child: const Text('Retry'),
              ),
            ],
          )
        else if (_staffMembers.isEmpty)
          _SequenceNotice(
            message:
                'This business has no active staff profiles yet. Please check again later.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _staffMembers.map((member) {
              final isSelected = _selectedStaff?.id == member.id;
              final roleText = member.role.trim();
              return ChoiceChip(
                label: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (roleText.isNotEmpty)
                      Text(
                        roleText,
                        style: const TextStyle(fontSize: 10),
                      ),
                  ],
                ),
                selected: isSelected,
                selectedColor: primaryPink.withOpacity(0.14),
                backgroundColor: Colors.white,
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? primaryPink : Colors.grey.shade200,
                  ),
                ),
                onSelected: (value) {
                  if (!value) {
                    setState(() {
                      _selectedStaff = null;
                      _selectedDate = null;
                      _selectedSlotStart = null;
                      _bookedDays = {};
                      _bookedSlotsByDate = {};
                      _shiftSlotsByDate = {};
                      _availabilityError = null;
                      _availabilityLoading = false;
                    });
                    return;
                  }
                  _handleStaffSelection(member);
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    if (_selectedStaff == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'When?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _SequenceNotice(
            message: 'Pick a staff member to view available dates and times.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _buildCalendarCard(),
        const SizedBox(height: 12),
        if (_availabilityLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_availabilityError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _availabilityError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              TextButton(
                onPressed: () => _loadAvailabilityForMonth(_focusedMonth),
                child: const Text('Retry'),
              ),
            ],
          )
        else
          _buildTimeSlotsGrid(),
      ],
    );
  }

  Widget _buildCalendarCard() {
    final days = _daysInMonth(_focusedMonth);
    final monthLabel =
        '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _CalendarDow('Mon'),
              _CalendarDow('Tue'),
              _CalendarDow('Wed'),
              _CalendarDow('Thu'),
              _CalendarDow('Fri'),
              _CalendarDow('Sat'),
              _CalendarDow('Sun'),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final inMonth = day.month == _focusedMonth.month;
              final dateKey = _formatDateKey(day);
              final isBooked = _bookedDays.contains(dateKey);
              final hasShift = _shiftSlotsForDate(day).isNotEmpty;
              final hasAvailability = _availableSlotsForDay(day).isNotEmpty;
              final isFullyBooked = isBooked && !hasAvailability;
              final isSelected = _selectedDate != null &&
                  inMonth &&
                  day.year == _selectedDate!.year &&
                  day.month == _selectedDate!.month &&
                  day.day == _selectedDate!.day;
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              final dayDate = DateTime(day.year, day.month, day.day);
              final isPast = dayDate.isBefore(todayDate);

              Color bgColor = Colors.white;
              Color borderColor = Colors.grey.shade300;
              Color textColor = inMonth ? Colors.black : Colors.grey.shade400;

              if (isPast) {
                bgColor = const Color(0xFFF3F3F3);
                borderColor = Colors.grey.shade300;
                textColor = Colors.grey.shade500;
              } else if (!hasShift) {
                bgColor = const Color(0xFFF3F3F3);
                borderColor = Colors.grey.shade300;
                textColor = Colors.grey.shade500;
              } else if (isFullyBooked) {
                bgColor = const Color(0xFFFFEFEF);
                borderColor = Colors.redAccent.withOpacity(0.6);
                textColor = Colors.redAccent;
              } else if (isSelected) {
                bgColor = primaryPink.withOpacity(0.12);
                borderColor = primaryPink;
                textColor = primaryPink;
              }

              return GestureDetector(
                onTap: () async {
                  if (!inMonth || isFullyBooked || !hasShift || isPast) return;
                  final monthChanged = day.month != _focusedMonth.month;
                  setState(() {
                    _selectedDate = day;
                    _selectedSlotStart = null;
                  });
                  if (monthChanged) {
                    await _loadAvailabilityForMonth(
                        DateTime(day.year, day.month));
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final List<DateTime> days = [];
    for (int i = 0; i < daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    final weekday = first.weekday; // 1 = Mon
    final leading = weekday - 1;
    for (int i = 0; i < leading; i++) {
      days.insert(0, first.subtract(Duration(days: leading - i)));
    }
    return days;
  }

  void _changeMonth(int delta) async {
    final newMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    setState(() {
      _focusedMonth = newMonth;
    });
    await _loadAvailabilityForMonth(newMonth);
  }

  Widget _buildTimeSlotsGrid() {
    if (_selectedDate == null) {
      return _SequenceNotice(
        message: 'Select a date to see available time slots.',
      );
    }

    final standardSlots = _standardSlotsForDay(_selectedDate!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available time slots',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (standardSlots.isEmpty)
          const Text(
            'No available time slots for this day.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: standardSlots.map((start) {
              final isBooked = _isBookedSlot(start);
              final selected = _selectedSlotStart != null &&
                  _selectedSlotStart!.isAtSameMomentAs(start);

              return GestureDetector(
                onTap: isBooked
                    ? null
                    : () {
                        setState(() {
                          _selectedSlotStart = start;
                        });
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isBooked
                        ? const Color(0xFFFFEFEF)
                        : selected
                            ? primaryPink.withOpacity(0.15)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isBooked
                          ? Colors.redAccent
                          : selected
                              ? primaryPink
                              : Colors.grey.shade300,
                      width: selected ? 1.4 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _formatTime(start),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isBooked
                          ? Colors.redAccent
                          : selected
                              ? primaryPink
                              : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextField(
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
    );
  }

  Widget _buildSummaryCard() {
    return Container(
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total'),
              Text(
                '\$${_totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
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
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
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
    );
  }
}

class _CalendarDow extends StatelessWidget {
  final String label;
  const _CalendarDow(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SequenceNotice extends StatelessWidget {
  final String message;

  const _SequenceNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: primaryPink, size: 20),
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
