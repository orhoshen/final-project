import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/basic_audio_service.dart';
import '../services/native_audio.dart';
import 'dart:developer' as developer;

class BasicSoundTestScreen extends StatefulWidget {
  const BasicSoundTestScreen({super.key});

  @override
  State<BasicSoundTestScreen> createState() => _BasicSoundTestScreenState();
}

class _BasicSoundTestScreenState extends State<BasicSoundTestScreen> {
  final BasicAudioService _audioService = BasicAudioService();
  final List<String> _logs = [];

  void _addLog(String message) {
    developer.log(message);
    setState(() {
      _logs.add('[${DateTime.now().toString().split('.').first}] $message');
    });
  }

  Future<void> _testDirectSystemSound() async {
    try {
      _addLog('Testing direct system sound...');
      SystemSound.play(SystemSoundType.click);
      _addLog('System sound played');
    } catch (e) {
      _addLog('Error playing system sound: $e');
    }
  }

  Future<void> _testSimpleNote(int note) async {
    try {
      _addLog('Playing basic note $note');
      await _audioService.playSound(note);
      _addLog('Simple note $note playback triggered');
    } catch (e) {
      _addLog('Error triggering note $note: $e');
    }
  }

  Future<void> _testNativeSound() async {
    try {
      _addLog('Testing native sound playback...');
      await NativeAudio.playSystemSound();
      _addLog('Native sound playback completed');
    } catch (e) {
      _addLog('Error playing native sound: $e');
    }
  }

  Future<void> _testNativePianoNote(int note) async {
    try {
      _addLog('Testing native piano note $note...');
      await NativeAudio.playPianoNote(note);
      _addLog('Native piano note $note playback completed');
    } catch (e) {
      _addLog('Error playing native piano note: $e');
    }
  }

  Future<void> _testHapticFeedback() async {
    try {
      _addLog('Testing haptic feedback...');
      await HapticFeedback.mediumImpact();
      _addLog('Haptic feedback triggered');
    } catch (e) {
      _addLog('Error triggering haptic feedback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Basic Sound Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Basic Sound Tests',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'These tests use simpler, more direct methods to play sounds',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _testDirectSystemSound,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('System Sound'),
                ),
                ElevatedButton(
                  onPressed: _testNativeSound,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Native Sound'),
                ),
                ElevatedButton(
                  onPressed: _testHapticFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Haptic Feedback'),
                ),
                ElevatedButton(
                  onPressed: () => _testSimpleNote(60),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Note C4 (60)'),
                ),
                ElevatedButton(
                  onPressed: () => _testSimpleNote(67),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Note G4 (67)'),
                ),
                ElevatedButton(
                  onPressed: () => _testNativePianoNote(60),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Native C4 (60)'),
                ),
                ElevatedButton(
                  onPressed: () => _testNativePianoNote(67),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Native G4 (67)'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                color: Colors.grey.shade200,
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