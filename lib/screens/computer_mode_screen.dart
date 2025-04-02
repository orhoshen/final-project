import 'package:flutter/material.dart';
import '../widgets/piano_keyboard.dart';
import '../services/midi_service.dart';
import '../services/simple_audio_player.dart';
import 'dart:developer' as developer;

class ComputerModeScreen extends StatefulWidget {
  const ComputerModeScreen({super.key});

  @override
  State<ComputerModeScreen> createState() => _ComputerModeScreenState();
}

class _ComputerModeScreenState extends State<ComputerModeScreen> {
  final MidiService _midiService = MidiService();
  final SimpleAudioPlayer _simpleAudio = SimpleAudioPlayer();
  List<int> _computerSequence = [];
  List<int> _playerSequence = [];
  bool _isPlayerTurn = false;
  int _score = 0;
  bool _isPlayingSequence = false;
  int? _highlightedNote;

  @override
  void initState() {
    super.initState();
    _initMidi();
    _startNewGame();
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
    if (!_isPlayerTurn || _isPlayingSequence) return;

    setState(() {
      _playerSequence.add(midiNote);
      _highlightedNote = midiNote;
    });
    
    // Play sound using both methods for reliability
    _midiService.playMidiNote(midiNote).catchError((error) {
      developer.log('MidiService error, using fallback: $error');
      _simpleAudio.playPianoNote(midiNote);
    });

    // Check if the player's sequence matches the computer's sequence
    if (_playerSequence.length == _computerSequence.length) {
      bool isCorrect = true;
      for (int i = 0; i < _playerSequence.length; i++) {
        if (_playerSequence[i] != _computerSequence[i]) {
          isCorrect = false;
          break;
        }
      }

      if (isCorrect) {
        setState(() {
          _score++;
          _isPlayerTurn = false;
          _playerSequence = [];
        });
        _addNoteToSequence();
      } else {
        _showGameOver();
      }
    }
  }

  void _onNoteReleased(int midiNote) {
    if (_highlightedNote == midiNote) {
      setState(() {
        _highlightedNote = null;
      });
    }
  }

  void _addNoteToSequence() {
    // Add a random note to the computer's sequence
    final random = _computerSequence.isEmpty 
        ? 60 // Middle C
        : _computerSequence.last + [-2, -1, 1, 2][DateTime.now().millisecond % 4];
    
    // Ensure the note is in the valid range (60-72)
    final validNote = random.clamp(60, 72);
    
    setState(() {
      _computerSequence.add(validNote);
    });
    _playComputerSequence();
  }

  Future<void> _playComputerSequence() async {
    developer.log('Playing computer sequence: $_computerSequence');
    setState(() {
      _isPlayingSequence = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      for (final note in _computerSequence) {
        if (!mounted) return;
        setState(() {
          _highlightedNote = note;
        });
        
        // Play sound using both methods for reliability
        try {
          await _midiService.playMidiNote(note);
        } catch (e) {
          developer.log('Error with MIDI playback: $e');
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
        });
      }
    }
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
              'Your Score: $_score',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Can you beat your high score?',
              style: Theme.of(context).textTheme.bodyLarge,
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
    setState(() {
      _computerSequence = [];
      _playerSequence = [];
      _score = 0;
      _isPlayerTurn = false;
      _isPlayingSequence = false;
      _highlightedNote = null;
    });
    _addNoteToSequence();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play vs Computer'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
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
                Text(
                  _isPlayingSequence 
                      ? 'Listen...' 
                      : _isPlayerTurn 
                          ? 'Your Turn' 
                          : 'Get Ready...',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _isPlayingSequence
                        ? Theme.of(context).colorScheme.primary
                        : _isPlayerTurn
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.tertiary,
                  ),
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
          if (_isPlayerTurn && !_isPlayingSequence)
            Text(
              'Notes to match: ${_playerSequence.length}/${_computerSequence.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
        ],
      ),
    );
  }
} 