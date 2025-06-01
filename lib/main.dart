import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/computer_mode_screen.dart';
import 'screens/player_mode_screen.dart';
import 'screens/sound_test_screen.dart';
import 'screens/basic_sound_test_screen.dart';
import 'screens/fallback_sound_screen.dart';
import 'screens/multiplayer_main_screen.dart';
import 'screens/server_connection_test_screen.dart';
import 'screens/testing_hub_screen.dart';
import 'services/multiplayer_service.dart';
import 'services/websocket_service.dart';
import 'theme.dart';

// Original main function
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

// Minimal main function for testing
/*
void main() {
  runApp(MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Android Test')),
      body: const Center(child: Text('Hello Android! It Works!')),
    ),
  ));
}
*/

// Original MyApp class
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Register WebSocketService and MultiplayerService
        ChangeNotifierProvider<WebSocketService>(
          create: (_) => WebSocketService(),
        ),
        ChangeNotifierProxyProvider<WebSocketService, MultiplayerService>(
          create: (context) => MultiplayerService(Provider.of<WebSocketService>(context, listen: false)),
          update: (context, webSocketService, previous) => 
            previous ?? MultiplayerService(webSocketService),
        ),
      ],
      child: MaterialApp(
        title: 'Piano Memory',
        theme: appTheme, // Restore custom theme
        home: const MainAppShell(), // Changed to MainAppShell
        routes: { // Restore routes
          '/computer_mode': (context) => const ComputerModeScreen(),
          '/player_mode': (context) => const PlayerModeScreen(),
          '/sound_test': (context) => const SoundTestScreen(),
          '/basic_sound_test': (context) => const BasicSoundTestScreen(),
          '/fallback_sound_test': (context) => const FallbackSoundScreen(),
          '/multiplayer': (context) => const MultiplayerMainScreen(),
          '/server_test': (context) => const ServerConnectionTestScreen(),
        },
      ),
    );
  }
}

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    LandingPage(), // Game modes
    TestingHubScreen(), // Testing Hub
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.gamepad_outlined),
            label: 'Play',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science_outlined),
            label: 'Testing',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
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
        automaticallyImplyLeading: false, // No back button if it's a main tab view
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding( // Added padding for better spacing
            padding: const EdgeInsets.all(16.0),
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
                
                // Game modes
                const Text(
                  'Game Modes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Computer Mode
                _buildGameModeButton(context, 'Computer Mode', '/computer_mode', Colors.purple, Icons.computer),
                const SizedBox(height: 12),
                
                // Player Mode
                _buildGameModeButton(context, 'Player Mode', '/player_mode', Colors.blue, Icons.person),
                const SizedBox(height: 12),
                
                // Multiplayer Mode
                _buildGameModeButton(context, 'Multiplayer Mode', '/multiplayer', Colors.green, Icons.people),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for game mode buttons for consistency
  Widget _buildGameModeButton(BuildContext context, String title, String routeName, Color color, IconData icon) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(title),
      onPressed: () {
        Navigator.pushNamed(context, routeName);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        minimumSize: const Size(double.infinity, 50), // Make buttons take full width
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Softer corners
      ),
    );
  }
}
