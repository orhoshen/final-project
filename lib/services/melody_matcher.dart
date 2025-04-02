import 'midi_handler.dart';

class MelodyMatcher {
  static int calculateScore(List<MidiNote> original, List<MidiNote> played) {
    if (played.isEmpty) return 0;
    
    int score = 0;
    int maxLength = original.length > played.length ? original.length : played.length;
    
    for (int i = 0; i < maxLength; i++) {
      if (i >= original.length || i >= played.length) {
        score -= 2; // Penalty for missing or extra notes
        continue;
      }
      
      MidiNote originalNote = original[i];
      MidiNote playedNote = played[i];
      
      // Check note pitch
      if (originalNote.note == playedNote.note) {
        score += 2; // Correct note
      } else if ((originalNote.note - playedNote.note).abs() <= 2) {
        score += 1; // Close note (within 2 semitones)
      }
      
      // Check timing
      int timeDiff = (originalNote.startTime - playedNote.startTime).abs();
      if (timeDiff <= 10) {
        score += 1; // Good timing
      } else if (timeDiff <= 20) {
        score += 0; // Acceptable timing (no points)
      }
      
      // Check duration
      int durationDiff = (originalNote.duration - playedNote.duration).abs();
      if (durationDiff <= 10) {
        score += 1; // Good duration
      } else if (durationDiff <= 20) {
        score += 0; // Acceptable duration (no points)
      }
    }
    
    return score;
  }

  static double calculateAccuracy(List<MidiNote> original, List<MidiNote> played) {
    if (original.isEmpty || played.isEmpty) return 0.0;
    
    int correctNotes = 0;
    int maxLength = original.length > played.length ? original.length : played.length;
    
    for (int i = 0; i < maxLength; i++) {
      if (i >= original.length || i >= played.length) continue;
      
      MidiNote originalNote = original[i];
      MidiNote playedNote = played[i];
      
      if (originalNote.note == playedNote.note) {
        correctNotes++;
      }
    }
    
    return correctNotes / original.length;
  }

  static List<MidiNote> generateRandomMelody(int length) {
    final List<MidiNote> melody = [];
    int currentTime = 0;
    
    for (int i = 0; i < length; i++) {
      // Generate random note (MIDI note 21 (A0) to 108 (C8))
      int note = 21 + (DateTime.now().millisecondsSinceEpoch % 88);
      
      // Generate random duration (between 100 and 500 ticks)
      int duration = 100 + (DateTime.now().millisecondsSinceEpoch % 400);
      
      melody.add(MidiNote(
        note: note,
        startTime: currentTime,
        duration: duration,
      ));
      
      currentTime += duration + 50; // Add small gap between notes
    }
    
    return melody;
  }
} 