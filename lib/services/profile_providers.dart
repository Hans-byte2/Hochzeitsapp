// lib/services/profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kProfileImgPath = 'profile_img_path';
const _kName1 = 'profile_name1';
const _kName2 = 'profile_name2';
const _kWeddingDate = 'wedding_date_iso';

class ProfileState {
  final String? imagePath;
  final String name1;
  final String name2;
  final String? weddingDateIso;

  const ProfileState({
    required this.imagePath,
    required this.name1,
    required this.name2,
    required this.weddingDateIso,
  });

  ProfileState copyWith({
    String? imagePath,
    String? name1,
    String? name2,
    String? weddingDateIso,
  }) {
    return ProfileState(
      imagePath: imagePath ?? this.imagePath,
      name1: name1 ?? this.name1,
      name2: name2 ?? this.name2,
      weddingDateIso: weddingDateIso ?? this.weddingDateIso,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._prefs)
    : super(
        const ProfileState(
          imagePath: null,
          name1: '',
          name2: '',
          weddingDateIso: null,
        ),
      ) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    state = ProfileState(
      imagePath: _prefs.getString(_kProfileImgPath),
      name1: _prefs.getString(_kName1) ?? '',
      name2: _prefs.getString(_kName2) ?? '',
      weddingDateIso: _prefs.getString(_kWeddingDate),
    );
  }

  Future<void> setImagePath(String? path) async {
    if (path == null) {
      await _prefs.remove(_kProfileImgPath);
    } else {
      await _prefs.setString(_kProfileImgPath, path);
    }
    state = state.copyWith(imagePath: path);
  }

  Future<void> setName1(String v) async {
    await _prefs.setString(_kName1, v);
    state = state.copyWith(name1: v);
  }

  Future<void> setName2(String v) async {
    await _prefs.setString(_kName2, v);
    state = state.copyWith(name2: v);
  }

  Future<void> setWeddingDateIso(String? iso) async {
    if (iso == null) {
      await _prefs.remove(_kWeddingDate);
    } else {
      await _prefs.setString(_kWeddingDate, iso);
    }
    state = state.copyWith(weddingDateIso: iso);
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      throw UnimplementedError('override in main()');
    });
