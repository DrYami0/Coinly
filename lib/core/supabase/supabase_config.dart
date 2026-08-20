import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<bool> initialize() async {
    if (!isConfigured || Supabase.instance.isInitialized) return isConfigured;
    await Supabase.initialize(url: url, anonKey: anonKey);
    return true;
  }
}
