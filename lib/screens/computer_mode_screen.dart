import 'package:flutter/material.dart';
import '../widgets/piano_keyboard.dart';
import '../services/midi_service.dart';
import '../services/simple_audio_player.dart';
import '../services/server_melody_matcher.dart';
import '../services/firebase_melody_service.dart';
import 'dart:developer' as developer;

class ComputerModeScreen extends StatefulWidget {
  const ComputerModeScreen({super.key});

  @override
  State<ComputerModeScreen> createState() => _ComputerModeScreenState();
}

class _ComputerModeScreenState extends State<ComputerModeScreen> {
  final FirebaseMelodyService _melodyService = FirebaseMelodyService();
  final ServerMelodyMatcher _matcherService = ServerMelodyMatcher.instance;
  final MidiService _midiService = MidiService();
  final SimpleAudioPlayer _simpleAudio = SimpleAudioPlayer();
  List<int> _computerSequence = [];
  List<int> _playerSequence = [];
  bool _isPlayerTurn = false;
  int _score = 0;
  bool _isPlayingSequence = false;
  int? _highlightedNote;
  bool _serverAvailable = false;
  String _statusMessage = 'Initializing...';
  double? _lastMatchScore;
  Map<String, dynamic>? _lastDifficultyInfo;
  Map<String, dynamic>? _lastComparisonDetails;
  int? _processingTimeMs;

  @override
  void initState() {
    super.initState();
    _initServices();
  }
  
