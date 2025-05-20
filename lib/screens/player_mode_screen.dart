import 'package:flutter/material.dart';
import '../widgets/piano_keyboard.dart';
import '../services/midi_service.dart';
import '../services/simple_audio_player.dart';
import '../services/server_melody_matcher.dart';
import 'dart:developer' as developer;

class PlayerModeScreen extends StatefulWidget {
  const PlayerModeScreen({super.key});

  @override
  State<PlayerModeScreen> createState() => _PlayerModeScreenState();
}

class _PlayerModeScreenState extends State<PlayerModeScreen> {
  final MidiService _midiService = MidiService();
  final SimpleAudioPlayer _simpleAudio = SimpleAudioPlayer();
  final ServerMelodyMatcher _serverMatcher = ServerMelodyMatcher.instance;
  
  // Controllers for player name inputs
  final TextEditingController _player1NameController = TextEditingController(text: 'Player 1');
  final TextEditingController _player2NameController = TextEditingController(text: 'Player 2');
  
  // Game state
  List<int> _referenceSequence = [];  // Melody to match
  List<int> _attemptSequence = [];    // Attempt to match the melody
  String _player1Name = 'Player 1';
  String _player2Name = 'Player 2';
  bool _isCreatorTurn = true;  // When true, player is creating a melody; when false, player is matching
  bool _isPlayer1Creator = true;  // Tracks which player is the creator (vs matcher)
  bool _isRecording = false;
  int _roundNumber = 1;
  int _player1Score = 0;
  int _player2Score = 0;
  int? _highlightedNote;
  bool _serverAvailable = true;
  Map<String, dynamic>? _lastComparisonResult;
  bool _gameStarted = false;

