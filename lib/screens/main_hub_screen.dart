import 'package:flutter/material.dart';

import '../services/service_provider_hub.dart';
import 'computer_mode_screen.dart';
import 'player_mode_screen.dart';
import 'simple_multiplayer_screen.dart';
import 'testing_hub_screen.dart';

class MainHubScreen extends StatefulWidget {
  const MainHubScreen({super.key});

  @override
  State<MainHubScreen> createState() => _MainHubScreenState();
}

class _MainHubScreenState extends State<MainHubScreen> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const PlayerModeScreen(),
    const ComputerModeScreen(),
    const SimpleMultiplayerScreen(),
    const ServiceProviderHub(child: TestingHubScreen()), // For debug/testing purposes
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
            icon: Icon(Icons.person),
            label: 'Player Mode',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.computer),
            label: 'Computer Mode',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Multiplayer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science),
            label: 'Testing',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // To show all labels
      ),
    );
  }
}
