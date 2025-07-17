import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_room.dart';
import 'enhanced_websocket_service.dart';
import 'server_manager.dart';

/// Service for managing multiplayer game session
class MultiplayerService extends ChangeNotifier {
  final EnhancedWebSocketService _websocketService;
  GameRoom? _currentRoom;
  String _playerName = '';
  bool _isJoining = false;
  bool _isCreating = false;

  // Stream subscriptions
  StreamSubscription? _roomUpdateSubscription;
  StreamSubscription? _playerJoinedSubscription;
  StreamSubscription? _playerLeftSubscription;
  StreamSubscription? _turnChangeSubscription;
  StreamSubscription? _newChallengeSubscription;
  StreamSubscription? _scoreUpdateSubscription;

  MultiplayerService(this._websocketService) {
    _loadPlayerName();
  }

  /// Initialize the service and setup listeners.
  /// This should be called after the websocket is connected.
  void initialize() {
    // Ensure listeners are only set up once.
    if (_roomUpdateSubscription != null) return;
    _setupListeners();
  }

  // Getters
  GameRoom? get currentRoom => _currentRoom;
  String get playerName => _playerName;
  bool get isJoining => _isJoining;
  bool get isCreating => _isCreating;
  bool get isConnected => _websocketService.isConnected;
  bool get isInRoom => _currentRoom != null;

  // Add a getter for playerId
  String get playerId => _websocketService.playerId;

  // Check if the current user is the active player
  bool get isActivePlayer {
    if (_currentRoom == null || _websocketService.playerId.isEmpty) return false;
    return _currentRoom!.activePlayer?.id == _websocketService.playerId;
  }

  // Check if the current user is the challenge player (the one who replays)
  bool get isChallengePlayer {
    if (_currentRoom == null || _websocketService.playerId.isEmpty) return false;
    return _currentRoom!.challengePlayer?.id == _websocketService.playerId;
  }

  /// Set the player's name
  Future<void> setPlayerName(String name) async {
    _playerName = name;
    notifyListeners();

    // Save to persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', name);
  }

