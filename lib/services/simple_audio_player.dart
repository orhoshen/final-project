import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:final_project/services/js_stub.dart' if (dart.library.js) 'dart:js' as js;
import 'dart:async';
import 'dart:math' as math;

/// A simple audio player for piano notes
class SimpleAudioPlayer {
  final Map<int, AudioPlayer> _players = {};
  bool _webAudioReady = false;
  
  // Server URL for piano notes as fallback
  static const String _serverBaseUrl = 'https://summer-heaven-460309-n7.uc.r.appspot.com/api/piano_notes';
  
  // Set a timeout to prevent hanging operations
  static const Duration _operationTimeout = Duration(seconds: 3);

  SimpleAudioPlayer() {
    if (kIsWeb) {
      _initWebAudio();
    }
  }
  
  void _initWebAudio() {
    try {
      js.context.callMethod('eval', ['''
        // Create a global audio context
        if (!window.audioContext) {
          window.audioContext = new (window.AudioContext || window.webkitAudioContext)();
          console.log("Web Audio API initialized in SimpleAudioPlayer");
          
          // Create a simple note player with correct A4=440Hz standard tuning
          window.playNoteFrequency = function(frequency, duration) {
            try {
              if (frequency <= 0) {
                console.error("Invalid frequency value: " + frequency);
                return false;
              }
            
              var ctx = window.audioContext;
              var oscillator = ctx.createOscillator();
              var gain = ctx.createGain();
              
              // Use triangle wave for piano-like tone (more harmonics than sine)
              oscillator.type = 'triangle';
              oscillator.frequency.value = frequency;
              
              // Smoother envelope for better sound
              gain.gain.setValueAtTime(0.0, ctx.currentTime);
              gain.gain.linearRampToValueAtTime(0.7, ctx.currentTime + 0.01);
              gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + duration);
              
              oscillator.connect(gain);
              gain.connect(ctx.destination);
              
              oscillator.start();
              oscillator.stop(ctx.currentTime + duration);
              console.log("SimpleAudioPlayer - Playing note at frequency: " + frequency + " Hz");
              return true;
            } catch (e) {
              console.error("Error playing Web Audio note:", e);
              return false;
            }
          };
        }
      ''']);
      
      _webAudioReady = true;
      developer.log('Web Audio ready for SimpleAudioPlayer');
    } catch (e) {
      developer.log('Error initializing WebAudio in SimpleAudioPlayer: $e');
      _webAudioReady = false;
    }
  }
  
  /// Play a system sound (guaranteed to work on all platforms)
  Future<void> playSystemSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      developer.log('System sound played successfully');
      
