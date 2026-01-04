import 'package:flutter/material.dart';

/// Ein intelligentes DropdownButton das mit SmartFormValidation zusammenarbeitet
///
/// Nutzt die gleiche Logik wie SmartTextField für Konsistenz
class SmartDropdown<T> extends StatefulWidget {
  final String label;
  final String fieldKey;
  final bool isRequired;
  final void Function(String fieldKey, bool isValid)? onValidationChanged;
  final bool isDisabled;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?)? onChanged;
  final String? hintText;

  const SmartDropdown({
    Key? key,
    required this.label,
    required this.fieldKey,
    required this.items,
    required this.itemLabel,
    this.isRequired = false,
    this.onValidationChanged,
    this.isDisabled = false,
    this.value,
    this.onChanged,
    this.hintText,
  }) : super(key: key);

  @override
  State<SmartDropdown<T>> createState() => _SmartDropdownState<T>();
}

class _SmartDropdownState<T> extends State<SmartDropdown<T>> {
  bool _isValid = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Validierung NACH dem Build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateField(widget.value);
    });
  }

  @override
  void didUpdateWidget(SmartDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validateField(widget.value);
      });
    }
  }

  void _validateField(T? value) {
    bool isValid = true;
    String? error;

    if (widget.isRequired && value == null) {
      error = 'Bitte wählen Sie eine Option';
      isValid = false;
    } else {
      isValid = true;
      error = null;
    }

    // WICHTIG: Nur setState wenn Widget noch mounted ist
    if (mounted) {
      setState(() {
        _isValid = isValid;
        _errorText = error;
      });

      widget.onValidationChanged?.call(widget.fieldKey, isValid);
    }
  }

  String _getLabelText() {
    if (widget.isDisabled && _isValid) {
      return '${widget.label} ✓';
    } else if (widget.isRequired) {
      return '${widget.label} *';
    }
    return widget.label;
  }

  Color? _getFillColor() {
    if (widget.isDisabled && _isValid) {
      return Colors.grey[100];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getLabelText(),
          style: TextStyle(
            fontSize: 12,
            color: widget.isDisabled && _isValid
                ? Colors.grey[600]
                : _isValid && widget.value != null
                ? Colors.green[700]
                : Colors.grey[700],
            fontWeight: widget.isDisabled && _isValid ? FontWeight.w500 : null,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _getFillColor(),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _errorText != null
                  ? Colors.red
                  : _isValid && widget.value != null
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: widget.value,
                    hint: Text(widget.hintText ?? 'Bitte wählen...'),
                    isExpanded: true,
                    items: widget.items.map((item) {
                      return DropdownMenuItem<T>(
                        value: item,
                        child: Text(widget.itemLabel(item)),
                      );
                    }).toList(),
                    onChanged: widget.isDisabled
                        ? null
                        : (newValue) {
                            _validateField(newValue);
                            widget.onChanged?.call(newValue);
                          },
                    style: TextStyle(
                      color: widget.isDisabled
                          ? Colors.grey[600]
                          : Colors.black87,
                      fontSize: 16,
                    ),
                    icon: widget.isDisabled && _isValid
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              _errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
