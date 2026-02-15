import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SmartTextField extends StatefulWidget {
  final String label;
  final String fieldKey;
  final bool isRequired;
  final TextEditingController controller;
  final Function(String, bool) onValidationChanged;
  final bool isDisabled;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters; // NEU!

  const SmartTextField({
    Key? key,
    required this.label,
    required this.fieldKey,
    required this.isRequired,
    required this.controller,
    required this.onValidationChanged,
    required this.isDisabled,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters, // NEU!
  }) : super(key: key);

  @override
  State<SmartTextField> createState() => _SmartTextFieldState();
}

class _SmartTextFieldState extends State<SmartTextField> {
  bool _isValid = false;
  String? _errorText;
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    // Initiale Validierung
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateField(widget.controller.text);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (_hasInteracted) {
      _validateField(widget.controller.text);
    }
  }

  void _validateField(String value) {
    if (!mounted) return;

    final validator = widget.validator;
    String? error;
    bool isValid = false;

    if (validator != null) {
      error = validator(value);
      isValid = error == null;
    } else {
      // Standard-Validierung wenn kein validator angegeben
      if (widget.isRequired) {
        isValid = value.trim().isNotEmpty;
        error = isValid ? null : 'Dieses Feld ist erforderlich';
      } else {
        isValid = true;
      }
    }

    setState(() {
      _isValid = isValid;
      _errorText = error;
    });

    widget.onValidationChanged(widget.fieldKey, isValid);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: widget.controller,
      enabled: !widget.isDisabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters, // NEU!
      maxLines: widget.keyboardType == TextInputType.multiline ? 3 : 1,
      onChanged: (value) {
        if (!_hasInteracted) {
          setState(() => _hasInteracted = true);
        }
        _validateField(value);
      },
      decoration: InputDecoration(
        labelText: widget.label + (widget.isRequired ? ' *' : ''),
        errorText: _hasInteracted ? _errorText : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _isValid && _hasInteracted
                ? Colors.green
                : Colors.grey.shade400,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _isValid && _hasInteracted
                ? Colors.green
                : Colors.grey.shade400,
            width: _isValid && _hasInteracted ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _isValid && _hasInteracted ? Colors.green : scheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        suffixIcon: _hasInteracted && _isValid
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
