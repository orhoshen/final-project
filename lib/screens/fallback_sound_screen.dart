import 'package:flutter/material.dart';
import '../services/simple_audio_player.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:final_project/services/js_stub.dart' if (dart.library.js) 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'dart:math';

class FallbackSoundScreen extends StatefulWidget {
  const FallbackSoundScreen({super.key});

  @override
  State<FallbackSoundScreen> createState() => _FallbackSoundScreenState();
}

class _FallbackSoundScreenState extends State<FallbackSoundScreen> {
  final SimpleAudioPlayer _audioPlayer = SimpleAudioPlayer();
  final List<String> _logMessages = [];
  bool _webAudioInitialized = false;
  
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWebAudio();
    }
  }
  
  void _initWebAudio() {
    try {
      // Initialize WebAudio using JS interop
      js.context.callMethod('eval', ['''
        // Create a global audio context
        if (!window.pianoAudioContext) {
          window.pianoAudioContext = new (window.AudioContext || window.webkitAudioContext)();
          console.log("Web Audio API initialized");
          
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
              console.log("Playing note at frequency: " + frequency);
              return true;
            } catch (e) {
              console.error("Error playing Web Audio note:", e);
              return false;
            }
          };
        }
      ''']);
      setState(() {
        _webAudioInitialized = true;
      });
      _addToLog('Web Audio initialized successfully');
    } catch (e) {
      developer.log('Error initializing WebAudio: $e');
      _addToLog('Error initializing WebAudio: $e');
    }
  }
  
  void _addToLog(String message) {
    developer.log(message);
    setState(() {
      _logMessages.add('${DateTime.now().toString().split('.').first}: $message');
      if (_logMessages.length > 20) {
        _logMessages.removeAt(0);
      }
    });
  }
  
  void _playSystemSound() {
    _addToLog('Playing system sound...');
    _audioPlayer.playSystemSound()
        .then((_) => _addToLog('System sound played successfully'))
        .catchError((error) => _addToLog('Error: $error'));
  }
  
  void _playNote(int note) {
    _addToLog('Playing note $note...');
    
    if (kIsWeb && _webAudioInitialized) {
      _playWebAudioNote(note);
    } else {
      _audioPlayer.playPianoNote(note)
          .then((_) => _addToLog('Note $note played successfully'))
          .catchError((error) => _addToLog('Error playing note $note: $error'));
    }
  }
  
  void _playWebAudioNote(int midiNote) {
    try {
      // Calculate frequency (A4 = 440Hz, MIDI note 69)
      final frequency = 440.0 * pow(2, (midiNote - 69) / 12);
      
      // Call JavaScript method
      final success = js.context.callMethod('eval', [
        'window.playPianoNoteFrequency(${frequency.toStringAsFixed(2)}, 0.75)'
      ]);
      
      if (success == true) {
        _addToLog('Web Audio played note $midiNote (${frequency.toStringAsFixed(2)}Hz)');
      } else {
        _addToLog('Error playing Web Audio note: unknown error');
        // Fall back to system sound
        _audioPlayer.playSystemSound();
      }
    } catch (e) {
      _addToLog('Error playing Web Audio note: $e');
      // Fall back to system sound
      _audioPlayer.playSystemSound();
    }
  }
  
  void _playCMajorScale() {
    _addToLog('Playing C major scale...');
    _playNoteSequence([60, 62, 64, 65, 67, 69, 71, 72]);
  }
  
  Future<void> _playNoteSequence(List<int> notes) async {
    for (var note in notes) {
      _playNote(note);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _addToLog('Sequence complete');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(kIsWeb ? 'Web Audio Test' : 'Simple Sound Test'),
        backgroundColor: Colors.deepPurple.shade800,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              kIsWeb ? 'Test Web Audio API' : 'Test Basic Sounds',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          
          // System sound button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _playSystemSound,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Play System Sound'),
            ),
          ),
          
          if (kIsWeb) Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _webAudioInitialized 
                  ? 'Web Audio API is initialized' 
                  : 'Web Audio API not available',
              style: TextStyle(
                color: _webAudioInitialized ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Piano Notes'),
          ),
          
          // Full octave of white piano keys
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNoteButton('C4', 60),
                _buildNoteButton('D4', 62),
                _buildNoteButton('E4', 64),
                _buildNoteButton('F4', 65),
                _buildNoteButton('G4', 67),
                _buildNoteButton('A4', 69),
                _buildNoteButton('B4', 71),
                _buildNoteButton('C5', 72),
              ],
            ),
          ),
          
          // Black keys
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBlackNoteButton('C#4', 61),
                _buildBlackNoteButton('D#4', 63),
                _buildBlackNoteButton('F#4', 66),
                _buildBlackNoteButton('G#4', 68),
                _buildBlackNoteButton('A#4', 70),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _playCMajorScale,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Play C Major Scale'),
          ),
          
          const Divider(),
          // Activity log
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Activity Log',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logMessages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      _logMessages[index],
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoteButton(String label, int note) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: ElevatedButton(
          onPressed: () => _playNote(note),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            side: const BorderSide(color: Colors.black, width: 1),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
  
  Widget _buildBlackNoteButton(String label, int note) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: ElevatedButton(
          onPressed: () => _playNote(note),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
} 