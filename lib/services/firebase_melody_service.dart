import 'dart:developer' as developer;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:async';
import 'server_melody_matcher.dart';

/// Service to fetch pre-saved melodies from Firebase
class FirebaseMelodyService {
  FirebaseMelodyService._();
  static final instance = FirebaseMelodyService._();
  
  // Use Firebase function URL or direct Firestore REST API
  static const String _apiBaseUrl = 'http://localhost:5002/api/melodies';
  static const String _firestoreApiUrl = 'https://firestore.googleapis.com/v1/projects/finalproj-piano-game/databases/(default)/documents/melodies';
  static const String _localMelodiesUrl = 'http://localhost:5002/static/melodies.json';
  
  // Cache of fetched melodies to reduce API calls
  final Map<int, List<List<int>>> _cachedMelodiesByDifficulty = {};
  final List<List<int>> _cachedMelodies = [];
  bool _isFetchingMelodies = false;
  final ServerMelodyMatcher _serverMatcher = ServerMelodyMatcher.instance;
  
  /// Get a saved melody, fallback to a generated one if needed
  Future<List<int>> getMelody({int complexity = 4}) async {
    // Try to use a cached melody with matching difficulty if available
    if (_cachedMelodiesByDifficulty.containsKey(complexity) && 
        _cachedMelodiesByDifficulty[complexity]!.isNotEmpty) {
      final random = Random();
      final targetMelodies = _cachedMelodiesByDifficulty[complexity]!;
      return targetMelodies[random.nextInt(targetMelodies.length)];
    }
    
    // If no exact match, try to find melodies with similar difficulty
    if (_cachedMelodies.isNotEmpty) {
      // Select a random melody from cache
      final random = Random();
      return _cachedMelodies[random.nextInt(_cachedMelodies.length)];
    }
    
    // Try to fetch melodies if cache is empty and not already fetching
    if (!_isFetchingMelodies) {
      _isFetchingMelodies = true;
      fetchMelodies().then((_) {
        _isFetchingMelodies = false;
      }).catchError((e) {
        _isFetchingMelodies = false;
        developer.log('Error fetching melodies: $e');
      });
    }
    
    // Generate a fallback melody while waiting for fetch
    return _generateFallbackMelody(complexity);
  }
  
  /// Fetch saved melodies from the server
  Future<void> fetchMelodies() async {
    try {
      // First try local melodies.json as our primary source
      try {
        developer.log('Fetching melodies from local JSON');
        final response = await http.get(
          Uri.parse(_localMelodiesUrl),
        ).timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data.containsKey('melodies') && data['melodies'] is List) {
            final melodies = data['melodies'] as List;
            
            _cachedMelodies.clear();
            _cachedMelodiesByDifficulty.clear();
            
            for (final melody in melodies) {
              if (melody['notes'] is List) {
                final notes = List<int>.from(melody['notes']);
                
                if (notes.isNotEmpty) {
                  // Filter out notes outside the C3-C6 range (MIDI 48-84)
                  bool validRange = true;
                  for (final note in notes) {
                    if (note < 48 || note > 84) {
                      validRange = false;
                      break;
                    }
                  }
                  
                  if (validRange) {
                    _cachedMelodies.add(notes);
                    
                    // Add to difficulty mapping
                    if (melody.containsKey('difficulty')) {
                      final difficulty = melody['difficulty'] as int;
                      if (!_cachedMelodiesByDifficulty.containsKey(difficulty)) {
                        _cachedMelodiesByDifficulty[difficulty] = [];
                      }
                      _cachedMelodiesByDifficulty[difficulty]!.add(notes);
                    }
                    
                    developer.log('Loaded local melody: ${melody['title']} with ${notes.length} notes');
                  } else {
                    developer.log('Skipped melody with notes outside C3-C6 range');
                  }
                }
              }
            }
            
            developer.log('Fetched ${_cachedMelodies.length} melodies from local JSON');
            
            // If we successfully loaded melodies from local JSON, stop here
            if (_cachedMelodies.isNotEmpty) {
              return;
            }
          }
        }
      } catch (e) {
        developer.log('Error fetching local melodies: $e, trying Firestore');
      }
      
