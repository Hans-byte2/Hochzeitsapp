import 'package:flutter/material.dart';

/// Utility-Klasse für Kategorie-Farben und Icons
class CategoryUtils {
  /// Gibt die Farbe für eine Kategorie zurück
  static Color getCategoryColor(String category) {
    switch (category) {
      case 'location':
        return Colors.red.shade600;
      case 'catering':
        return Colors.orange.shade600;
      case 'decoration':
        return Colors.amber.shade700;
      case 'clothing':
        return Colors.green.shade600;
      case 'documentation':
        return Colors.blue.shade600;
      case 'music':
        return Colors.purple.shade600;
      case 'photography':
        return Colors.brown.shade600;
      case 'flowers':
        return Colors.pink.shade600;
      case 'timeline':
        return Colors.amber.shade600;
      case 'other':
      default:
        return Colors.grey.shade600;
    }
  }

  /// Gibt das Icon für eine Kategorie zurück
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'location':
        return Icons.place;
      case 'catering':
        return Icons.restaurant;
      case 'decoration':
        return Icons.auto_awesome;
      case 'clothing':
        return Icons.checkroom;
      case 'documentation':
        return Icons.description;
      case 'music':
        return Icons.music_note;
      case 'photography':
        return Icons.camera_alt;
      case 'flowers':
        return Icons.local_florist;
      case 'timeline':
        return Icons.timeline;
      case 'other':
      default:
        return Icons.category;
    }
  }

  /// Gibt eine hellere Version der Kategorie-Farbe zurück (für Hintergründe)
  static Color getCategoryLightColor(String category) {
    switch (category) {
      case 'location':
        return Colors.red.shade50;
      case 'catering':
        return Colors.orange.shade50;
      case 'decoration':
        return Colors.amber.shade50;
      case 'clothing':
        return Colors.green.shade50;
      case 'documentation':
        return Colors.blue.shade50;
      case 'music':
        return Colors.purple.shade50;
      case 'photography':
        return Colors.brown.shade50;
      case 'flowers':
        return Colors.pink.shade50;
      case 'timeline':
        return Colors.amber.shade50;
      case 'other':
      default:
        return Colors.grey.shade50;
    }
  }

  /// Kategorie-Labels (Deutsch)
  static const Map<String, String> categoryLabels = {
    'location': 'Location',
    'catering': 'Catering',
    'decoration': 'Dekoration',
    'clothing': 'Kleidung',
    'documentation': 'Dokumente',
    'music': 'Musik',
    'photography': 'Fotografie',
    'flowers': 'Blumen',
    'timeline': 'Timeline',
    'other': 'Sonstiges',
  };
}