  Future<void> _initServices() async {
    try {
      setState(() {
        _statusMessage = 'Initializing audio...';
      });
      
      await _midiService.initialize();
      // Play a test sound to warm up the audio system
      await _midiService.testAudio();
      
      setState(() {
        _statusMessage = 'Testing server connection...';
      });
      
      // Test server connection
      _serverAvailable = await _matcherService.testConnection();
      developer.log('Server connection test: ${_serverAvailable ? 'SUCCESS' : 'FAILED'}');
      
      setState(() {
        _statusMessage = _serverAvailable 
            ? 'Connected to melody server' 
            : 'Using offline mode';
      });
      
      // Prefetch melodies in the background
      _melodyService.fetchMelodies().then((_) {
        if (mounted) {
          setState(() {
            // _hasFetchedMelodies = true;
          });
        }
      }).catchError((e) {
        developer.log('Error prefetching melodies: $e');
      });
      
      // Start the game after a short delay
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        _startNewGame();
      }
    } catch (e) {
      developer.log('Error initializing services: $e');
      if (mounted) {
        setState(() {
          _serverAvailable = false;
          _statusMessage = 'Error initializing: $e';
        });
      }
    }
  }

  void _onNotePressed(int midiNote) {
    if (!_isPlayerTurn || _isPlayingSequence) return;

    setState(() {
      _playerSequence.add(midiNote);
      _highlightedNote = midiNote;
    });
    
    // Play sound using both methods for reliability, same as in _playComputerSequence
    _midiService.playMidiNote(midiNote).catchError((error) {
      developer.log('MidiService error, using fallback: $error');
      _simpleAudio.playPianoNote(midiNote);
    });

    // Check if the player's sequence is complete
    if (_playerSequence.length == _computerSequence.length) {
      _checkSequenceMatch();
    }
  }

  Future<void> _checkSequenceMatch() async {
    setState(() {
      _statusMessage = 'Analyzing your melody...';
      _lastComparisonDetails = null;
      _processingTimeMs = null;
    });
    
    // Record start time to calculate processing time
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    if (_serverAvailable) {
      try {
        // Use server for more advanced comparison
        final result = await _matcherService.compareMelodies(
          _computerSequence, 
          _playerSequence
        );
        
        // Calculate processing time
        final endTime = DateTime.now().millisecondsSinceEpoch;
        final processingTime = endTime - startTime;
        
        if (result['success'] == true) {
          final resultData = result['result'];
          final score = resultData['final_score'] as double;
          final detailedScores = resultData['individual_scores'] as Map<String, dynamic>;
          
          // Extract additional metrics if available
          Map<String, dynamic> additionalMetrics = {};
          
          if (resultData.containsKey('pitch_accuracy')) {
            additionalMetrics['pitch_accuracy'] = resultData['pitch_accuracy'];
          }
          if (resultData.containsKey('timing_accuracy')) {
            additionalMetrics['timing_accuracy'] = resultData['timing_accuracy'];
          }
          if (resultData.containsKey('onset_accuracy')) {
            additionalMetrics['onset_accuracy'] = resultData['onset_accuracy'];
          }
          if (resultData.containsKey('duration_accuracy')) {
            additionalMetrics['duration_accuracy'] = resultData['duration_accuracy'];
          }
          
          developer.log('Server comparison score: $score');
          developer.log('Individual scores: $detailedScores');
          developer.log('Additional metrics: $additionalMetrics');
          developer.log('Processing time: $processingTime ms');
          
          setState(() {
            _lastMatchScore = score;
            _lastComparisonDetails = Map<String, dynamic>.from(resultData);
            _processingTimeMs = processingTime;
          });
          
          // Consider it correct if score is above threshold (adjusting threshold based on difficulty)
          double threshold = 0.7;
          if (_lastDifficultyInfo != null && 
              _lastDifficultyInfo!['difficulty_score'] != null) {
            // More difficult melodies get a more lenient threshold
            final difficulty = _lastDifficultyInfo!['difficulty_score'] as double;
            threshold = 0.8 - (difficulty / 50); // 0.8 at lowest difficulty, down to 0.6 at highest
            threshold = threshold.clamp(0.6, 0.8);
            developer.log('Adjusted match threshold: $threshold (difficulty: $difficulty)');
          }
          
          final isCorrect = score > threshold;
          
          if (isCorrect) {
            setState(() {
              _score++;
              _isPlayerTurn = false;
              _playerSequence = [];
              _statusMessage = 'Good job! Score: ${(score * 100).toStringAsFixed(1)}%';
            });
            
            // Add a delay so player can see the status before next melody
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              _setNextMelody();
            }
          } else {
            setState(() {
              _statusMessage = 'Not quite right: ${(score * 100).toStringAsFixed(1)}%';
            });
            // Add a delay so player can see the score
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              _showGameOver(score);
            }
          }
        } else {
          // Fall back to simple comparison if server returns error
          developer.log('Server error, using fallback comparison');
          _performSimpleComparison();
        }
      } catch (e) {
        developer.log('Error with server comparison: $e');
        _performSimpleComparison();
      }
    } else {
      // Use simple comparison if server is not available
      _performSimpleComparison();
    }
  }
  
  void _performSimpleComparison() {
    // Record start time to calculate processing time
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    bool isCorrect = true;
    int matches = 0;
    
    for (int i = 0; i < _playerSequence.length; i++) {
      if (_playerSequence[i] == _computerSequence[i]) {
        matches++;
      } else {
        isCorrect = false;
      }
    }
    
    // Calculate a simple score
    final simpleScore = _computerSequence.isEmpty ? 0.0 : matches / _computerSequence.length;
    
    // Calculate processing time
    final endTime = DateTime.now().millisecondsSinceEpoch;
    final processingTime = endTime - startTime;
    
    setState(() {
      _lastMatchScore = simpleScore;
      _processingTimeMs = processingTime;
      _lastComparisonDetails = {
        'final_score': simpleScore,
        'pitch_accuracy': simpleScore,
        'individual_scores': {
          'exact_match': simpleScore,
        },
      };
    });

    if (isCorrect) {
      setState(() {
        _score++;
        _isPlayerTurn = false;
        _playerSequence = [];
        _statusMessage = 'Good job! Perfect match!';
      });
      _setNextMelody();
    } else {
      setState(() {
        _statusMessage = 'Not quite right: ${(simpleScore * 100).toStringAsFixed(1)}%';
      });
      // Add a delay so player can see the score
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _showGameOver(simpleScore);
        }
      });
    }
  }

  void _onNoteReleased(int midiNote) {
    if (!mounted) return;
    if (_highlightedNote == midiNote) {
      // Delay setState to after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Check mounted again inside the callback
          setState(() {
            _highlightedNote = null;
          });
        }
      });
    }
  }
  
  Future<void> _setNextMelody() async {
    // Get next melody from the service (complexity increases with score)
    final complexity = (_score + 3).clamp(3, 8);
    
    setState(() {
      _statusMessage = 'Loading next melody (level $complexity)...';
      _lastComparisonDetails = null;
      _processingTimeMs = null;
    });
    
    final melody = await _melodyService.getMelody(complexity: complexity);
    
    setState(() {
      _computerSequence = melody;
    });
    
    developer.log('Setting next melody: $_computerSequence (complexity: $complexity)');
    
    // If server is available, get the actual difficulty estimate
    if (_serverAvailable) {
      try {
        final difficultyResult = await _matcherService.estimateDifficulty(melody);
        if (difficultyResult['success'] == true) {
          setState(() {
            _lastDifficultyInfo = difficultyResult['result'];
            final diffScore = _lastDifficultyInfo!['difficulty_score'] as double;
            _statusMessage = 'Next melody (difficulty: ${diffScore.toStringAsFixed(1)}/10)';
          });
          developer.log('Melody difficulty: $_lastDifficultyInfo');
        }
      } catch (e) {
        developer.log('Error getting difficulty estimate: $e');
      }
    }
    
    _playComputerSequence();
  }

  Future<void> _playComputerSequence() async {
    developer.log('Playing computer sequence: $_computerSequence');
    setState(() {
      _isPlayingSequence = true;
      if (_statusMessage.contains('Next melody')) {
        _statusMessage = 'Listen to this melody...';
      }
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      for (final note in _computerSequence) {
        if (!mounted) return;
        setState(() {
          _highlightedNote = note;
        });
        
        // Use the same audio playback method as player input for consistency
        try {
          // First try MIDI service for higher quality sound
          await _midiService.playMidiNote(note);
        } catch (e) {
          developer.log('Error with MIDI playback: $e');
          // Fall back to simple audio player (same as in onNotePressed)
          await _simpleAudio.playPianoNote(note);
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        setState(() {
          _highlightedNote = null;
        });
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      developer.log('Error playing sequence: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPlayingSequence = false;
          _isPlayerTurn = true;
          _statusMessage = 'Your turn - play it back!';
        });
      }
    }
  }

  void _showGameOver([double? finalScore]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Game Over'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Score: $_score',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (finalScore != null)
                Text(
                  'Final Match: ${(finalScore * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getColorForScore(finalScore),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Can you beat your high score?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              // Add detailed metrics if available
              if (_lastComparisonDetails != null && !_isPlayingSequence)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _buildMetricsDisplay(dialogContext), 
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _startNewGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void _startNewGame() {
    setState(() {
      _playerSequence = [];
      _score = 0;
      _isPlayerTurn = false;
      _isPlayingSequence = false;
      _highlightedNote = null;
      _lastMatchScore = null;
      _lastDifficultyInfo = null;
      _lastComparisonDetails = null;
      _processingTimeMs = null;
      _statusMessage = 'Starting new game...';
    });
    _setNextMelody();
  }

  // Build a metrics display widget for comparison details
  Widget _buildMetricsDisplay(BuildContext dialogContext) {
    if (_lastComparisonDetails == null) return const SizedBox.shrink();

    final scoreData = _lastComparisonDetails!;
    final bool serverComparison = scoreData.containsKey('note_details') || scoreData.containsKey('processing_time_ms');

    // Safely extract new metrics
    final double? pitchAccuracy = scoreData['pitch_accuracy'] as double?;
    final double? timingAccuracy = scoreData['timing_accuracy'] as double?;
    final double? matchingRuntimeNocom = scoreData['processing_time_ms'] as double?;
    final List<dynamic>? noteDetailsList = scoreData['note_details'] as List<dynamic>?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                serverComparison ? 'Server Analysis' : 'Offline Analysis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_processingTimeMs != null)
                Text(
                  'Response Time: ${_processingTimeMs}ms', 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
            ],
          ),
          const Divider(),
          
          if (_lastMatchScore != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Overall Score: ${(_lastMatchScore! * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getColorForScore(_lastMatchScore!),
                ),
              ),
            ),
          
          // Display accuracies if available
          if (pitchAccuracy != null)
            _buildMetricRow('Pitch Accuracy', pitchAccuracy * 100),
          
          if (timingAccuracy != null)
            _buildMetricRow('Timing Accuracy', timingAccuracy * 100),
            
          if (matchingRuntimeNocom != null)
             _buildMetricRow('Server Match Time (no com)', matchingRuntimeNocom, isMilliseconds: false),
          
          if (scoreData.containsKey('onset_accuracy'))
            _buildMetricRow('Onset Accuracy', 
              (scoreData['onset_accuracy'] as double) * 100),
              
          if (scoreData.containsKey('duration_accuracy'))
            _buildMetricRow('Duration Accuracy', 
              (scoreData['duration_accuracy'] as double) * 100),
          
          // Divider before algorithm scores
          const Divider(),
          Text(
            serverComparison ? 'Server Algorithm Scores:' : 'Offline Algorithm Scores:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          
          // Algorithm scores as smaller items
          Wrap(
            spacing: 8,
            children: [
              for (final entry in (scoreData['individual_scores'] as Map<String, dynamic>).entries)
                _buildAlgorithmChip(entry.key, (entry.value as double) * 100),
            ],
          ),
          
          if (noteDetailsList != null && noteDetailsList.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Note Details:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: noteDetailsList.length,
              itemBuilder: (context, index) {
                final note = noteDetailsList[index] as Map<String, dynamic>;
                final targetNoteName = note['target_note_name'] ?? 'N/A';
                final playedNoteName = note['played_note_name'] ?? 'N/A';
                final isCorrectPitch = note['is_correct_pitch'] ?? false;
                final onsetErr = note['onset_error'] ?? 'N/A';
                final durationErr = note['duration_error'] ?? 'N/A';

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note ${index + 1}: Target: $targetNoteName, Played: $playedNoteName',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text('Correct Pitch: ${isCorrectPitch ? "Yes" : "No"}', style: TextStyle(color: isCorrectPitch ? Colors.green : Colors.red)),
                        Text('Onset Error: $onsetErr ms'),
                        Text('Duration Error: $durationErr ms'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          
          // Add Close button
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close Report'),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper to build individual metric rows
  Widget _buildMetricRow(String label, double value, {bool isMilliseconds = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Text(
                isMilliseconds ? '${value.toStringAsFixed(1)}ms' : value.toStringAsFixed(isMilliseconds ? 1 : 2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMilliseconds ? Colors.black : _getColorForScore(value / (isMilliseconds ? 1 : 100)),
                ),
              ),
              if (!isMilliseconds) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: LinearProgressIndicator(
                    value: value / 100,
                    backgroundColor: Colors.grey.shade300,
                    color: _getColorForScore(value / 100),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  
  // Helper to build algorithm score chips
  Widget _buildAlgorithmChip(String algorithm, double percentValue) {
    // Format algorithm name to be more readable
    final readableName = algorithm
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
    
    // Add brief description for each algorithm
    String description = '';
    switch (algorithm) {
      case 'dtw':
        description = '(Timing)';
        break;
      case 'levenshtein':
        description = '(Notes)';
        break;
      case 'lcs':
        description = '(Patterns)';
        break;
      case 'cosine':
        description = '(Overall)';
        break;
      case 'exact_match':
        description = '(Exact)';
        break;
      default:
        description = '';
    }
        
    return Chip(
      label: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$readableName $description: ',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
            TextSpan(
              text: '${percentValue.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getColorForScore(percentValue / 100),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey.shade200,
    );
  }
  
  // Get color based on score
  Color _getColorForScore(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play vs Computer'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Score: $_score',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Row(
                    children: [
                      Icon(
                        _serverAvailable ? Icons.cloud_done : Icons.cloud_off,
                        color: _serverAvailable 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).colorScheme.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPlayingSequence 
                            ? 'Listen...' 
                            : _isPlayerTurn 
                                ? 'Your Turn' 
                                : 'Get Ready...',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _isPlayingSequence
                              ? Theme.of(context).colorScheme.primary
                              : _isPlayerTurn
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
            if (_lastMatchScore != null && !_isPlayingSequence)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _lastMatchScore,
                      backgroundColor: Colors.grey.shade300,
                      color: _lastMatchScore! > 0.7 
                          ? Colors.green 
                          : _lastMatchScore! > 0.4 
                              ? Colors.orange 
                              : Colors.red,
                      minHeight: 8,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Final Score: ${(_lastMatchScore! * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _lastMatchScore! > 0.7 
                              ? Colors.green 
                              : _lastMatchScore! > 0.4 
                                  ? Colors.orange 
                                  : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Add detailed metrics display
            if (_lastComparisonDetails != null && !_isPlayingSequence)
              _buildMetricsDisplay(context),
            
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PianoKeyboard(
                onNotePressed: _onNotePressed,
                onNoteReleased: _onNoteReleased,
                startingOctave: 3,
                numberOfOctaves: 3,
                showNoteLabels: true,
                highlightedNote: _highlightedNote,
              ),
            ),
            const SizedBox(height: 20),
            if (_isPlayerTurn && !_isPlayingSequence)
              Text(
                'Notes to match: ${_playerSequence.length}/${_computerSequence.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
} 