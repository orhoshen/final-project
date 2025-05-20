import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;
import 'package:final_project/services/js_stub.dart' if (dart.library.js) 'dart:js' as js;

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
  
  // Initialization timeout
  static const Duration _initTimeout = Duration(seconds: 5);

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
        // Only initialize a few players to save resources
        _initializePlayerAsync();
      }
      
      // Mark as initialized immediately, we'll load notes lazily
      _initialized = true;
      _isInitializing = false;
      developer.log('MIDI service initialization complete.');
    } catch (e) {
      developer.log('Error initializing MIDI service: $e');
      _initialized = false;
      _isInitializing = false;
      // Don't throw, we'll fall back to system sounds
    }
  }
  
  // Initialize players asynchronously without blocking UI
  void _initializePlayerAsync() {
    // Create a temporary test player
    final player = AudioPlayer();
    
    // Set a timeout to avoid hanging
    Timer(_initTimeout, () {
      _initialized = true;
      _isInitializing = false;
    });
    
    // Testing with middle C
    player.setAsset('assets/piano_notes/note_60.mp3').then((_) {
      _players[60] = player;
    }).catchError((e) {
      developer.log('Error initializing test player: $e');
      player.dispose();
    });
  }

  void _initWebAudio() {
    try {
      // Initialize WebAudio using JS interop
      js.context.callMethod('eval', ['''
        // Create a global audio context
        if (!window.pianoAudioContext) {
          window.pianoAudioContext = new (window.AudioContext || window.webkitAudioContext)();
          console.log("Web Audio API initialized in MidiService");
          
          // Create a piano-like note player using standard A4=440Hz tuning
          window.playPianoNoteFrequency = function(frequency, duration) {
            try {
              if (frequency <= 0) {
                console.error("Invalid frequency value: " + frequency);
                return false;
              }
            
              var ctx = window.pianoAudioContext;
              var oscillator = ctx.createOscillator();
              var gain = ctx.createGain();
              
              // Triangle has more harmonics, closer to piano sound
              oscillator.type = 'triangle';
              oscillator.frequency.value = frequency;
              
              // More realistic piano envelope
              gain.gain.setValueAtTime(0.0, ctx.currentTime);
              gain.gain.linearRampToValueAtTime(0.7, ctx.currentTime + 0.01); 
              gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + duration);
              
              oscillator.connect(gain);
              gain.connect(ctx.destination);
              
              oscillator.start();
              oscillator.stop(ctx.currentTime + duration);
              console.log("MIDI - Playing note at frequency: " + frequency + " Hz");
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
    // Restrict to supported MIDI range (0-127)
    midiNote = midiNote.clamp(0, 127);
    
    developer.log('Playing MIDI note: $midiNote');

    try {
      // For web, use WebAudio API
      if (kIsWeb && _webAudioReady) {
        _playWebAudioNote(midiNote);
        return;
      }
      
      // Lazy-load player for this note if needed
      if (!_players.containsKey(midiNote)) {
        await _loadPlayer(midiNote);
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
  
  // Load a player for a specific note
  Future<void> _loadPlayer(int midiNote) async {
    try {
      if (midiNote < 60 || midiNote > 72) {
        developer.log('Note $midiNote outside supported range for audio files');
        return;
      }
      
      final player = AudioPlayer();
      
      // Set a timeout to prevent hanging
      final completer = Completer<void>();
      final timer = Timer(_initTimeout, () {
        if (!completer.isCompleted) {
          developer.log('Timeout loading audio for note $midiNote');
          completer.completeError('Timeout loading audio');
        }
      });
      
      // Try to load the note
      try {
        final assetPath = 'assets/piano_notes/note_$midiNote.mp3';
        developer.log('Attempting to load asset: $assetPath');
        
        try {
          // Check if the asset exists first
          await player.setAsset(assetPath);
          developer.log('Successfully loaded asset: $assetPath');
          _players[midiNote] = player;
          
          if (!completer.isCompleted) {
            completer.complete();
          }
        } catch (assetError) {
          developer.log('Error loading asset for note $midiNote: $assetError');
          
          // Try loading from server as fallback
          try {
            final serverUrl = 'https://summer-heaven-460309-n7.uc.r.appspot.com/api/piano_notes/note_$midiNote.mp3';
            developer.log('Attempting to load from server: $serverUrl');
            
            await player.setUrl(serverUrl);
            developer.log('Successfully loaded note $midiNote from server');
            _players[midiNote] = player;
            
            if (!completer.isCompleted) {
              completer.complete();
            }
          } catch (serverError) {
            developer.log('Error loading note from server: $serverError');
            player.dispose();
            
            if (!completer.isCompleted) {
              completer.completeError('Failed to load note $midiNote from any source');
            }
          }
        }
      } catch (e) {
        developer.log('General error loading player for note $midiNote: $e');
        player.dispose();
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      } finally {
        timer.cancel();
      }
      
      await completer.future;
      
    } catch (e) {
      developer.log('Error in lazy-loading player: $e');
    }
  }
  
  void _playWebAudioNote(int midiNote) {
    try {
      // Standard formula from Wikipedia: f(n) = 2^((n-69)/12) * 440 Hz
      // Where n is the MIDI note number, and 69 is A4 (440 Hz)
      double frequency = 0;
      
      // Calculate using correct formula
      frequency = 440.0 * math.pow(2, (midiNote - 69) / 12);
      
      // Ensure we're getting a valid frequency (should always be positive)
      if (frequency <= 0) {
        developer.log('ERROR: Invalid frequency calculated: $frequency Hz for MIDI note $midiNote');
        // Use a safe default
        frequency = 440.0;
      }
      
      developer.log('Playing MIDI WebAudio note $midiNote - calculated frequency: ${frequency.toStringAsFixed(2)} Hz');
      
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