import 'package:flutter/material.dart';

class SnackBarUtils {
  static void showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Default icon if none provided
    final displayIcon = icon ?? (isError ? Icons.error_outline : Icons.info_outline);
    
    // Colors based on theme and message type
    final Color textColor = isError
        ? (isDark ? Colors.red[100]! : Colors.red[50]!)
        : (isDark ? Colors.blue[100]! : Colors.blue[50]!);
    
    final Color backgroundColor = isError
        ? (isDark ? Colors.red[900]!.withOpacity(0.95) : Colors.red[800]!)
        : (isDark ? Colors.blue[900]!.withOpacity(0.95) : Colors.blue[800]!);
    
    final Color borderColor = isError
        ? (isDark ? Colors.red[700]! : Colors.red[300]!)
        : (isDark ? Colors.blue[700]! : Colors.blue[300]!);
    
    // Create and show the SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              displayIcon,
              color: textColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
        elevation: 4,
        duration: duration ?? const Duration(seconds: 3),
        action: actionLabel != null || onActionPressed != null
            ? SnackBarAction(
                label: actionLabel ?? 'DISMISS',
                textColor: textColor,
                onPressed: onActionPressed ?? () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              )
            : null,
      ),
    );
  }
  
  // Method for showing success messages
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    showSnackBar(
      context,
      message: message,
      isError: false,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      icon: Icons.check_circle_outline,
    );
  }
  
  // Method for showing error messages
  static void showError(
    BuildContext context, {
    required String message,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    showSnackBar(
      context,
      message: message,
      isError: true,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      icon: Icons.error_outline,
    );
  }
}

