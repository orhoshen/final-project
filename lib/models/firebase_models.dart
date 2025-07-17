import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase data models for the Piano Game app
/// These models represent the structure of data stored in Firestore

// A simple data class for a melody.
class SharedMelody {
  final String id;
  final String name;
  final List<int> notes;

  SharedMelody({required this.id, required this.name, required this.notes});

  factory SharedMelody.fromJson(Map<String, dynamic> json) {
    return SharedMelody(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: List<int>.from(json['notes'] as List),
    );
  }
}

/// Represents a user profile in Firebase
class UserProfile {
  final String userId;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final int totalGamesPlayed;
  final int totalScore;
  final int highScore;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> statistics;

  UserProfile({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.createdAt,
    required this.lastActiveAt,
    this.totalGamesPlayed = 0,
    this.totalScore = 0,
    this.highScore = 0,
    this.settings = const {},
    this.statistics = const {},
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'totalGamesPlayed': totalGamesPlayed,
      'totalScore': totalScore,
      'highScore': highScore,
      'settings': settings,
      'statistics': statistics,
    };
  }

  /// Create from Firestore document
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastActiveAt: (map['lastActiveAt'] as Timestamp).toDate(),
      totalGamesPlayed: map['totalGamesPlayed'] ?? 0,
      totalScore: map['totalScore'] ?? 0,
      highScore: map['highScore'] ?? 0,
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      statistics: Map<String, dynamic>.from(map['statistics'] ?? {}),
    );
  }

  /// Create a copy with updated values
  UserProfile copyWith({
    String? userId,
    String? displayName,
    String? email,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    int? totalGamesPlayed,
    int? totalScore,
    int? highScore,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? statistics,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalScore: totalScore ?? this.totalScore,
      highScore: highScore ?? this.highScore,
      settings: settings ?? this.settings,
      statistics: statistics ?? this.statistics,
    );
  }
}

/// Game session data
class GameSession {
  final String sessionId;
  final String userId;
  final String gameMode; // 'computer', 'player', 'multiplayer'
  final DateTime startedAt;
  final DateTime? endedAt;
  final int finalScore;
  final int roundsPlayed;
  final List<RoundResult> rounds;
  final Map<String, dynamic> metadata;
  final String status; // 'in_progress', 'completed', 'abandoned'

  GameSession({
    required this.sessionId,
    required this.userId,
    required this.gameMode,
    required this.startedAt,
    this.endedAt,
    this.finalScore = 0,
    this.roundsPlayed = 0,
    this.rounds = const [],
    this.metadata = const {},
    this.status = 'in_progress',
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'gameMode': gameMode,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'finalScore': finalScore,
      'roundsPlayed': roundsPlayed,
      'rounds': rounds.map((round) => round.toMap()).toList(),
      'metadata': metadata,
      'status': status,
    };
  }

  /// Create from Firestore document
  factory GameSession.fromMap(Map<String, dynamic> map) {
    return GameSession(
      sessionId: map['sessionId'] ?? '',
      userId: map['userId'] ?? '',
      gameMode: map['gameMode'] ?? '',
      startedAt: (map['startedAt'] as Timestamp).toDate(),
      endedAt: map['endedAt'] != null ? (map['endedAt'] as Timestamp).toDate() : null,
      finalScore: map['finalScore'] ?? 0,
      roundsPlayed: map['roundsPlayed'] ?? 0,
      rounds: (map['rounds'] as List<dynamic>?)
              ?.map((round) => RoundResult.fromMap(Map<String, dynamic>.from(round)))
              .toList() ??
          [],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      status: map['status'] ?? 'in_progress',
    );
  }

  /// Create a copy with updated values
  GameSession copyWith({
    String? sessionId,
    String? userId,
    String? gameMode,
    DateTime? startedAt,
    DateTime? endedAt,
    int? finalScore,
    int? roundsPlayed,
    List<RoundResult>? rounds,
    Map<String, dynamic>? metadata,
    String? status,
  }) {
    return GameSession(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      gameMode: gameMode ?? this.gameMode,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      finalScore: finalScore ?? this.finalScore,
      roundsPlayed: roundsPlayed ?? this.roundsPlayed,
      rounds: rounds ?? this.rounds,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
    );
  }
}

