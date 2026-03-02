import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class ScheduleSelectionModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onScheduleSelected;

  const ScheduleSelectionModal({super.key, required this.onScheduleSelected});

  @override
  State<ScheduleSelectionModal> createState() => _ScheduleSelectionModalState();
}

class _ScheduleSelectionModalState extends State<ScheduleSelectionModal> {
  bool _useSpecificDate = true;
  TimeOfDay? _selectedTime;
  List<DateTime> _selectedDates = [];
  final List<String> _weekDays = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];
  final List<bool> _selectedDays = List.filled(7, false);

  // Light blue color scheme
  final Color _primaryColor = const Color(0xFF64B5F6); // Light Blue 300
  final Color _secondaryColor = const Color(0xFF2196F3); // Blue 500
  final Color _lightColor = const Color(0xFFBBDEFB); // Light Blue 100

  void _showDatePicker() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Select Dates',
              style: TextStyle(color: _secondaryColor),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SfDateRangePicker(
                selectionMode: DateRangePickerSelectionMode.multiple,
                initialSelectedDates: _selectedDates,
                selectionColor: _primaryColor,
                todayHighlightColor: _secondaryColor,
                onSelectionChanged: (args) {
                  setState(() => _selectedDates = args.value as List<DateTime>);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: _secondaryColor),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _submitSelection() {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a time'),
          backgroundColor: _secondaryColor,
        ),
      );
      return;
    }

    if (_useSpecificDate && _selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one date'),
          backgroundColor: _secondaryColor,
        ),
      );
      return;
    }

    if (!_useSpecificDate && !_selectedDays.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one day'),
          backgroundColor: _secondaryColor,
        ),
      );
      return;
    }

    final schedule =
        _useSpecificDate
            ? {
              'type': 'dates',
              'dates': _selectedDates,
              'time': _selectedTime!.format(context),
            }
            : {
              'type': 'weekly',
              'days':
                  List.generate(
                    7,
                    (index) => index,
                  ).where((i) => _selectedDays[i]).toList(),
              'time': _selectedTime!.format(context),
            };

    widget.onScheduleSelected(schedule);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle for bottom sheet
            Container(
              height: 5,
              width: 40,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Text(
              'Schedule Announcement',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: black, fontSize: 18),
            ),
            const SizedBox(height: 28),

            // Toggle between date/day selection
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useSpecificDate = true),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              _useSpecificDate
                                  ? _primaryColor
                                  : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(11),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Specific Dates',
                          style: TextStyle(
                            color:
                                _useSpecificDate
                                    ? Colors.white
                                    : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useSpecificDate = false),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              !_useSpecificDate
                                  ? _primaryColor
                                  : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(11),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Weekly Days',
                          style: TextStyle(
                            color:
                                !_useSpecificDate
                                    ? Colors.white
                                    : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Time selection
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _lightColor, width: 1.5),
              ),
              child: ListTile(
                tileColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  _selectedTime == null ? 'Select Time' : 'Time',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle:
                    _selectedTime != null
                        ? Text(
                          _selectedTime!.format(context),
                          style: TextStyle(
                            color: _secondaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                        : null,
                trailing: Icon(Icons.access_time, color: _primaryColor),
                onTap: _selectTime,
              ),
            ),

            const SizedBox(height: 16),

            // Date/Day selection
            if (_useSpecificDate)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _lightColor, width: 1.5),
                ),
                child: ListTile(
                  tileColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    _selectedDates.isEmpty ? 'Select Dates' : 'Selected Dates',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle:
                      _selectedDates.isNotEmpty
                          ? Text(
                            '${_selectedDates.length} dates selected',
                            style: TextStyle(color: _secondaryColor),
                          )
                          : null,
                  trailing: Icon(Icons.calendar_today, color: _primaryColor),
                  onTap: _showDatePicker,
                ),
              )
            else
              SizedBox(
                width: double.infinity,

                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _lightColor, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Days',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(7, (index) {
                            return FilterChip(
                              label: Text(_weekDays[index]),
                              selected: _selectedDays[index],
                              selectedColor: _lightColor,
                              checkmarkColor: _secondaryColor,
                              labelStyle: TextStyle(
                                color:
                                    _selectedDays[index]
                                        ? _secondaryColor
                                        : Colors.black87,
                                fontWeight:
                                    _selectedDays[index]
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color:
                                      _selectedDays[index]
                                          ? _primaryColor
                                          : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (selected) {
                                setState(() => _selectedDays[index] = selected);
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Display selected dates
            if (_useSpecificDate && _selectedDates.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedDates.length,
                  itemBuilder:
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            DateFormat('MMM d').format(_selectedDates[index]),
                            style: TextStyle(color: _secondaryColor),
                          ),
                          backgroundColor: _lightColor.withOpacity(0.7),
                          deleteIconColor: _secondaryColor,
                          onDeleted: () {
                            setState(() => _selectedDates.removeAt(index));
                          },
                        ),
                      ),
                ),
              ),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm Schedule',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
