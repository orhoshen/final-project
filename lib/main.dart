import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/computer_mode_screen.dart';
import 'screens/player_mode_screen.dart';
import 'screens/sound_test_screen.dart';
import 'screens/basic_sound_test_screen.dart';
import 'screens/fallback_sound_screen.dart';
import 'theme.dart';

Future<void> main() async {
  // Ensure bindings are initialized before any async work
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the generated options
  try {
    // For web, use web options specifically
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.web,
      );
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue without Firebase if initialization fails
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piano Memory',
      theme: appTheme,
      home: const LandingPage(),
      routes: {
        '/computer_mode': (context) => const ComputerModeScreen(),
        '/player_mode': (context) => const PlayerModeScreen(),
        '/sound_test': (context) => const SoundTestScreen(),
        '/basic_sound_test': (context) => const BasicSoundTestScreen(),
        '/fallback_sound_test': (context) => const FallbackSoundScreen(),
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Piano Memory Game'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Piano Memory!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Test your musical memory',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              SizedBox(height: screenHeight * 0.05),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/computer_mode');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                ),
                child: const Text('Computer Mode'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/player_mode');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                ),
                child: const Text('Player Mode'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/sound_test');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                ),
                child: const Text('Sound Test'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/basic_sound_test');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                ),
                child: const Text('Basic Sound Test'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/fallback_sound_test');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                ),
                child: const Text('Fallback Sound Test'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
