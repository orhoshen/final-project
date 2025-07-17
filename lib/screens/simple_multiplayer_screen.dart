import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/game_room.dart';
import '../services/enhanced_websocket_service.dart';
import '../services/multiplayer_service.dart';
import '../widgets/piano_keyboard.dart';

/// Multiplayer screen with real-time WebSocket communication
class SimpleMultiplayerScreen extends StatefulWidget {
  const SimpleMultiplayerScreen({super.key});

  @override
  State<SimpleMultiplayerScreen> createState() => _SimpleMultiplayerScreenState();
}

class _SimpleMultiplayerScreenState extends State<SimpleMultiplayerScreen> {
  // Services
  EnhancedWebSocketService? _websocketService;
  MultiplayerService? _multiplayerService;
  
  // Player info
  String _playerName = '';
  
  // Game state
  String _gameStatus = 'Connecting...';
  
  // Melody recording
  final List<int> _recordedMelody = [];
  bool _isRecording = false;
  int? _highlightedNote;
  
  // Stream subscriptions
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _roomUpdateSubscription;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _roomUpdateSubscription?.cancel();
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      String serverUrl = dotenv.env['FLASK_SERVER_URL'] ?? 'http://localhost:5001';
      developer.log('Initializing WebSocket service: $serverUrl');
      
      // Create WebSocket service
      _websocketService = await EnhancedWebSocketService.create(serverUrl);
      
      // Create multiplayer service
      _multiplayerService = MultiplayerService(_websocketService!);
      _multiplayerService!.initialize();
      
      // Setup listeners
      _setupListeners();
      
      setState(() {
        _gameStatus = _websocketService?.isConnected == true 
            ? 'Connected! Enter your name to start.' 
            : 'Connecting to server...';
      });
      
