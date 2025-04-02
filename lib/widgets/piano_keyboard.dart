import 'package:flutter/material.dart';
import '../services/midi_service.dart';
import '../services/simple_audio_player.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import 'dart:math';

class PianoKeyboard extends StatefulWidget {
  final Function(int)? onNotePressed;
  final Function(int)? onNoteReleased;
  final int startingOctave;
  final int numberOfOctaves;
  final bool showNoteLabels;

  const PianoKeyboard({
    super.key,
    this.onNotePressed,
    this.onNoteReleased,
    this.startingOctave = 4,
    this.numberOfOctaves = 2,
    this.showNoteLabels = false,
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  final MidiService _midiService = MidiService();
  final SimpleAudioPlayer _simpleAudio = SimpleAudioPlayer();
  final Set<int> _pressedKeys = {};
  bool _isInitialized = false;
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
          _isInitialized = true;
          _isInitializing = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      developer.log('Error initializing audio in PianoKeyboard: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
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
      js.context.callMethod('eval', ['''
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
      ''']);
      
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
      final success = js.context.callMethod('eval', [
        'window.playPianoNoteFrequency(${frequency.toStringAsFixed(2)}, 0.5)'
      ]);
      
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

  String _getNoteLabel(int midiNote) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (midiNote ~/ 12) - 1;
    final noteIndex = midiNote % 12;
    return '${notes[noteIndex]}$octave';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWhiteKeys = 7 * widget.numberOfOctaves;
        final whiteKeyWidth = constraints.maxWidth / totalWhiteKeys;
        final whiteKeyHeight = constraints.maxHeight;
        final blackKeyWidth = whiteKeyWidth * 0.6;
        final blackKeyHeight = whiteKeyHeight * 0.6;

        return ClipRect(
          child: Stack(
            children: [
              // White keys
              SizedBox(
                width: constraints.maxWidth,
                height: whiteKeyHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(totalWhiteKeys, (index) {
                    final octave = widget.startingOctave + (index ~/ 7);
                    final noteInOctave = index % 7;
                    final midiNote = _getMidiNoteForWhiteKey(octave, noteInOctave);
                    
                    return SizedBox(
                      width: whiteKeyWidth,
                      height: whiteKeyHeight,
                      child: GestureDetector(
                        onTapDown: (_) => _handleNotePressed(midiNote),
                        onTapUp: (_) => _handleNoteReleased(midiNote),
                        onTapCancel: () => _handleNoteReleased(midiNote),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _pressedKeys.contains(midiNote) 
                                ? Theme.of(context).colorScheme.primaryContainer 
                                : Colors.white,
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: widget.showNoteLabels
                              ? Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      _getNoteLabel(midiNote),
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Black keys
              SizedBox(
                width: constraints.maxWidth,
                height: blackKeyHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(totalWhiteKeys, (index) {
                    final octave = widget.startingOctave + (index ~/ 7);
                    final noteInOctave = index % 7;
                    
                    if (!_hasBlackKey(noteInOctave)) {
                      return SizedBox(width: whiteKeyWidth);
                    }

                    final midiNote = _getMidiNoteForBlackKey(octave, noteInOctave);
                    final offset = whiteKeyWidth - (blackKeyWidth / 2);
                    
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: offset,
                          child: GestureDetector(
                            onTapDown: (_) => _handleNotePressed(midiNote),
                            onTapUp: (_) => _handleNoteReleased(midiNote),
                            onTapCancel: () => _handleNoteReleased(midiNote),
                            child: Container(
                              width: blackKeyWidth,
                              height: blackKeyHeight,
                              decoration: BoxDecoration(
                                color: _pressedKeys.contains(midiNote)
                                    ? Theme.of(context).colorScheme.inversePrimary
                                    : Colors.black,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(3),
                                  bottomRight: Radius.circular(3),
                                ),
                              ),
                              child: widget.showNoteLabels
                                  ? Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Text(
                                          _getNoteLabel(midiNote),
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: Colors.white,
                                              ),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(width: whiteKeyWidth),
                      ],
                    );
                  }),
                ),
              ),
              // Message overlay (non-blocking)
              if (_errorMessage != null)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  int _getMidiNoteForWhiteKey(int octave, int noteInOctave) {
    // C D E F G A B
    final offsets = [0, 2, 4, 5, 7, 9, 11];
    return octave * 12 + offsets[noteInOctave];
  }

  int _getMidiNoteForBlackKey(int octave, int noteInOctave) {
    // C# D# F# G# A#
    final offsets = [1, 3, 6, 8, 10];
    final blackKeyIndex = [0, 1, 3, 4, 5].indexOf(noteInOctave);
    return octave * 12 + offsets[blackKeyIndex];
  }

  bool _hasBlackKey(int noteInOctave) {
    // Returns true for C, D, F, G, A (indices 0, 1, 3, 4, 5)
    return [0, 1, 3, 4, 5].contains(noteInOctave);
  }

  @override
  void dispose() {
    _midiService.dispose();
    super.dispose();
  }
} 