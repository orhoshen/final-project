import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

/// Service for managing Socket.IO connections with the game server
class WebSocketService extends ChangeNotifier {
  // Private constructor
  WebSocketService._();

  // Public factory method for creation
  static Future<WebSocketService> create(String serverUrl) async {
    final service = WebSocketService._();
    await service._connect(serverUrl);
    return service;
  }

  socket_io.Socket? _socket;
  bool _isConnected = false;
  String _roomId = '';
  String _playerId = ''; // Will be assigned by the server upon connection
  String _serverUrl = 'http://localhost:5001'; // Base URL for Socket.IO

  // Stream controllers for different event types
  final _roomUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _playerJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _playerLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _turnChangeController = StreamController<Map<String, dynamic>>.broadcast();
  final _newChallengeController = StreamController<Map<String, dynamic>>.broadcast();
  final _scoreUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectedController = StreamController<Map<String, dynamic>>.broadcast(); // For 'connected' event
  final _errorController = StreamController<Map<String, dynamic>>.broadcast(); // For generic errors

  // Expose streams for listeners
  Stream<Map<String, dynamic>> get onRoomUpdate => _roomUpdateController.stream;
  Stream<Map<String, dynamic>> get onPlayerJoined => _playerJoinedController.stream;
  Stream<Map<String, dynamic>> get onPlayerLeft => _playerLeftController.stream;
  Stream<Map<String, dynamic>> get onTurnChange => _turnChangeController.stream;
  Stream<Map<String, dynamic>> get onNewChallenge => _newChallengeController.stream;
  Stream<Map<String, dynamic>> get onScoreUpdate => _scoreUpdateController.stream;
  Stream<Map<String, dynamic>> get onConnected => _connectedController.stream;
  Stream<Map<String, dynamic>> get onError => _errorController.stream;

  // Getters
  bool get isConnected => _isConnected;
  String get roomId => _roomId;
  String get playerId => _playerId;

  /// Set the server URL (including port if needed)
  void _setServerUrl(String url) {
    String newUrl = url.trim();
    if (newUrl.isEmpty) {
      // Default to localhost if empty, ensure it's http for Socket.IO
      _serverUrl = 'http://localhost:5001';
      notifyListeners();
      return;
    }

    // Ensure the URL starts with http or https for Socket.IO client
    if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
      // If it starts with ws:// or wss://, try to convert, otherwise prepend http://
      if (newUrl.startsWith('ws://')) {
        newUrl = newUrl.replaceFirst('ws://', 'http://');
      } else if (newUrl.startsWith('wss://')) {
        newUrl = newUrl.replaceFirst('wss://', 'https://');
      } else {
        newUrl = 'http://$newUrl';
      }
    }

    // Remove any /socket.io/ or /ws suffixes as the IO.io() constructor handles this path.
    if (newUrl.endsWith('/socket.io/')) {
      newUrl = newUrl.substring(0, newUrl.length - '/socket.io/'.length);
    }
    if (newUrl.endsWith('/ws')) {
      newUrl = newUrl.substring(0, newUrl.length - '/ws'.length);
    }
    if (newUrl.endsWith('/')) {
      // Remove trailing slash if any
      newUrl = newUrl.substring(0, newUrl.length - 1);
    }

