import 'package:final_project/providers/server_status_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/basic_sound_test_screen.dart';
import 'screens/fallback_sound_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/main_hub_screen.dart';
import 'screens/server_connection_test_screen.dart';
import 'screens/sound_test_screen.dart';
import 'services/firebase_melody_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize the melody service singleton
  await FirebaseMelodyService.instance.getRandomMelody();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServerStatusNotifier()),
      ],
      child: const PianoGameApp(),
    ),
  );
}

class PianoGameApp extends StatelessWidget {
  const PianoGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MatchoMelody',
      theme: appTheme,
      home: const LandingScreen(),
      routes: {
        '/main-hub': (context) => const MainHubScreen(),
        // Restore routes for the testing hub
        '/server_test': (context) => const ServerConnectionTestScreen(),
        '/sound_test': (gcontext) => const SoundTestScreen(),
        '/basic_sound_test': (context) => const BasicSoundTestScreen(),
        '/fallback_sound_test': (context) => const FallbackSoundScreen(),
      },
    );
  }
}
