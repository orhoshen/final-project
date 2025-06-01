import 'dart:developer' as developer;

import 'package:web/web.dart' as web;

// Web-specific audio playback using modern web APIs
void playWebSound(int midiNote) {
  try {
    final audio = web.HTMLAudioElement();
    audio.src = 'assets/piano_notes/note_$midiNote.mp3';
    audio.play();
    developer.log('Web audio playback started for note $midiNote');
  } catch (e) {
    developer.log('Error playing web audio: $e');
  }
}
