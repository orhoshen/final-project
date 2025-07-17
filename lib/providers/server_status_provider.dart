import 'package:flutter/material.dart';

import '../services/server_manager.dart';

class ServerStatusNotifier extends ChangeNotifier {
  final ServerManager _serverManager = ServerManager.instance;
  bool _isServerAvailable = false;
  bool _isLoading = true;

  bool get isServerAvailable => _isServerAvailable;
  bool get isLoading => _isLoading;

  ServerStatusNotifier() {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    _isLoading = true;
    notifyListeners();
    _isServerAvailable = await _serverManager.testConnection();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    await _checkStatus();
  }
}
