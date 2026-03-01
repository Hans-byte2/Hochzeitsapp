// lib/services/profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kProfileImgPath = 'profile_img_path';

class ProfileState {
  final String? imagePath;

  const ProfileState({this.imagePath});
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController() : super(const ProfileState()) {
    _load();
  }

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _load() async {
    final prefs = await _instance;
    final path = prefs.getString(_kProfileImgPath);
    // hier NICHT copyWith – einfach neuen State setzen
    state = ProfileState(imagePath: path);
  }

  Future<void> setImagePath(String? path) async {
    final prefs = await _instance;

    if (path == null) {
      await prefs.remove(_kProfileImgPath);
    } else {
      await prefs.setString(_kProfileImgPath, path);
    }

    // WICHTIG: immer neuen State setzen – path kann hier explizit null sein
    state = ProfileState(imagePath: path);
  }
}

// ganz normaler Provider, kein override in main() nötig
final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>(
      (ref) => ProfileController(),
    );
