import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

class SharedMelody {
  final String id;
  final String name;
  final List<int> notes;

  SharedMelody({required this.id, required this.name, required this.notes});

  // This factory now parses the simpler structure
  factory SharedMelody.fromJson(Map<String, dynamic> json, int index) {
    return SharedMelody(
      id: 'melody_$index',
      name: json['title'] as String,
      notes: (json['notes'] as List).map((note) => note as int).toList(),
    );
  }
}

class FirebaseMelodyService {
  List<SharedMelody>? _melodies;
  List<SharedMelody> _availableMelodies = []; // New list for the shuffle logic
  static const String _assetPath = 'static/melodies.json';

  // Singleton pattern
  FirebaseMelodyService._();
  static final FirebaseMelodyService instance = FirebaseMelodyService._();

  Future<void> _loadMelodies() async {
    if (_melodies != null) return; // Already loaded

    try {
      final String jsonString = await rootBundle.loadString(_assetPath);
      // The new JSON is a list at the root
      final List<dynamic> jsonList = json.decode(jsonString);

      _melodies = [];
      for (int i = 0; i < jsonList.length; i++) {
        _melodies!.add(SharedMelody.fromJson(jsonList[i], i));
      }

      // Initialize the available melodies list
      _availableMelodies = List<SharedMelody>.from(_melodies!);

      developer.log('Successfully loaded ${_melodies?.length} melodies and initialized available list.');
    } catch (e) {
      developer.log('FATAL: Error loading local melodies asset: $e');
      _melodies = []; // Set to empty list on error
      _availableMelodies = [];
    }
  }

  Future<SharedMelody?> getRandomMelody() async {
    await _loadMelodies();

    if (_melodies == null || _melodies!.isEmpty) {
      developer.log('No melodies loaded. Returning null.');
      return null;
    }

    // If we've run out of unique melodies, reset the list to start a new cycle.
    if (_availableMelodies.isEmpty) {
      developer.log('All unique melodies played. Resetting shuffle list.');
      _availableMelodies = List<SharedMelody>.from(_melodies!);
    }

    final random = Random();
    // Pick a random melody from the available list and remove it.
    final int randomIndex = random.nextInt(_availableMelodies.length);
    final SharedMelody selectedMelody = _availableMelodies.removeAt(randomIndex);

    developer
        .log('Selected melody: "${selectedMelody.name}". Melodies remaining in cycle: ${_availableMelodies.length}');
    return selectedMelody;
  }
}
