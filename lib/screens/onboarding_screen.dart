// lib/screens/onboarding_screen.dart
//
// Onboarding-Flow für HeartPebble
// Wird nur beim ersten App-Start gezeigt.
// Danach wird onboarding_completed = true in SharedPreferences gesetzt.
//
// Schritte:
//   1. Willkommen
//   2. Namen des Brautpaars
//   3. Hochzeitsdatum
//   4. Budget
//   5. Feature-Übersicht → Fertig

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database_helper.dart';
import '../models/wedding_models.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Eingabe-Controller
  final _brideController = TextEditingController();
  final _groomController = TextEditingController();
  final _budgetController = TextEditingController();

  DateTime? _selectedDate;

  // Primärfarbe – passt zu HeartPebble Pink
  static const Color _primary = Color(0xFFE91E8C);
  static const Color _primaryLight = Color(0xFFFCE4F3);
  static const Color _textDark = Color(0xFF2D2D2D);
  static const Color _textGrey = Color(0xFF757575);

  @override
  void dispose() {
    _pageController.dispose();
    _brideController.dispose();
    _groomController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Validierung vor Weiterblättern
    if (_currentPage == 1) {
      if (_brideController.text.trim().isEmpty ||
          _groomController.text.trim().isEmpty) {
        _showSnack('Bitte beide Namen eingeben.');
        return;
      }
    }
    if (_currentPage == 2) {
      if (_selectedDate == null) {
        _showSnack('Bitte ein Hochzeitsdatum wählen.');
        return;
      }
    }

    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Hochzeitsdaten speichern
      final date =
          _selectedDate ?? DateTime.now().add(const Duration(days: 365));
      final bride = _brideController.text.trim();
      final groom = _groomController.text.trim();

      await DatabaseHelper.instance.updateWeddingData(date, bride, groom);

      // Budget als BudgetItem speichern (falls eingegeben)
      final budgetText = _budgetController.text.trim().replaceAll(',', '.');
      if (budgetText.isNotEmpty) {
        final budget = double.tryParse(budgetText);
        if (budget != null && budget > 0) {
          // Nur speichern wenn noch kein Gesamtbudget-Eintrag existiert
          final existing = await DatabaseHelper.instance.getAllBudgetItems();
          final alreadyExists = existing.any(
            (item) => item.category == 'total_budget',
          );
          if (!alreadyExists) {
            await DatabaseHelper.instance.createBudgetItem(
              BudgetItem(
                name: 'Gesamtbudget',
                planned: budget,
                actual: 0.0,
                category: 'total_budget',
                notes: 'Im Onboarding festgelegt',
                paid: false,
              ),
            );
          }
        }
      }

      // Onboarding als abgeschlossen markieren
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      widget.onFinished();
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Fehler beim Speichern. Bitte nochmal versuchen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress-Indicator ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: List.generate(5, (i) {
                  final active = i <= _currentPage;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active ? _primary : const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Seiten ─────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _PageWelcome(),
                  _PageNames(
                    brideController: _brideController,
                    groomController: _groomController,
                  ),
                  _PageDate(selectedDate: _selectedDate, onPickDate: _pickDate),
                  _PageBudget(budgetController: _budgetController),
                  _PageFeatures(),
                ],
              ),
            ),

            // ── Navigation Buttons ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _prevPage,
                      child: const Text(
                        'Zurück',
                        style: TextStyle(color: _textGrey, fontSize: 15),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isSaving ? null : _nextPage,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(140, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentPage == 4 ? 'Loslegen 🎉' : 'Weiter',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// PAGE 1 — Willkommen
// ════════════════════════════════════════════════
class _PageWelcome extends StatelessWidget {
  static const Color _primary = Color(0xFFE91E8C);
  static const Color _primaryLight = Color(0xFFFCE4F3);
  static const Color _textDark = Color(0xFF2D2D2D);
  static const Color _textGrey = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'assets/images/heartpepple_logo.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.favorite, color: _primary, size: 52),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Willkommen bei\nHeartPebble',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _textDark,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Eure Hochzeit, alles an einem Ort.\nIn wenigen Schritten seid ihr startklar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _textGrey, height: 1.5),
          ),
          const SizedBox(height: 40),
          // Feature-Chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: const [
              _Chip('👥 Gäste'),
              _Chip('🍽️ Tischplanung'),
              _Chip('💰 Budget'),
              _Chip('✅ Checkliste'),
              _Chip('🏢 Dienstleister'),
              _Chip('🔄 Partner-Sync'),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// PAGE 2 — Namen
// ════════════════════════════════════════════════
class _PageNames extends StatelessWidget {
  final TextEditingController brideController;
  final TextEditingController groomController;

  static const Color _primary = Color(0xFFE91E8C);
  static const Color _textDark = Color(0xFF2D2D2D);
  static const Color _textGrey = Color(0xFF757575);

  const _PageNames({
    required this.brideController,
    required this.groomController,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💑', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          const Text(
            'Wie heißt ihr?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Eure Namen erscheinen im Dashboard und auf Exporten.',
            style: TextStyle(fontSize: 14, color: _textGrey),
          ),
          const SizedBox(height: 36),
          _InputField(
            controller: brideController,
            label: 'Name Person 1',
            hint: 'z.B. Sophie',
            icon: Icons.favorite_outline,
          ),
          const SizedBox(height: 16),
          _InputField(
            controller: groomController,
            label: 'Name Person 2',
            hint: 'z.B. Lukas',
            icon: Icons.favorite_outline,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// PAGE 3 — Datum
// ════════════════════════════════════════════════
class _PageDate extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onPickDate;

  static const Color _primary = Color(0xFFE91E8C);
  static const Color _primaryLight = Color(0xFFFCE4F3);
  static const Color _textDark = Color(0xFF2D2D2D);
  static const Color _textGrey = Color(0xFF757575);

  const _PageDate({required this.selectedDate, required this.onPickDate});

  String get _daysUntil {
    if (selectedDate == null) return '';
    final diff = selectedDate!.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Datum liegt in der Vergangenheit';
    if (diff == 0) return 'Heute! 🎉';
    return 'Noch $diff Tage bis zu eurem großen Tag!';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          const Text(
            'Wann ist die Hochzeit?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Der Countdown startet ab sofort im Dashboard.',
            style: TextStyle(fontSize: 14, color: _textGrey),
          ),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: onPickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: selectedDate != null
                    ? _primaryLight
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedDate != null
                      ? _primary
                      : const Color(0xFFE0E0E0),
                  width: selectedDate != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: selectedDate != null ? _primary : _textGrey,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      selectedDate != null
                          ? '${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}'
                          : 'Datum auswählen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: selectedDate != null ? _textDark : _textGrey,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: _textGrey),
                ],
              ),
            ),
          ),
          if (selectedDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _daysUntil,
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// PAGE 4 — Budget
// ════════════════════════════════════════════════
class _PageBudget extends StatelessWidget {
  final TextEditingController budgetController;

  static const Color _primary = Color(0xFFE91E8C);
  static const Color _textDark = Color(0xFF2D2D2D);
  static const Color _textGrey = Color(0xFF757575);

  const _PageBudget({required this.budgetController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💰', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          const Text(
            'Euer Gesamtbudget',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dieser Schritt ist optional — ihr könnt das Budget jederzeit in den Einstellungen ändern.',
            style: TextStyle(fontSize: 14, color: _textGrey, height: 1.4),
          ),
          const SizedBox(height: 36),
          TextField(
            controller: budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Budget in €',
              hintText: 'z.B. 15000',
              prefixIcon: const Icon(Icons.euro, color: _primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFFF9F9F9),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tipp: Euer Budget könnt ihr jederzeit im Budget-Tab eintragen und anpassen. HeartPebble trackt dann automatisch alle Ausgaben.',
            style: TextStyle(fontSize: 13, color: _textGrey, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// PAGE 5 — Feature-Übersicht
// ════════════════════════════════════════════════
class _PageFeatures extends StatelessWidget {
  static const Color _textDark = Color(0xFF2D2D2D);
  static const Color _textGrey = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    const features = [
      ('👥', 'Gästeverwaltung', 'RSVP, Kinder, KI-Scoring'),
      ('🍽️', 'Tischplanung', 'Drag & Drop Sitzplan'),
      ('💰', 'Budget', 'Kategorien & Donut-Chart'),
      ('✅', 'Checkliste', 'Tasks mit Fälligkeitsdatum'),
      ('🏢', 'Dienstleister', 'Verträge & Kosten im Blick'),
      // ('🔄', 'Partner-Sync', 'Daten mit Partner teilen'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Alles startklar! 🎉',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Das erwartet euch in HeartPebble:',
            style: TextStyle(fontSize: 15, color: _textGrey),
          ),
          const SizedBox(height: 28),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(f.$1, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.$2,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        f.$3,
                        style: const TextStyle(fontSize: 13, color: _textGrey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// HILFWIDGETS
// ════════════════════════════════════════════════

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  static const Color _primary = Color(0xFFE91E8C);

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _primary, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  static const Color _primaryLight = Color(0xFFFCE4F3);
  static const Color _primary = Color(0xFFE91E8C);

  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: _primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
