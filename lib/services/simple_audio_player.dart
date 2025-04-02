import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:js' as js;

/// A very simple audio player that uses built-in Flutter mechanisms
/// for playing sounds - no external dependencies required
class SimpleAudioPlayer {
  static final SimpleAudioPlayer _instance = SimpleAudioPlayer._internal();
  factory SimpleAudioPlayer() => _instance;
  
  bool _webAudioReady = false;
  
  SimpleAudioPlayer._internal() {
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
  Future<void> playPianoNote(int midiNote) async {
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