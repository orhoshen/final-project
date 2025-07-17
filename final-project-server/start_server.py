#!/usr/bin/env python3
"""
Simple script to start the Flask server with the correct configuration.
This ensures the server runs on port 5001 with SocketIO support.
"""

import os
import sys
from app import app, socketio

def main():
    # Set the port from environment variable or default to 5001
    port = int(os.getenv('PORT', 5001))
    
    print(f"Starting Piano Game Server on port {port}")
    print("Server will be available at: http://localhost:{port}")
    print("Press CTRL+C to quit")
    
    try:
        # Run the server with SocketIO
        socketio.run(app, 
                    host='0.0.0.0', 
                    port=port, 
                    debug=True,
                    allow_unsafe_werkzeug=True)
    except KeyboardInterrupt:
        print("\nShutting down server...")
        sys.exit(0)

if __name__ == '__main__':
    main()