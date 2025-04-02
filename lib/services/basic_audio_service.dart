import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
// Conditionally import dart:html for web platforms
import 'audio_web.dart' if (dart.library.io) 'audio_non_web.dart';
import 'native_audio.dart';

/// A simpler audio service that uses platform-specific approaches for sound playback
class BasicAudioService {
  static final BasicAudioService _instance = BasicAudioService._internal();
  factory BasicAudioService() => _instance;
  BasicAudioService._internal();

  // Play a note using the most direct method available on the platform
  Future<void> playSound(int midiNote) async {
    developer.log('BasicAudioService: Playing sound for note $midiNote');
    
    if (kIsWeb) {
      playWebSound(midiNote);
    } else {
      // Try native system sound first
      try {
        await NativeAudio.playSystemSound();
      } catch (e) {
        developer.log('Native audio failed, falling back to system sound: $e');
        _playSystemSound();
      }
    }
  }
  
  // Fallback to system sounds
  void _playSystemSound() {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
      developer.log('System sound played as fallback');
    } catch (e) {
      developer.log('Failed to play system sound: $e');
    }
  }
} 