      developer.log('Services initialized successfully');
    } catch (e) {
      developer.log('Service initialization error: $e');
      setState(() {
        _gameStatus = 'Failed to initialize services: $e';
      });
    }
  }

  void _setupListeners() {
    // Listen to connection state changes
    _connectionStateSubscription = _websocketService?.onConnectionState.listen((state) {
      if (mounted) {
        setState(() {
          final isConnected = state['isConnected'] as bool? ?? false;
          final isConnecting = state['isConnecting'] as bool? ?? false;
          final lastError = state['lastError'] as String?;
          
          if (isConnected) {
            _gameStatus = 'Connected! Enter your name to start.';
          } else if (isConnecting) {
            _gameStatus = 'Connecting to server...';
          } else if (lastError != null) {
            _gameStatus = 'Connection failed: $lastError';
          } else {
            _gameStatus = 'Disconnected';
          }
        });
      }
    });
    
    // Listen to multiplayer service state changes
    _multiplayerService?.addListener(_onMultiplayerServiceChanged);
  }
  
  void _onMultiplayerServiceChanged() {
    if (!mounted) return;
    
    setState(() {
      final room = _multiplayerService?.currentRoom;
      final isConnected = _multiplayerService?.isConnected ?? false;
      final isInRoom = _multiplayerService?.isInRoom ?? false;
      
      if (!isConnected) {
        _gameStatus = 'Disconnected from server';
      } else if (!isInRoom) {
        _gameStatus = 'Connected! Enter your name to start.';
      } else if (room != null) {
        final playerNames = room.players.map((p) => p.name).toList();
        _gameStatus = 'In room ${room.id} with ${room.players.length} players: ${playerNames.join(", ")}';
        
        // Check for game state changes
        if (room.state == GameState.replaying && (_multiplayerService?.isChallengePlayer ?? false)) {
          _gameStatus += '\nYour turn to replay the melody!';
        } else if (room.state == GameState.recording && (_multiplayerService?.isActivePlayer ?? false)) {
          _gameStatus += '\nYour turn to record a melody!';
        } else {
          _gameStatus += '\nWaiting for other player...';
        }
      }
    });
  }


  Future<void> _createRoom() async {
    if (_multiplayerService?.isConnected != true || _playerName.isEmpty) return;

    setState(() {
      _gameStatus = 'Creating room...';
    });

    try {
      developer.log('Creating room for player: $_playerName');
      await _multiplayerService!.setPlayerName(_playerName);
      final success = await _multiplayerService!.createRoom();
      
      if (success && _multiplayerService?.currentRoom != null) {
        setState(() {
          _gameStatus = 'Room created! Room ID: ${_multiplayerService!.currentRoom!.id}';
        });
        developer.log('Room created: ${_multiplayerService!.currentRoom!.id}');
      } else {
        setState(() {
          _gameStatus = 'Failed to create room';
        });
      }
    } catch (e) {
      developer.log('Error creating room: $e');
      setState(() {
        _gameStatus = 'Error creating room: $e';
      });
    }
  }

  Future<void> _joinRoom() async {
    if (_multiplayerService?.isConnected != true || _playerName.isEmpty || _roomController.text.isEmpty) return;

    setState(() {
      _gameStatus = 'Joining room...';
    });

    try {
      final roomId = _roomController.text.trim();
      developer.log('Joining room: $roomId');
      await _multiplayerService!.setPlayerName(_playerName);
      final success = await _multiplayerService!.joinRoom(roomId);
      
      if (success && _multiplayerService?.currentRoom != null) {
        setState(() {
          _gameStatus = 'Joined room successfully! Room ID: ${_multiplayerService!.currentRoom!.id}';
        });
        developer.log('Joined room: ${_multiplayerService!.currentRoom!.id}');
      } else {
        setState(() {
          _gameStatus = 'Failed to join room';
        });
      }
    } catch (e) {
      developer.log('Error joining room: $e');
      setState(() {
        _gameStatus = 'Error joining room: $e';
      });
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordedMelody.clear();
      _gameStatus = 'Recording melody... Press notes on the piano.';
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _recordedMelody.isEmpty) return;

    setState(() {
      _isRecording = false;
      _gameStatus = 'Melody recorded! Submitting to room...';
    });

    try {
      // Submit melody via multiplayer service
      final success = await _multiplayerService!.submitRecordedMelody(
        _recordedMelody,
        List.generate(_recordedMelody.length, (i) => i * 500), // Simple timing
        List.generate(_recordedMelody.length, (i) => 500), // Simple duration
      );
      
      if (success) {
        setState(() {
          _gameStatus = 'Melody submitted successfully! Waiting for other player...';
        });
        developer.log('Melody submitted successfully');
      } else {
        setState(() {
          _gameStatus = 'Failed to submit melody';
        });
      }
    } catch (e) {
      developer.log('Error submitting melody: $e');
      setState(() {
        _gameStatus = 'Error submitting melody: $e';
      });
    }
  }
  

  void _onNotePressed(int midiNote) {
    if (!_isRecording) return;

    setState(() {
      _recordedMelody.add(midiNote);
      _highlightedNote = midiNote;
    });

    // Auto-stop recording after 8 notes
    if (_recordedMelody.length >= 8) {
      _stopRecording();
    }
  }

  void _onNoteReleased(int midiNote) {
    if (_highlightedNote == midiNote) {
      setState(() {
        _highlightedNote = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Multiplayer'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    (_multiplayerService?.isConnected ?? false) ? Icons.wifi : Icons.wifi_off,
                    color: (_multiplayerService?.isConnected ?? false) ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (_multiplayerService?.isConnected ?? false) ? 'Connected' : 'Disconnected',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Connection: ${(_multiplayerService?.isConnected ?? false) ? "Connected" : "Disconnected"}'),
                    Text('Player ID: ${(_multiplayerService?.playerId.isEmpty ?? true) ? "Not assigned" : _multiplayerService?.playerId ?? "Unknown"}'),
                    Text('Room: ${_multiplayerService?.currentRoom?.id ?? "Not in room"}'),
                    Text('Game: $_gameStatus'),
                    if (_multiplayerService?.currentRoom != null) ...[
                      const SizedBox(height: 8),
                      Text('Room Active: ${_multiplayerService!.currentRoom!.state != GameState.waiting}'),
                      Text('Current Round: ${_multiplayerService!.currentRoom!.currentRound}'),
                      Text('Game State: ${_multiplayerService!.currentRoom!.state.toString().split('.').last}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Player setup section
            if (!(_multiplayerService?.isInRoom ?? false)) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Player Setup',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Your Name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _playerName = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (_multiplayerService?.isConnected ?? false) && _playerName.isNotEmpty && !(_multiplayerService?.isCreating ?? false) ? _createRoom : null,
                              child: Text((_multiplayerService?.isCreating ?? false) ? 'Creating...' : 'Create Room'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _roomController,
                              decoration: const InputDecoration(
                                labelText: 'Room ID',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: (_multiplayerService?.isConnected ?? false) && _playerName.isNotEmpty && _roomController.text.isNotEmpty && !(_multiplayerService?.isJoining ?? false)
                                ? _joinRoom
                                : null,
                            child: Text((_multiplayerService?.isJoining ?? false) ? 'Joining...' : 'Join'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Game section
            if (_multiplayerService?.isInRoom ?? false) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Game Controls',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (_recordedMelody.isNotEmpty) ...[
                        Text('Recorded melody: ${_recordedMelody.join(", ")}'),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _isRecording ? null : _startRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(_isRecording ? 'Recording...' : 'Start Recording'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isRecording && _recordedMelody.isNotEmpty ? _stopRecording : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Stop & Submit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Piano keyboard
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Piano',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: PianoKeyboard(
                        onNotePressed: _onNotePressed,
                        onNoteReleased: _onNoteReleased,
                        startingOctave: 3,
                        numberOfOctaves: 2,
                        showNoteLabels: true,
                        highlightedNote: _highlightedNote,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Debug section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Server URL: ${_websocketService?.serverUrl ?? "Not connected"}'),
                    Text('Transport: HTTP + WebSocket'),
                    Text('Retry Count: ${_websocketService?.retryCount ?? 0}'),
                    if (_websocketService?.lastError != null) ...[
                      const SizedBox(height: 4),
                      Text('Last Error: ${_websocketService?.lastError}', style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _websocketService?.reconnect,
                      child: const Text('Reconnect'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}