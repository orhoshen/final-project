import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

// Use conditional import for js
// Use @JS annotation for JavaScript interop
import 'dart:math';
import 'dart:js' as js;
import 'package:js/js.dart' if (dart.library.js) 'package:js/js.dart';

/// A MIDI service that uses pre-recorded piano samples for high-quality audio
class MidiService {
  static final MidiService _instance = MidiService._internal();
  factory MidiService() => _instance;
  MidiService._internal();

  // Audio players for each note (C4-C5 = MIDI 60-72)
  final Map<int, AudioPlayer> _players = {};
  bool _initialized = false;
  bool _isInitializing = false;
  bool _webAudioReady = false;

  // Check if audio is ready to play
  bool get isReady => _initialized;
  
  // Initialize audio system
  Future<void> initialize() async {
    if (_isInitializing || _initialized) {
      return;
    }
    
    _isInitializing = true;
    
    try {
      developer.log('Initializing MIDI service');
      
      // Web platform-specific initialization
      if (kIsWeb) {
        _initWebAudio();
      } else {
        // Initialize native audio players
        for (int note = 60; note <= 72; note++) {
          _players[note] = AudioPlayer();
        }
      }
      
      _initialized = true;
      _isInitializing = false;
      developer.log('MIDI service initialization complete.');
    } catch (e) {
      developer.log('Error initializing MIDI service: $e');
      _initialized = false;
      _isInitializing = false;
      throw Exception('Failed to initialize MIDI service: $e');
    }
  }

  void _initWebAudio() {
    try {
      // Initialize WebAudio using JS interop
      js.context.callMethod('eval', ['''
        // Create a global audio context
        if (!window.pianoAudioContext) {
          window.pianoAudioContext = new (window.AudioContext || window.webkitAudioContext)();
          console.log("Web Audio API initialized in MidiService");
          
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
              console.log("MIDI - Playing note at frequency: " + frequency);
              return true;
            } catch (e) {
              console.error("Error playing Web Audio note:", e);
              return false;
            }
          };
        }
      ''']);
      
      _webAudioReady = true;
      developer.log('Web Audio ready for MIDI service');
    } catch (e) {
      developer.log('Error initializing WebAudio in MidiService: $e');
      _webAudioReady = false;
    }
  }
  
  // Play a note
  Future<void> playMidiNote(int midiNote) async {
    developer.log('Playing MIDI note: $midiNote');

    try {
      // For web, use WebAudio API
      if (kIsWeb && _webAudioReady) {
        _playWebAudioNote(midiNote);
        return;
      }
      
      // For non-web, initialize if needed
      if (!_initialized) {
        await initialize();
      }
      
      // Ensure note is in range
      if (midiNote < 60 || midiNote > 72) {
        developer.log('Note out of range: $midiNote');
        // Play a note in range if the requested one isn't
        midiNote = midiNote < 60 ? 60 : (midiNote > 72 ? 72 : midiNote);
      }
      
      // For notes we have players
      if (_players.containsKey(midiNote)) {
        final player = _players[midiNote]!;
        if (player.playing) {
          await player.stop();
        }
        await player.seek(Duration.zero);
        
        try {
          // Try to play the note
          await player.play();
          developer.log('Playing native note: $midiNote');
          return;
        } catch (e) {
          developer.log('Error playing native note $midiNote: $e');
          // Fall through to fallback
        }
      }
      
      // Fallback to system sound
      await _playFallbackSound();
      
    } catch (e) {
      developer.log('Error in MIDI playback: $e');
      // Last resort fallback
      await _playFallbackSound();
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
      
      if (success != true) {
        developer.log('WebAudio playback failed for note $midiNote');
        _playFallbackSound();
      }
    } catch (e) {
      developer.log('Error playing Web Audio note in MidiService: $e');
      _playFallbackSound();
    }
  }
  
  Future<void> _playFallbackSound() async {
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      developer.log('Error playing fallback sound: $e');
    }
  }
  
  // Test audio playback
  Future<bool> testAudio() async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      // For web, just check if WebAudio is ready
      if (kIsWeb) {
        return _webAudioReady;
      }
      
      // Try to play middle C (MIDI 60)
      await playMidiNote(60);
      developer.log('Audio test successful');
      return true;
    } catch (e) {
      developer.log('Audio test failed: $e');
      return false;
    }
  }
  
  // Clean up
  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
    _initialized = false;
  }
} 