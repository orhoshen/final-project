import 'package:flutter/material.dart';
import '../widgets/piano_keyboard.dart';
import '../services/midi_service.dart';
import '../services/simple_audio_player.dart';
import 'dart:developer' as developer;

class PlayerModeScreen extends StatefulWidget {
  const PlayerModeScreen({super.key});

  @override
  State<PlayerModeScreen> createState() => _PlayerModeScreenState();
}

class _PlayerModeScreenState extends State<PlayerModeScreen> {
  final MidiService _midiService = MidiService();
  final SimpleAudioPlayer _simpleAudio = SimpleAudioPlayer();
  List<int> _player1Sequence = [];
  List<int> _player2Sequence = [];
  bool _isPlayer1Turn = true;
  bool _isRecording = false;
  int _roundNumber = 1;
  int _player1Score = 0;
  int _player2Score = 0;
  int? _highlightedNote;

  @override
  void initState() {
    super.initState();
    _initMidi();
  }
  
  Future<void> _initMidi() async {
    try {
      await _midiService.initialize();
      // Play a test sound to warm up the audio system
      await _midiService.testAudio();
    } catch (e) {
      developer.log('Error initializing MIDI: $e');
    }
  }

  void _onNotePressed(int midiNote) {
    if (!_isRecording) return;

    developer.log('Note pressed: $midiNote by ${_isPlayer1Turn ? "Player 1" : "Player 2"}');
    
    // Play sound using both methods for reliability
    _midiService.playMidiNote(midiNote).catchError((error) {
      developer.log('MidiService error, using fallback: $error');
      _simpleAudio.playPianoNote(midiNote);
    });
    
    setState(() {
      if (_isPlayer1Turn) {
        _player1Sequence.add(midiNote);
      } else {
        _player2Sequence.add(midiNote);
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
    developer.log('Starting recording for ${_isPlayer1Turn ? "Player 1" : "Player 2"}');
    setState(() {
      _isRecording = true;
      if (_isPlayer1Turn) {
        _player1Sequence = [];
      } else {
        _player2Sequence = [];
      }
    });
  }

  void _endRecording() {
    developer.log('Ending recording for ${_isPlayer1Turn ? "Player 1" : "Player 2"}');
    setState(() {
      _isRecording = false;
    });

    if (_isPlayer1Turn) {
      // Player 1 just finished recording
      setState(() {
        _isPlayer1Turn = false;
      });
    } else {
      // Player 2 just finished recording, compare sequences
      _compareSequences();
    }
  }

  void _compareSequences() {
    developer.log('Comparing sequences: P1: $_player1Sequence, P2: $_player2Sequence');
    bool isMatch = true;
    if (_player1Sequence.length != _player2Sequence.length) {
      isMatch = false;
    } else {
      for (int i = 0; i < _player1Sequence.length; i++) {
        if (_player1Sequence[i] != _player2Sequence[i]) {
          isMatch = false;
          break;
        }
      }
    }

    setState(() {
      if (isMatch) {
        _player2Score++;
      } else {
        _player1Score++;
      }
      _roundNumber++;
      _isPlayer1Turn = true;
      _player1Sequence = [];
      _player2Sequence = [];
    });

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
            Text(
              'Player 1 Score: $_player1Score',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: !isMatch 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Player 2 Score: $_player2Score',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isMatch 
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
              if (_roundNumber > 5) {
                _showGameOver();
              }
            },
            child: Text(_roundNumber > 5 ? 'End Game' : 'Next Round'),
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
              'Player 1 Score: $_player1Score',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _player1Score > _player2Score 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Player 2 Score: $_player2Score',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _player2Score > _player1Score 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              _player1Score > _player2Score
                  ? 'Player 1 Wins!'
                  : _player2Score > _player1Score
                      ? 'Player 2 Wins!'
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
      _isPlayer1Turn = true;
      _player1Sequence = [];
      _player2Sequence = [];
      _isRecording = false;
      _highlightedNote = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play vs Another Player'),
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
                      'Player 1: $_player1Score',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: _isPlayer1Turn 
                                ? Theme.of(context).colorScheme.primary 
                                : null,
                          ),
                    ),
                    Text(
                      'Player 2: $_player2Score',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: !_isPlayer1Turn 
                                ? Theme.of(context).colorScheme.primary 
                                : null,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _isPlayer1Turn ? 'Player 1\'s Turn' : 'Player 2\'s Turn',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
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
                    child: const Text('Start Recording'),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Recording: ${_isPlayer1Turn ? _player1Sequence.length : _player2Sequence.length} notes',
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
              startingOctave: 4,
              numberOfOctaves: 2,
              showNoteLabels: true,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
} 