import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HexLogo(size: 96),
            const SizedBox(height: 24),
            Text(
              'HEXADOMINATE',
              style: TextStyle(color: p.text, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 5),
            ),
            const SizedBox(height: 8),
            Text('Conquer every hex.', style: TextStyle(color: p.textSecondary, fontSize: 15)),
            const SizedBox(height: 36),
            if (error == null)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: p.textSecondary),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Could not start: $error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
