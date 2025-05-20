import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'dart:async';

/// Service to communicate with the Flask melody matching server
class ServerMelodyMatcher {
  ServerMelodyMatcher._();
  static final instance = ServerMelodyMatcher._();

  // URL of the deployed Flask server API
  static const String _baseUrl = 'http://localhost:5002';
  
  // Default timeout duration
  static const Duration _requestTimeout = Duration(seconds: 5);
  
  // Track if server is available to avoid repeated timeouts
  bool _serverAvailable = true;
  
  /// Compare two melodies using the server's algorithms
  /// Returns a score from 0 to 1 (1 being perfect match)
  Future<Map<String, dynamic>> compareMelodies(
    List<int> melody1, List<int> melody2
  ) async {
    // Skip server request if we already know it's unavailable
    if (!_serverAvailable) {
      return _getDefaultResult(melody1, melody2);
    }
    
    try {
      developer.log('Comparing melodies with server: ${melody1.length} notes vs ${melody2.length} notes');
      
      // Make POST request to the API with timeout
      final response = await http.post(
        Uri.parse('$_baseUrl/api/compare-melodies'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'melody1': melody1,
          'melody2': melody2,
        }),
      ).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('Melody comparison successful: $data');
        return data;
      } else {
        developer.log('Melody comparison failed: ${response.statusCode} - ${response.body}');
        _serverAvailable = false;
        return _getDefaultResult(melody1, melody2);
      }
    } on TimeoutException {
      developer.log('Melody comparison timed out');
      // Mark server as unavailable to avoid future timeouts
      _serverAvailable = false;
      return _getDefaultResult(melody1, melody2);
    } catch (e) {
      developer.log('Error comparing melodies: $e');
      _serverAvailable = false;
      return _getDefaultResult(melody1, melody2);
    }
  }

  /// Estimate the difficulty of a melody using server algorithms
  /// Returns a difficulty score from 1 (easy) to 10 (hard)
  Future<Map<String, dynamic>> estimateDifficulty(List<int> melody) async {
    // Skip server request if we already know it's unavailable
    if (!_serverAvailable) {
      return _getDefaultDifficultyResult(melody);
    }
    
    try {
      developer.log('Estimating difficulty of melody with ${melody.length} notes');
      
      // Make POST request to the API with timeout
      final response = await http.post(
        Uri.parse('$_baseUrl/api/estimate-difficulty'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'melody': melody,
        }),
      ).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('Difficulty estimation successful: $data');
        return data;
      } else {
        developer.log('Difficulty estimation failed: ${response.statusCode} - ${response.body}');
        return _getDefaultDifficultyResult(melody);
      }
    } on TimeoutException {
      developer.log('Difficulty estimation timed out');
      return _getDefaultDifficultyResult(melody);
    } catch (e) {
      developer.log('Error estimating difficulty: $e');
      return _getDefaultDifficultyResult(melody);
    }
  }
  
  /// Test the connection to the server
  Future<bool> testConnection() async {
    try {
      developer.log('Testing connection to melody matcher server');
      final response = await http.get(
        Uri.parse('$_baseUrl/api/health')
      ).timeout(_requestTimeout);
      
      final success = response.statusCode == 200;
      developer.log('Server connection test: ${success ? 'SUCCESS' : 'FAILED'}');
      _serverAvailable = success;
      return success;
    } on TimeoutException {
      developer.log('Server connection test timed out');
      _serverAvailable = false;
      return false;
    } catch (e) {
      developer.log('Error testing melody matcher server connection: $e');
      _serverAvailable = false;
      return false;
    }
  }
  
  /// Create a default result for fallback
  Map<String, dynamic> _getDefaultResult(List<int> melody1, List<int> melody2) {
    // Calculate a simple similarity score based on note counts
    double simpleScore = 0.0;
    
    // If melody lengths match, that's a good start
    if (melody1.length == melody2.length) {
      simpleScore = 0.5;
      
      // Count matching notes
      int matches = 0;
      for (int i = 0; i < melody1.length; i++) {
        if (melody1[i] == melody2[i]) {
          matches++;
        }
      }
      
      // Add percentage of matching notes to score
      if (melody1.isNotEmpty) {
        simpleScore += 0.5 * (matches / melody1.length);
      }
    } else {
      // Penalize length differences
      final lengthDiff = (melody1.length - melody2.length).abs();
      final maxLength = [melody1.length, melody2.length].reduce((a, b) => a > b ? a : b);
      simpleScore = 0.5 * (1 - (lengthDiff / maxLength));
    }
    
    return {
      'success': true,
      'result': {
        'final_score': simpleScore,
        'individual_scores': {
          'dtw': simpleScore,
          'levenshtein': simpleScore,
          'lcs': simpleScore,
          'cosine': simpleScore
        }
      }
    };
  }

  /// Create a default difficulty estimation for fallback
  Map<String, dynamic> _getDefaultDifficultyResult(List<int> melody) {
    // Simple difficulty estimate based on melody length and note range
    double difficultyScore = 1.0; // Start with minimum difficulty
    
    // Factor 1: Length - longer melodies are harder
    difficultyScore += melody.length / 2.0; // Add 0.5 points per note
    
    // Factor 2: Range - wider range is harder
    if (melody.isNotEmpty) {
      final minNote = melody.reduce((a, b) => a < b ? a : b);
      final maxNote = melody.reduce((a, b) => a > b ? a : b);
      final range = maxNote - minNote;
      difficultyScore += range / 12.0; // Add 1 point per octave
    }
    
    // Factor 3: Intervals - larger jumps are harder
    if (melody.length > 1) {
      int totalJump = 0;
      for (int i = 1; i < melody.length; i++) {
        totalJump += (melody[i] - melody[i-1]).abs();
      }
      final avgJump = totalJump / (melody.length - 1);
      difficultyScore += avgJump / 2.0; // Add 0.5 points per semitone of average jump
    }
    
    // Clamp the result to 1-10 range
    difficultyScore = difficultyScore.clamp(1.0, 10.0);
    
    return {
      'success': true,
      'result': {
        'difficulty_score': difficultyScore,
        'factors': {
          'length': melody.length,
          'complexity': difficultyScore - 1, // Adjusted complexity factor
        }
      }
    };
  }
} 