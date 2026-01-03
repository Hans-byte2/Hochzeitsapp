import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SmartDatePicker extends StatefulWidget {
  final String label;
  final String fieldKey;
  final bool isRequired;
  final DateTime? selectedDate;
  final Function(DateTime?) onDateSelected;
  final Function(String, bool) onValidationChanged;
  final bool isDisabled;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? Function(DateTime?)? validator;

  const SmartDatePicker({
    super.key,
    required this.label,
    required this.fieldKey,
    required this.isRequired,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onValidationChanged,
    required this.isDisabled,
    this.firstDate,
    this.lastDate,
    this.validator,
  });

  @override
  State<SmartDatePicker> createState() => _SmartDatePickerState();
}

class _SmartDatePickerState extends State<SmartDatePicker> {
  String? _errorText;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    // Initiale Validierung NACH dem Build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateDate();
    });
  }

  @override
  void didUpdateWidget(SmartDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Validierung wenn sich das Datum ändert
    if (oldWidget.selectedDate != widget.selectedDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validateDate();
      });
    }
  }

  void _validateDate() {
    String? error;
    bool isValid = false;

    if (widget.validator != null) {
      error = widget.validator!(widget.selectedDate);
      isValid = error == null;
    } else if (widget.isRequired) {
      if (widget.selectedDate == null) {
        error = '${widget.label} ist erforderlich';
        isValid = false;
      } else {
        isValid = true;
      }
    } else {
      isValid = true;
    }

    // WICHTIG: setState nur wenn sich was geändert hat
    if (_errorText != error || _isValid != isValid) {
      setState(() {
        _errorText = error;
        _isValid = isValid;
      });

      // Callback NACH setState
      widget.onValidationChanged(widget.fieldKey, isValid);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate ?? DateTime.now(),
      firstDate: widget.firstDate ?? DateTime(1900),
      lastDate: widget.lastDate ?? DateTime(2100),
      // Locale entfernt - wird automatisch vom System übernommen
    );

    if (picked != null) {
      widget.onDateSelected(picked);
      // Validierung erfolgt automatisch über didUpdateWidget
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Datum wählen';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.isDisabled ? null : () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '${widget.label}${widget.isRequired ? ' *' : ''}',
          errorText: _errorText,
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: _isValid ? Colors.green : Colors.grey,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: _isValid ? Colors.green : Colors.grey,
              width: _isValid ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: _isValid ? Colors.green : Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          filled: widget.isDisabled,
          fillColor: widget.isDisabled ? Colors.grey[200] : null,
          suffixIcon: widget.isDisabled
              ? const Icon(Icons.check_circle, color: Colors.green)
              : _isValid && widget.selectedDate != null
              ? const Icon(Icons.check_circle, color: Colors.green)
              : widget.isRequired
              ? const Icon(Icons.star, color: Colors.red, size: 12)
              : const Icon(Icons.calendar_today),
        ),
        child: Text(
          _formatDate(widget.selectedDate),
          style: TextStyle(
            color: widget.isDisabled
                ? Colors.grey
                : widget.selectedDate == null
                ? Colors.grey[600]
                : Colors.black87,
            fontWeight: widget.isDisabled ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
