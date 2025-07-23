import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import 'server_manager.dart';

/// Enhanced WebSocket service with retry logic and server management integration
class EnhancedWebSocketService extends ChangeNotifier {
  // Private constructor
  EnhancedWebSocketService._();

  // Public factory method for creation
  static Future<EnhancedWebSocketService> create(String serverUrl) async {
    final service = EnhancedWebSocketService._();
    await service._initialize(serverUrl);
    return service;
  }

  socket_io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _roomId = '';
  String _playerId = '';
  String _serverUrl = 'http://localhost:5001';

  // Retry configuration
  int _retryCount = 0;
  final int _maxRetries = 10;
  final int _baseRetryDelay = 1000; // 1 second
  final int _maxRetryDelay = 30000; // 30 seconds
  Timer? _retryTimer;

  // Connection state
  DateTime? _lastConnectAttempt;
  DateTime? _lastSuccessfulConnection;
  String? _lastError;

  // Stream controllers for different event types
  final _roomUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _playerJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _playerLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _turnChangeController = StreamController<Map<String, dynamic>>.broadcast();
  final _newChallengeController = StreamController<Map<String, dynamic>>.broadcast();
  final _scoreUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<Map<String, dynamic>>.broadcast();

  // Expose streams for listeners
  Stream<Map<String, dynamic>> get onRoomUpdate => _roomUpdateController.stream;
  Stream<Map<String, dynamic>> get onPlayerJoined => _playerJoinedController.stream;
  Stream<Map<String, dynamic>> get onPlayerLeft => _playerLeftController.stream;
  Stream<Map<String, dynamic>> get onTurnChange => _turnChangeController.stream;
  Stream<Map<String, dynamic>> get onNewChallenge => _newChallengeController.stream;
  Stream<Map<String, dynamic>> get onScoreUpdate => _scoreUpdateController.stream;
  Stream<Map<String, dynamic>> get onConnected => _connectedController.stream;
  Stream<Map<String, dynamic>> get onError => _errorController.stream;
  Stream<Map<String, dynamic>> get onConnectionState => _connectionStateController.stream;

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get roomId => _roomId;
  String get playerId => _playerId;
  String get serverUrl => _serverUrl;
  int get retryCount => _retryCount;
  DateTime? get lastConnectAttempt => _lastConnectAttempt;
  DateTime? get lastSuccessfulConnection => _lastSuccessfulConnection;
  String? get lastError => _lastError;

  /// Initialize the service
  Future<void> _initialize(String serverUrl) async {
    _setServerUrl(serverUrl);
    await _connectWithRetry();
  }

  /// Set the server URL
  void _setServerUrl(String url) {
    String newUrl = url.trim();
    if (newUrl.isEmpty) {
      _serverUrl = 'http://localhost:5001';
      notifyListeners();
      return;
    }

    // Ensure the URL starts with http or https for Socket.IO client
    if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
      if (newUrl.startsWith('ws://')) {
        newUrl = newUrl.replaceFirst('ws://', 'http://');
      } else if (newUrl.startsWith('wss://')) {
        newUrl = newUrl.replaceFirst('wss://', 'https://');
      } else {
        newUrl = 'http://$newUrl';
      }
    }

    // Clean up URL suffixes
    if (newUrl.endsWith('/socket.io/')) {
      newUrl = newUrl.substring(0, newUrl.length - '/socket.io/'.length);
    }
    if (newUrl.endsWith('/ws')) {
      newUrl = newUrl.substring(0, newUrl.length - '/ws'.length);
    }
    if (newUrl.endsWith('/')) {
      newUrl = newUrl.substring(0, newUrl.length - 1);
    }

