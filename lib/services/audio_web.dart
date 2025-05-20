import 'dart:html' as html;
import 'dart:developer' as developer;

// Web-specific audio playback using the HTML audio element
void playWebSound(int midiNote) {
  try {
    final audio = html.AudioElement('assets/piano_notes/note_$midiNote.mp3');
    audio.play();
    developer.log('Web audio playback started for note $midiNote');
  } catch (e) {
    developer.log('Error playing web audio: $e');
  }
} 