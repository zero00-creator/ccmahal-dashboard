import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shown when the live data does not arrive: a plain sentence and two ways out.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({
    super.key,
    required this.onRetry,
    required this.onSignOut,
  });

  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final size = WidgetStateProperty.all(const Size(minTap, minTap));
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Can't reach the database. Check your connection and try again.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x4),
              FilledButton(
                key: const ValueKey('retry'),
                style: ButtonStyle(minimumSize: size),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
              const SizedBox(height: Space.x2),
              TextButton(
                key: const ValueKey('sign-out'),
                style: ButtonStyle(minimumSize: size),
                onPressed: onSignOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