    _serverUrl = newUrl;
    debugPrint("Enhanced WebSocket service URL set to: $_serverUrl");
    notifyListeners();
  }

  /// Connect with retry logic
  Future<bool> _connectWithRetry() async {
    if (_isConnecting) return false;

    _isConnecting = true;
    _lastConnectAttempt = DateTime.now();
    _notifyConnectionState();

    try {
      // First ensure server is running
      if (!await ServerManager.instance.testConnection()) {
        _lastError = 'Server is not available.';
        _isConnecting = false;
        _notifyConnectionState();
        return false;
      }

      // Try to connect
      if (await _attemptConnection()) {
        _retryCount = 0;
        _lastSuccessfulConnection = DateTime.now();
        _lastError = null;
        _isConnecting = false;
        _notifyConnectionState();
        return true;
      }

      // If connection failed, schedule retry
      _scheduleRetry();
      return false;
    } catch (e) {
      _lastError = 'Connection attempt failed: $e';
      debugPrint(_lastError);
      _scheduleRetry();
      return false;
    }
  }

  /// Attempt a single connection
  Future<bool> _attemptConnection() async {
    if (_isConnected && _socket != null && _playerId.isNotEmpty) {
      return true;
    }

    final completer = Completer<bool>();
    Timer? timeoutTimer;

    try {
      debugPrint('Attempting to connect to Socket.IO server: $_serverUrl (attempt ${_retryCount + 1})');

      _socket?.dispose();
      _socket = socket_io.io(
        _serverUrl,
        socket_io.OptionBuilder()
            .disableAutoConnect()
            .setTimeout(30000) // Increased to 30 seconds
            .setTransports(['websocket']) // Force websocket transport
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        _playerId = _socket!.id!;
        debugPrint('Socket.IO connected successfully: Player ID $_playerId');

        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }

        _connectedController.add({
          'player_id': _playerId,
          'connected_at': DateTime.now().toIso8601String(),
        });

        notifyListeners();
      });

      _socket!.on('connect_response', (data) {
        debugPrint('Received server connect_response: $data');
      });

      // Set up all event handlers
      _setupEventHandlers();

      _socket!.onDisconnect((_) {
        _isConnected = false;
        _playerId = '';
        debugPrint('Socket.IO disconnected');

        // Auto-reconnect if not manually disconnected
        if (!completer.isCompleted) {
          _scheduleRetry();
        }

        notifyListeners();
      });

      _socket!.onConnectError((data) {
        debugPrint('Socket.IO connect_error: $data');
        _isConnected = false;
        _lastError = 'Connection error: $data';

        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }

        notifyListeners();
      });

      _socket!.onError((error) {
        debugPrint('Socket.IO error: $error');
        _isConnected = false;
        _lastError = 'Socket error: $error';

        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }

        notifyListeners();
      });

      _socket!.connect();

      // Connection timeout (increased for Cloud Run)
      timeoutTimer = Timer(const Duration(seconds: 35), () {
        if (!completer.isCompleted) {
          debugPrint('Socket.IO connection timeout after 35 seconds');
          _lastError = 'Connection timeout - server may be cold starting';
          completer.complete(false);
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize Socket.IO connection: $e');
      _lastError = 'Connection initialization failed: $e';
      timeoutTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    return completer.future;
  }

  /// Set up event handlers for socket events
  void _setupEventHandlers() {
    _socket!.on('room_update', (data) => _handleEvent('room_update', data, _roomUpdateController));
    _socket!.on('player_joined', (data) => _handleEvent('player_joined', data, _playerJoinedController));
    _socket!.on('player_left', (data) => _handleEvent('player_left', data, _playerLeftController));
    _socket!.on('turn_change', (data) => _handleEvent('turn_change', data, _turnChangeController));
    _socket!.on('new_challenge', (data) => _handleEvent('new_challenge', data, _newChallengeController));
    _socket!.on('score_update', (data) => _handleEvent('score_update', data, _scoreUpdateController));
    _socket!.on('error', (data) => _handleEvent('error', data, _errorController));
  }

  /// Schedule a retry with exponential backoff
  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) {
      debugPrint('Max retries reached. Giving up connection attempts.');
      _isConnecting = false;
      _lastError = 'Max retries reached. Connection failed.';
      _notifyConnectionState();
      return;
    }

    // Calculate delay with exponential backoff and jitter
    final delay = min(
      _baseRetryDelay * pow(2, _retryCount).toInt(),
      _maxRetryDelay,
    );

    // Add jitter to prevent thundering herd
    final jitter = (delay * 0.1 * (Random().nextDouble() - 0.5)).toInt();
    final finalDelay = delay + jitter;

    debugPrint('Scheduling retry ${_retryCount + 1} in ${finalDelay}ms');

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: finalDelay), () {
      _retryCount++;
      _connectWithRetry();
    });
  }

  /// Handle incoming events
  void _handleEvent(String eventName, dynamic data, StreamController<Map<String, dynamic>> controller) {
    // Enhanced logging for debugging
    debugPrint('🔌 WebSocket Event Received: $eventName');
    debugPrint('🔌 Event Data: $data');
    debugPrint('🔌 Player ID: $_playerId, Room ID: $_roomId');

    if (data is Map<String, dynamic>) {
      debugPrint('🔌 Processing Map data for $eventName');
      controller.add(data);
    } else if (data is String) {
      try {
        final Map<String, dynamic> parsedData = jsonDecode(data);
        debugPrint('🔌 Parsed JSON for $eventName: $parsedData');
        controller.add(parsedData);
      } catch (e) {
        debugPrint('Error decoding JSON for event $eventName: $e. Data: $data');
        _errorController.add({'message': 'Invalid data format for event $eventName'});
      }
    } else {
      debugPrint('Received non-map/non-string data for event $eventName: $data');
      _errorController.add({'message': 'Unknown data format for event $eventName'});
    }
  }

  /// Notify connection state changes
  void _notifyConnectionState() {
    _connectionStateController.add({
      'isConnected': _isConnected,
      'isConnecting': _isConnecting,
      'retryCount': _retryCount,
      'lastError': _lastError,
      'lastConnectAttempt': _lastConnectAttempt?.toIso8601String(),
      'lastSuccessfulConnection': _lastSuccessfulConnection?.toIso8601String(),
    });
  }

  /// Manually trigger reconnection
  Future<bool> reconnect() async {
    await disconnect();
    _retryCount = 0;
    return await _connectWithRetry();
  }

  /// Disconnect from the Socket.IO server
  Future<void> disconnect() async {
    _retryTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    _playerId = '';
    _roomId = '';
    debugPrint('Socket.IO explicitly disconnected by client.');
    notifyListeners();
  }

  /// Emit events (helper method)
  void _emit(String event, Map<String, dynamic> data) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
    } else {
      debugPrint('Socket not connected. Cannot emit event: $event');
    }
  }

  // Game-specific methods
  Future<bool> createRoom(String playerName) async {
    if (!_isConnected) {
      debugPrint('Cannot create room: Not connected to server.');
      return false;
    }

    try {
      debugPrint('Creating room for player: $playerName');
      // Use HTTP API to create room
      final result = await ServerManager.instance.createRoom(playerName);
      debugPrint('Create room response: $result');

      if (result['success'] == true) {
        _roomId = result['room_id'] ?? '';
        _playerId = result['player_id'] ?? '';

        debugPrint('Room created successfully: $_roomId, Player ID: $_playerId');

        // Add delay to prevent server-side race condition between HTTP API and WebSocket
        debugPrint('Waiting 500ms for server synchronization...');
        await Future.delayed(const Duration(milliseconds: 500));

        // Join the Socket.IO room for real-time events
        _emit('join_room', {
          'room_id': _roomId,
          'player_id': _playerId,
        });

        debugPrint('Emitted join_room event for real-time updates');
        return true;
      } else {
        debugPrint('Failed to create room: ${result['error']}');
        return false;
      }
    } catch (e) {
      debugPrint('Exception creating room: $e');
      return false;
    }
  }

  Future<bool> joinRoom(String roomId, String playerName) async {
    if (!_isConnected) {
      debugPrint('Cannot join room: Not connected to server.');
      return false;
    }

    try {
      debugPrint('Joining room: $roomId with player: $playerName');
      // Use HTTP API to join room
      final result = await ServerManager.instance.joinRoom(roomId, playerName);
      debugPrint('Join room response: $result');

      if (!result.containsKey('success')) {
        debugPrint('Error: Server response missing "success" field');
        return false;
      }

      if (result['success'] == true) {
        // Validate required fields
        if (!result.containsKey('player_id')) {
          debugPrint('Error: Server response missing "player_id" field');
          return false;
        }

        final playerId = result['player_id'];
        if (playerId == null || playerId.toString().isEmpty) {
          debugPrint('Error: Server returned null or empty player_id');
          return false;
        }

        _roomId = roomId;
        _playerId = playerId.toString();

        debugPrint('Room joined successfully: $_roomId, Player ID: $_playerId');

        // Add delay to prevent server-side race condition between HTTP API and WebSocket
        debugPrint('Waiting 500ms for server synchronization...');
        await Future.delayed(const Duration(milliseconds: 500));

        // Join the Socket.IO room for real-time events
        _emit('join_room', {
          'room_id': _roomId,
          'player_id': _playerId,
        });

        debugPrint('Emitted join_room event for real-time updates');
        notifyListeners();
        return true;
      } else {
        final errorMsg = result['error'] ?? 'Unknown error';
        debugPrint('Failed to join room: $errorMsg');
        return false;
      }
    } catch (e) {
      debugPrint('Exception joining room: $e');
      return false;
    }
  }

  Future<bool> leaveRoom() async {
    if (!_isConnected || _roomId.isEmpty || _playerId.isEmpty) {
      debugPrint('Cannot leave room: Not connected, no room ID, or no player ID.');
      return false;
    }
    _emit('leave_room', {
      'room_id': _roomId,
      'player_id': _playerId,
    });
    _roomId = '';
    notifyListeners();
    return true;
  }

  Future<bool> submitMelody(List<int> notes, List<int> timings, List<int> durations) async {
    if (!_isConnected || _roomId.isEmpty || _playerId.isEmpty) {
      debugPrint('Cannot submit melody: Not connected, no room ID, or no player ID.');
      return false;
    }

    try {
      // Use HTTP API to record melody
      final result = await ServerManager.instance.recordMelody(_roomId, _playerId, notes, timings, durations);

      if (result['success'] == true) {
        // Notify other players via WebSocket
        _emit('melody_recorded', {
          'room_id': _roomId,
        });

        debugPrint('Melody recorded successfully');
        return true;
      } else {
        debugPrint('Failed to record melody: ${result['error']}');
        return false;
      }
    } catch (e) {
      debugPrint('Failed to record melody: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> submitReplay(List<int> notes, List<int> timings, List<int> durations) async {
    if (!_isConnected || _roomId.isEmpty || _playerId.isEmpty) {
      debugPrint('Cannot submit replay: Not connected, no room ID, or no player ID.');
      return {'success': false, 'error': 'Not connected or missing room/player info'};
    }

    try {
      debugPrint('🎯 Submitting replay with Room ID: $_roomId, Player ID: $_playerId');
      debugPrint('🎯 Notes: $notes');
      debugPrint(
          '🎯 Is connected: $_isConnected, Room ID empty: ${_roomId.isEmpty}, Player ID empty: ${_playerId.isEmpty}');

      // Use HTTP API to submit replay
      final result = await ServerManager.instance.submitReplay(_roomId, _playerId, notes, timings, durations);

      if (result['success'] == true) {
        // Notify other players via WebSocket
        _emit('replay_submitted', {
          'room_id': _roomId,
          'score': result['score'],
        });

        debugPrint('Replay submitted successfully with score: ${result['score']['final_score']}');
        return result; // Return the full result including score
      } else {
        debugPrint('Failed to submit replay: ${result['error']}');
        debugPrint('Full server response: $result');
        debugPrint('Room ID: $_roomId, Player ID: $_playerId');
        debugPrint('Notes: $notes, Timings: $timings, Durations: $durations');
        return result; // Return the error result
      }
    } catch (e) {
      debugPrint('Failed to submit replay: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _roomUpdateController.close();
    _playerJoinedController.close();
    _playerLeftController.close();
    _turnChangeController.close();
    _newChallengeController.close();
    _scoreUpdateController.close();
    _connectedController.close();
    _errorController.close();
    _connectionStateController.close();
    _socket?.dispose();
    super.dispose();
  }
}
