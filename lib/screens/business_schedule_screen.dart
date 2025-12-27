import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../widgets/business_bottom_nav.dart';
import 'business_dashboard_screen.dart';

class BusinessScheduleScreen extends StatefulWidget {
  final bool? isPending;

  const BusinessScheduleScreen({
    super.key,
    this.isPending,
  });

  @override
  State<BusinessScheduleScreen> createState() =>
      _BusinessScheduleScreenState();
}

class _BusinessScheduleScreenState extends State<BusinessScheduleScreen> {
  final _backend = BackendService.instance;

  DateTime? _baseMonth;
  PageController? _pageController;
  DateTime? _currentMonth;
  int? _pageIndex;
  List<ShiftItem> _shifts = [];
  List<StaffMember> _staff = [];
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ensurePaging();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _ensurePaging() {
    if (_pageController != null) return;
    final now = DateTime.now();
    _baseMonth = DateTime(now.year, now.month, 1);
    _pageIndex = 1200;
    _pageController = PageController(initialPage: _pageIndex!);
    _currentMonth = _monthForPage(_pageIndex!);
    _loadDataForMonth(_currentMonth!);
  }

  DateTime _monthForPage(int page) {
    final baseMonth = _baseMonth ?? DateTime.now();
    final baseIndex = _pageIndex ?? 1200;
    final delta = page - baseIndex;
    return DateTime(baseMonth.year, baseMonth.month + delta, 1);
  }

  int _pageForMonth(DateTime month) {
    final baseMonth = _baseMonth ?? DateTime.now();
    final baseIndex = _pageIndex ?? 1200;
    final deltaMonths = (month.year - baseMonth.year) * 12 +
        (month.month - baseMonth.month);
    return baseIndex + deltaMonths;
  }

  Future<void> _loadDataForMonth(DateTime month) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final startDate = _gridStartForMonth(month);
    final endDate = startDate.add(const Duration(days: 41));

