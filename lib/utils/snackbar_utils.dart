import 'package:flutter/material.dart';

class SnackBarUtils {
  static void showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration? duration,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color:
                  isError
                      ? (isDark ? Colors.red[300] : Colors.red[50])
                      : (isDark ? Colors.blue[300] : Colors.blue[50]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color:
                      isError
                          ? (isDark ? Colors.red[300] : Colors.red[50])
                          : (isDark ? Colors.blue[300] : Colors.blue[50]),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError
                ? (isDark
                    ? Colors.red[900]!.withOpacity(0.9)
                    : Colors.red[900]!)
                : (isDark
                    ? Colors.blue[900]!.withOpacity(0.9)
                    : Colors.blue[900]!),
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color:
                isError
                    ? (isDark ? Colors.red[700]! : Colors.red[300]!)
                    : (isDark ? Colors.blue[700]! : Colors.blue[300]!),
            width: 1,
          ),
        ),
        elevation: 4,
        duration: duration ?? const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor:
              isError
                  ? (isDark ? Colors.red[300] : Colors.red[50])
                  : (isDark ? Colors.blue[300] : Colors.blue[50]),
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
