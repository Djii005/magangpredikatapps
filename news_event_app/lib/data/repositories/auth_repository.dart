import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_result.dart';
import '../models/user_model.dart' as models;
import '../../utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';

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
      AppLogger.info('Attempting to sign up user: $email');

      // Validate email
      if (!isValidEmail(email)) {
        AppLogger.warning('Sign up failed: Invalid email format');
        return AuthResult.failure('Invalid email format');
      }

      // Validate password
      if (!isValidPassword(password)) {
        AppLogger.warning('Sign up failed: Password too short');
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
        AppLogger.error('Sign up failed: No user returned from auth');
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
          AppLogger.warning('Retry $retries/$maxRetries: Failed to fetch user profile', e);
          if (retries >= maxRetries) {
            rethrow;
          }
        }
      }

      if (user == null) {
        AppLogger.error('Sign up failed: User profile not created');
        return AuthResult.failure('Failed to create user profile');
      }

      // Store session token securely
      await _storeSession(authResponse.session);

      AppLogger.info('User signed up successfully: ${user.email}');
      return AuthResult.success(user);
    } on AuthException catch (e, stackTrace) {
      AppLogger.error('Auth exception during sign up', e, stackTrace);
      // Handle duplicate email error
      if (e.message.contains('already registered') ||
          e.message.contains('already exists')) {
        return AuthResult.failure('Email already exists');
      }
      return AuthResult.failure(e.message);
    } on PostgrestException catch (e, stackTrace) {
      AppLogger.error('Database exception during sign up', e, stackTrace);
      // Handle database errors
      if (e.code == '23505') {
        // Unique constraint violation
        return AuthResult.failure('Email already exists');
      }
      return AuthResult.failure('Database error: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error during sign up', e, stackTrace);
      return AuthResult.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Sign in method
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('Attempting to sign in user: $email');

      // Validate email
      if (!isValidEmail(email)) {
        AppLogger.warning('Sign in failed: Invalid email format');
        return AuthResult.failure('Invalid email format');
      }

      // Authenticate user
      final authResponse = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        AppLogger.warning('Sign in failed: Invalid credentials');
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

      AppLogger.info('User signed in successfully: ${user.email} (${user.role})');
      return AuthResult.success(user);
    } on AuthException catch (e, stackTrace) {
      AppLogger.error('Auth exception during sign in', e, stackTrace);
      return AuthResult.failure('Invalid credentials');
    } on PostgrestException catch (e, stackTrace) {
      AppLogger.error('Database exception during sign in', e, stackTrace);
      return AuthResult.failure('Failed to retrieve user data. Please try again.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error during sign in', e, stackTrace);
      return AuthResult.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Sign out method
  Future<void> signOut() async {
    try {
      AppLogger.info('Attempting to sign out user');
      await _supabaseClient.auth.signOut();
      await _clearSession();
      AppLogger.info('User signed out successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to sign out', e, stackTrace);
      throw AuthenticationException('Failed to sign out. Please try again.', originalError: e);
    }
  }

  // Get current user
  Future<models.User?> getCurrentUser() async {
    try {
      final authUser = _supabaseClient.auth.currentUser;
      
      if (authUser == null) {
        AppLogger.debug('No current user found');
        return null;
      }

      final userResponse = await _supabaseClient
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      final user = models.User.fromJson(userResponse);
      AppLogger.debug('Current user retrieved: ${user.email}');
      return user;
    } on AuthException catch (e, stackTrace) {
      AppLogger.warning('Auth exception getting current user', e, stackTrace);
      // Session might be expired
      if (e.message.contains('expired') || e.message.contains('invalid')) {
        throw SessionExpiredException();
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting current user', e, stackTrace);
      return null;
    }
  }

  // Get user role
  Future<String> getUserRole(String userId) async {
    try {
      AppLogger.debug('Fetching role for user: $userId');
      final response = await _supabaseClient
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();

      final role = response['role'] as String;
      AppLogger.debug('User role retrieved: $role');
      return role;
    } on PostgrestException catch (e, stackTrace) {
      AppLogger.error('Database exception getting user role', e, stackTrace);
      throw ServerException('Failed to get user role', originalError: e);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting user role', e, stackTrace);
      throw ServerException('Failed to get user role', originalError: e);
    }
  }

  // Store session securely
  Future<void> _storeSession(Session? session) async {
    if (session == null) return;

    try {
      AppLogger.debug('Storing session tokens securely');
      await _secureStorage.write(
        key: 'access_token',
        value: session.accessToken,
      );
      await _secureStorage.write(
        key: 'refresh_token',
        value: session.refreshToken,
      );
      AppLogger.debug('Session tokens stored successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to store session', e, stackTrace);
      throw AppStorageException('Failed to store session', originalError: e);
    }
  }

  // Clear session
  Future<void> _clearSession() async {
    try {
      AppLogger.debug('Clearing session tokens');
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
      AppLogger.debug('Session tokens cleared successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear session', e, stackTrace);
      throw AppStorageException('Failed to clear session', originalError: e);
    }
  }

  // Restore session from secure storage
  Future<bool> restoreSession() async {
    try {
      AppLogger.debug('Attempting to restore session');
      final accessToken = await _secureStorage.read(key: 'access_token');
      final refreshToken = await _secureStorage.read(key: 'refresh_token');

      if (accessToken == null || refreshToken == null) {
        AppLogger.debug('No stored session found');
        return false;
      }

      // Supabase will automatically restore the session if tokens are valid
      // The session is managed by Supabase internally
      final hasSession = _supabaseClient.auth.currentSession != null;
      AppLogger.debug('Session restore result: $hasSession');
      return hasSession;
    } catch (e, stackTrace) {
      AppLogger.error('Error restoring session', e, stackTrace);
      return false;
    }
  }
}
