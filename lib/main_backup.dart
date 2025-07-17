import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/basic_sound_test_screen.dart';
import 'screens/computer_mode_screen.dart';
import 'screens/fallback_sound_screen.dart';
import 'screens/landing_page.dart';
import 'screens/multiplayer_main_screen.dart';
import 'screens/player_mode_screen.dart';
import 'screens/server_connection_test_screen.dart';
import 'screens/sound_test_screen.dart';
import 'screens/testing_hub_screen.dart';
import 'services/enhanced_websocket_service.dart';
import 'services/firebase_game_service.dart';
import 'services/multiplayer_service.dart';
import 'services/server_manager.dart';
import 'theme.dart';

// Original main function
Future<void> main() async {
  try {
    // Ensure bindings are initialized before any async work
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('Environment variables loaded successfully');
    } catch (e) {
      debugPrint('Error loading .env file: $e');
      // Continue without .env file - use defaults
    }

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
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
      // Continue without Firebase if initialization fails
    }

    // Initialize server manager
    try {
      await ServerManager.instance.initialize();
      debugPrint('Server manager initialized successfully');
    } catch (e) {
      debugPrint('Server manager initialization error: $e');
      // Continue without server manager if initialization fails
    }

    // Initialize Firebase game service
    try {
      await FirebaseGameService.instance.initialize();
      debugPrint('Firebase game service initialized successfully');
    } catch (e) {
      debugPrint('Firebase game service initialization error: $e');
      // Continue without Firebase game service if initialization fails
    }

    debugPrint('Starting MyApp...');
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Critical error in main: $e');
    // Fallback to a basic app
    runApp(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text('Initialization error: $e'),
        ),
      ),
    ));
  }
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
    try {
      // Get the server URL from environment variables
      final serverUrl = dotenv.env['FLASK_SERVER_URL'] ?? 'http://localhost:5001';
      debugPrint('Building MyApp with server URL: $serverUrl');

      return MultiProvider(
        providers: [
          // Provide the ServerManager instance
          ChangeNotifierProvider<ServerManager>.value(
            value: ServerManager.instance,
          ),
          // Provide the Firebase Game Service instance
          ChangeNotifierProvider<FirebaseGameService>.value(
            value: FirebaseGameService.instance,
          ),
          // Asynchronously create and provide the Enhanced WebSocketService
          FutureProvider<EnhancedWebSocketService?>(
            create: (_) {
              debugPrint('Creating EnhancedWebSocketService...');
              return EnhancedWebSocketService.create(serverUrl);
            },
            initialData: null, // Start with null data
            catchError: (context, error) {
              // Handle connection errors gracefully
              debugPrint("Failed to create EnhancedWebSocketService: $error");
              return null; // Provide null on error
            },
          ),
          // MultiplayerService depends on the result of the FutureProvider
          ChangeNotifierProxyProvider<EnhancedWebSocketService?, MultiplayerService?>(
            create: (context) => null, // Start with null, will be created in update
            update: (context, wsService, previous) {
              try {
                if (wsService == null) return null;

                // If the service is being created for the first time, initialize it.
                if (previous == null) {
                  debugPrint('Creating MultiplayerService...');
                  final newService = MultiplayerService(wsService);
                  newService.initialize(); // Initialize listeners
                  return newService;
                }

                // If the wsService instance somehow changes, we could create a new service,
                // but for now, we assume it's stable once created.
                return previous;
              } catch (e) {
                debugPrint('Error creating MultiplayerService: $e');
                return null;
              }
            },
          ),
        ],
        child: MaterialApp(
          title: 'Piano Memory',
          theme: appTheme, // Restore custom theme
          home: const MainAppShell(), // Changed to MainAppShell
          routes: {
            // Restore routes
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
    } catch (e) {
      debugPrint('Error in MyApp build: $e');
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('App initialization error'),
                const SizedBox(height: 16),
                Text('Error: $e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Try to restart the app
                    debugPrint('Attempting to restart app...');
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
