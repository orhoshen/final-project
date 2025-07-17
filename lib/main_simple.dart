import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/computer_mode_screen.dart';
import 'screens/player_mode_screen.dart';
import 'screens/sound_test_screen.dart';
import 'screens/basic_sound_test_screen.dart';
import 'screens/fallback_sound_screen.dart';
import 'screens/multiplayer_main_screen.dart';
import 'screens/server_connection_test_screen.dart';
import 'screens/testing_hub_screen.dart';
import 'theme.dart';

// Minimal main function for testing
Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Load environment variables
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('Environment variables loaded');
    } catch (e) {
      debugPrint('Error loading .env: $e');
    }
    
    runApp(const SimpleApp());
  } catch (e) {
    debugPrint('Error in main: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    ));
  }
}

class SimpleApp extends StatelessWidget {
  const SimpleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piano Memory',
      theme: appTheme,
      home: const SimpleMainShell(),
      routes: {
        '/computer_mode': (context) => const ComputerModeScreen(),
        '/player_mode': (context) => const PlayerModeScreen(),
        '/sound_test': (context) => const SoundTestScreen(),
        '/basic_sound_test': (context) => const BasicSoundTestScreen(),
        '/fallback_sound_test': (context) => const FallbackSoundScreen(),
        '/multiplayer': (context) => const MultiplayerMainScreen(),
        '/server_test': (context) => const ServerConnectionTestScreen(),
      },
    );
  }
}

class SimpleMainShell extends StatefulWidget {
  const SimpleMainShell({super.key});

  @override
  State<SimpleMainShell> createState() => _SimpleMainShellState();
}

class _SimpleMainShellState extends State<SimpleMainShell> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    SimpleLandingPage(),
    TestingHubScreen(),
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

class SimpleLandingPage extends StatelessWidget {
  const SimpleLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Piano Memory Game'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
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
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}