  @override
  void initState() {
    super.initState();
    _initServices();
    // Show player registration dialog when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_gameStarted) {
        _showPlayerRegistration();
      }
    });
  }
  
  @override
  void dispose() {
    _player1NameController.dispose();
    _player2NameController.dispose();
    super.dispose();
  }
  
  Future<void> _initServices() async {
    try {
      await _midiService.initialize();
      // Play a test sound to warm up the audio system
      await _midiService.testAudio();
      
      // Test server connection
      _serverAvailable = await _serverMatcher.testConnection();
      developer.log('Server connection test: ${_serverAvailable ? 'SUCCESS' : 'FAILED'}');
    } catch (e) {
      developer.log('Error initializing services: $e');
      _serverAvailable = false;
    }
  }

  // Show dialog for player name registration
  void _showPlayerRegistration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Player Names'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _player1NameController,
              decoration: const InputDecoration(
                labelText: 'Player 1 Name',
                hintText: 'Enter name for Player 1',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _player2NameController,
              decoration: const InputDecoration(
                labelText: 'Player 2 Name',
                hintText: 'Enter name for Player 2',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _player1Name = _player1NameController.text.isNotEmpty 
                    ? _player1NameController.text 
                    : 'Player 1';
                _player2Name = _player2NameController.text.isNotEmpty 
                    ? _player2NameController.text 
                    : 'Player 2';
                _gameStarted = true;
              });
              Navigator.of(context).pop();
              _showGameInstructions();
            },
            child: const Text('Start Game'),
          ),
        ],
      ),
    );
  }

  void _showGameInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('How to Play'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Round $_roundNumber',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'First, $_player1Name will create a melody by playing notes on the piano.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Then, $_player2Name will try to match the melody.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'After each round, players will switch roles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Begin'),
          ),
        ],
      ),
    );
  }

  void _onNotePressed(int midiNote) {
    if (!_isRecording) return;

    String currentPlayer = _isCreatorTurn
        ? (_isPlayer1Creator ? _player1Name : _player2Name)
        : (_isPlayer1Creator ? _player2Name : _player1Name);
    
    developer.log('Note pressed: $midiNote by $currentPlayer');
    
    // Play sound using both methods for reliability
    _midiService.playMidiNote(midiNote).catchError((error) {
      developer.log('MidiService error, using fallback: $error');
      _simpleAudio.playPianoNote(midiNote);
    });
    
    setState(() {
      if (_isCreatorTurn) {
        _referenceSequence.add(midiNote);
      } else {
        _attemptSequence.add(midiNote);
      }
      _highlightedNote = midiNote;
    });
  }

  void _onNoteReleased(int midiNote) {
    if (_highlightedNote == midiNote) {
      setState(() {
        _highlightedNote = null;
      });
    }
  }

  void _startRecording() {
    String currentPlayer = _isCreatorTurn
        ? (_isPlayer1Creator ? _player1Name : _player2Name)
        : (_isPlayer1Creator ? _player2Name : _player1Name);
    
    developer.log('Starting recording for $currentPlayer');
    setState(() {
      _isRecording = true;
      if (_isCreatorTurn) {
        _referenceSequence = [];
      } else {
        _attemptSequence = [];
      }
    });
  }

  void _endRecording() {
    String currentPlayer = _isCreatorTurn
        ? (_isPlayer1Creator ? _player1Name : _player2Name)
        : (_isPlayer1Creator ? _player2Name : _player1Name);
    
    developer.log('Ending recording for $currentPlayer');
    setState(() {
      _isRecording = false;
    });

    if (_isCreatorTurn) {
      // Creator just finished recording the reference melody
      // Show a dialog to indicate it's matcher's turn
      String creatorName = _isPlayer1Creator ? _player1Name : _player2Name;
      String matcherName = _isPlayer1Creator ? _player2Name : _player1Name;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Melody Recorded'),
          content: Text(
            '$creatorName has created a melody with ${_referenceSequence.length} notes.\n\n'
            'Now $matcherName will try to match it!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Switch to matcher's turn
                setState(() {
                  _isCreatorTurn = false;
                });
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } else {
      // Matcher just finished trying to match - compare sequences
      _compareSequences();
    }
  }

  Future<void> _compareSequences() async {
    String creatorName = _isPlayer1Creator ? _player1Name : _player2Name;
    String matcherName = _isPlayer1Creator ? _player2Name : _player1Name;
    
    developer.log('Comparing sequences: Reference: $_referenceSequence, Attempt: $_attemptSequence');
    
    bool isMatch = false;
    double matchScore = 0.0;
    
    if (_serverAvailable) {
      try {
        // Use server for advanced melody comparison
        final result = await _serverMatcher.compareMelodies(
          _referenceSequence, 
          _attemptSequence
        );
        
        if (result['success'] == true) {
          _lastComparisonResult = result;
          matchScore = result['result']['final_score'] as double;
          developer.log('Server comparison score: $matchScore');
          
          // Consider it a match if score is above 0.7 (70% match)
          isMatch = matchScore > 0.7;
        } else {
          // Fall back to simple comparison if server returns error
          isMatch = _performSimpleComparison();
        }
      } catch (e) {
        developer.log('Error with server comparison: $e');
        isMatch = _performSimpleComparison();
      }
    } else {
      // Use simple comparison if server is not available
      isMatch = _performSimpleComparison();
    }

    // Award points to the matcher player if they matched successfully
    if (isMatch) {
      setState(() {
        if (_isPlayer1Creator) {
          // Player 2 is matching
          _player2Score++;
        } else {
          // Player 1 is matching
          _player1Score++;
        }
      });
    }

    _showRoundResult(isMatch, matchScore);
  }
  
  bool _performSimpleComparison() {
    if (_referenceSequence.length != _attemptSequence.length) {
      return false;
    }
    
    for (int i = 0; i < _referenceSequence.length; i++) {
      if (_referenceSequence[i] != _attemptSequence[i]) {
        return false;
      }
    }
    
    return true;
  }

  // Helper methods for building metrics display
  // (unchanged - keeping existing implementation)

  // Helper to build algorithm score chips
  // (unchanged - keeping existing implementation)

  // Get color based on score
  // (unchanged - keeping existing implementation)

  void _showRoundResult(bool isMatch, double matchScore) {
    String creatorName = _isPlayer1Creator ? _player1Name : _player2Name;
    String matcherName = _isPlayer1Creator ? _player2Name : _player1Name;
    
    // If we have detailed metrics to show
    if (_lastComparisonResult != null && 
        _lastComparisonResult!.containsKey('result') && 
        _lastComparisonResult!['result'] is Map<String, dynamic>) {
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            isMatch ? 'Match!' : 'No Match!',
            style: TextStyle(
              color: isMatch 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    'Match Score: ${(matchScore * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getColorForScore(matchScore),
                    ),
                  ),
                ),
                Text(
                  '$creatorName created the melody\n$matcherName tried to match it',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                _buildMetricsDisplay(),
                const SizedBox(height: 12),
                Text(
                  '$_player1Name\'s Score: $_player1Score',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: (!_isPlayer1Creator && isMatch)
                            ? Theme.of(context).colorScheme.primary 
                            : null,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_player2Name\'s Score: $_player2Score',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: (_isPlayer1Creator && isMatch)
                            ? Theme.of(context).colorScheme.primary 
                            : null,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _prepareNextRound();
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } else {
      // Show the regular result dialog without detailed metrics
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            isMatch ? 'Match!' : 'No Match!',
            style: TextStyle(
              color: isMatch 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Match Score: ${(matchScore * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getColorForScore(matchScore),
                  ),
                ),
              ),
              Text(
                '$creatorName created the melody\n$matcherName tried to match it',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '$_player1Name\'s Score: $_player1Score',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: (!_isPlayer1Creator && isMatch)
                          ? Theme.of(context).colorScheme.primary 
                          : null,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_player2Name\'s Score: $_player2Score',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: (_isPlayer1Creator && isMatch)
                          ? Theme.of(context).colorScheme.primary 
                          : null,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _prepareNextRound();
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  }

  void _prepareNextRound() {
    // Check if this was the last round
    if (_roundNumber >= 5) {
      _showGameOver();
      return;
    }
    
    // Prepare for next round
    setState(() {
      _roundNumber++;
      // Switch creator role - alternate who creates the melody
      _isPlayer1Creator = !_isPlayer1Creator;
      _isCreatorTurn = true;
      _referenceSequence = [];
      _attemptSequence = [];
      _lastComparisonResult = null;
    });
    
    // Show instructions for the new round
    _showNextRoundInstructions();
  }
  
  void _showNextRoundInstructions() {
    String creatorName = _isPlayer1Creator ? _player1Name : _player2Name;
    String matcherName = _isPlayer1Creator ? _player2Name : _player1Name;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Round $_roundNumber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Next, $creatorName will create a melody.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Then, $matcherName will try to match it.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Begin'),
          ),
        ],
      ),
    );
  }

  void _showGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_player1Name\'s Score: $_player1Score',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _player1Score > _player2Score 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_player2Name\'s Score: $_player2Score',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _player2Score > _player1Score 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              _player1Score > _player2Score
                  ? '$_player1Name Wins!'
                  : _player2Score > _player1Score
                      ? '$_player2Name Wins!'
                      : 'It\'s a Tie!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void _startNewGame() {
    developer.log('Starting new game');
    setState(() {
      _player1Score = 0;
      _player2Score = 0;
      _roundNumber = 1;
      _isCreatorTurn = true;
      _isPlayer1Creator = true;
      _referenceSequence = [];
      _attemptSequence = [];
      _isRecording = false;
      _highlightedNote = null;
      _lastComparisonResult = null;
    });
    _showPlayerRegistration();
  }

  @override
  Widget build(BuildContext context) {
    String currentPlayerName = _isCreatorTurn
        ? (_isPlayer1Creator ? _player1Name : _player2Name)
        : (_isPlayer1Creator ? _player2Name : _player1Name);
    
    String currentRole = _isCreatorTurn ? "Creating Melody" : "Matching Melody";
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Play vs Another Player'),
            if (!_serverAvailable)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.cloud_off,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Round $_roundNumber/5',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_player1Name: $_player1Score',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: (_isPlayer1Creator && _isCreatorTurn) || (!_isPlayer1Creator && !_isCreatorTurn)
                                ? Theme.of(context).colorScheme.primary 
                                : null,
                          ),
                    ),
                    Text(
                      '$_player2Name: $_player2Score',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: (!_isPlayer1Creator && _isCreatorTurn) || (_isPlayer1Creator && !_isCreatorTurn)
                                ? Theme.of(context).colorScheme.primary 
                                : null,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$currentPlayerName\'s Turn ($currentRole)',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                if (_isCreatorTurn)
                  Text(
                    _isPlayer1Creator 
                        ? '$_player2Name will try to match it afterwards'
                        : '$_player1Name will try to match it afterwards',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                const SizedBox(height: 8),
                if (!_isRecording)
                  ElevatedButton(
                    onPressed: _startRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      '$currentPlayerName: Start Recording ${_isCreatorTurn ? "Melody" : "Match"}'
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Recording $currentPlayerName: ${_isCreatorTurn ? _referenceSequence.length : _attemptSequence.length} notes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _endRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Stop Recording'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Spacer(),
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
        ],
      ),
    );
  }

  // Helper to build individual metric rows
  Widget _buildMetricRow(String label, double percentValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Text(
                '${percentValue.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getColorForScore(percentValue / 100),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: LinearProgressIndicator(
                  value: percentValue / 100,
                  backgroundColor: Colors.grey.shade300,
                  color: _getColorForScore(percentValue / 100),
                ),
              ),
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

  // Build metrics display for comparison results
  Widget _buildMetricsDisplay() {
    if (_lastComparisonResult == null || 
        !_lastComparisonResult!.containsKey('result')) {
      return const SizedBox.shrink();
    }
    
    final scoreData = _lastComparisonResult!['result'] as Map<String, dynamic>;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                'Detailed Analysis', 
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (scoreData.containsKey('processing_time_ms'))
                Text(
                  'Process: ${scoreData['processing_time_ms']}ms',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
            ],
          ),
          const Divider(),
          
          // Display accuracies if available
          if (scoreData.containsKey('pitch_accuracy'))
            _buildMetricRow('Pitch Accuracy', 
              (scoreData['pitch_accuracy'] as double) * 100),
          
          if (scoreData.containsKey('timing_accuracy'))
            _buildMetricRow('Timing Accuracy', 
              (scoreData['timing_accuracy'] as double) * 100),
              
          if (scoreData.containsKey('onset_accuracy'))
            _buildMetricRow('Onset Accuracy', 
              (scoreData['onset_accuracy'] as double) * 100),
              
          if (scoreData.containsKey('duration_accuracy'))
            _buildMetricRow('Duration Accuracy', 
              (scoreData['duration_accuracy'] as double) * 100),
          
          // Divider before algorithm scores
          if (scoreData.containsKey('individual_scores')) ...[
            const Divider(),
            Text(
              'Algorithm Scores:',
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
          ],
          
          // Add Close button
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
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
} 