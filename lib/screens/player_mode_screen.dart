import 'package:final_project/providers/server_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/midi_service.dart';
import '../services/server_manager.dart';
import '../services/simple_audio_player.dart';
import '../widgets/analysis_report_widget.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/server_status_widget.dart';

class PlayerModeScreen extends StatefulWidget {
  const PlayerModeScreen({super.key});

  @override
  State<PlayerModeScreen> createState() => _PlayerModeScreenState();
}

class _PlayerModeScreenState extends State<PlayerModeScreen> {
  final MidiService _midiService = MidiService();
  final SimpleAudioPlayer _simpleAudio = SimpleAudioPlayer();

  // Player info
  final TextEditingController _player1NameController = TextEditingController();
  final TextEditingController _player2NameController = TextEditingController();
  String _player1Name = 'Player 1';
  String _player2Name = 'Player 2';

  // Game state
  bool _gameStarted = false;
  int _roundNumber = 1;
  int _player1Score = 0;
  int _player2Score = 0;
  bool _isPlayer1Creator = true; // Player 1 starts as the creator
  bool _isCreatorPhase = true; // Is the current action creating a melody?
  bool _roundOver = false; // Is the round over, waiting for user to continue?
  String _statusMessage = 'Enter player names to begin.';

  // Melody data
  final List<int> _referenceSequence = [];
  final List<int> _attemptSequence = [];
  int? _highlightedNote;
  bool _isPlayingMelody = false;

  // Server and Analytics
  Map<String, dynamic>? _lastComparisonDetails;
  int? _comparisonProcessingTimeMs;
  double? _lastMatchScore;

  // Repeat button functionality
  int _repeatCount = 0;
  static const int _maxRepeats = 2;

