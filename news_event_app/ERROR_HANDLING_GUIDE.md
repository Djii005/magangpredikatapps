# Error Handling and User Feedback Guide

This document explains the comprehensive error handling and user feedback system implemented in the News & Events app.

## Overview

The app implements a multi-layered error handling approach:

1. **Repository Layer**: Catches exceptions and returns Result types with user-friendly messages
2. **Provider Layer**: Handles errors from repositories and updates UI state
3. **UI Layer**: Displays errors using SnackBars and Dialogs
4. **Logging**: All errors are logged for debugging purposes

## Components

### 1. Custom Exceptions (`lib/data/exceptions/app_exceptions.dart`)

Custom exception classes for different error types:

- `AuthenticationException`: Login/registration errors
- `AuthorizationException`: Permission errors
- `NetworkException`: Network connectivity issues
- `ValidationException`: Input validation errors
- `NotFoundException`: Resource not found errors
- `AppStorageException`: Local storage errors
- `SessionExpiredException`: Session expiration (auto-redirects to login)
- `ServerException`: Generic server errors

### 2. Logger Utility (`lib/utils/app_logger.dart`)

Centralized logging using the `logger` package:

```dart
AppLogger.debug('Debug message');
AppLogger.info('Info message');
AppLogger.warning('Warning message');
AppLogger.error('Error message', error, stackTrace);
AppLogger.fatal('Fatal error', error, stackTrace);
```

### 3. Error Handler Utility (`lib/utils/error_handler.dart`)

Utility functions for displaying errors in the UI:

```dart
// Show error SnackBar
ErrorHandler.showErrorSnackBar(context, 'Error message');

// Show success SnackBar
ErrorHandler.showSuccessSnackBar(context, 'Success message');

// Show error Dialog
ErrorHandler.showErrorDialog(context, 'Title', 'Message');

// Handle any error automatically
ErrorHandler.handleError(context, error);
```

### 4. Session Handler (`lib/presentation/widgets/session_handler.dart`)

Handles session expiration globally:

```dart
final success = await SessionHandler.execute(
  context,
  () => provider.someOperation(),
);
```

When a session expires, it automatically:
- Logs out the user
- Navigates to login screen
- Shows an error message

## Repository Error Handling

All repository methods follow this pattern:

```dart
Future<Result<T>> someOperation() async {
  try {
    AppLogger.info('Starting operation');
    
    // Check authentication
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      throw SessionExpiredException();
    }
    
    // Perform operation
    final result = await _supabaseClient.from('table').select();
    
    AppLogger.info('Operation successful');
    return Result.success(data);
    
  } on SessionExpiredException {
    rethrow; // Let UI handle session expiration
  } on SocketException catch (e, stackTrace) {
    AppLogger.error('Network error', e, stackTrace);
    return Result.failure('No internet connection. Please check your network.');
  } on PostgrestException catch (e, stackTrace) {
    AppLogger.error('Database error', e, stackTrace);
    return Result.failure('Failed to perform operation. Please try again.');
  } catch (e, stackTrace) {
    AppLogger.error('Unexpected error', e, stackTrace);
    return Result.failure('An unexpected error occurred. Please try again.');
  }
}
```

## Provider Error Handling

Providers catch SessionExpiredException and re-throw it for UI handling:

```dart
Future<bool> createItem(Input input) async {
  try {
    final result = await _repository.createItem(input);
    
    if (result.isSuccess) {
      await refresh();
      return true;
    } else {
      _setError(result.error!);
      return false;
    }
  } on SessionExpiredException catch (e) {
    AppLogger.warning('Session expired');
    _setError(e.message);
    rethrow; // Re-throw for UI to handle
  } catch (e, stackTrace) {
    AppLogger.error('Error creating item', e, stackTrace);
    _setError('An unexpected error occurred. Please try again.');
    return false;
  }
}
```

## UI Error Handling

### Basic Error Display

```dart
final success = await provider.someOperation();

if (success) {
  ErrorHandler.showSuccessSnackBar(context, 'Operation successful');
} else {
  ErrorHandler.showErrorSnackBar(context, provider.errorMessage!);
}
```

### With Session Handling

```dart
final success = await SessionHandler.execute(
  context,
  () => provider.someOperation(),
);

if (success) {
  ErrorHandler.showSuccessSnackBar(context, 'Operation successful');
  Navigator.pop(context);
} else {
  ErrorHandler.showErrorSnackBar(context, provider.errorMessage!);
}
```

## Error Messages

All error messages are user-friendly and actionable:

### Network Errors
- "No internet connection. Please check your network."

### Authentication Errors
- "Invalid credentials"
- "Email already exists"
- "Your session has expired. Please log in again."

### Authorization Errors
- "You do not have permission to create news articles"
- "You do not have permission to update events"

### Validation Errors
- "Invalid email format"
- "Password must be at least 8 characters"
- "Event date cannot be in the past"
- "Image size exceeds 5MB limit"

### Generic Errors
- "An unexpected error occurred. Please try again."
- "Failed to fetch news. Please try again."

## Logging

All errors are automatically logged with:
- Error message
- Exception details
- Stack trace
- Timestamp
- Context (what operation was being performed)

Logs can be viewed in the console during development and can be integrated with crash reporting services (like Sentry or Firebase Crashlytics) in production.

## Best Practices

1. **Always use SessionHandler.execute()** for operations that require authentication
2. **Use ErrorHandler utilities** instead of manual SnackBar creation
3. **Log all errors** at the repository level
4. **Provide user-friendly messages** - avoid technical jargon
5. **Handle specific exceptions first** - catch more specific exceptions before general ones
6. **Don't expose sensitive information** in error messages
7. **Test error scenarios** - ensure all error paths work correctly

## Testing Error Handling

To test error handling:

1. **Network errors**: Turn off internet connection
2. **Session expiration**: Wait for token to expire or manually clear session
3. **Permission errors**: Try admin operations as regular user
4. **Validation errors**: Submit invalid data
5. **Not found errors**: Try to access non-existent resources

## Future Enhancements

- Integration with crash reporting service (Sentry/Firebase Crashlytics)
- Offline error queue for retry when connection is restored
- More granular error codes for better error tracking
- Localization of error messages
- User feedback mechanism for reporting errors
