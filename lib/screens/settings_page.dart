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
            Expanded(
              child: Column(
                children: [
                  TextFormField(
                    initialValue: state.name1,
                    decoration: const InputDecoration(labelText: 'Name 1'),
                    onChanged: controller.setName1,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: state.name2,
                    decoration: const InputDecoration(labelText: 'Name 2'),
                    onChanged: controller.setName2,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DateRow(
          label: 'Hochzeitsdatum',
          isoString: state.weddingDateIso,
          onPick: controller.setWeddingDateIso,
        ),
        const SizedBox(height: 8),
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

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.isoString,
    required this.onPick,
  });

  final String label;
  final String? isoString;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final display = isoString ?? 'Auswählen';
    return Row(
      children: [
        Expanded(child: Text('$label: $display')),
        TextButton(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
            );
            if (picked != null) {
              final iso =
                  '${picked.year.toString().padLeft(4, '0')}-'
                  '${picked.month.toString().padLeft(2, '0')}-'
                  '${picked.day.toString().padLeft(2, '0')}';
              onPick(iso);
            }
          },
          child: const Text('Ändern'),
        ),
      ],
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          children: [
            _ModeChip(
              label: 'Sand (hell)',
              onTap: () => ref
                  .read(themeControllerProvider.notifier)
                  .setVariant(ThemeVariant.sandVintageCream),
            ),
            _ModeChip(
              label: 'Mint',
              onTap: () => ref
                  .read(themeControllerProvider.notifier)
                  .setVariant(ThemeVariant.vintageMint),
            ),
            _ModeChip(
              label: 'Dunkel',
              onTap: () => ref
                  .read(themeControllerProvider.notifier)
                  .setVariant(ThemeVariant.vintageMintDark),
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