  @override
  void initState() {
    super.initState();
    _initServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_gameStarted) {
        _showPlayerRegistration();
      }
    });
  }

  @override
  void dispose() {
    _player1NameController.dispose();
    _player2NameController.dispose();
    super.dispose();
  }

  Future<void> _initServices() async {
    await _midiService.initialize();
    // Server status is now handled by the global provider.
  }

  void _showPlayerRegistration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Player Names'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _player1NameController, decoration: const InputDecoration(labelText: 'Player 1')),
            TextField(controller: _player2NameController, decoration: const InputDecoration(labelText: 'Player 2')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            child: const Text('Start Game'),
          ),
        ],
      ),
    );
  }

  void _startNewGame() {
    setState(() {
      _player1Name = _player1NameController.text.isNotEmpty ? _player1NameController.text : 'Player 1';
      _player2Name = _player2NameController.text.isNotEmpty ? _player2NameController.text : 'Player 2';
      _gameStarted = true;
      _roundNumber = 1;
      _player1Score = 0;
      _player2Score = 0;
      _isPlayer1Creator = true;
      _startNextRound();
    });
  }

  void _startNextRound() {
    if (_roundNumber > 1) {
      _isPlayer1Creator = !_isPlayer1Creator;
    }
    setState(() {
      _isCreatorPhase = true;
      _roundOver = false;
      _referenceSequence.clear();
      _attemptSequence.clear();
      _lastComparisonDetails = null;
      _lastMatchScore = null;
      _repeatCount = 0;
      _updateStatusMessage();
    });
  }

  void _updateStatusMessage() {
    final creatorName = _isPlayer1Creator ? _player1Name : _player2Name;
    final matcherName = _isPlayer1Creator ? _player2Name : _player1Name;
    setState(() {
      if (_roundOver) {
        // Status is set by the match result
        return;
      }
      if (_isCreatorPhase) {
        _statusMessage = '$creatorName: Create a Melody';
      } else if (_isPlayingMelody) {
        _statusMessage = '$matcherName: Listen to the melody...';
      } else {
        _statusMessage = '$matcherName: Your Turn - Match the Melody!';
      }
    });
  }

  void _onNotePressed(int midiNote) {
    if (!_gameStarted || _isPlayingMelody || _roundOver) return;

    _midiService.playMidiNote(midiNote).catchError((e) => _simpleAudio.playPianoNote(midiNote));

    setState(() {
      if (_isCreatorPhase) {
        _referenceSequence.add(midiNote);
      } else {
        _attemptSequence.add(midiNote);
        if (_attemptSequence.length >= _referenceSequence.length) {
          _checkMatch();
        }
      }
      _highlightedNote = midiNote;
    });
  }

  void _onNoteReleased(int midiNote) {
    if (_highlightedNote == midiNote) {
      setState(() => _highlightedNote = null);
    }
  }

  Future<void> _creatorIsDone() async {
    if (_referenceSequence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please create a melody first!')));
      return;
    }
    setState(() {
      _isCreatorPhase = false;
      _isPlayingMelody = true;
      _updateStatusMessage();
    });

    await Future.delayed(const Duration(milliseconds: 500));
    await _playReferenceMelody(isFirstPlayback: true);

    setState(() {
      _isPlayingMelody = false;
      _updateStatusMessage();
    });
  }

  Future<void> _checkMatch() async {
    setState(() {
      _statusMessage = 'Analyzing...';
      _roundOver = true; // End the round, show results
    });

    final startTime = DateTime.now().millisecondsSinceEpoch;
    // Use the provider to get server status and the ServerManager instance
    final serverAvailable = context.read<ServerStatusNotifier>().isServerAvailable;
    final serverManager = ServerManager.instance;

    final result = await (serverAvailable
        ? serverManager.compareMelodies(_referenceSequence, _attemptSequence)
        : serverManager.compareMelodies(_referenceSequence, _attemptSequence));

    final endTime = DateTime.now().millisecondsSinceEpoch;

    double score = 0.0;
    if (result['success'] == true) {
      _lastComparisonDetails = result['result'] as Map<String, dynamic>;
      score = _lastComparisonDetails!['final_score'] as double;
    }

    setState(() {
      _comparisonProcessingTimeMs = endTime - startTime;
      _lastMatchScore = score;
      final creatorName = _isPlayer1Creator ? _player1Name : _player2Name;
      final matcherName = _isPlayer1Creator ? _player2Name : _player1Name;

      if (score > 0.7) {
        _statusMessage = '$matcherName matched the melody!';
        if (_isPlayer1Creator) {
          _player2Score++;
        } else {
          _player1Score++;
        }
      } else {
        _statusMessage = '$creatorName wins the round!';
        if (_isPlayer1Creator) {
          _player1Score++;
        } else {
          _player2Score++;
        }
      }
    });
  }

  Future<void> _playReferenceMelody({bool isFirstPlayback = false}) async {
    if (_referenceSequence.isEmpty) return;
    if (!isFirstPlayback) {
      if (_repeatCount >= _maxRepeats) return;
      _repeatCount++;
    }

    setState(() => _isPlayingMelody = true);

    for (final note in _referenceSequence) {
      if (!mounted) return;
      setState(() => _highlightedNote = note);
      await _midiService.playMidiNote(note);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _highlightedNote = null);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() => _isPlayingMelody = false);
  }

  Color _getColorForScore(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    bool canPressPiano = _gameStarted && !_isPlayingMelody && !_roundOver;
    context.watch<ServerStatusNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player vs Player'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: ServerStatusWidget(),
          ),
        ],
      ),
      body: !_gameStarted
          ? Center(child: Text('Enter player names to start.', style: Theme.of(context).textTheme.headlineSmall))
          : Column(
              children: [
                _buildScoreboard(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(_statusMessage,
                      style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                ),
                if (_lastMatchScore != null && _roundOver)
                  Text(
                    'Match Score: ${(_lastMatchScore! * 100).toStringAsFixed(0)}%',
                    style:
                        TextStyle(color: _getColorForScore(_lastMatchScore), fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: _roundOver
                        ? AnalysisReportWidget(
                            scoreData: _lastComparisonDetails ?? {}, clientRoundTripTime: _comparisonProcessingTimeMs)
                        : const SizedBox(),
                  ),
                ),
                _buildActionButton(),
                SizedBox(
                  height: 200,
                  child: AbsorbPointer(
                    absorbing: !canPressPiano,
                    child: Opacity(
                      opacity: canPressPiano ? 1.0 : 0.5,
                      child: PianoKeyboard(
                        onNotePressed: _onNotePressed,
                        onNoteReleased: _onNoteReleased,
                        highlightedNote: _highlightedNote,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildScoreboard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPlayerScore(_player1Name, _player1Score, _isPlayer1Creator ? _isCreatorPhase : !_isCreatorPhase),
          Text('Round $_roundNumber', style: Theme.of(context).textTheme.headlineMedium),
          _buildPlayerScore(_player2Name, _player2Score, !_isPlayer1Creator ? _isCreatorPhase : !_isCreatorPhase),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(String name, int score, bool isTurn) {
    return Column(
      children: [
        Text(name,
            style: TextStyle(
                fontSize: 20,
                fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
                color: isTurn ? Theme.of(context).colorScheme.primary : Colors.black)),
        Text('Score: $score', style: const TextStyle(fontSize: 18)),
      ],
    );
  }

  Widget _buildActionButton() {
    if (!_gameStarted) return const SizedBox.shrink();

    // Show 'Done' button for the creator
    if (_isCreatorPhase) {
      return ElevatedButton.icon(
        onPressed: _creatorIsDone,
        icon: const Icon(Icons.check),
        label: const Text('Done Creating'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    }

    // Show 'Next Round' button when the round is over
    if (_roundOver) {
      return ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _roundNumber++;
            _startNextRound();
          });
        },
        icon: const Icon(Icons.skip_next),
        label: const Text('Next Round'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    }

    // Show 'Repeat Melody' button for the matcher
    return Opacity(
      opacity: _repeatCount >= _maxRepeats ? 0.5 : 1.0,
      child: ElevatedButton.icon(
        onPressed: _repeatCount >= _maxRepeats ? null : _playReferenceMelody,
        icon: const Icon(Icons.replay),
        label: Text('Repeat Melody (${_maxRepeats - _repeatCount} left)'),
      ),
    );
  }
}