      // Also provide haptic feedback for physical sensation
      await HapticFeedback.mediumImpact();
    } catch (e) {
      developer.log('Error playing system sound: $e');
    }
  }
  
  /// Play a sound with specific characteristics
  Future<void> playTone({double frequency = 440.0, int durationMs = 500}) async {
    try {
      if (frequency <= 0) {
        developer.log('Invalid frequency: $frequency Hz, using 440 Hz instead');
        frequency = 440.0;
      }
      
      if (kIsWeb && _webAudioReady) {
        // Use Web Audio API
        js.context.callMethod('eval', [
          'window.playNoteFrequency(${frequency.toStringAsFixed(2)}, ${(durationMs / 1000).toStringAsFixed(2)})'
        ]);
        developer.log('Tone played with Web Audio - frequency: $frequency Hz, duration: $durationMs ms');
        return;
      }
      
      // Use medium impact as a standin for tone on non-web platforms
      await HapticFeedback.mediumImpact();
      developer.log('Tone played with frequency: $frequency Hz, duration: $durationMs ms');
    } catch (e) {
      developer.log('Error playing tone: $e');
    }
  }
  
  /// Play a piano note using either WebAudio or audio file
  Future<void> playPianoNote(int midiNote) async {
    // Restrict to supported MIDI range (0-127)
    midiNote = midiNote.clamp(0, 127);
    
    // Web platforms use the WebAudio API
    if (kIsWeb && _webAudioReady) {
      _playWebAudioNote(midiNote);
      return;
    }
    
    // Check if note is in range for our audio files
    bool useAssetAudio = midiNote >= 60 && midiNote <= 72;
    
    if (!useAssetAudio) {
      developer.log('Note $midiNote out of range for audio files, using WebAudio fallback');
      _playWebAudioNote(midiNote);
      return;
    }
    
    // Try playing audio file
    try {
      // Create player for this note if needed
      if (!_players.containsKey(midiNote)) {
        final completer = Completer<void>();
        final timeoutTimer = Timer(_operationTimeout, () {
          if (!completer.isCompleted) {
            developer.log('Timeout loading note $midiNote');
            completer.completeError('Timeout loading note');
          }
        });
        
        try {
          _players[midiNote] = AudioPlayer();
          
          // First try loading from assets
          final assetPath = 'assets/piano_notes/note_$midiNote.mp3';
          developer.log('Attempting to load asset: $assetPath');
          
          try {
            await _players[midiNote]!.setAsset(assetPath)
                .timeout(_operationTimeout);
            developer.log('Successfully loaded note $midiNote from assets');
            if (!completer.isCompleted) completer.complete();
          } catch (e) {
            developer.log('Error loading asset for note $midiNote: $e');
            
            // Try loading from server as fallback
            try {
              final url = '$_serverBaseUrl/note_$midiNote.mp3';
              developer.log('Attempting to load from server: $url');
              
              await _players[midiNote]!.setUrl(url)
                  .timeout(_operationTimeout);
              developer.log('Successfully loaded note $midiNote from server');
              if (!completer.isCompleted) completer.complete();
            } catch (serverError) {
              developer.log('Error loading note from server: $serverError');
              if (!completer.isCompleted) {
                completer.completeError('Failed to load note $midiNote from any source');
              }
            }
          }
          
          // Wait for loading to complete or timeout
          await completer.future;
        } catch (e) {
          developer.log('Error initializing player for note $midiNote: $e');
          if (_players.containsKey(midiNote)) {
            _players[midiNote]?.dispose();
            _players.remove(midiNote);
          }
          rethrow;
        } finally {
          timeoutTimer.cancel();
        }
      }
      
      // If we have a valid player, play the note
      if (_players.containsKey(midiNote)) {
        final player = _players[midiNote]!;
        await player.seek(Duration.zero);
        await player.play();
        developer.log('Playing audio file for note $midiNote');
      } else {
        // Fall back to web audio or system sound
        throw Exception('No player available for note $midiNote');
      }
    } catch (e) {
      developer.log('Error playing note $midiNote: $e');
      
      // As a last resort, try a generic tone with WebAudio
      _playWebAudioNote(midiNote);
    }
  }
  
  void _playWebAudioNote(int midiNote) {
    // Standard formula from Wikipedia: f(n) = 2^((n-69)/12) * 440 Hz
    // Where n is the MIDI note number, and 69 is A4 (440 Hz)
    double frequency = 0;
    
    try {
      // Calculate using correct formula
      frequency = 440.0 * math.pow(2, (midiNote - 69) / 12);
      
      // Ensure we're getting a valid frequency (should always be positive)
      if (frequency <= 0) {
        developer.log('ERROR: Invalid frequency calculated: $frequency Hz for MIDI note $midiNote');
        // Use a safe default
        frequency = 440.0;
      }
      
      developer.log('Playing WebAudio note $midiNote - calculated frequency: ${frequency.toStringAsFixed(2)} Hz');
      
      js.context.callMethod('eval', [
        'window.playNoteFrequency(${frequency.toStringAsFixed(2)}, 0.5)'
      ]);
      developer.log('WebAudio played note $midiNote at ${frequency.toStringAsFixed(2)} Hz');
    } catch (e) {
      developer.log('Error playing WebAudio: $e');
      // Try to play a system sound as a last resort
      playSystemSound();
    }
  }
  
  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}

// Calculate power of a number (for WebAudio frequency calculation)
double pow(num x, num exponent) {
  return math.pow(x.toDouble(), exponent.toDouble()) as double;
}

