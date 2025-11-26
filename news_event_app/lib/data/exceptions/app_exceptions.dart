/// Base exception class for the application
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Authentication related exceptions
class AuthenticationException extends AppException {
  AuthenticationException(super.message, {super.code, super.originalError});
}

/// Authorization/Permission related exceptions
class AuthorizationException extends AppException {
  AuthorizationException(super.message, {super.code, super.originalError});
}

/// Network related exceptions
class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError});
}

/// Validation related exceptions
class ValidationException extends AppException {
  ValidationException(super.message, {super.code, super.originalError});
}

/// Resource not found exceptions
class NotFoundException extends AppException {
  NotFoundException(super.message, {super.code, super.originalError});
}

/// Storage related exceptions
class AppStorageException extends AppException {
  AppStorageException(super.message, {super.code, super.originalError});
}

/// Session expired exception
class SessionExpiredException extends AuthenticationException {
  SessionExpiredException()
      : super('Your session has expired. Please log in again.',
            code: 'SESSION_EXPIRED');
}

/// Generic server error exception
class ServerException extends AppException {
  ServerException(super.message, {super.code, super.originalError});
}
