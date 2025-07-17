import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/server_status_provider.dart';

/// A widget that displays the current server connection status.
class ServerStatusWidget extends StatelessWidget {
  const ServerStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume the ServerStatusNotifier to get the current state
    return Consumer<ServerStatusNotifier>(
      builder: (context, serverStatus, child) {
        // Show a loading indicator while checking the status
        if (serverStatus.isLoading) {
          return const _StatusRow(
            icon: Icons.hourglass_empty,
            text: 'Checking Server...',
            color: Colors.orange,
            isloading: true,
          );
        }

        // Show the appropriate status based on availability
        if (serverStatus.isServerAvailable) {
          return _StatusRow(
            icon: Icons.cloud_done,
            text: 'Server Online',
            color: Colors.green,
            onRefresh: () => serverStatus.refreshStatus(),
          );
        } else {
          return _StatusRow(
            icon: Icons.cloud_off,
            text: 'Server Offline',
            color: Colors.red,
            onRefresh: () => serverStatus.refreshStatus(),
          );
        }
      },
    );
  }
}

/// Helper widget to build the status row consistently.
class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onRefresh;
  final bool isloading;

  const _StatusRow({
    required this.icon,
    required this.text,
    required this.color,
    this.onRefresh,
    this.isloading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isloading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            if (onRefresh != null) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh),
                iconSize: 20,
                onPressed: onRefresh,
                tooltip: 'Refresh Status',
              ),
            ]
          ],
        ),
      ),
    );
  }
}
