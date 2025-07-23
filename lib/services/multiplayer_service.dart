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

  // Stream controllers for exposing game events
  final StreamController<GameRoom?> _roomUpdateController = StreamController<GameRoom?>.broadcast();
  final StreamController<Melody> _challengeAvailableController = StreamController<Melody>.broadcast();

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

  // Stream getter for room updates
  Stream<GameRoom?> get roomUpdates => _roomUpdateController.stream;
  
  // Stream getter for challenge availability
  Stream<Melody> get challengeAvailable => _challengeAvailableController.stream;

  // Check if the current user is the active player
  bool get isActivePlayer {
    if (_currentRoom == null || _websocketService.playerId.isEmpty) return false;
    return _currentRoom!.activePlayer?.id == _websocketService.playerId;
  }

  // Check if the current user is the challenge player (the one who replays)
  bool get isChallengePlayer {
    if (_currentRoom == null || _websocketService.playerId.isEmpty) return false;
    // The challenge player is the one who should match (NOT the active player who created)
    return _currentRoom!.activePlayer?.id != _websocketService.playerId;
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
    _roomUpdateController.add(null);
    notifyListeners();
  }

  /// Create a new game room
  Future<bool> createRoom() async {
    debugPrint('MultiplayerService.createRoom() called');
    debugPrint('Connected: ${_websocketService.isConnected}, Player name: $_playerName');
    
    if (!_websocketService.isConnected || _playerName.isEmpty) {
      debugPrint('Cannot create room: not connected or no player name');
      return false;
    }

    _isCreating = true;
    notifyListeners();

    debugPrint('Calling websocket service createRoom...');
    final result = await _websocketService.createRoom(_playerName);
    debugPrint('createRoom result: $result');

    // If successful, immediately set up initial room state
    if (result) {
      final roomId = _websocketService.roomId;
      final playerId = _websocketService.playerId;
      
      debugPrint('Setting up initial room state: $roomId, player: $playerId');
      
      // Create initial room state with just the creator
      _currentRoom = GameRoom(
        id: roomId,
        players: [Player(id: playerId, name: _playerName, score: 0)],
        state: GameState.waiting,
        currentRound: 1,
        totalRounds: 5,
        activePlayer: Player(id: playerId, name: _playerName, score: 0),
      );
      
      // Broadcast initial room update
      _roomUpdateController.add(_currentRoom);
      debugPrint('Initial room state created and broadcasted');
    }

    _isCreating = false;
    notifyListeners();

    return result;
  }

  /// Join an existing game room
  Future<bool> joinRoom(String roomId) async {
    debugPrint('MultiplayerService.joinRoom() called with roomId: $roomId');
    debugPrint('Connected: ${_websocketService.isConnected}, Player name: $_playerName');
    
    if (!_websocketService.isConnected || _playerName.isEmpty) {
      debugPrint('Cannot join room: not connected or no player name');
      return false;
    }

    _isJoining = true;
    notifyListeners();

    debugPrint('Calling websocket service joinRoom...');
    final result = await _websocketService.joinRoom(roomId, _playerName);
    debugPrint('joinRoom result: $result');

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
      _roomUpdateController.add(null);
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
  Future<Map<String, dynamic>> submitReplayAttempt(List<int> notes, List<int> timings, List<int> durations) async {
    if (!isInRoom || !isChallengePlayer) return {'success': false, 'error': 'Not in room or not the challenge player'};

    return await _websocketService.submitReplay(notes, timings, durations);
  }

  /// Update room state from server response (public method)
  void updateRoomFromServerState(Map<String, dynamic> roomData) {
    _updateRoomFromState(roomData);
    _roomUpdateController.add(_currentRoom);
    notifyListeners();
  }

  /// Setup WebSocket event listeners
  void _setupListeners() {
    // Room updates
    _roomUpdateSubscription = _websocketService.onRoomUpdate.listen((data) {
      debugPrint('🎯 MultiplayerService received room_update event');
      debugPrint('🎯 Room update data: $data');
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
        final String currentTurnPlayerId = roomData['current_turn'] as String? ?? '';
        final bool hasChallenge = roomData['has_challenge'] as bool? ?? false;
        final int turnCount = roomData['turn_count'] as int? ?? 0;

        // Parse players list from server format
        final List<dynamic> playersData = roomData['players'] as List<dynamic>? ?? [];
        final players = playersData.map((playerData) {
          return Player(
            id: playerData['id'] as String,
            name: playerData['name'] as String,
            score: (playerData['score'] as num?)?.toDouble() ?? 0.0,
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

        // Broadcast room update to listeners
        debugPrint('🎯 Broadcasting room update to UI: ${_currentRoom?.players.length} players');
        _roomUpdateController.add(_currentRoom);
        notifyListeners();
      } catch (e) {
        debugPrint('Error handling room update: $e');
        debugPrint('Room data: $data');
      }
    });

    // Player joined
    _playerJoinedSubscription = _websocketService.onPlayerJoined.listen((data) {
      debugPrint('🎯 MultiplayerService received player_joined event');
      debugPrint('🎯 Player joined data: $data');
      try {
        // Update room state from the event
        if (data.containsKey('room_state')) {
          debugPrint('🎯 Updating room state from player_joined event');
          _updateRoomFromState(data['room_state'] as Map<String, dynamic>);
          
          // Ensure room update is broadcast to UI
          debugPrint('🎯 Broadcasting updated room state: ${_currentRoom?.players.length} players');
          _roomUpdateController.add(_currentRoom);
          notifyListeners();
        } else {
          debugPrint('🎯 Warning: player_joined event missing room_state');
        }
      } catch (e) {
        debugPrint('Error handling player joined: $e');
      }
    });

    // Player left
    _playerLeftSubscription = _websocketService.onPlayerLeft.listen((data) {
      try {
        // Update room state from the event or handle manually
        if (data.containsKey('room_state')) {
          _updateRoomFromState(data['room_state'] as Map<String, dynamic>);
        } else if (_currentRoom != null && data.containsKey('player_id')) {
          // Manually remove player if no room state provided
          final playerId = data['player_id'] as String;
          final updatedPlayers = _currentRoom!.players
              .where((p) => p.id != playerId)
              .toList();
          
          _currentRoom = _currentRoom!.copyWith(players: updatedPlayers);
        }
        _roomUpdateController.add(_currentRoom);
        notifyListeners();
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
          _roomUpdateController.add(_currentRoom);
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

          // Fetch challenge if I'm NOT the current turn player (the matcher, not creator)
          if (_currentRoom!.activePlayer?.id != _websocketService.playerId) {
            debugPrint('🎵 I should match the challenge, fetching challenge melody');
            _fetchCurrentChallenge();
          } else {
            debugPrint('🎵 I created the challenge, waiting for opponent to match');
          }
          
          _roomUpdateController.add(_currentRoom);
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
          // Update room state from the event
          if (data.containsKey('room_state')) {
            _updateRoomFromState(data['room_state'] as Map<String, dynamic>);
          }
          
          _roomUpdateController.add(_currentRoom);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error handling score update: $e');
      }
    });
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
          score: (playerData['score'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      // Determine active and challenge players
      Player? activePlayer;
      Player? challengePlayer;
      
      if (currentTurnPlayerId.isNotEmpty && players.isNotEmpty) {
        activePlayer = players.firstWhere(
          (p) => p.id == currentTurnPlayerId,
          orElse: () => players.first,
        );

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
          gameState = GameState.replaying;
        } else {
          gameState = GameState.recording;
        }
      }

      // Create a new room with updated data (since players is final)
      _currentRoom = GameRoom(
        id: _currentRoom!.id,
        players: players,
        activePlayer: activePlayer,
        challengePlayer: challengePlayer,
        state: gameState,
        currentRound: (turnCount / 2).floor() + 1,
        totalRounds: _currentRoom!.totalRounds,
        currentChallenge: _currentRoom!.currentChallenge,
      );

      // Broadcast room update to listeners
      _roomUpdateController.add(_currentRoom);
    } catch (e) {
      debugPrint('Error updating room from state: $e');
    }
  }

  /// Fetch the current challenge melody from the server
  Future<void> _fetchCurrentChallenge() async {
    if (_currentRoom == null || _websocketService.playerId.isEmpty) return;
    
    try {
      debugPrint('🎵 Fetching challenge for room: ${_currentRoom!.id}, player: ${_websocketService.playerId}');
      final result = await ServerManager.instance.getChallenge(
        _currentRoom!.id, 
        _websocketService.playerId
      );
      
      debugPrint('🎵 Challenge fetch result: $result');
      
      if (result['success'] == true) {
        debugPrint('🎵 Processing challenge result: $result');
        
        Melody melody;
        
        // Handle the actual server response format (data at root level)
        if (result.containsKey('melody') && result.containsKey('timings') && result.containsKey('durations')) {
          debugPrint('🎵 Using root-level challenge data format');
          melody = Melody(
            notes: List<int>.from(result['melody'] as List),
            timings: List<int>.from(result['timings'] as List),
            durations: List<int>.from(result['durations'] as List),
          );
        }
        // Fallback: Handle nested format if server changes
        else if (result.containsKey('melody') && result['melody'] is Map) {
          debugPrint('🎵 Using nested challenge data format');
          final melodyData = result['melody'] as Map<String, dynamic>;
          melody = Melody(
            notes: List<int>.from(melodyData['melody'] as List),
            timings: List<int>.from(melodyData['timings'] as List),
            durations: List<int>.from(melodyData['durations'] as List),
          );
        } else {
          throw Exception('Challenge response missing required fields: melody, timings, durations');
        }
        
        _currentRoom!.setChallenge(melody);
        debugPrint('🎵 Challenge melody set successfully: ${melody.notes.length} notes');
        
        // Emit challenge available event
        _challengeAvailableController.add(melody);
        debugPrint('🎵 Challenge available event emitted');
      } else {
        debugPrint('🎵 Challenge fetch failed: ${result['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('Error fetching challenge: $e');
      // Don't crash the game - continue without the challenge melody
      debugPrint('🎵 Continuing without challenge melody due to error');
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
    
    // Close stream controllers
    _roomUpdateController.close();
    _challengeAvailableController.close();
    
    super.dispose();
  }
}
