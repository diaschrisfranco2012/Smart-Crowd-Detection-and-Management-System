import 'package:flutter/material.dart';

import '../main.dart'; // To navigate to AuthGate

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() =>
      _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // Wait for 2 seconds, then navigate to the AuthGate
    Future.delayed(
      const Duration(seconds: 2),
      () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const AuthGate(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            // A sleek security icon glowing slightly
            Icon(
              Icons.shield_outlined,
              size: 120,
              color: Colors.blueAccent
                  .withOpacity(0.8),
            ),
            const SizedBox(height: 20),
            const Text(
              "C R O W D S E N S E",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "AI Security System",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
