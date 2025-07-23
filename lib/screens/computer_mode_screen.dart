import 'dart:developer' as developer;

import 'package:final_project/providers/server_status_provider.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firebase_melody_service.dart';
import '../services/midi_service.dart';
import '../services/server_manager.dart';
import '../services/simple_audio_player.dart';
import '../widgets/analysis_report_widget.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/server_status_widget.dart';

class ComputerModeScreen extends StatefulWidget {
  const ComputerModeScreen({super.key});

  @override
  State<ComputerModeScreen> createState() => _ComputerModeScreenState();
}

class _ComputerModeScreenState extends State<ComputerModeScreen> {
  final FirebaseMelodyService _melodyService = FirebaseMelodyService.instance;
  final ServerManager _matcherService = ServerManager.instance;
  final MidiService _midiService = MidiService();
  final SimpleAudioPlayer _simpleAudio = SimpleAudioPlayer();
  List<int> _computerSequence = [];
  List<int> _playerSequence = [];
  bool _isPlayerTurn = false;
  int _score = 0;
  bool _isPlayingSequence = false;
  int? _highlightedNote;
  String _statusMessage = 'Loading...';
  double? _lastMatchScore;
  Map<String, dynamic>? _lastComparisonDetails;
  int? _processingTimeMs;

  // Repeat button functionality
  int _repeatCount = 0; // Count of times the reference melody has been repeated
  static const int _maxRepeats = 2; // Maximum allowed repeats per round

  // Analysis mode tracking
  bool _showingAnalysis = false; // Track when user is reviewing analysis
  bool _lastRoundWasCorrect = false; // Track if they can continue or game ends

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      setState(() {
        _statusMessage = 'Initializing services...';
      });

      await _midiService.initialize();

