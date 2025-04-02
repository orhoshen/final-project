import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:developer' as developer;
import '../services/midi_service.dart';
import 'package:flutter/services.dart';

class SoundTestScreen extends StatefulWidget {
  const SoundTestScreen({super.key});

  @override
  State<SoundTestScreen> createState() => _SoundTestScreenState();
}

class _SoundTestScreenState extends State<SoundTestScreen> {
  final MidiService _midiService = MidiService();
  bool _isInitialized = false;
  final List<String> _logs = [];
  final AudioPlayer _testPlayer = AudioPlayer();
  
  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }
  
  Future<void> _initializeAudio() async {
    try {
      _addLog('Initializing MIDI service...');
      await _midiService.initialize();
      setState(() {
        _isInitialized = true;
      });
      _addLog('MIDI service initialized successfully');
    } catch (e) {
      _addLog('Error initializing MIDI service: $e');
    }
  }
  
  void _addLog(String message) {
    developer.log(message);
    setState(() {
      _logs.add('[${DateTime.now().toString().split('.').first}] $message');
    });
  }
  
  Future<void> _testNote(int midiNote) async {
    try {
      _addLog('Playing MIDI note $midiNote');
      await _midiService.playMidiNote(midiNote);
      _addLog('Note $midiNote played');
    } catch (e) {
      _addLog('Error playing note $midiNote: $e');
    }
  }
  
  Future<void> _testDirectAudio() async {
    try {
      _addLog('Testing direct audio playback...');
      await _testPlayer.setAsset('assets/piano_notes/note_60.mp3');
      await _testPlayer.play();
      _addLog('Direct audio playback completed');
    } catch (e) {
      _addLog('Error in direct audio playback: $e');
    }
  }
  
  Future<void> _testTone() async {
    try {
      _addLog('Testing system sound...');
      // For now, just use the system sound directly
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
      _addLog('System sound played');
    } catch (e) {
      _addLog('Error playing system sound: $e');
    }
  }
  
  @override
  void dispose() {
    _testPlayer.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              color: _isInitialized 
                  ? Colors.green.shade100 
                  : Colors.orange.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'MIDI Service Status:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isInitialized ? 'Initialized ✓' : 'Initializing...',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _isInitialized ? Colors.green.shade800 : Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test buttons section
            Text(
              'Sound Tests:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _testNote(60),
                  child: const Text('Play C4 (60)'),
                ),
                ElevatedButton(
                  onPressed: () => _testNote(64),
                  child: const Text('Play E4 (64)'),
                ),
                ElevatedButton(
                  onPressed: () => _testNote(67),
                  child: const Text('Play G4 (67)'),
                ),
                ElevatedButton(
                  onPressed: _testDirectAudio,
                  child: const Text('Direct Audio Test'),
                ),
                ElevatedButton(
                  onPressed: _testTone,
                  child: const Text('System Sound Test'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Log section
            Expanded(
              child: Card(
                color: Colors.grey.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Logs:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: Text(
                              _logs[_logs.length - 1 - index],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 