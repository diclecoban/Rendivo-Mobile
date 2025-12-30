import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_snackbar.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../widgets/business_bottom_nav.dart';
import 'business_appointments_screen.dart';
import 'business_dashboard_screen.dart';
import 'business_services_screen.dart';
import 'business_staff_screen.dart';

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

  late DateTime _currentDate;
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  bool _isPendingApproval = false;

  List<ShiftItem> _shifts = [];
  List<StaffMember> _staff = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentDate = DateTime(now.year, now.month, 1);
    _isPendingApproval = widget.isPending ?? false;
    _checkApprovalAndFetchData();
  }

  Future<void> _checkApprovalAndFetchData() async {
    if (widget.isPending != null) {
      await _loadData();
      return;
    }

    try {
      final dashboard = await _backend.fetchBusinessDashboard();
      final business = dashboard['business'] as Map?;
      final status =
          business?['approvalStatus']?.toString().toLowerCase() ?? '';

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
    } catch (_) {
      // If approval check fails, still attempt to load schedule data.
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final startDate = _calendarStartDate(_currentDate);
    final endDate = startDate.add(const Duration(days: 41));

    try {
      final results = await Future.wait([
        _backend.fetchBusinessShifts(
          startDate: startDate,
          endDate: endDate,
        ),
        _backend.fetchShiftStaffMembers(),
      ]);
      setState(() {
        _shifts = results[0] as List<ShiftItem>;
        _staff = results[1] as List<StaffMember>;
      });
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to load schedule.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  DateTime _calendarStartDate(DateTime date) {
    final firstOfMonth = DateTime(date.year, date.month, 1);
    final daysToMonday = (firstOfMonth.weekday + 6) % 7;
    return firstOfMonth.subtract(Duration(days: daysToMonday));
  }

  List<_ScheduleDay> _getDaysInRange(DateTime currentDate) {
    final start = _calendarStartDate(currentDate);
    return List.generate(
      42,
      (index) => _ScheduleDay(
        date: start.add(Duration(days: index)),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compare = DateTime(date.year, date.month, date.day);
    return compare.isBefore(today);
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _readableDateLabel(DateTime date) {
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
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[(date.weekday - 1) % 7];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  List<ShiftItem> _getShiftsForDate(DateTime date) {
    final dateStr = _formatDate(date);
    return _shifts.where((shift) => shift.shiftDate == dateStr).toList();
  }

  String _staffName(StaffMember staffMember) {
    final name = staffMember.name.trim();
    return name.isNotEmpty ? name : staffMember.role;
  }

  String _shiftStaffName(ShiftItem shift) {
    return shift.staffName.isNotEmpty ? shift.staffName : 'Staff';
  }

  Widget _buildStaffLegend() {
    if (_staff.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: _staff.map((member) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _staffColor(member.id),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _staffName(member),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _staffColor(String staffId) {
    final colors = [
      const Color(0xFFFFE7EE),
      const Color(0xFF4B3F72),
      const Color(0xFF2F3E6E),
      const Color(0xFF2F5D50),
      const Color(0xFF3D3A5C),
      const Color(0xFF1F4F5A),
    ];
    final index = (int.tryParse(staffId) ?? staffId.hashCode).abs();
    return colors[index % colors.length];
  }

  Color _staffTextColor(String staffId) {
    final colors = [
      const Color(0xFFE91E63),
      const Color(0xFF5E35B1),
      const Color(0xFF3F51B5),
      const Color(0xFF2E7D32),
      const Color(0xFFF57C00),
      const Color(0xFF00796B),
    ];
    final index = (int.tryParse(staffId) ?? staffId.hashCode).abs();
    return colors[index % colors.length];
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() => _currentDate = DateTime(now.year, now.month, 1));
    _loadData();
  }

  void _goToPreviousWeek() {
    setState(
      () => _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month - 1,
        1,
      ),
    );
    _loadData();
  }

  void _goToNextWeek() {
    setState(
      () => _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month + 1,
        1,
      ),
    );
    _loadData();
  }

  Future<void> _showShiftDetails(ShiftItem shift) async {
    final parsedDate = DateTime.tryParse(shift.shiftDate);
    final dateLabel = parsedDate != null
        ? _readableDateLabel(parsedDate)
        : shift.shiftDate;
    final timeRange =
        '${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}';
    final isPastShift =
        parsedDate != null ? _isPastDate(parsedDate) : false;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: primaryPink.withOpacity(0.15),
                  child: Text(
                    shift.staffName.isNotEmpty
                        ? shift.staffName[0].toUpperCase()
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
                        shift.staffName.isNotEmpty
                            ? shift.staffName
                            : 'Staff Member',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Shift Time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              timeRange,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isPastShift
                    ? null
                    : () {
                        Navigator.pop(context);
                        _openShiftDialog(
                          selectedDate: parsedDate ?? DateTime.now(),
                          editingShift: shift,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Edit Shift',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openShiftDialog({
    DateTime? selectedDate,
    ShiftItem? editingShift,
  }) async {
    final isPending = _isPendingApproval;
    if (isPending) return;
    if (_staff.isEmpty) {
      _showSnack('Add staff members before scheduling shifts.');
      return;
    }
    if (selectedDate != null && _isPastDate(selectedDate)) return;

    final result = await showDialog<_ShiftDialogResult>(
      context: context,
      builder: (context) => _ShiftEditorDialog(
        staff: _staff,
        selectedDate: selectedDate ?? DateTime.now(),
        editingShift: editingShift,
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
    if (editingShift == null &&
        (result.applyToWeek || result.applyToMonth)) {
      final confirmed = await _confirmBulkSchedule(
        result.applyToMonth ? 'month' : 'week',
      );
      if (!confirmed) return;
    }
    setState(() => _submitting = true);
    try {
      if (editingShift != null) {
        final updated = await _backend.updateShift(
          shiftId: editingShift.id,
          staffId: result.staffId,
          shiftDate: result.date,
          startTime: result.startTime,
          endTime: result.endTime,
        );
        setState(() {
          _shifts = _shifts
              .map((shift) => shift.id == updated.id ? updated : shift)
              .toList();
        });
      } else {
        final dates = _expandDates(result);
        final newShifts = <ShiftItem>[];
        for (final date in dates) {
          final dateStr = _formatDate(date);
          final existing = _shifts.firstWhere(
            (shift) =>
                shift.shiftDate == dateStr &&
                shift.staffId == result.staffId,
            orElse: () => const ShiftItem(
              id: '',
              staffId: '',
              shiftDate: '',
              startTime: '',
              endTime: '',
              staffName: '',
            ),
          );
          if (existing.id.isNotEmpty) {
            final updated = await _backend.updateShift(
              shiftId: existing.id,
              staffId: result.staffId,
              shiftDate: date,
              startTime: result.startTime,
              endTime: result.endTime,
            );
            setState(() {
              _shifts = _shifts
                  .map((shift) => shift.id == updated.id ? updated : shift)
                  .toList();
            });
          } else {
            final created = await _backend.createShift(
              staffId: result.staffId,
              shiftDate: date,
              startTime: result.startTime,
              endTime: result.endTime,
            );
            newShifts.add(created);
          }
        }
        if (newShifts.isNotEmpty) {
          setState(() {
            _shifts = [..._shifts, ...newShifts];
          });
        }
      }
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to save shift.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirmBulkSchedule(String scope) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm bulk schedule'),
        content: Text(
          'This will apply the shift to the entire $scope (from today onward). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  List<DateTime> _expandDates(_ShiftDialogResult result) {
    final selected = result.date;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (result.applyToMonth) {
      final month = selected.month;
      final year = selected.year;
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final dates = <DateTime>[];
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        if (!date.isBefore(todayDate)) {
          dates.add(date);
        }
      }
      return dates;
    }

    if (result.applyToWeek) {
      final dayOfWeek = selected.weekday;
      final daysToMonday = dayOfWeek == 7 ? 6 : dayOfWeek - 1;
      final monday =
          DateTime(selected.year, selected.month, selected.day).subtract(
        Duration(days: daysToMonday),
      );
      final dates = <DateTime>[];
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        if (!date.isBefore(todayDate)) {
          dates.add(date);
        }
      }
      return dates;
    }

    return [selected];
  }

  Future<void> _deleteShift(ShiftItem shift) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _backend.deleteShift(shift.id);
      setState(() {
        _shifts = _shifts.where((item) => item.id != shift.id).toList();
      });
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to delete shift.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackbar.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _isPendingApproval;
    final days = _getDaysInRange(_currentDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Staff Schedule',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: isPending
                ? null
                : () => _openShiftDialog(selectedDate: DateTime.now()),
            icon: const Icon(Icons.add),
            tooltip: 'Add shift',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
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
                  : _buildContent(days),
        ),
      ),
      bottomNavigationBar: BusinessBottomNav(
        currentIndex: 3,
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

  Widget _buildContent(List<_ScheduleDay> days) {
    final monthNames = const [
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Staff Schedule',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _openShiftDialog(selectedDate: DateTime.now()),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Shift'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _goToPreviousWeek,
                    icon: const Icon(Icons.chevron_left),
                    splashRadius: 20,
                  ),
                  IconButton(
                    onPressed: _goToNextWeek,
                    icon: const Icon(Icons.chevron_right),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Text(
              '${monthNames[_currentDate.month - 1]} ${_currentDate.year}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: _goToToday,
              icon: const _TodayDot(),
              label: const Text('Today'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStaffLegend(),
        if (_staff.isNotEmpty) const SizedBox(height: 12),
        if (_staff.isEmpty)
          const Text(
            'No staff members available.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        const SizedBox(height: 12),
        _CalendarGrid(
          days: days,
          isToday: _isToday,
          isPastDate: _isPastDate,
          shiftsForDate: _getShiftsForDate,
          onDayTap: (date) {
            if (_isPastDate(date)) return;
            _openShiftDialog(selectedDate: date);
          },
          onShiftTap: (shift) {
            _showShiftDetails(shift);
          },
          staffColor: _staffColor,
          staffTextColor: _staffTextColor,
          staffName: _shiftStaffName,
        ),
      ],
    );
  }
}

class _ScheduleDay {
  final DateTime date;

  const _ScheduleDay({
    required this.date,
  });
}

enum _ShiftDialogAction { save, delete }

class _ShiftDialogResult {
  final _ShiftDialogAction action;
  final DateTime date;
  final String staffId;
  final String startTime;
  final String endTime;
  final bool applyToWeek;
  final bool applyToMonth;

  const _ShiftDialogResult({
    required this.action,
    required this.date,
    required this.staffId,
    required this.startTime,
    required this.endTime,
    required this.applyToWeek,
    required this.applyToMonth,
  });
}

class _ShiftEditorDialog extends StatefulWidget {
  final List<StaffMember> staff;
  final DateTime selectedDate;
  final ShiftItem? editingShift;

  const _ShiftEditorDialog({
    required this.staff,
    required this.selectedDate,
    required this.editingShift,
  });

  @override
  State<_ShiftEditorDialog> createState() => _ShiftEditorDialogState();
}

class _ShiftEditorDialogState extends State<_ShiftEditorDialog> {
  late DateTime _selectedDate;
  StaffMember? _selectedStaff;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  bool _applyToWeek = false;
  bool _applyToMonth = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    if (widget.editingShift != null) {
      final staffMatch = widget.staff
          .where((member) => member.id == widget.editingShift!.staffId)
          .toList();
      _selectedStaff = staffMatch.isNotEmpty ? staffMatch.first : null;
      _startTime = _parseTime(widget.editingShift!.startTime);
      _endTime = _parseTime(widget.editingShift!.endTime);
    } else if (widget.staff.isNotEmpty) {
      _selectedStaff = widget.staff.first;
    }
    _startController = TextEditingController(
      text: _startTime != null ? _formatTime(_startTime) : '',
    );
    _endController = TextEditingController(
      text: _endTime != null ? _formatTime(_endTime) : '',
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String value) {
    if (value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    return _parseHourMinute(parts[0], parts[1]);
  }

  TimeOfDay? _parseTimeInput(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length < 2) return null;
      return _parseHourMinute(parts[0], parts[1]);
    }
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 4) {
      return _parseHourMinute(digits.substring(0, 2), digits.substring(2, 4));
    }
    return null;
  }

  TimeOfDay? _parseHourMinute(String hour, String minute) {
    final h = int.tryParse(hour);
    final m = int.tryParse(minute);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
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
    if (_selectedStaff == null || _startTime == null || _endTime == null) {
      return false;
    }
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    return endMinutes > startMinutes;
  }

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

  void _handleStartTimeChange(String value) {
    setState(() {
      _startTime = _parseTimeInput(value);
    });
  }

  void _handleEndTimeChange(String value) {
    setState(() {
      _endTime = _parseTimeInput(value);
    });
  }

  void _normalizeTimeController(TextEditingController controller, TimeOfDay? time) {
    if (time == null) return;
    controller.text = _formatTime(time);
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
  }

  void _setStartTime(TimeOfDay time) {
    setState(() {
      _startTime = time;
      _startController.text = _formatTime(time);
      _startController.selection =
          TextSelection.collapsed(offset: _startController.text.length);
    });
  }

  void _setEndTime(TimeOfDay time) {
    setState(() {
      _endTime = time;
      _endController.text = _formatTime(time);
      _endController.selection =
          TextSelection.collapsed(offset: _endController.text.length);
    });
  }

  Future<void> _openTimePickerSheet({required bool isStart}) async {
    final current = isStart ? _startTime : _endTime;
    final initialHour = current?.hour ?? 9;
    final initialMinute = current?.minute ?? 0;
    final hourController =
        FixedExtentScrollController(initialItem: initialHour);
    final minuteController =
        FixedExtentScrollController(initialItem: initialMinute);

    var result = TimeOfDay(hour: initialHour, minute: initialMinute);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isStart ? 'Select start time' : 'Select end time',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: hourController,
                        itemExtent: 36,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          result = TimeOfDay(
                            hour: index,
                            minute: minuteController.selectedItem,
                          );
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 24,
                          builder: (context, index) {
                            return Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const Text(
                      ':',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: minuteController,
                        itemExtent: 36,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          result = TimeOfDay(
                            hour: hourController.selectedItem,
                            minute: index,
                          );
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 60,
                          builder: (context, index) {
                            return Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (isStart) {
      _setStartTime(result);
    } else {
      _setEndTime(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingShift != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Shift' : 'Add New Shift',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDate(_selectedDate),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Icon(Icons.calendar_month,
                              size: 18, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Staff Member',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<StaffMember>(
                    value: _selectedStaff,
                    items: widget.staff
                        .map(
                          (member) => DropdownMenuItem(
                            value: member,
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name
                                  : member.role,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedStaff = value),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'Start Time',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'End Time',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _startController,
                          keyboardType: TextInputType.datetime,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _TimeInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            hintText: 'HH:MM',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.expand_less,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () => _openTimePickerSheet(isStart: true),
                            ),
                          ),
                          onChanged: _handleStartTimeChange,
                          onEditingComplete: () => _normalizeTimeController(
                            _startController,
                            _startTime,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _endController,
                          keyboardType: TextInputType.datetime,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _TimeInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            hintText: 'HH:MM',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.expand_less,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () => _openTimePickerSheet(isStart: false),
                            ),
                          ),
                          onChanged: _handleEndTimeChange,
                          onEditingComplete: () => _normalizeTimeController(
                            _endController,
                            _endTime,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter time as HH:MM (e.g. 09:30).',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F8FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _BulkOptionRow(
                            label: 'Schedule for this week',
                            value: _applyToWeek,
                            onChanged: (value) {
                              setState(() {
                                _applyToWeek = value;
                                if (_applyToWeek) _applyToMonth = false;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _BulkOptionRow(
                            label: 'Schedule for this month',
                            value: _applyToMonth,
                            onChanged: (value) {
                              setState(() {
                                _applyToMonth = value;
                                if (_applyToMonth) _applyToWeek = false;
                              });
                            },
                          ),
                          if (_applyToWeek || _applyToMonth) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8DB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _applyToMonth
                                          ? 'This shift will be added for the entire month (from today onwards)'
                                          : 'This shift will be added for the entire week (from today onwards)',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_canSave
                        ? null
                        : () {
                            final staff = _selectedStaff;
                            final start = _formatTime(_startTime);
                            final end = _formatTime(_endTime);
                            if (staff == null ||
                                start == '--:--' ||
                                end == '--:--') {
                              return;
                            }
                            Navigator.pop(
                              context,
                              _ShiftDialogResult(
                                action: _ShiftDialogAction.save,
                                date: _selectedDate,
                                staffId: staff.id,
                                startTime: '$start:00',
                                endTime: '$end:00',
                                applyToWeek: _applyToWeek,
                                applyToMonth: _applyToMonth,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(isEditing ? 'Save Changes' : 'Add Shift'),
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

class _BulkOptionRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BulkOptionRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (checked) => onChanged(checked ?? false),
              activeColor: primaryPink,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.calendar_month, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final List<_ScheduleDay> days;
  final bool Function(DateTime date) isToday;
  final bool Function(DateTime date) isPastDate;
  final List<ShiftItem> Function(DateTime date) shiftsForDate;
  final void Function(DateTime date) onDayTap;
  final void Function(ShiftItem shift) onShiftTap;
  final Color Function(String staffId) staffColor;
  final Color Function(String staffId) staffTextColor;
  final String Function(ShiftItem shift) staffName;

  const _CalendarGrid({
    required this.days,
    required this.isToday,
    required this.isPastDate,
    required this.shiftsForDate,
    required this.onDayTap,
    required this.onShiftTap,
    required this.staffColor,
    required this.staffTextColor,
    required this.staffName,
  });

  List<String> _uniqueStaffIds(List<ShiftItem> shifts) {
    final seen = <String>{};
    final result = <String>[];
    for (final shift in shifts) {
      if (seen.add(shift.staffId)) {
        result.add(shift.staffId);
      }
    }
    return result;
  }

  Widget _buildShiftBackground(List<String> staffIds) {
    final colors = staffIds.map(staffColor).toList();
    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }
    if (colors.length == 1) {
      return Container(color: colors.first);
    }
    if (colors.length == 2) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final half = (constraints.maxWidth / 2).floorToDouble();
          final remainder = constraints.maxWidth - half;
          return Row(
            children: [
              SizedBox(width: half, child: Container(color: colors[0])),
              SizedBox(width: remainder, child: Container(color: colors[1])),
            ],
          );
        },
      );
    }
    if (colors.length == 3) {
      return Column(
        children: [
          Expanded(child: Container(color: colors[0])),
          Expanded(child: Container(color: colors[1])),
          Expanded(child: Container(color: colors[2])),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: Container(color: colors[0])),
              Expanded(child: Container(color: colors[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: Container(color: colors[2])),
              Expanded(child: Container(color: colors[3])),
            ],
          ),
        ),
      ],
    );
  }

  String _staffIdForTap(
    Offset position,
    Size size,
    List<String> staffIds,
  ) {
    if (staffIds.isEmpty) return '';
    if (staffIds.length == 1) return staffIds.first;
    if (staffIds.length == 2) {
      return position.dx < size.width / 2
          ? staffIds[0]
          : staffIds[1];
    }
    if (staffIds.length == 3) {
      final third = size.height / 3;
      if (position.dy < third) return staffIds[0];
      if (position.dy < third * 2) return staffIds[1];
      return staffIds[2];
    }
    final isLeft = position.dx < size.width / 2;
    final isTop = position.dy < size.height / 2;
    if (isTop && isLeft) return staffIds[0];
    if (isTop && !isLeft) return staffIds[1];
    if (!isTop && isLeft) return staffIds[2];
    return staffIds[3];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            _DayHeader('MON'),
            _DayHeader('TUE'),
            _DayHeader('WED'),
            _DayHeader('THU'),
            _DayHeader('FRI'),
            _DayHeader('SAT'),
            _DayHeader('SUN'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final dayShifts = shiftsForDate(day.date);
            final isTodayDate = isToday(day.date);
            final isPast = isPastDate(day.date);
            final hasShift = dayShifts.isNotEmpty;
            final staffIds = hasShift ? _uniqueStaffIds(dayShifts) : <String>[];
            final shiftTextColor =
                hasShift ? staffTextColor(staffIds.first) : null;

            return Builder(
              builder: (cellContext) {
                return InkWell(
                  onTapDown: (details) {
                    if (isPast) return;
                    if (!hasShift) return;
                    final box =
                        cellContext.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final size = box.size;
                    final tappedStaffId =
                        _staffIdForTap(details.localPosition, size, staffIds);
                    final shift = dayShifts.firstWhere(
                      (item) => item.staffId == tappedStaffId,
                      orElse: () => dayShifts.first,
                    );
                    onShiftTap(shift);
                  },
                  onTap: isPast || hasShift ? null : () => onDayTap(day.date),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: hasShift
                          ? Colors.transparent
                          : isPast
                              ? const Color(0xFFF3F3F3)
                              : isTodayDate
                                  ? const Color(0xFFFFF1F3)
                                  : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isTodayDate
                            ? const Color(0xFFFFC1D3)
                            : const Color(0xFFE8E8EE),
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (hasShift)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildShiftBackground(staffIds),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day.date.day.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: hasShift
                                      ? shiftTextColor
                                      : isPast
                                          ? Colors.grey.shade500
                                          : isTodayDate
                                              ? primaryPink
                                              : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Expanded(
                                child: SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final clipped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < clipped.length; i++) {
      if (i == 2) buffer.write(':');
      buffer.write(clipped[i]);
    }
    final text = buffer.toString();
    final selectionIndex = text.length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

class _TodayDot extends StatelessWidget {
  const _TodayDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: primaryPink,
        shape: BoxShape.circle,
      ),
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
