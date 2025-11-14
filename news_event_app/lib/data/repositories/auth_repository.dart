import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_result.dart';
import '../models/user_model.dart' as models;

class AuthRepository {
  final SupabaseClient _supabaseClient;
  final FlutterSecureStorage _secureStorage;

  AuthRepository({
    required SupabaseClient supabaseClient,
    FlutterSecureStorage? secureStorage,
  })  : _supabaseClient = supabaseClient,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // Email validation
  bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Password validation
  bool isValidPassword(String password) {
    return password.length >= 8;
  }

  // Sign up method
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Validate email
      if (!isValidEmail(email)) {
        return AuthResult.failure('Invalid email format');
      }

      // Validate password
      if (!isValidPassword(password)) {
        return AuthResult.failure('Password must be at least 8 characters');
      }

      // Create auth user with metadata
      final authResponse = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
        },
      );

      if (authResponse.user == null) {
        return AuthResult.failure('Failed to create account');
      }

      final userId = authResponse.user!.id;

      // Retry logic to fetch user profile created by trigger
      models.User? user;
      int retries = 0;
      const maxRetries = 5;
      
      while (retries < maxRetries) {
        try {
          await Future.delayed(Duration(milliseconds: 300 * (retries + 1)));
          
          final userResponse = await _supabaseClient
              .from('users')
              .select()
              .eq('id', userId)
              .maybeSingle();

          if (userResponse != null) {
            user = models.User.fromJson(userResponse);
            break;
          }
        } catch (e) {
          retries++;
          if (retries >= maxRetries) {
            rethrow;
          }
        }
      }

      if (user == null) {
        return AuthResult.failure('Failed to create user profile');
      }

      // Store session token securely
      await _storeSession(authResponse.session);

      return AuthResult.success(user);
    } on AuthException catch (e) {
      // Handle duplicate email error
      if (e.message.contains('already registered') ||
          e.message.contains('already exists')) {
        return AuthResult.failure('Email already exists');
      }
      return AuthResult.failure(e.message);
    } on PostgrestException catch (e) {
      // Handle database errors
      if (e.code == '23505') {
        // Unique constraint violation
        return AuthResult.failure('Email already exists');
      }
      return AuthResult.failure('Database error: ${e.message}');
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  // Sign in method
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Validate email
      if (!isValidEmail(email)) {
        return AuthResult.failure('Invalid email format');
      }

      // Authenticate user
      final authResponse = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return AuthResult.failure('Invalid credentials');
      }

      final userId = authResponse.user!.id;

      // Retrieve user role from users table
      final userResponse = await _supabaseClient
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      final user = models.User.fromJson(userResponse);

      // Store session token securely
      await _storeSession(authResponse.session);

      return AuthResult.success(user);
    } on AuthException {
      return AuthResult.failure('Invalid credentials');
    } on PostgrestException catch (e) {
      return AuthResult.failure('Failed to retrieve user data: ${e.message}');
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  // Sign out method
  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
      await _clearSession();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Get current user
  Future<models.User?> getCurrentUser() async {
    try {
      final authUser = _supabaseClient.auth.currentUser;
      
      if (authUser == null) {
        return null;
      }

      final userResponse = await _supabaseClient
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      return models.User.fromJson(userResponse);
    } catch (e) {
      return null;
    }
  }

  // Get user role
  Future<String> getUserRole(String userId) async {
    try {
      final response = await _supabaseClient
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();

      return response['role'] as String;
    } catch (e) {
      throw Exception('Failed to get user role: $e');
    }
  }

  // Store session securely
  Future<void> _storeSession(Session? session) async {
    if (session == null) return;

    try {
      await _secureStorage.write(
        key: 'access_token',
        value: session.accessToken,
      );
      await _secureStorage.write(
        key: 'refresh_token',
        value: session.refreshToken,
      );
    } catch (e) {
      throw Exception('Failed to store session: $e');
    }
  }

  // Clear session
  Future<void> _clearSession() async {
    try {
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
    } catch (e) {
      throw Exception('Failed to clear session: $e');
    }
  }

  // Restore session from secure storage
  Future<bool> restoreSession() async {
    try {
      final accessToken = await _secureStorage.read(key: 'access_token');
      final refreshToken = await _secureStorage.read(key: 'refresh_token');

      if (accessToken == null || refreshToken == null) {
        return false;
      }

      // Supabase will automatically restore the session if tokens are valid
      // The session is managed by Supabase internally
      return _supabaseClient.auth.currentSession != null;
    } catch (e) {
      return false;
    }
  }
}
