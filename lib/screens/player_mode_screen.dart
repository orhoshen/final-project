import 'package:flutter/material.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/analysis_report_widget.dart';
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
  Map<String, dynamic>? _lastComparisonDetails;
  int? _comparisonProcessingTimeMs;
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
        content: SizedBox(
          width: 300,
          child: Column(
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
    
    // Start timing for client-server-client round trip or local processing
    final startTime = DateTime.now().millisecondsSinceEpoch;

    bool isMatch = false;
    double matchScore = 0.0;
    Map<String, dynamic>? currentComparisonDetails;
    
    if (_serverAvailable) {
      try {
        final serverResult = await _serverMatcher.compareMelodies(
          _referenceSequence, 
          _attemptSequence
        );
        
        if (serverResult['success'] == true && serverResult['result'] != null) {
          currentComparisonDetails = Map<String, dynamic>.from(serverResult['result']);
          matchScore = currentComparisonDetails['final_score'] as double? ?? 0.0;
          developer.log('Server comparison score: $matchScore');
          isMatch = matchScore > 0.7; // Define match threshold
        } else {
          developer.log('Server comparison returned success:false or null result. Falling back.');
          isMatch = _performSimpleComparison();
          matchScore = isMatch ? 1.0 : 0.3; // Arbitrary score for simple comparison
          currentComparisonDetails = {
            'final_score': matchScore,
            'pitch_accuracy': matchScore,
            'individual_scores': {'exact_match': matchScore}
          }; 
        }
      } catch (e) {
        developer.log('Error with server comparison: $e. Falling back.');
        isMatch = _performSimpleComparison();
        matchScore = isMatch ? 1.0 : 0.3;
        currentComparisonDetails = {
          'final_score': matchScore,
          'pitch_accuracy': matchScore,
          'individual_scores': {'exact_match': matchScore}
        };
      }
    } else {
      isMatch = _performSimpleComparison();
      matchScore = isMatch ? 1.0 : 0.3;
      currentComparisonDetails = {
        'final_score': matchScore,
        'pitch_accuracy': matchScore,
        'individual_scores': {'exact_match': matchScore}
      };
    }

    final endTime = DateTime.now().millisecondsSinceEpoch;
    final roundTripTime = endTime - startTime;

    setState(() {
      _lastComparisonDetails = currentComparisonDetails; // Store details for the dialog
      _comparisonProcessingTimeMs = roundTripTime; // Store client-server-client time
      if (isMatch) {
        if (_isPlayer1Creator) {
          _player2Score++;
        } else {
          _player1Score++;
        }
      }
    });

    _showRoundResult(isMatch, matcherName, creatorName);
  }
  
  bool _performSimpleComparison() {
    if (_referenceSequence.isEmpty || _attemptSequence.isEmpty) return false;
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

  void _showRoundResult(bool isMatch, String matcherName, String creatorName) {
    String title = isMatch ? 'Melody Matched!' : 'Try Again!';
    String message = isMatch
        ? '$matcherName successfully matched $creatorName\'s melody!'
        : '$matcherName didn\'t quite match. Better luck next time!';

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                // Display the detailed analytics using the shared widget
                if (_lastComparisonDetails != null)
                  AnalysisReportWidget(
                    scoreData: _lastComparisonDetails!,
                    clientRoundTripTime: _comparisonProcessingTimeMs,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _startNextRoundOrEndGame(); 
              },
              child: const Text('Next Round'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _resetGame(); // Or navigate to a game summary screen
              },
              child: const Text('End Game'),
            ),
          ],
        );
      },
    );
  }



  void _startNextRoundOrEndGame() {
    // Check if this was the last round (e.g., 5 rounds)
    if (_roundNumber >= 5) { 
      // Show final game over dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Game Over!'),
          content: Text(
            'Final Scores:\n$_player1Name: $_player1Score\n$_player2Name: $_player2Score',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetGame(); // Reset for a new game or go to main menu
              },
              child: const Text('Play Again'),
            ),
          ],
        ),
      );
    } else {
      // Prepare for the next round
      setState(() {
        _roundNumber++;
        _isPlayer1Creator = !_isPlayer1Creator; // Switch roles
        _isCreatorTurn = true;
        _referenceSequence = [];
        _attemptSequence = [];
        _lastComparisonDetails = null; // Clear previous comparison details
        _comparisonProcessingTimeMs = null; // Clear previous timing
        _isRecording = false; 
      });
      // Optionally, show instructions for the new round/creator
      String nextCreator = _isPlayer1Creator ? _player1Name : _player2Name;
      String nextMatcher = _isPlayer1Creator ? _player2Name : _player1Name;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Round $_roundNumber'),
          content: Text(
            'Now $nextCreator will create a melody, and $nextMatcher will match it.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Begin'),
            ),
          ],
        ),
      );
    }
  }
  
  void _resetGame() {
    setState(() {
      _player1Name = _player1NameController.text.isNotEmpty ? _player1NameController.text : 'Player 1';
      _player2Name = _player2NameController.text.isNotEmpty ? _player2NameController.text : 'Player 2';
      _roundNumber = 1;
      _player1Score = 0;
      _player2Score = 0;
      _isPlayer1Creator = true;
      _isCreatorTurn = true;
      _referenceSequence = [];
      _attemptSequence = [];
      _isRecording = false;
      _highlightedNote = null;
      _lastComparisonDetails = null;
      _comparisonProcessingTimeMs = null;
      _gameStarted = false; // This will trigger player registration again if needed
    });
    // Show player registration to start a new game flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (!_gameStarted) {
         _showPlayerRegistration();
       }
    });
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
} 