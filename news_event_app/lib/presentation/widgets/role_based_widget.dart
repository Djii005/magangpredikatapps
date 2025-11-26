import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Widget that shows/hides children based on user role
class RoleBasedWidget extends StatelessWidget {
  final Widget child;
  final bool showForAdmin;
  final Widget? fallback;

  const RoleBasedWidget({
    super.key,
    required this.child,
    this.showForAdmin = true,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdmin;

    // Show child if user role matches requirement
    if (showForAdmin && isAdmin) {
      return child;
    } else if (!showForAdmin && !isAdmin) {
      return child;
    }

    // Show fallback or empty container
    return fallback ?? const SizedBox.shrink();
  }
}
