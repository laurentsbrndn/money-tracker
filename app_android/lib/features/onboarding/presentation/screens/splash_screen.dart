import 'package:flutter/material.dart';

/// Shown while the session and database flags are read (APP_FLOWS Flow 1).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
