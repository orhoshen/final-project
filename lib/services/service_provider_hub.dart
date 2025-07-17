import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'enhanced_websocket_service.dart';
import 'multiplayer_service.dart';

class ServiceProviderHub extends StatelessWidget {
  final Widget child;
  
  const ServiceProviderHub({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final serverUrl = dotenv.env['FLASK_SERVER_URL'] ?? 'http://localhost:5001';

    return MultiProvider(
      providers: [
        // Asynchronously create and provide the EnhancedWebSocketService
        FutureProvider<EnhancedWebSocketService?>(
          create: (_) => EnhancedWebSocketService.create(serverUrl),
          initialData: null,
          catchError: (context, error) {
            debugPrint("Failed to create EnhancedWebSocketService: $error");
            return null;
          },
        ),
        // MultiplayerService depends on the result of the FutureProvider
        ChangeNotifierProxyProvider<EnhancedWebSocketService?, MultiplayerService?>(
          create: (context) => null,
          update: (context, wsService, previous) {
            if (wsService == null) return null;
            // Create a new service if one doesn't exist
            if (previous == null) {
              final newService = MultiplayerService(wsService);
              newService.initialize();
              return newService;
            }
            return previous;
          },
        ),
      ],
      // The child is the UI that needs these services.
      child: child,
    );
  }
}
