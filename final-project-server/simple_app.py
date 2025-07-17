from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import os
from algorithms.melody_matcher import MelodyMatcher

# Initialize Flask app with static folder
app = Flask(__name__, static_folder='static', static_url_path='/static')

# Enable CORS with specific settings
CORS(app, resources={r"/*": {
    "origins": "*",
    "methods": ["GET", "POST", "OPTIONS"],
    "allow_headers": ["Content-Type"]
}})

# Initialize SocketIO with the app - configure for CORS
socketio = SocketIO(app, cors_allowed_origins="*")

# CORS is handled by Flask-CORS extension above

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-here')

# Initialize melody matcher
melody_matcher = MelodyMatcher()

@app.route('/')
def home():
    return jsonify({
        'message': 'Welcome to the Piano Game Server!',
        'status': 'running'
    })

# OPTIONS requests are handled by Flask-CORS extension

@app.route('/static/<path:filename>')
def static_files(filename):
    return send_from_directory(app.static_folder, filename)

@app.route('/api/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'version': '1.0.0'
    })

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

# Socket.IO events for basic multiplayer support
@socketio.on('connect')
def handle_connect():
    print('Client connected')
    # Generate a unique player ID using the socket session ID
    player_id = request.sid
    print(f'Assigning player ID: {player_id}')
    # Send the player ID to the client immediately upon connection
    emit('connected', {'player_id': player_id})
    return True

@socketio.on('disconnect')
def handle_disconnect():
    print('Client disconnected')

@socketio.on('player_connected')
def handle_player_connected(data):
    player_id = data.get('player_id', 'unknown')
    print(f'Player connected: {player_id}')
    emit('player_id_assigned', {'player_id': player_id})

@socketio.on('create_room')
def handle_create_room(data):
    player_name = data.get('player_name', 'Unknown Player')
    player_id = data.get('player_id', request.sid)
    
    # Generate a simple room ID
    import uuid
    room_id = str(uuid.uuid4())[:8]
    
    print(f'Player {player_name} ({player_id}) creating room {room_id}')
    
    # For now, just emit a basic room update
    room_data = {
        'id': room_id,
        'players': [{'id': player_id, 'name': player_name, 'score': 0}],
        'state': 'waiting',
        'current_round': 1,
        'total_rounds': 3,
        'active_player': player_id,
        'challenge_player': None,
        'current_challenge': None
    }
    
    emit('room_update', {'room': room_data})

@socketio.on('join_room')
def handle_join_room(data):
    room_id = data.get('room_id', '')
    player_name = data.get('player_name', 'Unknown Player')
    player_id = data.get('player_id', request.sid)
    
    print(f'Player {player_name} ({player_id}) joining room {room_id}')
    
    # For now, just emit a basic room update
    room_data = {
        'id': room_id,
        'players': [
            {'id': 'existing_player', 'name': 'Existing Player', 'score': 0},
            {'id': player_id, 'name': player_name, 'score': 0}
        ],
        'state': 'waiting',
        'current_round': 1,
        'total_rounds': 3,
        'active_player': 'existing_player',
        'challenge_player': player_id,
        'current_challenge': None
    }
    
    emit('room_update', {'room': room_data})

@socketio.on('leave_room')
def handle_leave_room(data):
    room_id = data.get('room_id', '')
    player_id = data.get('player_id', request.sid)
    
    print(f'Player {player_id} leaving room {room_id}')
    
    # Just acknowledge the leave for now
    emit('room_left', {'success': True})

@socketio.on('record_melody')
def handle_record_melody(data):
    room_id = data.get('room_id', '')
    player_id = data.get('player_id', request.sid)
    melody = data.get('melody', {})
    
    print(f'Player {player_id} recorded melody in room {room_id}')
    
    # Emit new challenge to the room
    emit('new_challenge', {'melody': melody})

@socketio.on('submit_replay')
def handle_submit_replay(data):
    room_id = data.get('room_id', '')
    player_id = data.get('player_id', request.sid)
    melody = data.get('melody', {})
    
    print(f'Player {player_id} submitted replay in room {room_id}')
    
    # Calculate a simple score (for testing)
    score = {'final_score': 0.85, 'pitch_accuracy': 0.9}
    
    # Emit score update
    emit('score_update', {'score': score})

if __name__ == '__main__':
    # Run the server with SocketIO
    port = int(os.getenv('PORT', 5001))
    socketio.run(app, host='0.0.0.0', port=port, debug=True, allow_unsafe_werkzeug=True) 