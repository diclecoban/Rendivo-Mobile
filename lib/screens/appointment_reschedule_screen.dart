import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';

class AppointmentRescheduleScreen extends StatefulWidget {
  final Appointment appointment;

  const AppointmentRescheduleScreen({
    super.key,
    required this.appointment,
  });

  @override
  State<AppointmentRescheduleScreen> createState() =>
      _AppointmentRescheduleScreenState();
}

class _AppointmentRescheduleScreenState
    extends State<AppointmentRescheduleScreen> {
  final _backend = BackendService.instance;

  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, List<AvailabilitySlot>> _bookedSlotsByDate = {};
  Map<String, List<AvailabilitySlot>> _shiftSlotsByDate = {};
  DateTime? _selectedSlotStart;
  bool _loading = false;
  String? _error;

  int get _durationMinutes =>
      widget.appointment.totalDurationMinutes > 0
          ? widget.appointment.totalDurationMinutes
          : 30;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.appointment.startAt;
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _loadAvailabilityForMonth(_focusedMonth);
  }

  Future<void> _loadAvailabilityForMonth(DateTime month) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedSlotStart = null;
    });

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    try {
      final availability = await _backend.fetchBusinessAvailability(
        businessId: widget.appointment.businessId,
        startDate: start,
        endDate: end,
      );
      final bookedMap = <String, List<AvailabilitySlot>>{};
      for (final slot in availability.bookedSlots) {
        final key = _formatDateKey(slot.startAt);
        bookedMap.putIfAbsent(key, () => []).add(slot);
      }
      final shiftMap = <String, List<AvailabilitySlot>>{};
      for (final slot in availability.shiftSlots) {
        final key = _formatDateKey(slot.startAt);
        shiftMap.putIfAbsent(key, () => []).add(slot);
      }
      setState(() {
        _bookedSlotsByDate = bookedMap;
        _shiftSlotsByDate = shiftMap;
        _focusedMonth = month;
        final avail = _availableSlotsForDay(_selectedDate);
        _selectedSlotStart = avail.isNotEmpty ? avail.first : null;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load availability.';
        _loading = false;
      });
    }
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

    final stepMinutes = _durationMinutes;
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
        final slotEnd = cursor.add(Duration(minutes: _durationMinutes));
        if (!slotEnd.isAfter(limit)) {
          slots.add(cursor);
        }
        cursor = cursor.add(Duration(minutes: stepMinutes));
      }
    }
    return slots;
  }

  bool _isBookedSlot(DateTime start) {
    final end = start.add(Duration(minutes: _durationMinutes));
    return _bookedSlotsForDate(start).any((slot) {
      final s = slot.startAt.toLocal();
      final e = slot.endAt.toLocal();
      return start.isBefore(e) && end.isAfter(s);
    });
  }

  List<DateTime> _availableSlotsForDay(DateTime date) {
    return _standardSlotsForDay(date)
        .where((slot) => !_isBookedSlot(slot))
        .toList();
  }

  void _changeMonth(int delta) async {
    final newMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    setState(() {
      _focusedMonth = newMonth;
    });
    await _loadAvailabilityForMonth(newMonth);
  }

  void _confirmReschedule() {
    final start = _selectedSlotStart;
    if (start == null) return;
    final end = start.add(Duration(minutes: _durationMinutes));
    Navigator.pop(context, {'startAt': start, 'endAt': end});
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final List<DateTime> days = [];
    for (int i = 0; i < daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    final weekday = first.weekday;
    final leading = weekday - 1;
    for (int i = 0; i < leading; i++) {
      days.insert(0, first.subtract(Duration(days: leading - i)));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reschedule Appointment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Pick a new time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildCalendarCard(monthLabel),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _loadAvailabilityForMonth(_focusedMonth),
                    child: const Text('Retry'),
                  ),
                ],
              )
            else
              _buildTimeSlotsGrid(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedSlotStart == null
                    ? null
                    : _confirmReschedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Confirm Reschedule',
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
    );
  }

  Widget _buildCalendarCard(String monthLabel) {
    final days = _daysInMonth(_focusedMonth);
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
              final hasShift = _shiftSlotsForDate(day).isNotEmpty;
              final isSelected = day.year == _selectedDate.year &&
                  day.month == _selectedDate.month &&
                  day.day == _selectedDate.day;
              final hasAvailability = _availableSlotsForDay(day).isNotEmpty;
              final isFullyBooked = hasShift && !hasAvailability;
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
                  if (!inMonth || !hasShift || isFullyBooked || isPast) return;
                  setState(() {
                    _selectedDate = day;
                    final avail = _availableSlotsForDay(day);
                    _selectedSlotStart = avail.isNotEmpty ? avail.first : null;
                  });
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

  Widget _buildTimeSlotsGrid() {
    final slots = _availableSlotsForDay(_selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available time slots',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          const Text(
            'No available time slots for this day.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((start) {
              final selected = _selectedSlotStart != null &&
                  _selectedSlotStart!.isAtSameMomentAs(start);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSlotStart = start;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? primaryPink.withOpacity(0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? primaryPink : Colors.grey.shade300,
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
                      color: selected ? primaryPink : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
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