    _serverUrl = newUrl;
    debugPrint("WebSocketService server URL set to: $_serverUrl");
    notifyListeners();
  }

  /// Connect to the Socket.IO server
  Future<bool> _connect(String url) async {
    _setServerUrl(url); // Set the server URL first

    if (_isConnected && _socket != null && _playerId.isNotEmpty) {
      debugPrint('Already connected with player ID.');
      return true;
    }
    if (_socket?.connected == true && _playerId.isEmpty) {
      debugPrint('Socket connected but waiting for player ID...');
      // Already connecting or connected, just need player ID, wait for it via the existing listener
      // Create a completer that waits for the 'connected' event with player_id
      final completer = Completer<bool>();
      StreamSubscription? sub;
      sub = onConnected.listen((data) {
        if (data.containsKey('player_id') && data['player_id'].isNotEmpty) {
          if (!completer.isCompleted) completer.complete(true);
          sub?.cancel();
        }
      });
      // Timeout for safety
      Future.delayed(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          debugPrint('Timeout waiting for player ID after already connected.');
          sub?.cancel();
        }
      });
      return completer.future;
    }

    final completer = Completer<bool>();
    Timer? timeoutTimer;

    try {
      debugPrint('Attempting to connect to Socket.IO server: $_serverUrl');
      _socket = socket_io.io(
          _serverUrl,
          socket_io.OptionBuilder()
              .disableAutoConnect()
              //.setTransports(['websocket']) // Force websocket if issues persist with polling fallback
              .build());

      _socket!.onConnect((_) {
        _isConnected = true;
        // The player ID is the socket's unique session ID
        _playerId = _socket!.id!;
        debugPrint('Socket.IO transport connected: Player ID ${_socket?.id}');

        timeoutTimer?.cancel(); // Cancel the timeout timer
        if (!completer.isCompleted) {
          completer.complete(true);
        }
        notifyListeners();
      });

      _socket!.on('connect_response', (data) {
        // Optional: Can be used to confirm application-level connection
        debugPrint('Received server connect_response: $data');
      });

      _socket!.on('room_update', (data) => _handleEvent('room_update', data, _roomUpdateController));
      _socket!.on('player_joined', (data) => _handleEvent('player_joined', data, _playerJoinedController));
      _socket!.on('player_left', (data) => _handleEvent('player_left', data, _playerLeftController));
      _socket!.on('turn_change', (data) => _handleEvent('turn_change', data, _turnChangeController));
      _socket!.on('new_challenge', (data) => _handleEvent('new_challenge', data, _newChallengeController));
      _socket!.on('score_update', (data) => _handleEvent('score_update', data, _scoreUpdateController));
      _socket!.on('error', (data) => _handleEvent('error', data, _errorController));

      _socket!.onDisconnect((_) {
        _isConnected = false;
        _playerId = '';
        debugPrint('Socket.IO disconnected');
        notifyListeners();
      });

      _socket!.onConnectError((data) {
        debugPrint('Socket.IO connect_error: $data');
        _isConnected = false;
        _errorController.add({'message': data.toString()});
        timeoutTimer?.cancel(); // Cancel the timeout timer
        if (!completer.isCompleted) completer.complete(false);
        notifyListeners();
      });

      _socket!.onError((error) {
        debugPrint('Socket.IO connection error (onError): $error');
        _isConnected = false;
        _errorController.add({'message': error.toString()});
        timeoutTimer?.cancel(); // Cancel the timeout timer
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        notifyListeners();
      });

      _socket!.connect();

      // Timeout for the connection attempt itself
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          debugPrint('Socket.IO connection attempt timed out.');
          completer.complete(false);
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize Socket.IO connection: $e');
      _isConnected = false;
      timeoutTimer?.cancel(); // Cancel the timeout timer
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      notifyListeners();
    }
    return completer.future;
  }

  void _handleEvent(String eventName, dynamic data, StreamController<Map<String, dynamic>> controller) {
    if (data is Map<String, dynamic>) {
      controller.add(data);
    } else if (data is String) {
      try {
        final Map<String, dynamic> parsedData = jsonDecode(data);
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

  /// Disconnect from the Socket.IO server
  Future<void> disconnect() async {
    _socket?.disconnect();
    _isConnected = false;
    _playerId = '';
    _roomId = ''; // Clear room ID on disconnect as well
    debugPrint('Socket.IO explicitly disconnected by client.');
    notifyListeners();
  }

  // Helper to emit events
  void _emit(String event, Map<String, dynamic> data) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
    } else {
      debugPrint('Socket not connected. Cannot emit event: $event');
    }
  }

  Future<bool> createRoom(String playerName) async {
    if (!_isConnected || _playerId.isEmpty) {
      debugPrint('Cannot create room: Not connected or no player ID.');
      return false;
    }
    _emit('create_room', {
      'player_name': playerName,
      'player_id': _playerId,
    });
    // Assuming creation is optimistic or server confirms via 'room_update'
    return true;
  }

  Future<bool> joinRoom(String roomId, String playerName) async {
    if (!_isConnected || _playerId.isEmpty) {
      debugPrint('Cannot join room: Not connected or no player ID.');
      return false;
    }
    _emit('join_room', {
      'room_id': roomId,
      'player_name': playerName,
      'player_id': _playerId,
    });
    _roomId = roomId; // Optimistically set room ID, server will confirm via room_update
    notifyListeners();
    return true;
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
    _emit('record_melody', {
      'room_id': _roomId,
      'player_id': _playerId,
      'melody': {
        'notes': notes,
        'timings': timings,
        'durations': durations,
      }
    });
    return true;
  }

  Future<bool> submitReplay(List<int> notes, List<int> timings, List<int> durations) async {
    if (!_isConnected || _roomId.isEmpty || _playerId.isEmpty) {
      debugPrint('Cannot submit replay: Not connected, no room ID, or no player ID.');
      return false;
    }
    _emit('submit_replay', {
      'room_id': _roomId,
      'player_id': _playerId,
      'melody': {
        'notes': notes,
        'timings': timings,
        'durations': durations,
      }
    });
    return true;
  }

  @override
  void dispose() {
    _roomUpdateController.close();
    _playerJoinedController.close();
    _playerLeftController.close();
    _turnChangeController.close();
    _newChallengeController.close();
    _scoreUpdateController.close();
    _connectedController.close();
    _errorController.close();
    _socket?.dispose();
    super.dispose();
  }
}
