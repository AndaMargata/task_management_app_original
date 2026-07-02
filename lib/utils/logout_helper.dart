import 'package:flutter/material.dart';
import '../services/auth_service.dart';

Future<void> logoutWithAlert(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('Logging out...')),
        ],
      ),
    ),
  );

  try {
    await Future.delayed(const Duration(seconds: 2));
    navigator.pop();
    await AuthService.signOut();
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to log out: $e')),
    );
  }
}