      // The server check is now handled by the provider. We just wait for it.
      // Start the game after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _startNewGame();
      }
    } catch (e) {
      developer.log('Error initializing services: $e');
      if (mounted) {
        setState(() {
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

    _midiService.playMidiNote(midiNote).catchError((error) {
      developer.log('MidiService error, using fallback: $error');
      _simpleAudio.playPianoNote(midiNote);
    });

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

    final startTime = DateTime.now().millisecondsSinceEpoch;

    // Use the provider to check server status
    final serverAvailable = context.read<ServerStatusNotifier>().isServerAvailable;

    if (serverAvailable) {
      try {
        final result = await _matcherService.compareMelodies(_computerSequence, _playerSequence);
        final endTime = DateTime.now().millisecondsSinceEpoch;
        final processingTime = endTime - startTime;
        developer.log('Matching completed in ${processingTime}ms: $result');

        if (result['success'] == true) {
          final resultData = result['result'];
          final score = resultData['final_score'] as double;

          setState(() {
            _lastMatchScore = score;
            _lastComparisonDetails = Map<String, dynamic>.from(resultData);
            _processingTimeMs = processingTime;
          });

          final isCorrect = score > 0.7;

          if (isCorrect) {
            setState(() {
              _score++;
              _isPlayerTurn = false;
              _playerSequence = [];
              _showingAnalysis = true; // Enter analysis mode
              _lastRoundWasCorrect = true; // They can continue
              _statusMessage = 'Good job! Score: ${(score * 100).toStringAsFixed(1)}% - Review your results below.';
            });
          } else {
            setState(() {
              _isPlayerTurn = false;
              _showingAnalysis = true; // Enter analysis mode
              _lastRoundWasCorrect = false; // Game should end
              _statusMessage = 'Not quite right: ${(score * 100).toStringAsFixed(1)}% - Review your analysis below.';
            });
          }
        } else {
          developer.log('Server error, using fallback comparison');
          _performSimpleComparison();
        }
      } catch (e) {
        developer.log('Error with server comparison: $e');
        _performSimpleComparison();
      }
    } else {
      _performSimpleComparison();
    }
  }

  void _performSimpleComparison() {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    bool isCorrect = listEquals(_playerSequence, _computerSequence);
    final simpleScore = isCorrect ? 1.0 : 0.0;
    final endTime = DateTime.now().millisecondsSinceEpoch;
    final processingTime = endTime - startTime;
    developer.log('Simple comparison done in ${processingTime}ms: $_playerSequence vs $_computerSequence');

    setState(() {
      _lastMatchScore = simpleScore;
      _processingTimeMs = processingTime;
      _lastComparisonDetails = {
        'final_score': simpleScore,
        'pitch_accuracy': simpleScore,
        'individual_scores': {'exact_match': simpleScore},
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
        _statusMessage = 'Not quite right.';
      });
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _highlightedNote = null;
          });
        }
      });
    }
  }

  Future<void> _repeatMelody() async {
    if (_computerSequence.isEmpty) return;
    setState(() {
      _repeatCount++;
      _isPlayingSequence = true;
      _statusMessage = 'Replaying melody...';
    });
    await _playComputerSequence();
  }

  // Methods for user-controlled progression
  void _continueToNextMelody() {
    setState(() {
      _showingAnalysis = false;
      _lastComparisonDetails = null;
      _lastMatchScore = null;
      _processingTimeMs = null;
    });
    _setNextMelody();
  }

  void _endGameFromAnalysis() {
    setState(() {
      _showingAnalysis = false;
    });
    _showGameOver(_lastMatchScore);
  }

  Future<void> _setNextMelody() async {
    setState(() {
      _statusMessage = 'Loading next melody...';
      _isPlayingSequence = true;
      _lastComparisonDetails = null;
      _processingTimeMs = null;
      _repeatCount = 0;
    });

    try {
      final melody = await _melodyService.getRandomMelody();
      if (!mounted) return;

      if (melody != null) {
        setState(() {
          _computerSequence = melody.notes;
          _statusMessage = 'Listen to this melody.';
          _playerSequence.clear();
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to load melody. Using fallback.';
          _computerSequence = [60, 62, 64, 65, 67, 69, 71, 72]; // C-Major scale
          _playerSequence.clear();
        });
      }
      await _playComputerSequence();
    } catch (e) {
      developer.log('Error setting next melody: $e', error: e);
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: Could not load melody.';
        });
      }
    }
  }

  Future<void> _playComputerSequence() async {
    developer.log('Playing computer sequence: $_computerSequence');
    setState(() {
      _isPlayingSequence = true;
      _statusMessage = 'Listen to this melody...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      for (final note in _computerSequence) {
        if (!mounted) return;
        setState(() {
          _highlightedNote = note;
        });

        try {
          await _midiService.playMidiNote(note);
        } catch (e) {
          developer.log('Error with MIDI playback: $e, using fallback.');
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
              if (_lastComparisonDetails != null && !_isPlayingSequence)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: AnalysisReportWidget(
                    scoreData: _lastComparisonDetails!,
                    clientRoundTripTime: _processingTimeMs,
                  ),
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
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('End Game'),
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
      _lastComparisonDetails = null;
      _processingTimeMs = null;
      _repeatCount = 0;
      _showingAnalysis = false; // Reset analysis mode
      _lastRoundWasCorrect = false; // Reset round result
      _statusMessage = 'Starting new game...';
    });
    _setNextMelody();
  }

  Color _getColorForScore(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the provider for status changes
    final serverStatus = context.watch<ServerStatusNotifier>();
    final serverAvailable = serverStatus.isServerAvailable;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Play vs Computer'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: ServerStatusWidget(),
          ),
        ],
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
                      if (serverStatus.isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          serverAvailable ? Icons.cloud_done : Icons.cloud_off,
                          color: serverAvailable
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
                      color: _getColorForScore(_lastMatchScore!),
                      minHeight: 8,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Final Score: ${(_lastMatchScore! * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getColorForScore(_lastMatchScore!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_lastComparisonDetails != null && !_isPlayingSequence)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: AnalysisReportWidget(
                  scoreData: _lastComparisonDetails!,
                  clientRoundTripTime: _processingTimeMs,
                ),
              ),
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
              Column(
                children: [
                  Text(
                    'Notes to match: ${_playerSequence.length}/${_computerSequence.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _repeatCount < _maxRepeats ? _repeatMelody : null,
                    icon: const Icon(Icons.replay),
                    label: Text(_repeatCount < _maxRepeats
                        ? 'Repeat Melody (${_maxRepeats - _repeatCount} left)'
                        : 'No Repeats Left'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),

            // Add Continue/End Game buttons when showing analysis
            if (_showingAnalysis && _lastComparisonDetails != null) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_lastRoundWasCorrect) ...[
                    ElevatedButton.icon(
                      onPressed: _continueToNextMelody,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next Melody'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () => _startNewGame(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _endGameFromAnalysis,
                      icon: const Icon(Icons.stop),
                      label: const Text('End Game'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
