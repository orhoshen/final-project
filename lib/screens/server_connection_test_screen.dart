import 'package:flutter/material.dart';

import '../services/server_manager.dart';

class ServerConnectionTestScreen extends StatefulWidget {
  const ServerConnectionTestScreen({super.key});

  @override
  State<ServerConnectionTestScreen> createState() => _ServerConnectionTestScreenState();
}

class _ServerConnectionTestScreenState extends State<ServerConnectionTestScreen> {
  String _connectionStatus = 'Press the button to test connection.';
  bool _isConnected = false;
  String _testStatus = '';
  bool _isLoading = false;

  Future<void> _handleTestConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Testing...';
    });

    try {
      final success = await ServerManager.instance.testConnection();
      if (mounted) {
        setState(() {
          _isConnected = success;
          _connectionStatus = success ? 'Connection successful!' : 'Connection failed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Connection failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testCreateRoom() async {
    setState(() {
      _testStatus += '• Testing room creation...\n';
    });
    if (!_isConnected) {
      setState(() {
        _testStatus += '• Cannot create room: Not connected to server.\n';
      });
      return;
    }
    try {
      final result = await ServerManager.instance.createRoom('TestUser');
      setState(() {
        _testStatus += '• Room created successfully: ${result['room_code']}\n';
      });
    } catch (e) {
      setState(() {
        _testStatus += '• Failed to create room: $e\n';
      });
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Connection Status:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connectionStatus,
                      style: TextStyle(color: _isConnected ? Colors.green : Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleTestConnection,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Test Connection'),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'API Tests:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _testCreateRoom,
                      child: const Text('Test Create Room'),
                    ),
                    // Other test buttons can be re-enabled here as needed
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _clearStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Clear Log'),
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
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(8.0),
                      width: double.infinity,
                      height: 200,
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
