import 'package:flutter/foundation.dart';

/// Represents a player in the multiplayer game
class Player {
  final String id;
  final String name;
  double score;

  Player({
    required this.id,
    required this.name,
    this.score = 0.0,
  });

  Player copyWith({
    String? id,
    String? name,
    double? score,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
    );
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'score': score,
    };
  }
}

/// Represents a melody with notes, timings, and durations
class Melody {
  final List<int> notes;
  final List<int> timings;
  final List<int> durations;

  Melody({
    required this.notes,
    required this.timings,
    required this.durations,
  });

  Melody copyWith({
    List<int>? notes,
    List<int>? timings,
    List<int>? durations,
  }) {
    return Melody(
      notes: notes ?? this.notes,
      timings: timings ?? this.timings,
      durations: durations ?? this.durations,
    );
  }

  factory Melody.fromJson(Map<String, dynamic> json) {
    return Melody(
      notes: List<int>.from(json['notes']),
      timings: List<int>.from(json['timings']),
      durations: List<int>.from(json['durations']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notes': notes,
      'timings': timings,
      'durations': durations,
    };
  }

  bool get isEmpty => notes.isEmpty;
}

/// Game states in the multiplayer room
enum GameState {
  waiting,     // Waiting for players to join
  recording,   // Active player is recording a melody
  replaying,   // Other player is replaying the melody
  turnChange,  // Switching turns
  gameOver,    // Game has ended
}

/// Represents a multiplayer game room
class GameRoom extends ChangeNotifier {
  final String id;
  final List<Player> players;
  Player? activePlayer;
  Player? challengePlayer;
  GameState state;
  Melody? currentChallenge;
  int currentRound;
  final int totalRounds;
  DateTime? lastActivity;

  GameRoom({
    required this.id,
    required this.players,
    this.activePlayer,
    this.challengePlayer,
    this.state = GameState.waiting,
    this.currentChallenge,
    this.currentRound = 1,
    this.totalRounds = 5,
    this.lastActivity,
  });

  bool get isReady => players.length >= 2;
  bool get isGameOver => currentRound > totalRounds;

  /// Get player by ID
  Player? getPlayerById(String id) {
    try {
      return players.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Update player score
  void updatePlayerScore(String playerId, double score) {
    for (int i = 0; i < players.length; i++) {
      if (players[i].id == playerId) {
        players[i].score = score;
        notifyListeners();
        break;
      }
    }
  }

  /// Set the current challenge melody
  void setChallenge(Melody melody) {
    currentChallenge = melody;
    notifyListeners();
  }

  /// Switch active player and challenge player roles
  void switchTurns() {
    final temp = activePlayer;
    activePlayer = challengePlayer;
    challengePlayer = temp;
    notifyListeners();
  }

  /// Move to the next round
  void nextRound() {
    currentRound++;
    notifyListeners();
  }

  /// Change the current game state
  void changeState(GameState newState) {
    state = newState;
    lastActivity = DateTime.now();
    notifyListeners();
  }

  GameRoom copyWith({
    String? id,
    List<Player>? players,
    Player? activePlayer,
    Player? challengePlayer,
    GameState? state,
    Melody? currentChallenge,
    int? currentRound,
    int? totalRounds,
    DateTime? lastActivity,
  }) {
    return GameRoom(
      id: id ?? this.id,
      players: players ?? this.players,
      activePlayer: activePlayer ?? this.activePlayer,
      challengePlayer: challengePlayer ?? this.challengePlayer,
      state: state ?? this.state,
      currentChallenge: currentChallenge ?? this.currentChallenge,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      id: json['id'] as String,
      players: (json['players'] as List)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      activePlayer: json['active_player'] != null
          ? Player.fromJson(json['active_player'] as Map<String, dynamic>)
          : null,
      challengePlayer: json['challenge_player'] != null
          ? Player.fromJson(json['challenge_player'] as Map<String, dynamic>)
          : null,
      state: GameState.values.firstWhere(
          (s) => s.toString() == 'GameState.${json['state']}',
          orElse: () => GameState.waiting),
      currentChallenge: json['current_challenge'] != null
          ? Melody.fromJson(json['current_challenge'] as Map<String, dynamic>)
          : null,
      currentRound: json['current_round'] as int? ?? 1,
      totalRounds: json['total_rounds'] as int? ?? 5,
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'players': players.map((p) => p.toJson()).toList(),
      'active_player': activePlayer?.toJson(),
      'challenge_player': challengePlayer?.toJson(),
      'state': state.toString().split('.').last,
      'current_challenge': currentChallenge?.toJson(),
      'current_round': currentRound,
      'total_rounds': totalRounds,
      'last_activity': lastActivity?.toIso8601String(),
    };
  }
} 