  /// Load the player's name from persistent storage
  Future<void> _loadPlayerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('player_name');
      if (name != null && name.isNotEmpty) {
        _playerName = name;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load player name: $e');
    }
  }

  /// Connect to the WebSocket server
  // This is now handled by the provider, the service is expected to be connected.
  /*
  Future<bool> connect({String? serverUrl}) async {
    if (serverUrl != null) {
      _websocketService.setServerUrl(serverUrl);
    }
    
    return await _websocketService.connect();
  }
  */

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    await _websocketService.disconnect();
    _currentRoom = null;
    notifyListeners();
  }

  /// Create a new game room
  Future<bool> createRoom() async {
    if (!_websocketService.isConnected || _playerName.isEmpty) {
      return false;
    }

    _isCreating = true;
    notifyListeners();

    final result = await _websocketService.createRoom(_playerName);

    _isCreating = false;
    notifyListeners();

    return result;
  }

  /// Join an existing game room
  Future<bool> joinRoom(String roomId) async {
    if (!_websocketService.isConnected || _playerName.isEmpty) {
      return false;
    }

    _isJoining = true;
    notifyListeners();

    final result = await _websocketService.joinRoom(roomId, _playerName);

    _isJoining = false;
    notifyListeners();

    return result;
  }

  /// Leave the current game room
  Future<bool> leaveRoom() async {
    if (!isInRoom) return false;

    final result = await _websocketService.leaveRoom();
    if (result) {
      _currentRoom = null;
      notifyListeners();
    }

    return result;
  }

  /// Submit a recorded melody to challenge the other player
  Future<bool> submitRecordedMelody(List<int> notes, List<int> timings, List<int> durations) async {
    if (!isInRoom || !isActivePlayer) return false;

    return await _websocketService.submitMelody(notes, timings, durations);
  }

  /// Submit a replay attempt to be scored
  Future<bool> submitReplayAttempt(List<int> notes, List<int> timings, List<int> durations) async {
    if (!isInRoom || !isChallengePlayer) return false;

    return await _websocketService.submitReplay(notes, timings, durations);
  }

  /// Setup WebSocket event listeners
  void _setupListeners() {
    // Room updates
    _roomUpdateSubscription = _websocketService.onRoomUpdate.listen((data) {
      try {
        // Check if this is direct room state data or wrapped in 'room' key
        Map<String, dynamic> roomData;
        if (data.containsKey('room')) {
          roomData = data['room'] as Map<String, dynamic>;
        } else if (data.containsKey('room_state')) {
          roomData = data['room_state'] as Map<String, dynamic>;
        } else {
          // Direct room state format from server
          roomData = data;
        }

        // Parse server's simple room state format
        final roomId = roomData['room_id'] as String;
        final bool isActive = roomData['active'] as bool? ?? true;
        final String currentTurnPlayerId = roomData['current_turn'] as String? ?? '';
        final bool hasChallenge = roomData['has_challenge'] as bool? ?? false;
        final int turnCount = roomData['turn_count'] as int? ?? 0;

        // Parse players list from server format
        final List<dynamic> playersData = roomData['players'] as List<dynamic>? ?? [];
        final players = playersData.map((playerData) {
          return Player(
            id: playerData['id'] as String,
            name: playerData['name'] as String,
            score: playerData['score'] as int? ?? 0,
          );
        }).toList();

        // Determine active and challenge players based on game logic
        Player? activePlayer;
        Player? challengePlayer;

        if (currentTurnPlayerId.isNotEmpty && players.isNotEmpty) {
          // Find the current turn player
          activePlayer = players.firstWhere(
            (p) => p.id == currentTurnPlayerId,
            orElse: () => players.first,
          );

          // If there's a challenge, the non-active player is the challenge player
          if (hasChallenge && players.length >= 2) {
            challengePlayer = players.firstWhere(
              (p) => p.id != currentTurnPlayerId,
              orElse: () => players.last,
            );
          }
        }

        // Determine game state based on turn and challenge
        GameState gameState = GameState.waiting;
        if (players.length >= 2) {
          if (hasChallenge) {
            gameState = GameState.replaying; // Someone needs to replay the challenge
          } else {
            gameState = GameState.recording; // Someone needs to record a melody
          }
        }

        // Create the room object with server data
        _currentRoom = GameRoom(
          id: roomId,
          players: players,
          state: gameState,
          currentRound: (turnCount / 2).floor() + 1, // Estimate round from turn count
          totalRounds: 5, // Default total rounds
          activePlayer: activePlayer,
          challengePlayer: challengePlayer,
          currentChallenge: null, // Will be set via separate challenge events
        );

        notifyListeners();
      } catch (e) {
        debugPrint('Error handling room update: $e');
        debugPrint('Room data: $data');
      }
    });

    // Player joined
    _playerJoinedSubscription = _websocketService.onPlayerJoined.listen((data) {
      try {
        final playerId = data['player_id'] as String;
        final playerName = data['player_name'] as String;

        if (_currentRoom != null) {
          final player = Player(id: playerId, name: playerName);
          _currentRoom!.players.add(player);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error handling player joined: $e');
      }
    });

    // Player left
    _playerLeftSubscription = _websocketService.onPlayerLeft.listen((data) {
      try {
        final playerId = data['player_id'] as String;

        if (_currentRoom != null) {
          _currentRoom!.players.removeWhere((p) => p.id == playerId);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error handling player left: $e');
      }
    });

    // Turn change
    _turnChangeSubscription = _websocketService.onTurnChange.listen((data) {
      try {
        if (_currentRoom != null) {
          final activePlayerId = data['active_player_id'] as String;
          final challengePlayerId = data['challenge_player_id'] as String;

          // Update active and challenge player roles
          _currentRoom!.activePlayer = _currentRoom!.getPlayerById(activePlayerId);
          _currentRoom!.challengePlayer = _currentRoom!.getPlayerById(challengePlayerId);

          // Update game state
          _currentRoom!.changeState(GameState.recording);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error handling turn change: $e');
      }
    });

    // New challenge
    _newChallengeSubscription = _websocketService.onNewChallenge.listen((data) {
      try {
        if (_currentRoom != null) {
          // First update room state from the event
          if (data.containsKey('room_state')) {
            _updateRoomFromState(data['room_state'] as Map<String, dynamic>);
          }

          // Then try to get the challenge melody from the server
          _fetchCurrentChallenge();
          
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error handling new challenge: $e');
      }
    });

    // Score update
    _scoreUpdateSubscription = _websocketService.onScoreUpdate.listen((data) {
      try {
        if (_currentRoom != null) {
          final playerId = data['player_id'] as String;
          final score = data['score'] as double;
          final roundComplete = data['round_complete'] as bool? ?? false;

          // Update player score
          _currentRoom!.updatePlayerScore(playerId, score.toInt());

          // Handle round completion
          if (roundComplete) {
            // Game state updates will come via room_update event
          }

          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error handling score update: $e');
      }
    });
  }

  /// Convert string representation of game state to enum
  GameState _convertStateFromString(String stateStr) {
    switch (stateStr) {
      case 'waiting':
        return GameState.waiting;
      case 'recording':
        return GameState.recording;
      case 'replaying':
        return GameState.replaying;
      case 'game_over':
        return GameState.gameOver;
      default:
        return GameState.waiting;
    }
  }

  /// Update room from room state data (helper for WebSocket events)
  void _updateRoomFromState(Map<String, dynamic> roomData) {
    if (_currentRoom == null) return;
    
    try {
      final String currentTurnPlayerId = roomData['current_turn'] as String? ?? '';
      final bool hasChallenge = roomData['has_challenge'] as bool? ?? false;
      final int turnCount = roomData['turn_count'] as int? ?? 0;

      // Parse players list from server format
      final List<dynamic> playersData = roomData['players'] as List<dynamic>? ?? [];
      final players = playersData.map((playerData) {
        return Player(
          id: playerData['id'] as String,
          name: playerData['name'] as String,
          score: playerData['score'] as int? ?? 0,
        );
      }).toList();

      // Update room data
      _currentRoom!.players = players;
      
      // Determine active and challenge players
      if (currentTurnPlayerId.isNotEmpty && players.isNotEmpty) {
        _currentRoom!.activePlayer = players.firstWhere(
          (p) => p.id == currentTurnPlayerId,
          orElse: () => players.first,
        );

        if (hasChallenge && players.length >= 2) {
          _currentRoom!.challengePlayer = players.firstWhere(
            (p) => p.id != currentTurnPlayerId,
            orElse: () => players.last,
          );
        }
      }

      // Update game state
      if (players.length >= 2) {
        if (hasChallenge) {
          _currentRoom!.changeState(GameState.replaying);
        } else {
          _currentRoom!.changeState(GameState.recording);
        }
      }
    } catch (e) {
      debugPrint('Error updating room from state: $e');
    }
  }

  /// Fetch the current challenge melody from the server
  Future<void> _fetchCurrentChallenge() async {
    if (_currentRoom == null || _websocketService.playerId.isEmpty) return;
    
    try {
      final result = await ServerManager.instance.getChallenge(
        _currentRoom!.id, 
        _websocketService.playerId
      );
      
      if (result['success'] == true && result.containsKey('melody')) {
        final melodyData = result['melody'] as Map<String, dynamic>;
        final melody = Melody(
          notes: List<int>.from(melodyData['melody'] as List),
          timings: List<int>.from(melodyData['timings'] as List),
          durations: List<int>.from(melodyData['durations'] as List),
        );
        
        _currentRoom!.setChallenge(melody);
      }
    } catch (e) {
      debugPrint('Error fetching challenge: $e');
    }
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions
    _roomUpdateSubscription?.cancel();
    _playerJoinedSubscription?.cancel();
    _playerLeftSubscription?.cancel();
    _turnChangeSubscription?.cancel();
    _newChallengeSubscription?.cancel();
    _scoreUpdateSubscription?.cancel();
    super.dispose();
  }
}
