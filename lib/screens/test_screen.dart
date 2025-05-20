import 'package:flutter/material.dart';
import '../services/midi_service.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final MidiService _midiService = MidiService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeMidi();
  }

  Future<void> _initializeMidi() async {
    try {
      await _midiService.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing MIDI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing MIDI: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _midiService.dispose();
    super.dispose();
  }

  Future<void> _playNote(int midiNote) async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MIDI not initialized yet')),
      );
      return;
    }

    try {
      await _midiService.playNote(midiNote);
    } catch (e) {
      print('Error playing note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIDI Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'MIDI Status: ${_isInitialized ? "Initialized" : "Not Initialized"}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _playNote(60), // Middle C
              child: const Text('Play Middle C'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _playNote(64), // E
              child: const Text('Play E'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _playNote(67), // G
              child: const Text('Play G'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _playNote(72), // C (one octave higher)
              child: const Text('Play High C'),
            ),
          ],
        ),
      ),
    );
  }
} 