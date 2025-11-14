import 'package:flutter/services.dart';

class SupabaseConfig {
  static String? _supabaseUrl;
  static String? _supabaseAnonKey;

  static String get supabaseUrl {
    if (_supabaseUrl == null) {
      throw Exception('Supabase URL not initialized. Call SupabaseConfig.load() first.');
    }
    return _supabaseUrl!;
  }

  static String get supabaseAnonKey {
    if (_supabaseAnonKey == null) {
      throw Exception('Supabase Anon Key not initialized. Call SupabaseConfig.load() first.');
    }
    return _supabaseAnonKey!;
  }

  static Future<void> load() async {
    try {
      final envFile = await rootBundle.loadString('assets/.env');
      final lines = envFile.split('\n');
      
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        
        final parts = line.split('=');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = parts[1].trim();
          
          if (key == 'SUPABASE_URL') {
            _supabaseUrl = value;
          } else if (key == 'SUPABASE_ANON_KEY') {
            _supabaseAnonKey = value;
          }
        }
      }
      
      if (_supabaseUrl == null || _supabaseAnonKey == null) {
        throw Exception('Missing required Supabase configuration in .env file');
      }
    } catch (e) {
      throw Exception('Failed to load Supabase configuration: $e');
    }
  }
}
