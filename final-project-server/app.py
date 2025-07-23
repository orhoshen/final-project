from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from flask_socketio import SocketIO
from dotenv import load_dotenv
import os
import threading
import time
from algorithms.melody_matcher import MelodyMatcher

# Import our modules
from api.room_routes import room_routes

# Load environment variables
load_dotenv()

# Initialize Flask app with static folder
app = Flask(__name__, static_folder='static', static_url_path='/static')

# Enable CORS with specific settings
CORS(app, resources={r"/*": {
    "origins": "*",
    "methods": ["GET", "POST", "OPTIONS"],
    "allow_headers": ["Content-Type"]
}})

# The flask_cors extension handles this automatically.
# This middleware is redundant and causes the double header issue.
# @app.after_request
# def add_cors_headers(response):
#     response.headers.add('Access-Control-Allow-Origin', '*')
#     response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
#     response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
#     return response

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-here')

# Initialize melody matcher
melody_matcher = MelodyMatcher()

# Initialize SocketIO with the app - configure for CORS
socketio = SocketIO(app, cors_allowed_origins="*")

# Import and register WebSocket events after socketio is created
from websocket_handlers.events import register_socketio_events
register_socketio_events(socketio)

# Register blueprint for room routes
app.register_blueprint(room_routes, url_prefix='/api/room')

@app.route('/')
def home():
    return jsonify({
        'message': 'Welcome to the Piano Game Server!',
        'status': 'running'
    })

# The flask_cors extension handles OPTIONS preflight requests automatically.
# This route is redundant.
# @app.route('/<path:path>', methods=['OPTIONS'])
# def handle_options(path):
#     response = app.make_default_options_response()
#     response.headers.add('Access-Control-Allow-Origin', '*')
#     response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
#     response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
#     return response

@app.route('/static/<path:filename>')
def static_files(filename):
    return send_from_directory(app.static_folder, filename)

@app.route('/api/health')
def health_check():
    try:
        # Test melody matcher is working
        test_result = melody_matcher.dtw_distance([60, 62], [60, 62], [0, 500], [0, 500])
        return jsonify({
            'status': 'healthy',
            'service': 'piano-game-server',
            'version': '1.0.0',
            'timestamp': int(time.time()),
            'melody_matcher': 'working',
            'socketio': 'enabled'
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'service': 'piano-game-server',
            'version': '1.0.0',
            'timestamp': int(time.time()),
            'error': str(e)
        }), 500

@app.route('/api/compare-melodies', methods=['POST'])
def compare_melodies():
    try:
        data = request.get_json()
        
        if not data or 'melody1' not in data or 'melody2' not in data:
            return jsonify({
                'error': 'Missing required fields: melody1 and melody2'
            }), 400

        melody1 = data['melody1']  # Target melody
        melody2 = data['melody2']  # Played melody
        
        # Optional timing and duration data
        timings1 = data.get('timings1')  # Target note onset times
        timings2 = data.get('timings2')  # Played note onset times
        durations1 = data.get('durations1')  # Target note durations
        durations2 = data.get('durations2')  # Played note durations

        # Validate input
        if not isinstance(melody1, list) or not isinstance(melody2, list):
            return jsonify({
                'error': 'Melodies must be lists of integers'
            }), 400
            
        # Validate timing data if provided
        if timings1 and not isinstance(timings1, list):
            return jsonify({'error': 'timings1 must be a list of numbers'}), 400
        if timings2 and not isinstance(timings2, list):
            return jsonify({'error': 'timings2 must be a list of numbers'}), 400
            
        # Validate duration data if provided
        if durations1 and not isinstance(durations1, list):
            return jsonify({'error': 'durations1 must be a list of numbers'}), 400
        if durations2 and not isinstance(durations2, list):
            return jsonify({'error': 'durations2 must be a list of numbers'}), 400
            
        # Validate lengths
        if timings1 and len(timings1) != len(melody1):
            return jsonify({'error': 'timings1 must have the same length as melody1'}), 400
        if timings2 and len(timings2) != len(melody2):
            return jsonify({'error': 'timings2 must have the same length as melody2'}), 400
        if durations1 and len(durations1) != len(melody1):
            return jsonify({'error': 'durations1 must have the same length as melody1'}), 400
        if durations2 and len(durations2) != len(melody2):
            return jsonify({'error': 'durations2 must have the same length as melody2'}), 400

        # Compare melodies with all available data
        result = melody_matcher.compare_melodies(
            melody1, 
            melody2,
            timings1=timings1,
            timings2=timings2,
            durations1=durations1,
            durations2=durations2
        )
        
        return jsonify({
            'success': True,
            'result': result
        })

    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

@app.route('/api/estimate-difficulty', methods=['POST'])
def estimate_difficulty():
    try:
        data = request.get_json()
        
        if not data or 'melody' not in data:
            return jsonify({
                'error': 'Missing required field: melody'
            }), 400

        melody = data['melody']
        
        # Validate input
        if not isinstance(melody, list):
            return jsonify({
                'error': 'Melody must be a list of integers'
            }), 400
            
        # Validate that all notes are integers
        for note in melody:
            if not isinstance(note, (int, float)):
                return jsonify({
                    'error': 'All notes in melody must be numbers'
                }), 400

        # Convert to integers if they're floats
        melody = [int(note) for note in melody]
        
        # Get difficulty estimate
        result = melody_matcher.get_difficulty_estimate(melody)
        
        return jsonify({
            'success': True,
            'result': result
        })

    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

# Background task for cleaning up inactive rooms
def cleanup_task():
    """Background task to clean up inactive rooms"""
    from game.manager import room_manager
    
    while True:
        # Sleep for 60 seconds
        time.sleep(60)
        
        # Cleanup inactive rooms
        room_manager.cleanup_inactive_rooms()

# Create a WSGI application for production deployment
def create_app():
    """Create and configure the Flask-SocketIO application for WSGI deployment"""
    # Start the cleanup background task
    cleanup_thread = threading.Thread(target=cleanup_task)
    cleanup_thread.daemon = True
    cleanup_thread.start()
    
    return app

# For gunicorn deployment - ensure SocketIO is properly initialized
# Start the cleanup background task for production
cleanup_thread = threading.Thread(target=cleanup_task)
cleanup_thread.daemon = True
cleanup_thread.start()

# Export the Flask app (not socketio) as the WSGI application
# The socketio instance wraps the Flask app and handles both HTTP and WebSocket
application = app

if __name__ == '__main__':
    # Run the server with SocketIO for local development
    port = int(os.getenv('PORT', 5001))
    
    # Enable CORS for WebSocket connections
    socketio.run(app, 
                host='0.0.0.0', 
                port=port, 
                debug=True,
                allow_unsafe_werkzeug=True)  # Remove cors_allowed_origins parameter 