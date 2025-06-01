import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/midi_service.dart'; // Simplified to use the existing service
import '../services/websocket_service.dart';

class ServerConnectionTestScreen extends StatefulWidget {
  const ServerConnectionTestScreen({super.key});

  @override
  State<ServerConnectionTestScreen> createState() => _ServerConnectionTestScreenState();
}

class _ServerConnectionTestScreenState extends State<ServerConnectionTestScreen> {
  final MidiService _midiService = MidiService();
  bool _isConnecting = false;
  String _connectionStatus = 'Not connected';
  String _testStatus = '';

  @override
  void initState() {
    super.initState();
    _midiService.initialize();
  }

  @override
  void dispose() {
    _midiService.dispose();
    super.dispose();
  }

  Future<void> _connectToServer() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Connecting...';
    });

    try {
      final websocketService = Provider.of<WebSocketService>(context, listen: false);
      final success = await websocketService.connect();

      setState(() {
        _isConnecting = false;
        _connectionStatus = success ? 'Connected to server' : 'Connection failed';
      });

      if (success) {
        // Try to create a testing room
        final createRoomSuccess = await websocketService.createRoom('TestUser');
        setState(() {
          _testStatus += createRoomSuccess ? '• Created test room successfully\n' : '• Failed to create test room\n';
        });
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _connectionStatus = 'Error: $e';
      });
    }
  }

  Future<void> _testCompareMelodies() async {
    setState(() {
      _testStatus += '• Testing melody comparison API...\n';
    });

    try {
      // Using the server melody matcher to compare melodies
      // This is a simplified version using our existing components

      setState(() {
        _testStatus += '• Testing comparison between [C, D, E] and [C, D, D#]\n';
        _testStatus += '• Test implementation is simplified for demo\n';
        _testStatus += '• In a real setup, this would call the server API\n';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _testStatus += '• Melody comparison completed (simulated)\n';
        _testStatus += '• Similarity score: 0.78 (simulated)\n';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _testStatus += '• Error: $e\n';
        });
      }
    }
  }

  Future<void> _testAudioPlayback() async {
    if (mounted) {
      setState(() {
        _testStatus += '• Testing audio playback...\n';
      });
    }

    try {
      for (int note = 60; note <= 72; note += 2) {
        // Try to play the note
        if (mounted) {
          setState(() {
            _testStatus += '• Playing note $note...\n';
          });
        }

        await _midiService.playMidiNote(note);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        setState(() {
          _testStatus += '• Audio playback test completed\n';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testStatus += '• Audio error: $e\n';
          _testStatus += '• This is likely due to browser restrictions.\n';
          _testStatus += '• Try running on a mobile device or desktop instead.\n';
        });
      }
    }
  }

  void _clearStatus() {
    setState(() {
      _testStatus = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Connection Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_connectionStatus),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isConnecting ? null : _connectToServer,
                      child: _isConnecting ? const CircularProgressIndicator() : const Text('Connect to Server'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API Tests:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _testCompareMelodies,
                      child: const Text('Test Melody Comparison API'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _testAudioPlayback,
                      child: const Text('Test Audio Playback'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _clearStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Clear Status'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Results:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(8.0),
                      width: double.infinity,
                      height: 300,
                      child: SingleChildScrollView(
                        child: Text(_testStatus.isEmpty ? 'No tests run yet' : _testStatus),
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
