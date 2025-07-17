import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../services/server_manager.dart';
import '../widgets/piano_keyboard.dart';

/// Simplified complex multiplayer that works like simple multiplayer but with game flow
class SimpleComplexMultiplayerScreen extends StatefulWidget {
  const SimpleComplexMultiplayerScreen({super.key});

  @override
  State<SimpleComplexMultiplayerScreen> createState() => _SimpleComplexMultiplayerScreenState();
}

class _SimpleComplexMultiplayerScreenState extends State<SimpleComplexMultiplayerScreen> {
  // Socket.IO connection
  socket_io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _connectionStatus = 'Disconnected';
  
  // Player info
  String _playerName = '';
  String _playerId = '';
  String _roomId = '';
  
  // Game state
  bool _isInRoom = false;
  List<String> _roomPlayers = [];
  String _gameStatus = 'Waiting to connect...';
  String _gameState = 'waiting';
  int _currentRound = 1;
  int _totalRounds = 3;
  bool _isActivePlayer = false;
  bool _isChallengePlayer = false;
  
  // Melody recording
  List<int> _recordedMelody = [];
  bool _isRecording = false;
  int? _highlightedNote;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkServerAndConnect();
  }

  @override
  void dispose() {
    _disconnect();
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _checkServerAndConnect() async {
    setState(() {
      _connectionStatus = 'Checking server...';
    });

    // Skip server health check for now - go directly to WebSocket connection
    developer.log('Skipping HTTP health check, attempting direct WebSocket connection');
    _connectToSocket();
  }

  void _connectToSocket() {
    if (_isConnecting || _isConnected) return;

    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Connecting...';
    });

    developer.log('Attempting to connect to Socket.IO server at http://localhost:5001');

    try {
      _socket = socket_io.io(
        'http://localhost:5001',
        socket_io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setTimeout(10000)
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      developer.log('Socket.IO client created, setting up listeners...');
      _setupSocketListeners();
      
      developer.log('Calling socket.connect()...');
      _socket!.connect();

      // Add a timeout to catch connection failures
      Timer(const Duration(seconds: 15), () {
        if (!_isConnected && _isConnecting && mounted) {
          developer.log('Connection timeout after 15 seconds');
          setState(() {
            _isConnecting = false;
            _connectionStatus = 'Connection timeout';
            _gameStatus = 'Connection timed out - please check server';
          });
        }
      });

    } catch (e) {
      developer.log('Socket connection error: $e');
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionStatus = 'Connection failed: $e';
          _gameStatus = 'Failed to connect to server';
        });
      }
    }
  }

  void _setupSocketListeners() {
    _socket!.onConnect((_) {
      developer.log('Socket connected');
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _connectionStatus = 'Connected';
          _gameStatus = 'Connected! Enter your name to start.';
        });
      }
    });

    _socket!.onDisconnect((_) {
      developer.log('Socket disconnected');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Disconnected';
          _gameStatus = 'Disconnected from server';
          _isInRoom = false;
          _roomPlayers.clear();
        });
      }
    });

    _socket!.on('connected', (data) {
      developer.log('Received connected event: $data');
      if (data['player_id'] != null && mounted) {
        setState(() {
          _playerId = data['player_id'];
        });
      }
    });

    _socket!.on('room_update', (data) {
      developer.log('Room update: $data');
      if (data['room'] != null && mounted) {
        final room = data['room'];
        setState(() {
          _roomId = room['id'] ?? '';
          _roomPlayers = (room['players'] as List? ?? [])
              .map((p) => p['name']?.toString() ?? 'Unknown')
              .toList();
          _isInRoom = true;
          _gameState = room['state'] ?? 'waiting';
          _currentRound = room['current_round'] ?? 1;
          _totalRounds = room['total_rounds'] ?? 3;
          
          // Check if current player is active or challenge player
          final activePlayerId = room['active_player'];
          final challengePlayerId = room['challenge_player'];
          _isActivePlayer = activePlayerId == _playerId;
          _isChallengePlayer = challengePlayerId == _playerId;
          
          _updateGameStatus();
        });
      }
    });

    _socket!.on('new_challenge', (data) {
      developer.log('New challenge: $data');
      if (mounted) {
        setState(() {
          _gameStatus = 'New challenge received! Try to match the melody.';
        });
      }
    });

    _socket!.on('score_update', (data) {
      developer.log('Score update: $data');
      if (mounted) {
        setState(() {
          _gameStatus = 'Score updated! Check the results.';
        });
      }
    });

    _socket!.onError((error) {
      developer.log('Socket error: $error');
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionStatus = 'Error: $error';
          _gameStatus = 'Connection error: $error';
        });
      }
    });

    _socket!.onConnectError((error) {
      developer.log('Socket connect error: $error');
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionStatus = 'Connect Error: $error';
          _gameStatus = 'Failed to connect: $error';
        });
      }
    });
  }

  void _updateGameStatus() {
    switch (_gameState) {
      case 'waiting':
        _gameStatus = 'Waiting for players (${_roomPlayers.length}/2)';
        break;
      case 'recording':
        if (_isActivePlayer) {
          _gameStatus = 'Your turn to record a melody!';
        } else {
          _gameStatus = 'Other player is recording...';
        }
        break;
      case 'replaying':
        if (_isChallengePlayer) {
          _gameStatus = 'Your turn to replay the melody!';
        } else {
          _gameStatus = 'Other player is replaying...';
        }
        break;
      case 'game_over':
        _gameStatus = 'Game Over!';
        break;
      default:
        _gameStatus = 'Round $_currentRound of $_totalRounds';
    }
  }

  void _disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    setState(() {
      _isConnected = false;
      _connectionStatus = 'Disconnected';
      _isInRoom = false;
    });
  }

  void _createRoom() {
    if (!_isConnected || _playerName.isEmpty) return;

    developer.log('Creating room for player: $_playerName');
    _socket!.emit('create_room', {
      'player_name': _playerName,
      'player_id': _playerId,
    });

    setState(() {
      _gameStatus = 'Creating room...';
    });
  }

  void _joinRoom() {
    if (!_isConnected || _playerName.isEmpty || _roomController.text.isEmpty) return;

    developer.log('Joining room: ${_roomController.text}');
    _socket!.emit('join_room', {
      'room_id': _roomController.text,
      'player_name': _playerName,
      'player_id': _playerId,
    });

    setState(() {
      _gameStatus = 'Joining room...';
    });
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordedMelody.clear();
      _gameStatus = 'Recording melody... Press notes on the piano.';
    });
  }

  void _stopRecording() {
    if (!_isRecording || _recordedMelody.isEmpty) return;

    setState(() {
      _isRecording = false;
      _gameStatus = 'Melody recorded! Submitting to room...';
    });

    // Submit melody to room
    _socket!.emit('record_melody', {
      'room_id': _roomId,
      'player_id': _playerId,
      'melody': {
        'notes': _recordedMelody,
        'timings': [], // Simplified - no timing data
        'durations': [], // Simplified - no duration data
      }
    });
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

  Widget _buildGameContent() {
    if (!_isInRoom) {
      // Lobby screen
      return Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multiplayer Piano Challenge',
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
                          onPressed: _isConnected && _playerName.isNotEmpty ? _createRoom : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Create Room'),
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
                        onPressed: _isConnected && _playerName.isNotEmpty && _roomController.text.isNotEmpty
                            ? _joinRoom
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Join'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Game room screen
      return Column(
        children: [
          // Game controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room: $_roomId - Round $_currentRound of $_totalRounds',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Players: ${_roomPlayers.join(", ")}'),
                  const SizedBox(height: 8),
                  Text('Status: $_gameStatus'),
                  const SizedBox(height: 16),
                  
                  // Game state specific controls
                  if (_gameState == 'recording' && _isActivePlayer) ...[
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
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complex Multiplayer'),
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
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: _isConnected ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _connectionStatus,
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
                    Text('Connection: $_connectionStatus'),
                    Text('Player ID: ${_playerId.isEmpty ? "Not assigned" : _playerId}'),
                    Text('Room: ${_roomId.isEmpty ? "Not in room" : _roomId}'),
                    Text('Game: $_gameStatus'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Game content (lobby or game room)
            _buildGameContent(),

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
                    Text('WebSocket URL: http://localhost:5001'),
                    Text('Transport: WebSocket'),
                    Text('Game State: $_gameState'),
                    Text('Is Active Player: $_isActivePlayer'),
                    Text('Is Challenge Player: $_isChallengePlayer'),
                    ElevatedButton(
                      onPressed: _checkServerAndConnect,
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