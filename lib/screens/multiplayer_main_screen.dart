import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/multiplayer_service.dart';
import 'multiplayer_room_screen.dart';

/// Main screen for multiplayer mode with options to create or join a room
class MultiplayerMainScreen extends StatefulWidget {
  const MultiplayerMainScreen({super.key});

  @override
  State<MultiplayerMainScreen> createState() => _MultiplayerMainScreenState();
}

class _MultiplayerMainScreenState extends State<MultiplayerMainScreen> {
  final _nameController = TextEditingController();
  final _roomIdController = TextEditingController();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Set default server URL for display, actual connection uses env var
    // _serverUrlController.text = 'http://localhost:5001'; // This line is removed
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomIdController.dispose();
    // _serverUrlController.dispose(); // This line is removed
    super.dispose();
  }

  Future<void> _createRoom() async {
    final service = Provider.of<MultiplayerService?>(context, listen: false);
    if (service == null || !service.isConnected) {
      setState(() {
        _errorMessage = 'Not connected to server. Please try again later.';
      });
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }
    await service.setPlayerName(_nameController.text.trim());

    setState(() {
      _errorMessage = '';
    });

    try {
      final success = await service.createRoom();

      if (success) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MultiplayerRoomScreen(),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to create room';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _joinRoom() async {
    final service = Provider.of<MultiplayerService?>(context, listen: false);
    if (service == null || !service.isConnected) {
      setState(() {
        _errorMessage = 'Not connected to server. Please try again later.';
      });
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }
    await service.setPlayerName(_nameController.text.trim());

    if (_roomIdController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a room ID';
      });
      return;
    }

    setState(() {
      _errorMessage = '';
    });

    try {
      final success = await service.joinRoom(_roomIdController.text.trim());

      if (success) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MultiplayerRoomScreen(),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to join room. Check if the room ID is correct.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer Piano Game'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Consumer<MultiplayerService?>(
            builder: (context, multiplayerService, _) {
              // Show loading if service is not ready
              if (multiplayerService == null) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Connecting to server...'),
                    ],
                  ),
                );
              }

              // Initialize name controller only once when the service is first available
              if (_nameController.text.isEmpty &&
                  multiplayerService.playerName.isNotEmpty) {
                _nameController.text = multiplayerService.playerName;
              }

              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Multiplayer Piano Challenge',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),

                    // Player name input
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Create room button
                    ElevatedButton(
                      onPressed: (multiplayerService.isCreating) ? null : _createRoom,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: (multiplayerService.isCreating)
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create New Room', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 20),

                    const Text('- OR -', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 20),

                    // Room ID input
                    TextField(
                      controller: _roomIdController,
                      decoration: const InputDecoration(
                        labelText: 'Room ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.meeting_room),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Join room button
                    ElevatedButton(
                      onPressed: (multiplayerService.isJoining) ? null : _joinRoom,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: (multiplayerService.isJoining)
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Join Room', style: TextStyle(fontSize: 16)),
                    ),

                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