      // Try Firestore as fallback if local JSON fails
      developer.log('Fetching melodies from Firestore');
      try {
        final response = await http.get(
          Uri.parse(_firestoreApiUrl),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data.containsKey('documents') && data['documents'] is List) {
            final documents = data['documents'] as List;
            
            _cachedMelodies.clear();
            for (final doc in documents) {
              if (doc.containsKey('fields') && 
                  doc['fields'].containsKey('notes') && 
                  doc['fields']['notes'].containsKey('arrayValue')) {
                
                final notesArray = doc['fields']['notes']['arrayValue'];
                if (notesArray.containsKey('values')) {
                  final notesList = notesArray['values'] as List;
                  final notes = notesList
                      .map((note) => note.containsKey('integerValue') 
                          ? int.parse(note['integerValue']) 
                          : null)
                      .where((note) => note != null)
                      .cast<int>()
                      .toList();
                  
                  if (notes.isNotEmpty) {
                    // Filter out notes outside the C3-C6 range (MIDI 48-84)
                    bool validRange = true;
                    for (final note in notes) {
                      if (note < 48 || note > 84) {
                        validRange = false;
                        break;
                      }
                    }
                    
                    if (validRange) {
                      _cachedMelodies.add(notes);
                      
                      // Add to difficulty mapping if difficulty field exists
                      if (doc['fields'].containsKey('difficulty') && 
                          doc['fields']['difficulty'].containsKey('integerValue')) {
                        final difficulty = int.parse(doc['fields']['difficulty']['integerValue']);
                        if (!_cachedMelodiesByDifficulty.containsKey(difficulty)) {
                          _cachedMelodiesByDifficulty[difficulty] = [];
                        }
                        _cachedMelodiesByDifficulty[difficulty]!.add(notes);
                      }
                      
                      developer.log('Loaded melody with ${notes.length} notes: $notes');
                    }
                  }
                }
              }
            }
            
            developer.log('Fetched ${_cachedMelodies.length} melodies from Firestore');
            
            // Process melodies and categorize by difficulty in the background if not already done
            if (_cachedMelodiesByDifficulty.isEmpty) {
              _categorizeMelodiesByDifficulty();
            }
            
            // Stop if we successfully loaded melodies from Firestore
            if (_cachedMelodies.isNotEmpty) {
              return;
            }
          }
        }
      } catch (e) {
        developer.log('Error fetching melodies from Firestore: $e, trying legacy API');
      }
      
      // Try legacy API endpoint as final fallback
      _fetchLegacyMelodies();
    } on TimeoutException {
      developer.log('Melody fetch timed out, trying legacy endpoint');
      _fetchLegacyMelodies();
    } catch (e) {
      developer.log('Error fetching melodies: $e, trying legacy endpoint');
      _fetchLegacyMelodies();
    }
  }
  
  /// Fallback to the legacy melody API if Firestore fails
  Future<void> _fetchLegacyMelodies() async {
    try {
      developer.log('Fetching melodies from legacy API');
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/list'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['melodies'] != null) {
          final melodies = (data['melodies'] as List);
          
          _cachedMelodies.clear();
          for (final melody in melodies) {
            final noteSequence = (melody['notes'] as List).map((n) => n as int).toList();
            
            if (noteSequence.isNotEmpty) {
              // Filter out notes outside the C3-C6 range (MIDI 48-84)
              bool validRange = true;
              for (final note in noteSequence) {
                if (note < 48 || note > 84) {
                  validRange = false;
                  break;
                }
              }
              
              if (validRange) {
                _cachedMelodies.add(noteSequence);
                developer.log('Loaded legacy melody with ${noteSequence.length} notes');
              } else {
                developer.log('Skipped legacy melody with notes outside C3-C6 range');
              }
            }
          }
          
          developer.log('Fetched ${_cachedMelodies.length} melodies from legacy API');
          
          // Process melodies and categorize by difficulty in the background
          _categorizeMelodiesByDifficulty();
        }
      } else {
        developer.log('Failed to fetch melodies from legacy API: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching melodies from legacy API: $e');
    }
  }
  
  /// Categorize fetched melodies by difficulty using the server's estimator
  Future<void> _categorizeMelodiesByDifficulty() async {
    if (_cachedMelodies.isEmpty) return;
    
    developer.log('Categorizing ${_cachedMelodies.length} melodies by difficulty');
    
    // Clear existing categorization
    _cachedMelodiesByDifficulty.clear();
    
    // Initialize difficulty buckets (1-10)
    for (int i = 1; i <= 10; i++) {
      _cachedMelodiesByDifficulty[i] = [];
    }
    
    // Process each melody
    for (final melody in _cachedMelodies) {
      try {
        // Estimate difficulty using server
        final result = await _serverMatcher.estimateDifficulty(melody);
        
        if (result['success'] == true) {
          final difficultyScore = result['result']['difficulty_score'] as double;
          final difficulty = difficultyScore.round().clamp(1, 10);
          
          // Add to appropriate bucket
          _cachedMelodiesByDifficulty[difficulty]!.add(melody);
          
          developer.log('Melody difficulty: $difficulty (${melody.length} notes)');
        } else {
          // Fallback to length-based categorization
          final difficulty = _calculateSimpleDifficulty(melody);
          _cachedMelodiesByDifficulty[difficulty]!.add(melody);
        }
      } catch (e) {
        developer.log('Error categorizing melody: $e');
        // Fallback to length-based categorization
        final difficulty = _calculateSimpleDifficulty(melody);
        _cachedMelodiesByDifficulty[difficulty]!.add(melody);
      }
    }
    
    // Log the counts per difficulty level
    for (int i = 1; i <= 10; i++) {
      developer.log('Difficulty $i: ${_cachedMelodiesByDifficulty[i]!.length} melodies');
    }
  }
  
  /// Calculate a simple difficulty level based on melody length and range
  int _calculateSimpleDifficulty(List<int> melody) {
    // Simple difficulty is based on melody length
    final length = melody.length;
    int difficulty = (length / 2).round().clamp(1, 10);
    
    // Adjust based on range if we have at least 2 notes
    if (melody.length >= 2) {
      final maxNote = melody.reduce((a, b) => a > b ? a : b);
      final minNote = melody.reduce((a, b) => a < b ? a : b);
      final range = maxNote - minNote;
      
      // Wide range increases difficulty
      if (range > 12) {
        difficulty += 1;
      }
    }
    
    return difficulty.clamp(1, 10);
  }
  
  /// Generate a fallback melody if server fetch fails
  List<int> _generateFallbackMelody(int complexity) {
    final result = <int>[];
    final random = Random();
    
    // Adjust length based on complexity (1-10)
    final length = complexity + random.nextInt(2); // Complexity + 0 or 1
    
    // Start with middle C (MIDI 60, which is C4)
    int currentNote = 60;
    result.add(currentNote);
    
    // Add more notes with small intervals for a musical result
    for (int i = 1; i < length; i++) {
      // Generate a step with range based on complexity
      final maxStep = ((complexity / 3) + 1).floor(); // Higher complexity = larger jumps
      final step = random.nextInt(maxStep * 2 + 1) - maxStep; // Range of -maxStep to +maxStep
      currentNote += step;
      
      // Keep within reasonable range (C3 to C6) - MIDI 48-84
      currentNote = currentNote.clamp(48, 84);
      result.add(currentNote);
    }
    
    return result;
  }
} 