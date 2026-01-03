import 'package:flutter/material.dart';

class SmartTextField extends StatefulWidget {
  final String label;
  final String fieldKey;
  final bool isRequired;
  final TextEditingController controller;
  final Function(String, bool) onValidationChanged;
  final bool isDisabled;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;

  const SmartTextField({
    super.key,
    required this.label,
    required this.fieldKey,
    required this.isRequired,
    required this.controller,
    required this.onValidationChanged,
    required this.isDisabled,
    this.validator,
    this.textInputAction,
    this.keyboardType,
  });

  @override
  State<SmartTextField> createState() => _SmartTextFieldState();
}

class _SmartTextFieldState extends State<SmartTextField> {
  String? _errorText;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validateField);
    // Initiale Validierung NACH dem Build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateField();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateField);
    super.dispose();
  }

  void _validateField() {
    final value = widget.controller.text;
    String? error;
    bool isValid = false;

    if (widget.validator != null) {
      error = widget.validator!(value);
      isValid = error == null;
    } else if (widget.isRequired) {
      isValid = value.trim().isNotEmpty;
      error = isValid ? null : '${widget.label} ist erforderlich';
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

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: !widget.isDisabled,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      style: TextStyle(
        color: widget.isDisabled ? Colors.grey : Colors.black87,
        fontWeight: widget.isDisabled ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        labelText: '${widget.label}${widget.isRequired ? ' *' : ''}',
        errorText: _errorText,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: _isValid ? Colors.green : Colors.grey),
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
            : _isValid && widget.controller.text.trim().isNotEmpty
            ? const Icon(Icons.check_circle, color: Colors.green)
            : widget.isRequired
            ? const Icon(Icons.star, color: Colors.red, size: 12)
            : null,
      ),
    );
  }
}