/// Individual round result data
class RoundResult {
  final int roundNumber;
  final List<int> referenceNotes;
  final List<int> playerNotes;
  final List<int> referenceTiming;
  final List<int> playerTiming;
  final List<int> referenceDurations;
  final List<int> playerDurations;
  final double score;
  final Map<String, dynamic> analysisData;
  final DateTime completedAt;
  final int processingTimeMs;

  RoundResult({
    required this.roundNumber,
    this.referenceNotes = const [],
    this.playerNotes = const [],
    this.referenceTiming = const [],
    this.playerTiming = const [],
    this.referenceDurations = const [],
    this.playerDurations = const [],
    required this.score,
    this.analysisData = const {},
    required this.completedAt,
    this.processingTimeMs = 0,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'roundNumber': roundNumber,
      'referenceNotes': referenceNotes,
      'playerNotes': playerNotes,
      'referenceTiming': referenceTiming,
      'playerTiming': playerTiming,
      'referenceDurations': referenceDurations,
      'playerDurations': playerDurations,
      'score': score,
      'analysisData': analysisData,
      'completedAt': Timestamp.fromDate(completedAt),
      'processingTimeMs': processingTimeMs,
    };
  }

  /// Create from Firestore document
  factory RoundResult.fromMap(Map<String, dynamic> map) {
    return RoundResult(
      roundNumber: map['roundNumber'] ?? 0,
      referenceNotes: List<int>.from(map['referenceNotes'] ?? []),
      playerNotes: List<int>.from(map['playerNotes'] ?? []),
      referenceTiming: List<int>.from(map['referenceTiming'] ?? []),
      playerTiming: List<int>.from(map['playerTiming'] ?? []),
      referenceDurations: List<int>.from(map['referenceDurations'] ?? []),
      playerDurations: List<int>.from(map['playerDurations'] ?? []),
      score: (map['score'] ?? 0.0).toDouble(),
      analysisData: Map<String, dynamic>.from(map['analysisData'] ?? {}),
      completedAt: (map['completedAt'] as Timestamp).toDate(),
      processingTimeMs: map['processingTimeMs'] ?? 0,
    );
  }
}

/// Leaderboard entry
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final int score;
  final String gameMode;
  final DateTime achievedAt;
  final Map<String, dynamic> gameData;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.score,
    required this.gameMode,
    required this.achievedAt,
    this.gameData = const {},
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'score': score,
      'gameMode': gameMode,
      'achievedAt': Timestamp.fromDate(achievedAt),
      'gameData': gameData,
    };
  }

  /// Create from Firestore document
  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? '',
      score: map['score'] ?? 0,
      gameMode: map['gameMode'] ?? '',
      achievedAt: (map['achievedAt'] as Timestamp).toDate(),
      gameData: Map<String, dynamic>.from(map['gameData'] ?? {}),
    );
  }
}

/// Game statistics and analytics
class GameStatistics {
  final String userId;
  final String gameMode;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalGames;
  final int totalScore;
  final double averageScore;
  final int bestScore;
  final int totalPlayTime; // in seconds
  final Map<String, dynamic> detailedStats;

  GameStatistics({
    required this.userId,
    required this.gameMode,
    required this.periodStart,
    required this.periodEnd,
    this.totalGames = 0,
    this.totalScore = 0,
    this.averageScore = 0.0,
    this.bestScore = 0,
    this.totalPlayTime = 0,
    this.detailedStats = const {},
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'gameMode': gameMode,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'totalGames': totalGames,
      'totalScore': totalScore,
      'averageScore': averageScore,
      'bestScore': bestScore,
      'totalPlayTime': totalPlayTime,
      'detailedStats': detailedStats,
    };
  }

  /// Create from Firestore document
  factory GameStatistics.fromMap(Map<String, dynamic> map) {
    return GameStatistics(
      userId: map['userId'] ?? '',
      gameMode: map['gameMode'] ?? '',
      periodStart: (map['periodStart'] as Timestamp).toDate(),
      periodEnd: (map['periodEnd'] as Timestamp).toDate(),
      totalGames: map['totalGames'] ?? 0,
      totalScore: map['totalScore'] ?? 0,
      averageScore: (map['averageScore'] ?? 0.0).toDouble(),
      bestScore: map['bestScore'] ?? 0,
      totalPlayTime: map['totalPlayTime'] ?? 0,
      detailedStats: Map<String, dynamic>.from(map['detailedStats'] ?? {}),
    );
  }
}
