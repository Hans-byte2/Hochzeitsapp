// lib/widgets/profile_background_container.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/profile_providers.dart';
import '../app_colors.dart';

class ProfileBackgroundContainer extends ConsumerWidget {
  const ProfileBackgroundContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final imagePath = profile.imagePath;

    // Wenn kein Bild vorhanden ist -> normale Card
    if (imagePath == null) {
      return Card(
        color: AppColors.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        elevation: 0,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
    }

    // Mit Profilbild als Hintergrund
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hintergrundbild
          Image.file(File(imagePath), fit: BoxFit.cover),
          // Leichter Overlay, damit Text lesbar bleibt
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.black.withOpacity(0.55),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Inhalt (Eingabefelder) oben drüber
          Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
