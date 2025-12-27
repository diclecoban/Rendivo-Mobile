import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';

class BusinessScheduleDayScreen extends StatefulWidget {
  final DateTime date;
  final bool? isPending;
  final ShiftItem? initialEditShift;

  const BusinessScheduleDayScreen({
    super.key,
    required this.date,
    this.isPending,
    this.initialEditShift,
  });

  @override
  State<BusinessScheduleDayScreen> createState() =>
      _BusinessScheduleDayScreenState();
}

class _BusinessScheduleDayScreenState extends State<BusinessScheduleDayScreen> {
  final _backend = BackendService.instance;

  bool _loading = false;
  bool _submitting = false;
  String? _error;
  bool _changed = false;

  List<ShiftItem> _shifts = [];
  List<StaffMember> _staff = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _backend.fetchBusinessShifts(
          startDate: widget.date,
          endDate: widget.date,
        ),
        _backend.fetchShiftStaffMembers(),
      ]);
      setState(() {
        _shifts = results[0] as List<ShiftItem>;
        _staff = results[1] as List<StaffMember>;
      });
      if (widget.initialEditShift != null) {
        final initial = widget.initialEditShift!;
        final initialDate = DateTime.tryParse(initial.shiftDate);
        if (initialDate != null && !_isPastDate(initialDate)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openShiftDialog(editingShift: initial);
            }
          });
        }
      }
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to load schedule.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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

  String _formatDateLabel(DateTime date) {
    const monthNames = [
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
    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _staffName(StaffMember staffMember) {
    final name = staffMember.name.trim();
    return name.isNotEmpty ? name : staffMember.role;
  }

  String _shiftStaffName(ShiftItem shift) {
    return shift.staffName.isNotEmpty ? shift.staffName : 'Staff';
  }

  Color _staffColor(String staffId) {
    final colors = [
      const Color(0xFFFFE7EE),
      const Color(0xFFEDE7FF),
      const Color(0xFFE8F0FF),
      const Color(0xFFE6F7F0),
      const Color(0xFFFFF1E0),
      const Color(0xFFE6F4F8),
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

  Future<void> _openShiftDialog({
    ShiftItem? editingShift,
  }) async {
    final isPending = widget.isPending ?? false;
    if (isPending) return;
    if (_staff.isEmpty) {
      _showSnack('Add staff members before scheduling shifts.');
      return;
    }
    if (_isPastDate(widget.date)) return;

    final result = await showDialog<_ShiftDialogResult>(
      context: context,
      builder: (context) => _ShiftEditorDialog(
        staff: _staff,
        selectedDate: widget.date,
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
            if (_formatDate(date) == _formatDate(widget.date)) {
              newShifts.add(created);
            }
          }
        }
        if (newShifts.isNotEmpty) {
          setState(() {
            _shifts = [..._shifts, ...newShifts];
          });
        }
      }
      _changed = true;
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (_) {
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
      _changed = true;
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Failed to delete shift.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.isPending ?? false;
    final isPast = _isPastDate(widget.date);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text(
            'Staff Schedule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          actions: [
            IconButton(
              onPressed:
                  isPending || isPast ? null : () => _openShiftDialog(),
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
                    : _buildContent(isPast),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isPast) {
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
              children: [
                const Text(
                  'Staff Schedule',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shifts for ${_formatDateLabel(widget.date)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: isPast ? null : () => _openShiftDialog(),
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: primaryPink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatDateLabel(widget.date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isPast)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Past',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_staff.isEmpty)
          const Text(
            'No staff members available.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        if (_shifts.isEmpty) ...[
          const SizedBox(height: 24),
          Center(
            child: Text(
              isPast
                  ? 'No shifts were scheduled for this day.'
                  : 'No shifts yet. Add one to get started.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ] else ...[
          const SizedBox(height: 4),
          ..._shifts.map(
            (shift) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                onTap: isPast ? null : () => _openShiftDialog(editingShift: shift),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _staffColor(shift.staffId),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 16,
                          color: _staffTextColor(shift.staffId),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _shiftStaffName(shift),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isPast)
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
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
  }

  TimeOfDay? _parseTime(String value) {
    if (value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
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
    final isEditing = widget.editingShift != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        child: InkWell(
                          onTap: _pickStartTime,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: InputDecoration(
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
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatTime(_startTime),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Icon(Icons.access_time,
                                    size: 16, color: Colors.grey.shade600),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickEndTime,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: InputDecoration(
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
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatTime(_endTime),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Icon(Icons.access_time,
                                    size: 16, color: Colors.grey.shade600),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
