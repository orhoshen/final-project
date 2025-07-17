import 'dart:async';
import 'dart:convert';

// dart:io is not available on web, which was causing the error.
// We will rely on http's ClientException for network errors.
// import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// A dedicated service for handling all HTTP API calls to the game server.
///
/// This class provides methods that correspond to the REST API endpoints
/// defined in the server's documentation. It handles making the requests,
/// processing responses, and throwing informative exceptions on errors.
class ServerManager {
  ServerManager._();
  static final instance = ServerManager._();

  static final String _baseUrl = dotenv.env['FLASK_SERVER_URL'] ?? 'http://localhost:5001';
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// A generic helper for making POST requests.
  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    } on http.ClientException {
      // This is the platform-independent exception for network errors.
      throw Exception('Could not connect to the server. Please check your network connection.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// A generic helper for making GET requests.
  Future<Map<String, dynamic>> _get(String endpoint, [Map<String, String>? queryParams]) async {
    final url = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParams);
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(_requestTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    } on http.ClientException {
      // This is the platform-independent exception for network errors.
      throw Exception('Could not connect to the server. Please check your network connection.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Processes the HTTP response and handles errors.
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Return the full data for proper access to all fields
        return data;
      } else {
        throw Exception(data['error'] ?? 'An unknown server error occurred.');
      }
    } else {
      throw Exception('Server error: ${response.statusCode} - ${response.reasonPhrase}');
    }
  }

  /// Tests the connection to the server's health check endpoint.
  Future<bool> testConnection() async {
    try {
      // Use the /api/health endpoint to check connectivity
      final response = await http.get(
        Uri.parse('$_baseUrl/api/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Single Player ---

  /// Compares two melodies without room/game management.
  /// Corresponds to POST /api/compare-melodies
  Future<Map<String, dynamic>> compareMelodies(List<int> melody1, List<int> melody2) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/compare-melodies'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'melody1': melody1, 'melody2': melody2}),
      ).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; // Return the full response including 'success' and 'result'
      } else {
        return {'success': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  // --- Multiplayer Room Management ---

  /// Fetches a list of all available rooms.
  /// Corresponds to GET /api/room/list
  Future<List<dynamic>> listRooms() async {
    final result = await _get('/api/room/list');
    return result['rooms'] ?? [];
  }

  /// Creates a new game room.
  /// Corresponds to POST /api/room/create
  Future<Map<String, dynamic>> createRoom(String playerName) async {
    return await _post('/api/room/create', {'player_name': playerName});
  }

  /// Joins an existing game room.
  /// Corresponds to POST /api/room/join
  Future<Map<String, dynamic>> joinRoom(String roomId, String playerName) async {
    return await _post('/api/room/join', {'room_id': roomId, 'player_name': playerName});
  }

  /// Leaves the current game room.
  /// Corresponds to POST /api/room/leave
  Future<void> leaveRoom(String roomId, String playerId) async {
    await _post('/api/room/leave', {'room_id': roomId, 'player_id': playerId});
  }

  /// Gets the current status of a specific room.
  /// Corresponds to GET /api/room/status
  Future<Map<String, dynamic>> getRoomStatus(String roomId) async {
    return await _get('/api/room/status', {'room_id': roomId});
  }

  // --- Multiplayer Gameplay ---

  /// Submits a melody for the other player to guess.
  /// Corresponds to POST /api/room/record-melody
  Future<Map<String, dynamic>> recordMelody(
      String roomId, String playerId, List<int> melody, List<int> timings, List<int> durations) async {
    return await _post('/api/room/record-melody', {
      'room_id': roomId,
      'player_id': playerId,
      'melody': melody,
      'timings': timings,
      'durations': durations,
    });
  }

  /// Gets the current melody challenge for a room.
  /// Corresponds to GET /api/room/get-challenge
  Future<Map<String, dynamic>> getChallenge(String roomId, String playerId) async {
    return await _get('/api/room/get-challenge', {
      'room_id': roomId,
      'player_id': playerId
    });
  }

  /// Submits a replay attempt for scoring.
  /// Corresponds to POST /api/room/submit-replay
  Future<Map<String, dynamic>> submitReplay(
      String roomId, String playerId, List<int> melody, List<int> timings, List<int> durations) async {
    return await _post('/api/room/submit-replay', {
      'room_id': roomId,
      'player_id': playerId,
      'melody': melody,
      'timings': timings,
      'durations': durations,
    });
  }
}
