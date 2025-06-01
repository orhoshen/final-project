import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_room.dart';
import '../services/midi_service.dart';
import '../services/multiplayer_service.dart';
import '../widgets/piano_keyboard.dart';

class MultiplayerRoomScreen extends StatefulWidget {
  const MultiplayerRoomScreen({super.key});

  @override
  State<MultiplayerRoomScreen> createState() => _MultiplayerRoomScreenState();
}

class _MultiplayerRoomScreenState extends State<MultiplayerRoomScreen> {
  final MidiService _midiService = MidiService();

  // Recording data
  List<int> _recordedNotes = [];
  List<int> _recordedTimings = [];
  List<int> _recordedDurations = [];
  int? _recordStartTime;
  Map<int, int> _activeNotes = {};
  bool _isRecording = false;

  // Replaying data
  int? _replayStartTime;
  bool _isReplaying = false;
  List<int> _replayedNotes = [];
  List<int> _replayedTimings = [];
  List<int> _replayedDurations = [];
  Timer? _challengeTimer;

  @override
  void initState() {
    super.initState();
    _midiService.initialize();
  }

  @override
  void dispose() {
    _midiService.dispose();
    _challengeTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordStartTime = DateTime.now().millisecondsSinceEpoch;
      _recordedNotes = [];
      _recordedTimings = [];
      _recordedDurations = [];
      _activeNotes = {};
    });
  }

  void _stopRecording() async {
    setState(() {
      _isRecording = false;
    });

    // Force any active notes to stop
    for (final entry in _activeNotes.entries) {
      _handleNoteUp(entry.key);
    }

    if (_recordedNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes recorded')),
      );
      return;
    }

    // Submit recording to server
    final service = Provider.of<MultiplayerService>(context, listen: false);
    final success = await service.submitRecordedMelody(
      _recordedNotes,
      _recordedTimings,
      _recordedDurations,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit recording')),
      );
    }
  }

  // Start and schedule replay of a challenge melody
  void _startReplay(Melody melody) {
    setState(() {
      _isReplaying = true;
      _replayedNotes = [];
      _replayedTimings = [];
      _replayedDurations = [];
      _replayStartTime = DateTime.now().millisecondsSinceEpoch;
    });

    // Schedule playing of challenge notes (visualization only)
    _challengeTimer?.cancel();
    for (int i = 0; i < melody.notes.length; i++) {
      final timing = melody.timings[i];
      final duration = melody.durations[i];

      // Schedule note start
      _challengeTimer = Timer(Duration(milliseconds: timing), () {
        // This is just visual, no sound for the challenge
        setState(() {
          // Add to highlighted notes for visualization
        });

        // Schedule note end
        Timer(Duration(milliseconds: duration), () {
          setState(() {
            // Remove from highlighted notes
          });
        });
      });
    }
  }

  void _stopReplay() async {
    setState(() {
      _isReplaying = false;
    });
    _challengeTimer?.cancel();

    // Force any active notes to stop
    for (final entry in _activeNotes.entries) {
      _handleNoteUp(entry.key);
    }

    if (_replayedNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes played')),
      );
      return;
    }

    // Submit replay to server for scoring
    final service = Provider.of<MultiplayerService>(context, listen: false);
    final success = await service.submitReplayAttempt(
      _replayedNotes,
      _replayedTimings,
      _replayedDurations,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit replay')),
      );
    }
  }

  void _handleNoteDown(int midiNote) {
    _midiService.playMidiNote(midiNote);

    if (_isRecording) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timing = now - (_recordStartTime ?? now);

      // Record the note
      _activeNotes[midiNote] = now;

      setState(() {
        // Only record note down for new notes (not already playing)
        if (!_recordedNotes.contains(midiNote)) {
          _recordedNotes.add(midiNote);
          _recordedTimings.add(timing);
          // We'll fill in duration when note is released
          _recordedDurations.add(0);
        }
      });
    } else if (_isReplaying) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timing = now - (_replayStartTime ?? now);

      // Record the replay attempt
      _activeNotes[midiNote] = now;

      setState(() {
        _replayedNotes.add(midiNote);
        _replayedTimings.add(timing);
        // We'll fill in duration when note is released
        _replayedDurations.add(0);
      });
    }
  }

  void _handleNoteUp(int midiNote) {
    if (_activeNotes.containsKey(midiNote)) {
      final startTime = _activeNotes[midiNote]!;
      final now = DateTime.now().millisecondsSinceEpoch;
      final duration = now - startTime;

      if (_isRecording) {
        // Find the index of the note in the recorded sequence
        final index = _recordedNotes.lastIndexOf(midiNote);
        if (index >= 0) {
          setState(() {
            _recordedDurations[index] = duration;
          });
        }
      } else if (_isReplaying) {
        // Find the index of the note in the replay sequence
        final index = _replayedNotes.lastIndexOf(midiNote);
        if (index >= 0) {
          setState(() {
            _replayedDurations[index] = duration;
          });
        }
      }

      // Remove from active notes
      _activeNotes.remove(midiNote);
    }
  }

  Widget _buildGameControls(MultiplayerService service) {
    final room = service.currentRoom;

    if (room == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Room information
    final isActivePlayer = service.isActivePlayer;
    final isChallengePlayer = service.isChallengePlayer;

    switch (room.state) {
      case GameState.waiting:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Room ID: ${room.id}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                'Waiting for players (${room.players.length}/2)...',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  final success = await service.leaveRoom();
                  if (success && mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Leave Room'),
              ),
            ],
          ),
        );

      case GameState.recording:
        if (isActivePlayer) {
          return Column(
            children: [
              Text(
                'Round ${room.currentRound} of ${room.totalRounds}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Your turn to record a melody!'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.green,
                ),
                child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
              ),
              const SizedBox(height: 10),
              if (_isRecording) Text('Recording... (${_recordedNotes.length} notes)'),
            ],
          );
        } else {
          return const Column(
            children: [
              Text(
                'Other player is recording a melody...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          );
        }

      case GameState.replaying:
        if (isChallengePlayer) {
          return Column(
            children: [
              Text(
                'Round ${room.currentRound} of ${room.totalRounds}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Your turn to replay the melody!'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isReplaying ? _stopReplay : () => _startReplay(room.currentChallenge!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isReplaying ? Colors.red : Colors.blue,
                ),
                child: Text(_isReplaying ? 'Stop Replay' : 'Start Replay'),
              ),
              const SizedBox(height: 10),
              if (_isReplaying) Text('Replaying... (${_replayedNotes.length} notes)'),
            ],
          );
        } else {
          return const Column(
            children: [
              Text(
                'Other player is replaying your melody...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          );
        }

      case GameState.gameOver:
        // Find the player with highest score
        final players = room.players;
        players.sort((a, b) => b.score.compareTo(a.score));
        final winner = players.first;
        final isWinner = winner.id == service.playerId;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Game Over!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                '${winner.name} wins with ${winner.score} points!',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                isWinner ? 'Congratulations!' : 'Better luck next time!',
                style: TextStyle(
                  fontSize: 16,
                  color: isWinner ? Colors.green : Colors.blue,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  final success = await service.leaveRoom();
                  if (success && mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Back to Lobby'),
              ),
            ],
          ),
        );

      default:
        return const Center(
          child: Text('Unknown game state'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer Game'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Consumer<MultiplayerService>(
        builder: (context, multiplayerService, _) {
          return Column(
            children: [
              // Game controls
              Container(
                padding: const EdgeInsets.all(16.0),
                child: _buildGameControls(multiplayerService),
              ),

              // Players and scores
              if (multiplayerService.currentRoom != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: multiplayerService.currentRoom!.players.map((player) {
                      final isActive = multiplayerService.currentRoom!.activePlayer?.id == player.id;
                      final isChallenge = multiplayerService.currentRoom!.challengePlayer?.id == player.id;

                      return Card(
                        color: isActive
                            ? Colors.green.withValues(alpha: 0.2)
                            : isChallenge
                                ? Colors.blue.withValues(alpha: 0.2)
                                : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                player.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('Score: ${player.score}'),
                              if (isActive) const Text('Recording', style: TextStyle(color: Colors.green)),
                              if (isChallenge) const Text('Replaying', style: TextStyle(color: Colors.blue)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Spacer
              const Spacer(),

              // Piano keyboard
              SizedBox(
                height: 200,
                child: PianoKeyboard(
                  onNotePressed: _handleNoteDown,
                  onNoteReleased: _handleNoteUp,
                  highlightedNote: null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
