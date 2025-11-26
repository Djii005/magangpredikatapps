import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../../data/exceptions/app_exceptions.dart';
import '../../utils/error_handler.dart';

/// Wrapper widget that handles session expiration globally
class SessionHandler extends StatelessWidget {
  final Widget child;
  final Future<bool> Function() operation;

  const SessionHandler({
    super.key,
    required this.child,
    required this.operation,
  });

  /// Execute an operation and handle session expiration
  static Future<bool> execute(
    BuildContext context,
    Future<bool> Function() operation,
  ) async {
    try {
      return await operation();
    } on SessionExpiredException catch (e) {
      // Handle session expiration
      final authProvider = context.read<AuthProvider>();
      await authProvider.handleSessionExpired();
      
      if (!context.mounted) return false;
      
      // Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      
      // Show error message
      ErrorHandler.showErrorSnackBar(context, e.message);
      
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
