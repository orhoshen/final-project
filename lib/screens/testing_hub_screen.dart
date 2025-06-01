import 'package:flutter/material.dart';

class TestingHubScreen extends StatelessWidget {
  const TestingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing Hub'),
        automaticallyImplyLeading: false, // No back button in the AppBar for a main tab screen
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildTestButton(
            context,
            title: 'Sound Test',
            routeName: '/sound_test',
            icon: Icons.audiotrack,
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          _buildTestButton(
            context,
            title: 'Basic Sound Test',
            routeName: '/basic_sound_test',
            icon: Icons.music_note,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildTestButton(
            context,
            title: 'Fallback Sound Test',
            routeName: '/fallback_sound_test',
            icon: Icons.speaker_notes_off,
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 12),
          _buildTestButton(
            context,
            title: 'Server Connection Test',
            routeName: '/server_test',
            icon: Icons.network_check,
            color: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(BuildContext context, {
    required String title,
    required String routeName,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(title),
      onPressed: () {
        Navigator.pushNamed(context, routeName);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        textStyle: const TextStyle(fontSize: 16),
        minimumSize: const Size(double.infinity, 50), // Make buttons take full width
      ),
    );
  }
} 