/// A very simple audio player that uses built-in Flutter mechanisms
/// for playing sounds - no external dependencies required
class SimpleAudioPlayerOld {
  static final SimpleAudioPlayerOld _instance = SimpleAudioPlayerOld._internal();
  factory SimpleAudioPlayerOld() => _instance;
  
  bool _webAudioReady = false;
  
  SimpleAudioPlayerOld._internal() {
    if (kIsWeb) {
      _initWebAudio();
    }
  }
  
  void _initWebAudio() {
    try {
      // Initialize WebAudio using JS interop if not already done
      js.context.callMethod('eval', ['''
        // Create a global audio context
        if (!window.pianoAudioContext) {
          window.pianoAudioContext = new (window.AudioContext || window.webkitAudioContext)();
          console.log("Web Audio API initialized in SimpleAudioPlayer");
          
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
              console.log("SimpleAudioPlayer - Playing note at frequency: " + frequency);
              return true;
            } catch (e) {
              console.error("Error playing Web Audio note:", e);
              return false;
            }
          };
        }
      ''']);
      
      _webAudioReady = true;
      developer.log('Web Audio ready for SimpleAudioPlayer');
    } catch (e) {
      developer.log('Error initializing WebAudio in SimpleAudioPlayer: $e');
      _webAudioReady = false;
    }
  }
  
  /// Play a system sound (guaranteed to work on all platforms)
  Future<void> playSystemSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      developer.log('System sound played successfully');
      
      // Also provide haptic feedback for physical sensation
      await HapticFeedback.mediumImpact();
    } catch (e) {
      developer.log('Error playing system sound: $e');
    }
  }
  
  /// Play a sound with specific characteristics
  Future<void> playTone({double frequency = 440.0, int durationMs = 500}) async {
    try {
      if (kIsWeb && _webAudioReady) {
        // Use Web Audio API
        js.context.callMethod('eval', [
          'window.playPianoNoteFrequency(${frequency.toStringAsFixed(2)}, ${(durationMs / 1000).toStringAsFixed(2)})'
        ]);
        developer.log('Tone played with Web Audio - frequency: $frequency Hz, duration: $durationMs ms');
        return;
      }
      
      // Use medium impact as a standin for tone on non-web platforms
      await HapticFeedback.mediumImpact();
      developer.log('Tone played with frequency: $frequency Hz, duration: $durationMs ms');
    } catch (e) {
      developer.log('Error playing tone: $e');
    }
  }
  
  /// Play a piano note (with the given MIDI note number)
  Future<void> playPianoNoteOld(int midiNote) async {
    try {
      developer.log('Playing piano note: $midiNote');
      
      // Calculate the frequency (A4 = 69 = 440Hz) based on MIDI note
      final frequency = 440.0 * pow(2, (midiNote - 69) / 12);
      
      // For web, use Web Audio API
      if (kIsWeb && _webAudioReady) {
        final success = js.context.callMethod('eval', [
          'window.playPianoNoteFrequency(${frequency.toStringAsFixed(2)}, 0.5)'
        ]);
        
        if (success == true) {
          developer.log('Web Audio played note $midiNote (${frequency.toStringAsFixed(2)}Hz)');
          return;
        }
      }
      
      // Fall back to system sound and haptic feedback
      await playSystemSound();
      
      // For debugging
      _logMidiNote(midiNote);
      
    } catch (e) {
      developer.log('Error playing piano note: $e');
      // Try system sound as a last resort
      await playSystemSound();
    }
  }
  
  /// Log information about the note
  void _logMidiNote(int midiNote) {
    // Note names (C, C#, D, etc.)
    final noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    
    // Calculate the octave (MIDI note 60 = C4)
    final octave = ((midiNote / 12) - 1).floor();
    
    // Calculate the note within the octave
    final noteIndex = midiNote % 12;
    
    // Calculate the frequency (A4 = 69 = 440Hz)
    final frequency = 440.0 * pow(2, (midiNote - 69) / 12);
    
    developer.log('MIDI: $midiNote = ${noteNames[noteIndex]}$octave (frequency: ${frequency.toStringAsFixed(2)} Hz)');
  }
} 