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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  
  bool _isConnecting = false;
  String _errorMessage = '';
  bool _showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final service = Provider.of<MultiplayerService>(context, listen: false);
    
    // Set default server URL
    _serverUrlController.text = 'http://localhost:5001';
    
    // Load existing player name if available
    setState(() {
      _nameController.text = service.playerName;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomIdController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = '';
    });

    try {
      final service = Provider.of<MultiplayerService>(context, listen: false);
      
      // Set player name
      await service.setPlayerName(_nameController.text.trim());
      
      // Connect to WebSocket server
      final connected = await service.connect(
        serverUrl: _serverUrlController.text.trim(),
      );
      
      if (!connected) {
        setState(() {
          _errorMessage = 'Failed to connect to the server';
          _isConnecting = false;
        });
        return;
      }
      
      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isConnecting = false;
      });
    }
  }

  Future<void> _createRoom() async {
    if (!_validateAndConnect()) return;

    setState(() {
      _errorMessage = '';
    });

    try {
      final service = Provider.of<MultiplayerService>(context, listen: false);
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
    if (!_validateAndConnect()) return;
    
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
      final service = Provider.of<MultiplayerService>(context, listen: false);
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

  bool _validateAndConnect() {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return false;
    }

    final service = Provider.of<MultiplayerService>(context, listen: false);
    
    if (!service.isConnected) {
      _connect();
      return false;
    }
    
    return true;
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
          child: Consumer<MultiplayerService>(
            builder: (context, multiplayerService, _) {
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
                      onPressed: multiplayerService.isCreating ? null : _createRoom,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: multiplayerService.isCreating
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
                      onPressed: multiplayerService.isJoining ? null : _joinRoom,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: multiplayerService.isJoining
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
                    
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAdvancedOptions = !_showAdvancedOptions;
                        });
                      },
                      child: Text(
                        _showAdvancedOptions ? 'Hide Advanced Options' : 'Show Advanced Options',
                      ),
                    ),
                    
                    if (_showAdvancedOptions) ...[
                      const SizedBox(height: 20),
                      TextField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Server URL',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.dns),
                          helperText: 'Default: http://localhost:5001',
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isConnecting ? null : _connect,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: _isConnecting
                            ? const CircularProgressIndicator()
                            : const Text('Connect to Server', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        multiplayerService.isConnected 
                            ? 'Connected to server'
                            : 'Not connected to server',
                        style: TextStyle(
                          color: multiplayerService.isConnected ? Colors.green : Colors.red,
                        ),
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