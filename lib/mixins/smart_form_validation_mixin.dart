import 'package:flutter/material.dart';

/// Mixin für intelligente Form-Validierung mit Auto-Disable nach Save
///
/// Features:
/// - Tracking von Feld-Validierungsstatus
/// - Automatisches Ausgrauen validierter Felder nach Save
/// - Visuelles Feedback (✓ für valide Felder, * für Pflichtfelder)
/// - Einheitliches Design in der gesamten App
///
/// Verwendung:
/// ```dart
/// class _MyFormState extends State<MyForm> with SmartFormValidation {
///   @override
///   Widget build(BuildContext context) {
///     return SmartTextField(
///       label: 'Name',
///       fieldKey: 'name',
///       isRequired: true,
///       validator: (value) => value?.isEmpty ?? true ? 'Pflichtfeld' : null,
///       onValidationChanged: updateFieldValidation,
///       isDisabled: isFieldDisabled('name'),
///       controller: _nameController,
///     );
///   }
/// }
/// ```
mixin SmartFormValidation<T extends StatefulWidget> on State<T> {
  /// Map zum Tracken des Validierungsstatus jedes Feldes
  final Map<String, bool> _fieldValidationStatus = {};

  /// Flag ob das Formular erfolgreich gespeichert wurde
  bool _formIsSaved = false;

  /// Flag ob wir im Edit-Modus sind (vs. Create-Modus)
  bool _isEditMode = false;

  /// Setzt den Edit-Modus
  void setEditMode(bool isEdit) {
    setState(() {
      _isEditMode = isEdit;
    });
  }

  /// Gibt zurück ob wir im Edit-Modus sind
  bool get isEditMode => _isEditMode;

  /// Aktualisiert den Validierungsstatus eines Feldes
  ///
  /// Wird von SmartTextField automatisch aufgerufen
  void updateFieldValidation(String fieldKey, bool isValid) {
    setState(() {
      _fieldValidationStatus[fieldKey] = isValid;
    });
  }

  /// Prüft ob ein Feld disabled sein soll
  ///
  /// Ein Feld wird disabled wenn:
  /// - Das Formular gespeichert wurde UND
  /// - Das Feld valide ist
  bool isFieldDisabled(String fieldKey) {
    return _formIsSaved && (_fieldValidationStatus[fieldKey] ?? false);
  }

  /// Prüft ob alle Pflichtfelder valide sind
  bool areAllRequiredFieldsValid(List<String> requiredFields) {
    for (final field in requiredFields) {
      if (!(_fieldValidationStatus[field] ?? false)) {
        return false;
      }
    }
    return true;
  }

  /// Markiert das Formular als gespeichert
  ///
  /// Rufe diese Methode nach erfolgreichem Save auf.
  /// Alle validen Felder werden dann ausgegraut.
  void markFormAsSaved() {
    setState(() {
      _formIsSaved = true;
    });
  }

  /// Setzt das Formular zurück (für "Bearbeiten"-Button)
  ///
  /// Alle Felder werden wieder editierbar
  void resetFormValidation() {
    setState(() {
      _formIsSaved = false;
      _fieldValidationStatus.clear();
    });
  }

  /// Aktiviert ein spezifisches Feld wieder zum Bearbeiten
  ///
  /// Nützlich wenn User einzelne Felder nachträglich ändern möchte
  void enableField(String fieldKey) {
    setState(() {
      _fieldValidationStatus[fieldKey] = false;
    });
  }

  /// Gibt die Anzahl der validen Felder zurück
  int get validFieldsCount =>
      _fieldValidationStatus.values.where((v) => v).length;

  /// Gibt die Gesamtanzahl der getrackten Felder zurück
  int get totalFieldsCount => _fieldValidationStatus.length;

  /// Berechnet den Validierungs-Fortschritt (0.0 - 1.0)
  double get validationProgress {
    if (totalFieldsCount == 0) return 0.0;
    return validFieldsCount / totalFieldsCount;
  }

  @override
  void dispose() {
    _fieldValidationStatus.clear();
    super.dispose();
  }
}
