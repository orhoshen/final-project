import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'dart:js' as js;
import 'dart:math';

/// Static class for playing audio using native platform methods
class NativeAudio {
  static const MethodChannel _channel = MethodChannel('com.example.final_project/audio');
  
  static bool _webAudioReady = false;
  
  /// Initialize Web Audio API for browser platforms
  static Future<void> initWebAudio() async {
    if (!kIsWeb || _webAudioReady) return;
    
    try {
      // Initialize WebAudio using JS interop
      js.context.callMethod('eval', ['''
        // Create a global audio context
        if (!window.pianoAudioContext) {
          window.pianoAudioContext = new (window.AudioContext || window.webkitAudioContext)();
          console.log("Web Audio API initialized in NativeAudio");
          
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
              console.log("Native Audio - Playing note at frequency: " + frequency);
              return true;
            } catch (e) {
              console.error("Error playing Web Audio note:", e);
              return false;
            }
          };
        }
      ''']);
      
      _webAudioReady = true;
      developer.log('Web Audio ready for NativeAudio');
    } catch (e) {
      developer.log('Error initializing WebAudio in NativeAudio: $e');
      _webAudioReady = false;
    }
  }
  
  /// Play a system sound on the native platform
  static Future<void> playSystemSound() async {
    try {
      if (kIsWeb) {
        // For web, just use system sounds provided by Flutter
        await SystemSound.play(SystemSoundType.click);
        await HapticFeedback.mediumImpact();
        return;
      }
      
      // For native platforms, attempt to use the platform channel
      await _channel.invokeMethod('playMacOSSound');
      developer.log('Native system sound played');
    } catch (e) {
      developer.log('Error in native system sound: $e');
      // Fall back to Flutter system sound
      await SystemSound.play(SystemSoundType.click);
    }
  }
  
  /// Play a piano note using native implementation
  static Future<void> playPianoNote(int midiNote) async {
    try {
      developer.log('Playing native piano note: $midiNote');
      
      // For web, use Web Audio API
      if (kIsWeb) {
        await playWebAudioNote(midiNote);
        return;
      }
      
      // Try to use the native channel
      final result = await _channel.invokeMethod('playPianoNote', {'note': midiNote});
      developer.log('Native piano note result: $result');
    } catch (e) {
      developer.log('Error in native piano note playback: (4) failed to load URL. Using fallback sound.');
      // Fall back to system sound
      await playSystemSound();
    }
  }
  
  /// Play a piano note using Web Audio API (for web)
  static Future<void> playWebAudioNote(int midiNote) async {
    if (!kIsWeb) return;
    
    // Initialize Web Audio if not already done
    if (!_webAudioReady) {
      await initWebAudio();
    }
    
    try {
      // Calculate frequency (A4 = 440Hz, MIDI note 69)
      final frequency = 440.0 * pow(2, (midiNote - 69) / 12);
      
      // Call JavaScript method
      final success = js.context.callMethod('eval', [
        'window.playPianoNoteFrequency(${frequency.toStringAsFixed(2)}, 0.5)'
      ]);
      
      if (success != true) {
        developer.log('WebAudio playback failed for note $midiNote');
        await playSystemSound();
      }
    } catch (e) {
      developer.log('Error playing Web Audio note in NativeAudio: $e');
      await playSystemSound();
    }
  }
} 