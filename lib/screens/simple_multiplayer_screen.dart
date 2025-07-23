import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/game_room.dart';
import '../services/enhanced_websocket_service.dart';
import '../services/midi_service.dart';
import '../services/multiplayer_service.dart';
import '../services/simple_audio_player.dart';
import '../widgets/analysis_report_widget.dart';
import '../widgets/piano_keyboard.dart';

/// Enhanced multiplayer screen with proper game flow matching Player Mode
class SimpleMultiplayerScreen extends StatefulWidget {
  const SimpleMultiplayerScreen({super.key});

  @override
  State<SimpleMultiplayerScreen> createState() => _SimpleMultiplayerScreenState();
}

/// Game states for multiplayer flow
enum MultiplayerGameState {
  playerRegistration, // Getting player name
  waitingForMatch, // Waiting to find/join a game
  gameStarting, // Both players connected, game initializing
  creatorPhase, // Current player creates melody
  melodyPlayback, // Reference melody plays for matcher
  matcherPhase, // Other player attempts to match
  roundScoring, // Showing results and scores
  gameComplete, // Final winner declaration
}

class _SimpleMultiplayerScreenState extends State<SimpleMultiplayerScreen> {
  // Services
  final MidiService _midiService = MidiService();
  final SimpleAudioPlayer _simpleAudio = SimpleAudioPlayer();
  EnhancedWebSocketService? _websocketService;
  MultiplayerService? _multiplayerService;

  // Game State Management
  MultiplayerGameState _gameState = MultiplayerGameState.playerRegistration;

  // Player info
  String _playerName = '';
  String _opponentName = '';
  String _myPlayerId = '';
  String _roomId = '';

  // Game progression
  int _roundNumber = 1;
  double _myScore = 0.0;
  double _opponentScore = 0.0;
  bool _isMyTurnToCreate = true; // Am I the creator this round?
  String _statusMessage = 'Enter your name to begin multiplayer.';

  // Melody data
  final List<int> _referenceSequence = [];
  final List<int> _attemptSequence = [];
  int? _highlightedNote;
  bool _isPlayingMelody = false;
  bool _isPlayingReference = false;

  // Repeat functionality
  int _repeatCount = 0;
  static const int _maxRepeats = 2;

  // Analytics
  Map<String, dynamic>? _lastComparisonDetails;
  int? _comparisonProcessingTimeMs;
  double? _lastMatchScore;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();

  // Stream subscriptions
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _roomUpdateSubscription;
  StreamSubscription? _challengeAvailableSubscription;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _roomUpdateSubscription?.cancel();
    _challengeAvailableSubscription?.cancel();
    _nameController.dispose();
    _roomController.dispose();
    _midiService.dispose();
    
    // Properly dispose of services to prevent setState after dispose
    _multiplayerService?.dispose();
    _websocketService?.dispose();
    
