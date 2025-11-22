// lib/screens/settings_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/profile_providers.dart';
import '../services/theme_providers.dart';
import '../theme/theme_variant.dart';
import '../widgets/theme_picker_grid.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(title: 'Profil', child: _ProfileCard()),
          SizedBox(height: 16),
          _Section(title: 'Erscheinungsbild', child: _AppearanceCard()),
          SizedBox(height: 16),
          _Section(title: 'Allgemein', child: _GeneralCard()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textStyle),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ],
    );
  }
}

/// 🔹 Nur Profilbild (Namen/Datum bleiben auf der Startseite / DB)
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _pickImage(context, ref),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                backgroundImage: state.imagePath != null
                    ? FileImage(File(state.imagePath!))
                    : null,
                child: state.imagePath == null
                    ? const Icon(Icons.person, size: 36)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Profilbild für die Startseite festlegen.\n'
                'Es wird hinter den Eingabefeldern für\n'
                'Namen und Hochzeitsdatum angezeigt.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.imagePath != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => controller.setImagePath(null),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Profilbild entfernen'),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'profile_${DateTime.now().millisecondsSinceEpoch.toString()}.jpg';
    final file = File('${dir.path}/$filename');
    await File(image.path).copy(file.path);

    await ref.read(profileControllerProvider.notifier).setImagePath(file.path);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profilbild aktualisiert')));
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(themeControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Farbschema'),
        const SizedBox(height: 8),
        const ThemePickerGrid(),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        const Text('Schnellwahl'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _ModeChip(
              label: 'Sand (hell)',
              onTap: () => controller.setVariant(ThemeVariant.sandVintageCream),
            ),
            _ModeChip(
              label: 'Vintage Mint',
              onTap: () => controller.setVariant(ThemeVariant.vintageMint),
            ),
            _ModeChip(
              label: 'Mint Fresh',
              onTap: () => controller.setVariant(ThemeVariant.mintFresh),
            ),
            _ModeChip(
              label: 'Frozen Mint',
              onTap: () => controller.setVariant(ThemeVariant.frozenMint),
            ),
            _ModeChip(
              label: 'Pink',
              onTap: () => controller.setVariant(ThemeVariant.romanticPink),
            ),
            _ModeChip(
              label: 'Creme',
              onTap: () => controller.setVariant(ThemeVariant.cremeElegance),
            ),
            _ModeChip(
              label: 'Gold',
              onTap: () => controller.setVariant(ThemeVariant.royalGold),
            ),
            _ModeChip(
              label: 'Schwarz/Weiß',
              onTap: () => controller.setVariant(ThemeVariant.blackWhite),
            ),
            _ModeChip(
              label: 'Dunkel',
              onTap: () => controller.setVariant(ThemeVariant.vintageMintDark),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _GeneralCard extends StatelessWidget {
  const _GeneralCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.language),
          title: Text('Sprache'),
          subtitle: Text('Deutsch'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.attach_money),
          title: Text('Währung'),
          subtitle: Text('EUR'),
        ),
      ],
    );
  }
}