    try {
      final results = await Future.wait([
        _backend.fetchBusinessShifts(startDate: startDate, endDate: endDate),
        _backend.fetchShiftStaffMembers(),
      ]);
      setState(() {
        _shifts = results[0] as List<ShiftItem>;
        _staff = results[1] as List<StaffMember>;
      });
    } on AppException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load schedule.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  DateTime _gridStartForMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final offset = firstDay.weekday - DateTime.monday;
    return firstDay.subtract(Duration(days: offset));
  }

  List<DateTime> _getDays(DateTime month) {
    final start = _gridStartForMonth(month);
    return List.generate(
      42,
      (index) => start.add(Duration(days: index)),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatMonth(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  List<ShiftItem> _getShiftsForDate(DateTime date) {
    final dateStr = _formatDate(date);
    return _shifts.where((shift) => shift.shiftDate == dateStr).toList();
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return today.year == date.year &&
        today.month == date.month &&
        today.day == date.day;
  }

  Future<void> _openShiftDialog({
    DateTime? selectedDate,
    ShiftItem? editingShift,
  }) async {
    if (_staff.isEmpty) {
      _showSnack('Add a staff member before scheduling shifts.');
      return;
    }
    final initialDate = selectedDate ??
        (editingShift != null
            ? DateTime.tryParse(editingShift.shiftDate) ?? DateTime.now()
            : DateTime.now());
    final result = await showDialog<_ShiftDialogResult>(
      context: context,
      builder: (context) => _ShiftEditorDialog(
        staff: _staff,
        initialDate: initialDate,
        initialStaffId: editingShift?.staffId,
        initialStart: editingShift?.startTime,
        initialEnd: editingShift?.endTime,
        allowDelete: editingShift != null,
      ),
    );

    if (result == null) return;

    if (result.action == _ShiftDialogAction.delete && editingShift != null) {
      await _deleteShift(editingShift);
      return;
    }

    if (result.action == _ShiftDialogAction.save) {
      await _saveShift(result, editingShift: editingShift);
    }
  }

  Future<void> _saveShift(
    _ShiftDialogResult result, {
    ShiftItem? editingShift,
  }) async {
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final startTime = _formatTimeOfDay(result.startTime);
      final endTime = _formatTimeOfDay(result.endTime);

      if (editingShift == null) {
        final created = await _backend.createShift(
          staffId: result.staffId,
          shiftDate: result.date,
          startTime: startTime,
          endTime: endTime,
        );
        setState(() {
          _shifts = [..._shifts, created];
        });
      } else {
        final updated = await _backend.updateShift(
          shiftId: editingShift.id,
          staffId: result.staffId,
          shiftDate: result.date,
          startTime: startTime,
          endTime: endTime,
        );
        setState(() {
          _shifts = _shifts
              .map((shift) => shift.id == updated.id ? updated : shift)
              .toList();
        });
      }
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to save shift.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _deleteShift(ShiftItem shift) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _backend.deleteShift(shift.id);
      setState(() {
        _shifts = _shifts.where((s) => s.id != shift.id).toList();
      });
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to delete shift.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Color _shiftBackground(String staffId) {
    final colors = [
      const Color(0xFFFFE7EE),
      const Color(0xFFE8F0FF),
      const Color(0xFFE6F7F0),
      const Color(0xFFFFF1E0),
      const Color(0xFFEDE7FF),
      const Color(0xFFE6F4F8),
    ];
    final index = (int.tryParse(staffId) ?? staffId.hashCode).abs();
    return colors[index % colors.length];
  }

  Color _shiftTextColor(String staffId) {
    final colors = [
      const Color(0xFFE91E63),
      const Color(0xFF3F51B5),
      const Color(0xFF2E7D32),
      const Color(0xFFF57C00),
      const Color(0xFF5E35B1),
      const Color(0xFF00796B),
    ];
    final index = (int.tryParse(staffId) ?? staffId.hashCode).abs();
    return colors[index % colors.length];
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensurePaging();
    final currentMonth = _currentMonth ?? DateTime.now();
    final isPending = widget.isPending ?? false;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Staff Schedule',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isPending || _staff.isEmpty || _loading
                ? null
                : () => _openShiftDialog(selectedDate: DateTime.now()),
            icon: const Icon(Icons.add),
            tooltip: 'Add shift',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadDataForMonth(currentMonth),
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
        currentIndex: 3,
        isPending: isPending,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const BusinessDashboardScreen(),
              ),
            );
          } else if (index == 1 || index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon.')),
            );
          }
        },
      ),
    );
  }

  Widget _buildContent() {
    final currentMonth = _currentMonth ?? DateTime.now();
    final pageController = _pageController;
    if (pageController == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatMonth(currentMonth),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Assign and manage staff shifts.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: () {
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final now = DateTime.now();
                      final target =
                          _pageForMonth(DateTime(now.year, now.month, 1));
                      pageController.animateToPage(
                        target,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Today'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_staff.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No staff members available.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: PageView.builder(
            controller: pageController,
            onPageChanged: (page) {
              final month = _monthForPage(page);
              setState(() {
                _currentMonth = month;
              });
              _loadDataForMonth(month);
            },
            itemBuilder: (context, index) {
              final month = _monthForPage(index);
              final days = _getDays(month);
              return _CalendarPage(
                days: days,
                isToday: _isToday,
                shiftsForDate: _getShiftsForDate,
                onDayTap: (date) => _openShiftDialog(selectedDate: date),
                onShiftTap: (shift) =>
                    _openShiftDialog(editingShift: shift),
                shiftBackground: _shiftBackground,
                shiftTextColor: _shiftTextColor,
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _ShiftDialogAction { save, delete }

class _ShiftDialogResult {
  final _ShiftDialogAction action;
  final DateTime date;
  final String staffId;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const _ShiftDialogResult({
    required this.action,
    required this.date,
    required this.staffId,
    required this.startTime,
    required this.endTime,
  });
}

class _ShiftEditorDialog extends StatefulWidget {
  final List<StaffMember> staff;
  final DateTime initialDate;
  final String? initialStaffId;
  final String? initialStart;
  final String? initialEnd;
  final bool allowDelete;

  const _ShiftEditorDialog({
    required this.staff,
    required this.initialDate,
    required this.initialStaffId,
    required this.initialStart,
    required this.initialEnd,
    required this.allowDelete,
  });

  @override
  State<_ShiftEditorDialog> createState() => _ShiftEditorDialogState();
}

class _ShiftEditorDialogState extends State<_ShiftEditorDialog> {
  late DateTime _date;
  StaffMember? _selectedStaff;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    if (widget.initialStaffId != null) {
      final matches = widget.staff
          .where((member) => member.id == widget.initialStaffId)
          .toList();
      if (matches.isNotEmpty) {
        _selectedStaff = matches.first;
      } else if (widget.staff.isNotEmpty) {
        _selectedStaff = widget.staff.first;
      }
    }
    if (_selectedStaff == null && widget.staff.isNotEmpty) {
      _selectedStaff = widget.staff.first;
    }
    _startTime = _parseTime(widget.initialStart);
    _endTime = _parseTime(widget.initialEnd);
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool get _canSave {
    if (_selectedStaff == null ||
        _selectedStaff!.id.isEmpty ||
        _startTime == null ||
        _endTime == null) {
      return false;
    }
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    return endMinutes > startMinutes;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffItems = widget.staff
        .where((member) => member.id.isNotEmpty)
        .toList();

    return AlertDialog(
      title: Text(widget.allowDelete ? 'Edit Shift' : 'Add Shift'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(_formatDate(_date)),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Change'),
              ),
            ),
            DropdownButtonFormField<StaffMember>(
              value: _selectedStaff,
              items: staffItems
                  .map(
                    (member) => DropdownMenuItem(
                      value: member,
                      child: Text(member.name.isNotEmpty ? member.name : member.role),
                    ),
                  )
                  .toList(),
              onChanged: staffItems.isEmpty
                  ? null
                  : (value) => setState(() => _selectedStaff = value),
              decoration: const InputDecoration(
                labelText: 'Staff member',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickStartTime,
                    child: Text('Start ${_formatTime(_startTime)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickEndTime,
                    child: Text('End ${_formatTime(_endTime)}'),
                  ),
                ),
              ],
            ),
            if (_startTime != null &&
                _endTime != null &&
                !_canSave)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'End time must be after start time.',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.allowDelete)
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                _ShiftDialogResult(
                  action: _ShiftDialogAction.delete,
                  date: _date,
                  staffId: _selectedStaff?.id ?? '',
                  startTime: _startTime ?? TimeOfDay.now(),
                  endTime: _endTime ?? TimeOfDay.now(),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: !_canSave
              ? null
              : () {
                  final staff = _selectedStaff;
                  final start = _startTime;
                  final end = _endTime;
                  if (staff == null || start == null || end == null) {
                    return;
                  }
                  Navigator.pop(
                    context,
                    _ShiftDialogResult(
                      action: _ShiftDialogAction.save,
                      date: _date,
                      staffId: staff.id,
                      startTime: start,
                      endTime: end,
                    ),
                  );
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

String _shortTime(String value) {
  if (value.length >= 5) {
    return value.substring(0, 5);
  }
  return value;
}

class _CalendarPage extends StatelessWidget {
  final List<DateTime> days;
  final bool Function(DateTime date) isToday;
  final List<ShiftItem> Function(DateTime date) shiftsForDate;
  final void Function(DateTime date) onDayTap;
  final void Function(ShiftItem shift) onShiftTap;
  final Color Function(String staffId) shiftBackground;
  final Color Function(String staffId) shiftTextColor;

  const _CalendarPage({
    required this.days,
    required this.isToday,
    required this.shiftsForDate,
    required this.onDayTap,
    required this.onShiftTap,
    required this.shiftBackground,
    required this.shiftTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _DayHeader('MON'),
                _DayHeader('TUE'),
                _DayHeader('WED'),
                _DayHeader('THU'),
                _DayHeader('FRI'),
                _DayHeader('SAT'),
                _DayHeader('SUN'),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 135,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final date = days[index];
                final shifts = shiftsForDate(date);
                final highlight = isToday(date);

                return InkWell(
                  onTap: () => onDayTap(date),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: highlight
                          ? const Color(0xFFFFF1F3)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: highlight
                            ? const Color(0xFFFFC1D3)
                            : const Color(0xFFE8E8EE),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: highlight ? primaryPink : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...shifts.map(
                          (shift) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: GestureDetector(
                              onTap: () => onShiftTap(shift),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: shiftBackground(shift.staffId),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shift.staffName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: shiftTextColor(shift.staffId),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_shortTime(shift.startTime)} - ${_shortTime(shift.endTime)}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: shiftTextColor(shift.staffId),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: days.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;

  const _DayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }
}
