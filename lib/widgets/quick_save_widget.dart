import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firebase_game_service.dart';

/// Widget for quick save/load game functionality
class QuickSaveWidget extends StatefulWidget {
  final Map<String, dynamic>? gameState;
  final VoidCallback? onLoad;
  final VoidCallback? onSave;

  const QuickSaveWidget({
    super.key,
    this.gameState,
    this.onLoad,
    this.onSave,
  });

  @override
  State<QuickSaveWidget> createState() => _QuickSaveWidgetState();
}

class _QuickSaveWidgetState extends State<QuickSaveWidget> {
  bool _isLoading = false;
  bool _isSaving = false;
  String? _lastSaveMessage;

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseGameService>(
      builder: (context, firebaseService, child) {
        if (!firebaseService.isInitialized) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      firebaseService.isConnected 
                          ? Icons.cloud_done 
                          : Icons.cloud_off,
                      color: firebaseService.isConnected 
                          ? Colors.green 
                          : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Save',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_lastSaveMessage != null) ...[
                  Text(
                    _lastSaveMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Save Button
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveGame,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(_isSaving ? 'Saving...' : 'Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 8,
                        ),
                      ),
                    ),
                    // Load Button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadGame,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download, size: 16),
                      label: Text(_isLoading ? 'Loading...' : 'Load'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveGame() async {
    if (widget.gameState == null) return;

    setState(() {
      _isSaving = true;
      _lastSaveMessage = null;
    });

    try {
      await FirebaseGameService.instance.quickSaveGameState(widget.gameState!);
      
      setState(() {
        _lastSaveMessage = 'Game saved successfully!';
      });
      
      widget.onSave?.call();
      
      // Clear message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _lastSaveMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _lastSaveMessage = 'Save failed: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _loadGame() async {
    setState(() {
      _isLoading = true;
      _lastSaveMessage = null;
    });

    try {
      final gameState = await FirebaseGameService.instance.quickLoadGameState();
      
      if (gameState != null) {
        setState(() {
          _lastSaveMessage = 'Game loaded successfully!';
        });
        
        widget.onLoad?.call();
        
        // Show load success dialog
        if (mounted) {
          _showLoadSuccessDialog(gameState);
        }
      } else {
        setState(() {
          _lastSaveMessage = 'No saved game found';
        });
      }
      
      // Clear message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _lastSaveMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _lastSaveMessage = 'Load failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLoadSuccessDialog(Map<String, dynamic> gameState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Loaded'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your saved game has been loaded successfully!'),
            const SizedBox(height: 16),
            if (gameState.containsKey('localSave')) ...[
              const Text('Loaded from local storage'),
            ] else ...[
              const Text('Loaded from cloud storage'),
              const SizedBox(height: 8),
              Text(
                'Saved data preview:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatGameStatePreview(gameState),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatGameStatePreview(Map<String, dynamic> gameState) {
    final buffer = StringBuffer();
    int count = 0;
    
    for (final entry in gameState.entries) {
      if (count >= 5) {
        buffer.writeln('...');
        break;
      }
      buffer.writeln('${entry.key}: ${entry.value}');
      count++;
    }
    
    return buffer.toString();
  }
}

/// Simple compact version for app bars
class QuickSaveIndicator extends StatelessWidget {
  const QuickSaveIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseGameService>(
      builder: (context, firebaseService, child) {
        if (!firebaseService.isInitialized) {
          return const SizedBox.shrink();
        }

        return Tooltip(
          message: firebaseService.isConnected
              ? 'Cloud save available'
              : 'Offline mode - local save only',
          child: Icon(
            firebaseService.isConnected 
                ? Icons.cloud_done 
                : Icons.cloud_off,
            color: firebaseService.isConnected 
                ? Colors.green 
                : Colors.orange,
            size: 20,
          ),
        );
      },
    );
  }
}

/// Game statistics widget
class GameStatsWidget extends StatelessWidget {
  const GameStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseGameService>(
      builder: (context, firebaseService, child) {
        final user = firebaseService.currentUser;
        
        if (user == null) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatRow(context, 'Games Played', user.totalGamesPlayed.toString()),
                _buildStatRow(context, 'Total Score', user.totalScore.toString()),
                _buildStatRow(context, 'High Score', user.highScore.toString()),
                _buildStatRow(context, 'Last Active', _formatDate(user.lastActiveAt)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}