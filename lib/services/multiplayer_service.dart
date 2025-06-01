import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_room.dart';
import 'websocket_service.dart';

/// Service for managing multiplayer game session
class MultiplayerService extends ChangeNotifier {
  final WebSocketService _websocketService;
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
    _setupListeners();
    _loadPlayerName();
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
  Future<bool> connect({String? serverUrl}) async {
    if (serverUrl != null) {
      _websocketService.setServerUrl(serverUrl);
    }
    
    return await _websocketService.connect();
  }

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
        if (data.containsKey('room')) {
          final roomData = data['room'];
          // Convert room data to a GameRoom object based on the JSON structure
          final roomId = roomData['id'] as String;
          final state = _convertStateFromString(roomData['state'] as String);
          final currentRound = roomData['current_round'] as int;
          final totalRounds = roomData['total_rounds'] as int;
          
          // Parse players
          final List<dynamic> playersData = roomData['players'] as List<dynamic>;
          final players = playersData.map((playerData) {
            return Player(
              id: playerData['id'] as String,
              name: playerData['name'] as String,
              score: playerData['score'] as int,
            );
          }).toList();
          
          // Parse active and challenge players
          Player? activePlayer;
          Player? challengePlayer;
          
          final String? activePlayerId = roomData['active_player'] as String?;
          final String? challengePlayerId = roomData['challenge_player'] as String?;
          
          if (activePlayerId != null) {
            activePlayer = players.firstWhere(
              (p) => p.id == activePlayerId,
              orElse: () => Player(id: '', name: ''),
            );
          }
          
          if (challengePlayerId != null) {
            challengePlayer = players.firstWhere(
              (p) => p.id == challengePlayerId,
              orElse: () => Player(id: '', name: ''),
            );
          }
          
          // Parse current challenge
          Melody? currentChallenge;
          final dynamic challengeData = roomData['current_challenge'];
          if (challengeData != null) {
            currentChallenge = Melody(
              notes: List<int>.from(challengeData['notes'] as List),
              timings: List<int>.from(challengeData['timings'] as List),
              durations: List<int>.from(challengeData['durations'] as List),
            );
          }
          
          // Create the room object
          _currentRoom = GameRoom(
            id: roomId,
            players: players,
            state: state,
            currentRound: currentRound,
            totalRounds: totalRounds,
            activePlayer: activePlayer,
            challengePlayer: challengePlayer,
            currentChallenge: currentChallenge,
          );
          
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error handling room update: $e');
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
        if (_currentRoom != null && data.containsKey('melody')) {
          final melodyData = data['melody'] as Map<String, dynamic>;
          final melody = Melody(
            notes: List<int>.from(melodyData['notes'] as List),
            timings: List<int>.from(melodyData['timings'] as List),
            durations: List<int>.from(melodyData['durations'] as List),
          );
          
          _currentRoom!.setChallenge(melody);
          _currentRoom!.changeState(GameState.replaying);
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