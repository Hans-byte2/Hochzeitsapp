class SupabaseConfig {
  // 🔐 Füge hier deine Keys ein!
  static const String supabaseUrl = 'https://qtmjqphsadffapbmfhgl.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_XYCkxX5_GB69ramzoQHszA_iPUmramG';

  static const bool enableDebugLogs = true;
  static const Duration pairCodeExpiry = Duration(hours: 24);

  static bool get isConfigured {
    return supabaseUrl != 'https://qtmjqphsadffapbmfhgl.supabase.co' &&
        supabaseAnonKey != 'sb_publishable_XYCkxX5_GB69ramzoQHszA_iPUmramG';
  }
}
