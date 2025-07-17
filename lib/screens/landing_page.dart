import 'package:flutter/material.dart';

import '../widgets/quick_save_widget.dart';
import '../widgets/server_status_widget.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Piano Memory Game'),
        automaticallyImplyLeading: false, // No back button if it's a main tab view
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: QuickSaveIndicator(),
          ),
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: ServerStatusIndicator(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            // Added padding for better spacing
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
                
                const SizedBox(height: 32),
                
                // Game Statistics Section
                const GameStatsWidget(),
                
                const SizedBox(height: 16),
                
                // Server Status Section
                const ServerStatusWidget(showControls: true),
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
