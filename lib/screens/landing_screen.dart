import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F), // Dark blue background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Use the logo image
            Image.asset(
              'assets/images/logo.png',
              width: 300, // Adjust size as needed
            ),
            const SizedBox(height: 70),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: const Color(0xFF0A192F),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/main-hub');
              },
              child: const Text('Start Playing'),
            ),
          ],
        ),
      ),
    );
  }
}
