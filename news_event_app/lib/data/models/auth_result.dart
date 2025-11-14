import 'user_model.dart';

class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult({
    required this.success,
    this.user,
    this.error,
  });

  factory AuthResult.success(User user) {
    return AuthResult(
      success: true,
      user: user,
      error: null,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(
      success: false,
      user: null,
      error: error,
    );
  }
}
