import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/exceptions/app_exceptions.dart';
import '../../utils/app_logger.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  // State fields
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  // Login method
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authRepository.signIn(
        email: email,
        password: password,
      );

      if (result.success && result.user != null) {
        _currentUser = result.user;
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Login failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
      return false;
    }
  }

  // Register method
  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authRepository.signUp(
        email: email,
        password: password,
        name: name,
      );

      if (result.success && result.user != null) {
        _currentUser = result.user;
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Registration failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
      return false;
    }
  }

  // Logout method
  Future<void> logout() async {
    _setLoading(true);
    _clearError();

    try {
      await _authRepository.signOut();
      _currentUser = null;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to logout: $e');
      _setLoading(false);
    }
  }

  // Check authentication state on app start
  Future<void> checkAuthState() async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authRepository.getCurrentUser();
      
      if (user != null) {
        _currentUser = user;
        AppLogger.info('Auth state restored for user: ${user.email}');
      } else {
        _currentUser = null;
        AppLogger.debug('No authenticated user found');
      }
      
      _setLoading(false);
      notifyListeners();
    } on SessionExpiredException catch (e) {
      AppLogger.warning('Session expired during auth check');
      _setError(e.message);
      _currentUser = null;
      _setLoading(false);
      // Clear stored session
      await _authRepository.signOut();
    } catch (e, stackTrace) {
      AppLogger.error('Error checking auth state', e, stackTrace);
      _setError('Failed to check authentication state');
      _currentUser = null;
      _setLoading(false);
    }
  }

  // Handle session expiration - to be called from repositories
  Future<void> handleSessionExpired() async {
    AppLogger.warning('Handling session expiration');
    _currentUser = null;
    _setError('Your session has expired. Please log in again.');
    notifyListeners();
    
    try {
      await _authRepository.signOut();
    } catch (e) {
      AppLogger.error('Error during session expiration cleanup', e);
    }
  }

  // Helper methods for state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Clear error message manually (useful for dismissing error messages in UI)
  void clearError() {
    _clearError();
    notifyListeners();
  }
}
