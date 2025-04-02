import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class MidiHandler {
  static Future<List<int>> loadMidiFile(String fileName) async {
    try {
      final ByteData data = await rootBundle.load('assets/midi/$fileName');
      return data.buffer.asUint8List();
    } catch (e) {
      print('Error loading MIDI file: $e');
      return [];
    }
  }

  static Future<List<MidiNote>> parseMidiFile(String fileName) async {
    final List<int> midiData = await loadMidiFile(fileName);
    if (midiData.isEmpty) return [];

    final List<MidiNote> notes = [];
    int currentTime = 0;
    
    // Basic MIDI parsing (this is a simplified version)
    for (int i = 0; i < midiData.length; i++) {
      if (midiData[i] == 0x90) { // Note On event
        if (i + 2 < midiData.length) {
          final note = midiData[i + 1];
          final velocity = midiData[i + 2];
          if (velocity > 0) {
            notes.add(MidiNote(
              note: note,
              startTime: currentTime,
              duration: 0, // Will be updated when Note Off is found
            ));
          }
        }
      } else if (midiData[i] == 0x80) { // Note Off event
        if (i + 2 < midiData.length) {
          final note = midiData[i + 1];
          // Find the corresponding Note On and update its duration
          for (var midiNote in notes) {
            if (midiNote.note == note && midiNote.duration == 0) {
              midiNote.duration = currentTime - midiNote.startTime;
              break;
            }
          }
        }
      }
      currentTime++;
    }
    
    return notes;
  }

  static Future<void> saveMidiFile(List<MidiNote> notes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    
    // Create MIDI file header
    final List<int> midiData = [
      0x4D, 0x54, 0x68, 0x64, // MThd
      0x00, 0x00, 0x00, 0x06, // Header length
      0x00, 0x01, // Format 1
      0x00, 0x01, // One track
      0x00, 0x60, // 96 ticks per quarter note
    ];

    // Add track header
    midiData.addAll([
      0x4D, 0x54, 0x72, 0x6B, // MTrk
      0x00, 0x00, 0x00, 0x00, // Track length (will be updated)
    ]);

    // Add notes
    for (var note in notes) {
      // Note On
      midiData.addAll([
        0x00, // Delta time
        0x90, // Note On
        note.note,
        0x64, // Velocity
      ]);

      // Note Off
      midiData.addAll([
        note.duration,
        0x80, // Note Off
        note.note,
        0x00, // Velocity
      ]);
    }

    // Update track length
    final trackLength = midiData.length - 8;
    midiData[4] = (trackLength >> 24) & 0xFF;
    midiData[5] = (trackLength >> 16) & 0xFF;
    midiData[6] = (trackLength >> 8) & 0xFF;
    midiData[7] = trackLength & 0xFF;

    await file.writeAsBytes(midiData);
  }
}

class MidiNote {
  final int note;
  final int startTime;
  int duration;

  MidiNote({
    required this.note,
    required this.startTime,
    this.duration = 0,
  });
} 