    super.dispose();
  }

  Future<void> _initServices() async {
    await _midiService.initialize();

    try {
      String serverUrl = dotenv.env['FLASK_SERVER_URL'] ?? 'http://localhost:5001';
      developer.log('Initializing WebSocket service: $serverUrl');

      if (mounted) {
        setState(() {
          _statusMessage = 'Connecting to server... (this may take up to 30 seconds)';
        });
      }

      // Create WebSocket service with retry logic
      _websocketService = await EnhancedWebSocketService.create(serverUrl);

      // Wait for connection or timeout
      int retries = 0;
      while (!_websocketService!.isConnected && retries < 3) {
        developer.log('Connection attempt ${retries + 1}/3');
        await Future.delayed(const Duration(seconds: 10));
        retries++;
      }

      if (!_websocketService!.isConnected) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Failed to connect to server. Please try refreshing the page.';
          });
        }
        return;
      }

      // Create multiplayer service
      _multiplayerService = MultiplayerService(_websocketService!);

      // CRITICAL: Initialize the multiplayer service to set up WebSocket listeners
      _multiplayerService!.initialize();
      developer.log('MultiplayerService initialized and listeners set up');

      _setupEventListeners();

      if (mounted) {
        setState(() {
          _gameState = MultiplayerGameState.playerRegistration;
          _statusMessage = 'Connected! Enter your name to begin multiplayer.';
        });
      }

      developer.log('Services initialized successfully');
    } catch (e) {
      developer.log('Service initialization error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to initialize services: $e. Please refresh the page.';
        });
      }
    }
  }

  void _setupEventListeners() {
    // Listen to connection state changes
    _connectionStateSubscription = _websocketService?.onConnectionState.listen((state) {
      if (mounted) {
        setState(() {
          final isConnected = state['isConnected'] as bool? ?? false;
          if (!isConnected && _gameState != MultiplayerGameState.playerRegistration) {
            _statusMessage = 'Connection lost. Reconnecting...';
          }
        });
      }
    });

    // Listen to room updates for game state changes
    _roomUpdateSubscription = _multiplayerService?.roomUpdates.listen((room) {
      if (mounted && room != null) {
        _handleRoomUpdate(room);
      }
    });

    // Listen to challenge availability
    _challengeAvailableSubscription = _multiplayerService?.challengeAvailable.listen((melody) {
      if (mounted) {
        _handleChallengeAvailable(melody);
      }
    });
  }

  void _handleRoomUpdate(GameRoom room) {
    print('🎮 Room Update: ${room.players.length} players, state: ${room.state}');
    if (!mounted) return;
    setState(() {
      _roomId = room.id;

      // Update player info
      if (room.players.length >= 2) {
        try {
          // Find opponent player
          final otherPlayer = room.players.firstWhere(
            (p) => p.id != _myPlayerId,
            orElse: () => throw StateError('Opponent not found'),
          );
          _opponentName = otherPlayer.name;
          print('🎮 Found opponent: $_opponentName (opponent ID: ${otherPlayer.id})');

          // Find my player info
          final myPlayer = room.players.firstWhere(
            (p) => p.id == _myPlayerId,
            orElse: () => throw StateError('My player not found'),
          );
          _myScore = myPlayer.score;
          _opponentScore = otherPlayer.score;
          print('🎮 Scores updated - Me: $_myScore, Opponent: $_opponentScore');
        } catch (e) {
          print('🔥 Error finding players: $e');
          print('🔥 My Player ID: $_myPlayerId');
          print('🔥 Room Players: ${room.players.map((p) => '${p.name}(${p.id})').toList()}');

          // Fallback: Use names instead of IDs for now
          if (room.players.length >= 2) {
            final otherPlayer = room.players.firstWhere((p) => p.name != _playerName);
            _opponentName = otherPlayer.name;
            print('🎮 Fallback: Found opponent by name: $_opponentName');
          }
        }
      } else {
        print('🎮 Still waiting for second player...');
      }

      // Update game state based on room state
      _updateGameStateFromRoom(room);

      // Challenge detection is now handled by the challengeAvailable stream event
      // No need for manual polling here
    });
  }

  void _handleChallengeAvailable(Melody melody) {
    print('🎵 Challenge available event received: ${melody.notes.length} notes');
    print('🎵 Current game state: $_gameState');
    print('🎵 Current turn player: ${_multiplayerService?.currentRoom?.activePlayer?.id}');
    print('🎵 My player ID: $_myPlayerId');
    print('🎵 Did I create this melody: $_isMyTurnToCreate');

    // Only play challenge if:
    // 1. I'm in the melodyPlayback state waiting for a challenge
    // 2. I'm NOT the current turn player (the matcher, not creator)
    // 3. I'm NOT the one who created this melody
    if (_gameState == MultiplayerGameState.melodyPlayback &&
        _multiplayerService?.currentRoom?.activePlayer?.id != _myPlayerId &&
        !_isMyTurnToCreate) {
      print('🎵 Auto-starting melody playback since I should be matching');
      _playReceivedChallenge(melody);
    } else {
      print('🎵 Ignoring challenge event - wrong player, wrong state, or I created this melody');
      print(
          '🎵 Reason: state=$_gameState, isCurrentPlayer=${_multiplayerService?.currentRoom?.activePlayer?.id == _myPlayerId}, isMyTurnToCreate=$_isMyTurnToCreate');
    }
  }

  Future<void> _playReceivedChallenge(Melody melody) async {
    print('🎵 Playing received challenge melody: ${melody.notes.length} notes');
    print('🎵 Old sequence length before clearing: ${_referenceSequence.length}');

    if (mounted) {
      setState(() {
        // Explicitly clear everything first
        _referenceSequence.clear();
        _attemptSequence.clear();
        _highlightedNote = null;

        // Set new melody
        _referenceSequence.addAll(melody.notes);
        _statusMessage = 'Listen to the melody...';
      });
    }

    print('🎵 New sequence length after setting: ${_referenceSequence.length}');
    print('🎵 New sequence notes: ${_referenceSequence.join(", ")}');

    // Auto-play the melody after a short delay
    await Future.delayed(const Duration(milliseconds: 500));
    await _playReferenceMelody(isFirstPlayback: true);

    if (mounted) {
      setState(() {
        _gameState = MultiplayerGameState.matcherPhase;
        _statusMessage = 'Your turn: Match the melody!';
      });
    }
  }

  void _updateGameStateFromRoom(GameRoom room) {
    print('🎮 _updateGameStateFromRoom called');
    print('🎮 Room state: ${room.state}, active player: ${room.activePlayer?.id}');
    print('🎮 My player ID: $_myPlayerId');
    print('🎮 Is it my turn? ${room.activePlayer?.id == _myPlayerId}');

    // PRESERVE roundScoring state - don't let WebSocket events override it
    if (_gameState == MultiplayerGameState.roundScoring) {
      print('🎮 Preserving roundScoring state, ignoring room state update');
      return; // Don't override when showing analysis report
    }

    if (room.players.length < 2) {
      _gameState = MultiplayerGameState.waitingForMatch;
      _statusMessage = 'Waiting for another player to join...';
      return;
    }

    switch (room.state) {
      case GameState.waiting:
        if (_gameState == MultiplayerGameState.waitingForMatch) {
          _gameState = MultiplayerGameState.gameStarting;
          _statusMessage = 'Game starting! Get ready...';
          // Auto-start first round after a delay
          Future.delayed(const Duration(seconds: 2), _startNextRound);
        }
        break;

      case GameState.recording:
        if (room.activePlayer?.id == _myPlayerId) {
          print('🎮 My turn to create melody - transitioning to creatorPhase for Player $_myPlayerId');
          _gameState = MultiplayerGameState.creatorPhase;
          _statusMessage = 'Your turn: Create a melody';
          _isMyTurnToCreate = true;
        } else {
          print('🎮 Opponent turn to create melody - waiting for ${room.activePlayer?.name}');
          _gameState = MultiplayerGameState.waitingForMatch;
          _statusMessage = '${room.activePlayer?.name ?? "Opponent"} is creating a melody...';
          _isMyTurnToCreate = false;
        }
        break;

      case GameState.replaying:
        // Check if I'm the one who needs to replay/match the melody
        // The current turn player CREATED the challenge, the OTHER player should match
        if (room.activePlayer?.id != _myPlayerId) {
          // I need to match the melody (I'm NOT the active/current turn player)
          print('🎮 My turn to match melody - transitioning to melodyPlayback state for Player $_myPlayerId');
          _gameState = MultiplayerGameState.melodyPlayback;
          _statusMessage = 'Listen to the melody...';
          _isMyTurnToCreate = false; // I'm matching, not creating
          _fetchAndPlayChallenge();
        } else {
          // I created the melody, waiting for opponent to match
          print('🎮 I created the melody, waiting for opponent to match');
          _gameState = MultiplayerGameState.waitingForMatch;
          _statusMessage = 'Waiting for $_opponentName to match your melody...';
          _isMyTurnToCreate = true; // I was the creator this round
        }
        break;

      case GameState.gameOver:
        _gameState = MultiplayerGameState.gameComplete;
        _determineWinner();
        break;

      default:
        break;
    }
  }

  void _startNextRound() {
    if (!mounted) return;
    setState(() {
      _roundNumber++;
      _referenceSequence.clear();
      _attemptSequence.clear();
      _lastComparisonDetails = null;
      _lastMatchScore = null;
      _repeatCount = 0;

      // The server determines whose turn it is
      // We'll update based on room state
    });
  }

  Future<void> _fetchAndPlayChallenge() async {
    print('🎵 _fetchAndPlayChallenge called, checking for challenge...');

    if (_multiplayerService?.currentRoom?.currentChallenge != null) {
      final challenge = _multiplayerService!.currentRoom!.currentChallenge!;
      print('🎵 Challenge found immediately: ${challenge.notes.length} notes');
      await _playReceivedChallenge(challenge);
    } else {
      print('🎵 No challenge available yet, waiting for challenge event...');
      setState(() {
        _statusMessage = 'Waiting for challenge melody...';
        // Stay in melodyPlayback state so the challenge event can trigger playback
        _gameState = MultiplayerGameState.melodyPlayback;
      });

      // Note: The challenge will be automatically played when the challengeAvailable event fires
      // This happens in _handleChallengeAvailable method
    }
  }

  void _determineWinner() {
    if (!mounted) return;
    setState(() {
      if (_myScore > _opponentScore) {
        _statusMessage = '🎉 You won! Final score: $_myScore - $_opponentScore';
      } else if (_opponentScore > _myScore) {
        _statusMessage = '😔 $_opponentName won! Final score: $_myScore - $_opponentScore';
      } else {
        _statusMessage = '🤝 It\'s a tie! Final score: $_myScore - $_opponentScore';
      }
    });
  }

  // UI Event Handlers
  Future<void> _joinGame() async {
    if (_playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your name first!')));
      return;
    }

    setState(() {
      _gameState = MultiplayerGameState.waitingForMatch;
      _statusMessage = 'Looking for a game...';
    });

    try {
      await _multiplayerService!.setPlayerName(_playerName);

      if (_roomController.text.isNotEmpty) {
        // Join specific room
        final success = await _multiplayerService!.joinRoom(_roomController.text);
        if (success) {
          _myPlayerId = _multiplayerService!.playerId;
          print('🎮 Room joined successfully! Room ID: ${_roomController.text}');
          print('🎮 My Player ID: $_myPlayerId');
        } else {
          setState(() {
            _statusMessage = 'Failed to join room. Please try again.';
            _gameState = MultiplayerGameState.playerRegistration;
          });
        }
      } else {
        // Create new room
        final success = await _multiplayerService!.createRoom();
        if (success) {
          _myPlayerId = _multiplayerService!.playerId;
          print('🎮 Room created successfully! Room ID: ${_multiplayerService!.currentRoom?.id}');
          print('🎮 My Player ID: $_myPlayerId');
        } else {
          setState(() {
            _statusMessage = 'Failed to create room. Please try again.';
            _gameState = MultiplayerGameState.playerRegistration;
          });
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _gameState = MultiplayerGameState.playerRegistration;
      });
    }
  }

  void _onNotePressed(int midiNote) {
    if (_gameState != MultiplayerGameState.creatorPhase && _gameState != MultiplayerGameState.matcherPhase) {
      return;
    }

    if (_isPlayingMelody) return;

    _midiService.playMidiNote(midiNote).catchError((e) => _simpleAudio.playPianoNote(midiNote));

    if (!mounted) return;
    setState(() {
      if (_gameState == MultiplayerGameState.creatorPhase) {
        _referenceSequence.add(midiNote);
      } else if (_gameState == MultiplayerGameState.matcherPhase) {
        _attemptSequence.add(midiNote);
        if (_attemptSequence.length >= _referenceSequence.length) {
          _submitMatch();
        }
      }
      _highlightedNote = midiNote;
    });
  }

  void _onNoteReleased(int midiNote) {
    if (_highlightedNote == midiNote) {
      setState(() => _highlightedNote = null);
    }
  }

  Future<void> _creatorIsDone() async {
    if (_referenceSequence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please create a melody first!')));
      return;
    }

    setState(() {
      _statusMessage = 'Submitting melody...';
    });

    try {
      // Submit melody via multiplayer service
      final success = await _multiplayerService!.submitRecordedMelody(
        _referenceSequence,
        List.generate(_referenceSequence.length, (i) => i * 500), // Simple timing
        List.generate(_referenceSequence.length, (i) => 500), // Simple duration
      );

      if (success) {
        setState(() {
          _gameState = MultiplayerGameState.waitingForMatch;
          _statusMessage = 'Waiting for $_opponentName to match your melody...';
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to submit melody. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error submitting melody: $e';
      });
    }
  }

  void _continueToNextRound() {
    print('🎮 Continuing to next round...');

    setState(() {
      _lastMatchScore = null;
      _lastComparisonDetails = null; // Clear analysis data when continuing
      _statusMessage = 'Starting next round...';

      // Clear roundScoring state so room updates can be processed
      _gameState = MultiplayerGameState.waitingForMatch; // Temporary state

      // Completely clear all melody data for clean state
      _referenceSequence.clear();
      _attemptSequence.clear();
      _repeatCount = 0;
      _highlightedNote = null;
      _isPlayingMelody = false;
      _isPlayingReference = false;
    });

    // The room state should already be updated from the submission response
    // Just need to process the current state to determine next phase
    final room = _multiplayerService?.currentRoom;
    if (room != null) {
      print('🎮 Processing room state for next round - active player: ${room.activePlayer?.name}');
      print('🎮 My player ID: $_myPlayerId, active player ID: ${room.activePlayer?.id}');
      print('🎮 Room game state: ${room.state}, has challenge: ${room.currentChallenge != null}');

      // The room should already have the switched turn from server
      // Process the current room state to determine UI state
      _updateGameStateFromRoom(room);
    } else {
      setState(() {
        _gameState = MultiplayerGameState.waitingForMatch;
        _statusMessage = 'Waiting for room update...';
      });
    }
  }

  Future<void> _submitMatch() async {
    final startTime = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _statusMessage = 'Analyzing your performance...';
    });

    try {
      // Submit replay attempt
      final result = await _multiplayerService!.submitReplayAttempt(
        _attemptSequence,
        List.generate(_attemptSequence.length, (i) => i * 500), // Simple timing
        List.generate(_attemptSequence.length, (i) => 500), // Simple duration
      );

      if (result['success'] == true) {
        final endTime = DateTime.now().millisecondsSinceEpoch;
        _comparisonProcessingTimeMs = endTime - startTime;

        // Extract and store the match score and full analysis
        if (result['score'] != null) {
          _lastComparisonDetails = result['score'] as Map<String, dynamic>;
          print('📊 Analysis data captured: ${_lastComparisonDetails?.keys}');
          print('📊 Full score data: $_lastComparisonDetails');

          if (result['score']['final_score'] != null) {
            _lastMatchScore = (result['score']['final_score'] as num).toDouble();
            print('🏆 Match score: ${(_lastMatchScore! * 100).toStringAsFixed(1)}%');
          }
        } else {
          print('❌ No score data in result: ${result.keys}');
        }

        // Update room state if provided in response (contains new current_turn after switch)
        if (result['room_state'] != null) {
          print('🎮 Updating room state from submission response');
          _multiplayerService?.updateRoomFromServerState(result['room_state'] as Map<String, dynamic>);
        }

        setState(() {
          _gameState = MultiplayerGameState.roundScoring;
          _statusMessage =
              'Round complete! Your score: ${(_lastMatchScore != null) ? ('${(_lastMatchScore! * 100).toStringAsFixed(1)}%') : 'N/A'}';
        });

        // Wait for room update with scores
        // This will trigger via WebSocket events
      } else {
        setState(() {
          _statusMessage = 'Failed to submit performance: ${result['error'] ?? 'Unknown error'}';
        });
        print('🚨 Submission failed: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error submitting performance: $e';
      });
    }
  }

  Future<void> _playReferenceMelody({bool isFirstPlayback = false}) async {
    if (_referenceSequence.isEmpty) return;

    // Prevent double playback - return if already playing
    if (_isPlayingReference) {
      print('🎵 Reference melody already playing, skipping duplicate playback');
      return;
    }

    if (!isFirstPlayback) {
      if (_repeatCount >= _maxRepeats) return;
      _repeatCount++;
    }

    setState(() {
      _isPlayingMelody = true;
      _isPlayingReference = true;
    });

    for (int i = 0; i < _referenceSequence.length; i++) {
      if (!mounted) return;
      final note = _referenceSequence[i];

      setState(() => _highlightedNote = note);

      // Play note and wait for it to complete - use try/catch to prevent double playback
      try {
        await _midiService.playMidiNote(note);
      } catch (e) {
        // Only use fallback if MIDI completely failed
        print('🎵 MIDI failed for note $note, using fallback: $e');
        await _simpleAudio.playPianoNote(note);
      }

      // Wait for note to play (consistent timing)
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      setState(() => _highlightedNote = null);

      // Gap between notes (except after last note)
      if (i < _referenceSequence.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    setState(() {
      _isPlayingMelody = false;
      _isPlayingReference = false;
    });
  }

  void _showAnalyticsDialog() {
    if (_lastComparisonDetails == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Analytics'),
        content: AnalysisReportWidget(
          scoreData: _lastComparisonDetails!,
          clientRoundTripTime: _comparisonProcessingTimeMs,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getColorForScore(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer Piano'),
        actions: [
          if (_gameState == MultiplayerGameState.gameComplete && _lastComparisonDetails != null)
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: _showAnalyticsDialog,
              tooltip: 'View Analytics',
            ),
        ],
      ),
      body: _buildGameContent(),
    );
  }

  Widget _buildGameContent() {
    switch (_gameState) {
      case MultiplayerGameState.playerRegistration:
        return _buildPlayerRegistration();
      case MultiplayerGameState.waitingForMatch:
      case MultiplayerGameState.gameStarting:
        return _buildWaitingScreen();
      case MultiplayerGameState.creatorPhase:
      case MultiplayerGameState.matcherPhase:
      case MultiplayerGameState.melodyPlayback:
      case MultiplayerGameState.roundScoring:
        return _buildGameScreen();
      case MultiplayerGameState.gameComplete:
        return _buildGameCompleteScreen();
    }
  }

  Widget _buildPlayerRegistration() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.piano, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Multiplayer Piano Game',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              onChanged: (value) => setState(() => _playerName = value.trim()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Room ID (optional - leave empty to create new)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _playerName.isNotEmpty ? _joinGame : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: Text(_roomController.text.isEmpty ? 'Create Game' : 'Join Game'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (_statusMessage.contains('Failed to connect'))
              ElevatedButton(
                onPressed: () {
                  // Reload the page
                  setState(() {
                    _statusMessage = 'Reconnecting...';
                  });
                  _initServices();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Try Again'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          if (_roomId.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'Room ID',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _roomId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (_roomId.isNotEmpty) {
                        await Clipboard.setData(ClipboardData(text: _roomId));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Room ID $_roomId copied to clipboard!'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Room ID'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Share this ID with a friend to join!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    bool canPressPiano =
        (_gameState == MultiplayerGameState.creatorPhase || _gameState == MultiplayerGameState.matcherPhase) &&
            !_isPlayingMelody &&
            !_isPlayingReference;

    // Show different UI content based on game state
    String gameStateDisplay = '';
    switch (_gameState) {
      case MultiplayerGameState.melodyPlayback:
        gameStateDisplay = '🎵 Listen carefully...';
        break;
      case MultiplayerGameState.matcherPhase:
        gameStateDisplay = '🎹 Your turn to match!';
        break;
      case MultiplayerGameState.creatorPhase:
        gameStateDisplay = '🎼 Create your melody';
        break;
      default:
        gameStateDisplay = '';
    }

    return Column(
      children: [
        // Scoreboard
        _buildScoreboard(),

        // Status message
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            _statusMessage,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),

        // Game state display
        if (gameStateDisplay.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              gameStateDisplay,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _gameState == MultiplayerGameState.melodyPlayback ? Colors.blue : Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Score display
        if (_lastMatchScore != null && _gameState == MultiplayerGameState.roundScoring)
          Text(
            'Match Score: ${(_lastMatchScore! * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: _getColorForScore(_lastMatchScore),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

        // Analysis report for round scoring
        if (_gameState == MultiplayerGameState.roundScoring && _lastComparisonDetails != null) ...[
          Text(
            'Analysis Report:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: AnalysisReportWidget(
                scoreData: _lastComparisonDetails!,
                clientRoundTripTime: _comparisonProcessingTimeMs,
              ),
            ),
          ),
        ] else if (_gameState == MultiplayerGameState.roundScoring) ...[
          const Text(
            'Debug: State is roundScoring but no analysis data',
            style: TextStyle(color: Colors.red),
          ),
          Text('Analysis details: $_lastComparisonDetails'),
        ],

        // Continue button for round scoring
        if (_gameState == MultiplayerGameState.roundScoring) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _continueToNextRound,
              child: const Text('Continue'),
            ),
          ),
        ],

        // Game controls
        if (_gameState == MultiplayerGameState.creatorPhase || _gameState == MultiplayerGameState.matcherPhase) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_gameState == MultiplayerGameState.creatorPhase)
                  ElevatedButton(
                    onPressed: _referenceSequence.isNotEmpty ? _creatorIsDone : null,
                    child: const Text('Done Creating'),
                  ),
                if (_gameState == MultiplayerGameState.matcherPhase) ...[
                  ElevatedButton(
                    onPressed: _repeatCount < _maxRepeats && !_isPlayingReference ? () => _playReferenceMelody() : null,
                    child: Text('Repeat (${_maxRepeats - _repeatCount} left)'),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Piano keyboard
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: PianoKeyboard(
              onNotePressed: canPressPiano ? _onNotePressed : null,
              onNoteReleased: _onNoteReleased,
              startingOctave: 3,
              numberOfOctaves: 2,
              showNoteLabels: true,
              highlightedNote: _highlightedNote,
            ),
          ),
        ),

        // Melody display
        if (_referenceSequence.isNotEmpty || _attemptSequence.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_referenceSequence.isNotEmpty) Text('Reference: ${_referenceSequence.join(", ")}'),
                if (_attemptSequence.isNotEmpty) Text('Your attempt: ${_attemptSequence.join(", ")}'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGameCompleteScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
          const SizedBox(height: 20),
          Text(
            'Game Complete!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            _statusMessage,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Return to Menu'),
              ),
              if (_lastComparisonDetails != null)
                ElevatedButton(
                  onPressed: _showAnalyticsDialog,
                  child: const Text('View Analytics'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(_playerName.isNotEmpty ? _playerName : 'You',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('$_myScore', style: const TextStyle(fontSize: 24, color: Colors.blue)),
            ],
          ),
          Column(
            children: [
              Text('Round', style: TextStyle(color: Colors.grey[600])),
              Text('$_roundNumber', style: const TextStyle(fontSize: 20)),
            ],
          ),
          Column(
            children: [
              Text(_opponentName.isNotEmpty ? _opponentName : 'Opponent',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('$_opponentScore', style: const TextStyle(fontSize: 24, color: Colors.red)),
            ],
          ),
        ],
      ),
    );
  }
}
