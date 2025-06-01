import 'dart:developer' as developer;

import 'package:final_project/services/js_stub.dart' if (dart.library.js) 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/midi_service.dart';
import '../services/simple_audio_player.dart';

class PianoKeyboard extends StatefulWidget {
  final Function(int)? onNotePressed;
  final Function(int)? onNoteReleased;
  final int startingOctave;
  final int numberOfOctaves;
  final bool showNoteLabels;
  final int? highlightedNote;

  const PianoKeyboard({
    super.key,
    this.onNotePressed,
    this.onNoteReleased,
    this.startingOctave = 3,
    this.numberOfOctaves = 3,
    this.showNoteLabels = false,
    this.highlightedNote,
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  final MidiService _midiService = MidiService();
  final SimpleAudioPlayer _simpleAudio = SimpleAudioPlayer();
  final Set<int> _pressedKeys = {};
  bool _isInitializing = false;
  String? _errorMessage;
  bool _webAudioReady = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      developer.log('Initializing audio in PianoKeyboard');

      if (kIsWeb) {
        _initWebAudio();
      }

      await _midiService.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      developer.log('Error initializing audio in PianoKeyboard: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Sound may not be available. Using system sounds.';

          // Auto-hide error after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _errorMessage = null;
              });
            }
          });
        });
      }
    }
  }

  void _initWebAudio() {
    try {
      // Initialize WebAudio using JS interop
      js.context.callMethod('eval', [
        '''
        // Create a global audio context
        if (!window.pianoAudioContext) {
          window.pianoAudioContext = new (window.AudioContext || window.webkitAudioContext)();
          console.log("Web Audio API initialized in PianoKeyboard");
          
          // Create a simple note player
          window.playPianoNoteFrequency = function(frequency, duration) {
            try {
              var ctx = window.pianoAudioContext;
              var oscillator = ctx.createOscillator();
              var gain = ctx.createGain();
              
              oscillator.type = 'sine';
              oscillator.frequency.value = frequency;
              
              gain.gain.setValueAtTime(0.5, ctx.currentTime);
              gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + duration);
              
              oscillator.connect(gain);
              gain.connect(ctx.destination);
              
              oscillator.start();
              oscillator.stop(ctx.currentTime + duration);
              console.log("Piano - Playing note at frequency: " + frequency);
              return true;
            } catch (e) {
              console.error("Error playing Web Audio note:", e);
              return false;
            }
          };
        }
      '''
      ]);

      _webAudioReady = true;
      developer.log('Web Audio ready for PianoKeyboard');
    } catch (e) {
      developer.log('Error initializing WebAudio in PianoKeyboard: $e');
      _webAudioReady = false;
    }
  }

  void _playWebAudioNote(int midiNote) {
    try {
      // Calculate frequency (A4 = 440Hz, MIDI note 69)
      final frequency = 440.0 * pow(2, (midiNote - 69) / 12);

      // Call JavaScript method
      final success =
          js.context.callMethod('eval', ['window.playPianoNoteFrequency(${frequency.toStringAsFixed(2)}, 0.5)']);

      if (success == true) {
        developer.log('Web Audio played note $midiNote (${frequency.toStringAsFixed(2)}Hz)');
      } else {
        developer.log('Error playing Web Audio note: unknown error');
        // Fall back to system sound
        _simpleAudio.playSystemSound();
      }
    } catch (e) {
      developer.log('Error playing Web Audio note: $e');
      // Fall back to system sound
      _simpleAudio.playSystemSound();
    }
  }

  void _handleNotePressed(int midiNote) {
    setState(() {
      _pressedKeys.add(midiNote);
    });

    // Try multiple methods for better sound
    if (kIsWeb && _webAudioReady) {
      _playWebAudioNote(midiNote);
    } else {
      // Try MIDI service first
      _midiService.playMidiNote(midiNote).catchError((error) {
        developer.log('MIDI service error playing note $midiNote: $error');
        // Fall back to simple audio player
        _simpleAudio.playPianoNote(midiNote);
      });
    }

    widget.onNotePressed?.call(midiNote);
  }

  void _handleNoteReleased(int midiNote) {
    setState(() {
      _pressedKeys.remove(midiNote);
    });

    widget.onNoteReleased?.call(midiNote);
  }

  // Get just the note name without octave (for simpler labels)
  String _getSimpleNoteLabel(int midiNote) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final noteIndex = midiNote % 12;
    return notes[noteIndex];
  }

  @override
  Widget build(BuildContext context) {
    // Calculate starting and ending notes
    final int startingNote = (widget.startingOctave + 1) * 12;
    final int totalKeys = widget.numberOfOctaves * 12;

    return Column(
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              height: double.infinity,
              child: LayoutBuilder(builder: (context, constraints) {
                final double keyHeight = constraints.maxHeight;
                const double whiteKeyWidth = 40;

                // Get total white keys (7 per octave)
                final int whiteKeysCount = _countWhiteKeys(startingNote, startingNote + totalKeys);
                final double totalWidth = whiteKeysCount * whiteKeyWidth;

                return SizedBox(
                  width: totalWidth,
                  height: keyHeight,
                  child: Stack(
                    children: [
                      // White keys first (base layer)
                      ..._buildWhiteKeys(
                        startingNote: startingNote,
                        totalKeys: totalKeys,
                        keyWidth: whiteKeyWidth,
                        keyHeight: keyHeight,
                      ),

                      // Black keys on top
                      ..._buildBlackKeys(
                        startingNote: startingNote,
                        totalKeys: totalKeys,
                        keyWidth: whiteKeyWidth,
                        keyHeight: keyHeight,
                      ),

                      // Octave labels
                      if (widget.showNoteLabels)
                        ..._buildOctaveLabels(
                          startingNote: startingNote,
                          totalKeys: totalKeys,
                          keyWidth: whiteKeyWidth,
                          keyHeight: keyHeight,
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        // Add octave navigation buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.numberOfOctaves} octaves (${widget.startingOctave}-${widget.startingOctave + widget.numberOfOctaves - 1})',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper to count white keys in range
  int _countWhiteKeys(int startNote, int endNote) {
    int count = 0;
    for (int note = startNote; note < endNote; note++) {
      if (!_isBlackKey(note)) {
        count++;
      }
    }
    return count;
  }

  // Helper to check if a note is a black key
  bool _isBlackKey(int midiNote) {
    final int noteIndex = midiNote % 12;
    return [1, 3, 6, 8, 10].contains(noteIndex);
  }

  // Build white keys
  List<Widget> _buildWhiteKeys({
    required int startingNote,
    required int totalKeys,
    required double keyWidth,
    required double keyHeight,
  }) {
    final List<Widget> whiteKeys = [];
    double xPosition = 0;

    for (int i = 0; i < totalKeys; i++) {
      final int midiNote = startingNote + i;

      if (!_isBlackKey(midiNote)) {
        // This is a white key
        final bool isPressed = _pressedKeys.contains(midiNote);
        final bool isHighlighted = widget.highlightedNote == midiNote;

        whiteKeys.add(
          Positioned(
            left: xPosition,
            top: 0,
            width: keyWidth,
            height: keyHeight,
            child: GestureDetector(
              onTapDown: (_) => _handleNotePressed(midiNote),
              onTapUp: (_) => _handleNoteReleased(midiNote),
              onTapCancel: () => _handleNoteReleased(midiNote),
              child: Container(
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Theme.of(context).colorScheme.primaryContainer
                      : isPressed
                          ? Colors.grey.shade300
                          : Colors.white,
                  border: Border.all(
                    color: Colors.grey.shade400,
                    width: 1,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: widget.showNoteLabels
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _getSimpleNoteLabel(midiNote),
                            style: TextStyle(
                              fontSize: 10,
                              color: isPressed ? Colors.grey.shade700 : Colors.black54,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );

        // Increment position for next white key
        xPosition += keyWidth;
      }
    }

    return whiteKeys;
  }

  // Build black keys
  List<Widget> _buildBlackKeys({
    required int startingNote,
    required int totalKeys,
    required double keyWidth,
    required double keyHeight,
  }) {
    final List<Widget> blackKeys = [];
    double xPosition = 0;

    for (int i = 0; i < totalKeys; i++) {
      final int midiNote = startingNote + i;

      if (!_isBlackKey(midiNote)) {
        // Update position counter for white keys
        if (i > 0) xPosition += keyWidth;
      } else {
        // This is a black key
        final bool isPressed = _pressedKeys.contains(midiNote);
        final bool isHighlighted = widget.highlightedNote == midiNote;

        // Position black key between white keys (offset to left)
        final double blackKeyWidth = keyWidth * 0.6;
        final double blackKeyHeight = keyHeight * 0.6;
        final double blackKeyXOffset = keyWidth - (blackKeyWidth / 2);

        blackKeys.add(
          Positioned(
            left: xPosition - blackKeyXOffset,
            top: 0,
            width: blackKeyWidth,
            height: blackKeyHeight,
            child: GestureDetector(
              onTapDown: (_) => _handleNotePressed(midiNote),
              onTapUp: (_) => _handleNoteReleased(midiNote),
              onTapCancel: () => _handleNoteReleased(midiNote),
              child: Container(
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Theme.of(context).colorScheme.tertiary
                      : isPressed
                          ? Colors.grey.shade700
                          : Colors.black,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: widget.showNoteLabels
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _getSimpleNoteLabel(midiNote),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      }
    }

    return blackKeys;
  }

  // Build octave labels
  List<Widget> _buildOctaveLabels({
    required int startingNote,
    required int totalKeys,
    required double keyWidth,
    required double keyHeight,
  }) {
    final List<Widget> octaveLabels = [];
    double xPosition = 0;

    // Find positions to place octave labels (at each C note)
    for (int i = 0; i < totalKeys; i++) {
      final int midiNote = startingNote + i;
      final int noteIndex = midiNote % 12;

      if (!_isBlackKey(midiNote)) {
        // This is a white key - if it's C, add octave label
        if (noteIndex == 0) {
          // C note
          final int octave = (midiNote ~/ 12) - 1;

          octaveLabels.add(
            Positioned(
              left: xPosition,
              top: 10,
              width: keyWidth,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Oct $octave',
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        xPosition += keyWidth;
      }
    }

    return octaveLabels;
  }

  @override
  void dispose() {
    _midiService.dispose();
    super.dispose();
  }
}
