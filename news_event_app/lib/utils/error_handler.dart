import 'package:flutter/material.dart';
import '../data/exceptions/app_exceptions.dart';
import 'app_logger.dart';

/// Utility class for handling and displaying errors in the UI
class ErrorHandler {
  /// Show error message using SnackBar
  static void showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    AppLogger.debug('Showing error snackbar: $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success message using SnackBar
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    AppLogger.debug('Showing success snackbar: $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    if (!context.mounted) return;
    
    AppLogger.debug('Showing error dialog: $title - $message');
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Convert exception to user-friendly message
  static String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    } else if (error is String) {
      return error;
    } else {
      AppLogger.error('Unknown error type', error);
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Handle error and show appropriate UI feedback
  static void handleError(
    BuildContext context,
    dynamic error, {
    bool useDialog = false,
    String? customMessage,
  }) {
    final message = customMessage ?? getErrorMessage(error);
    
    if (useDialog) {
      showErrorDialog(context, 'Error', message);
    } else {
      showErrorSnackBar(context, message);
    }
  }

  /// Check if error is a session expiration and handle accordingly
  static bool isSessionExpired(dynamic error) {
    return error is SessionExpiredException;
  }
}
