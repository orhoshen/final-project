from flask import Blueprint, jsonify, request
from flask_socketio import emit
from typing import Dict, Any

from game.manager import room_manager
from algorithms.melody_matcher import MelodyMatcher

# Initialize melody matcher
melody_matcher = MelodyMatcher()

# Create the routes blueprint
room_routes = Blueprint('room_routes', __name__)

@room_routes.route('/list', methods=['GET'])
def list_rooms():
    """Get list of available rooms"""
    # Cleanup inactive rooms before listing
    room_manager.cleanup_inactive_rooms()
    
    # Get active rooms
    rooms = room_manager.list_active_rooms()
    
    return jsonify({
        'success': True,
        'rooms': rooms
    })

@room_routes.route('/create', methods=['POST'])
def create_room():
    """Create a new room"""
    data = request.get_json()
    
    if not data or 'player_name' not in data:
        return jsonify({
            'success': False,
            'error': 'Missing required fields: player_name'
        }), 400
    
    player_name = data['player_name']
    
    # Create the room
    result = room_manager.create_room(player_name)
    
    return jsonify({
        'success': True,
        'room_id': result['room_id'],
        'player_id': result['player_id'],
        'room_state': result['room_state']
    })

@room_routes.route('/join', methods=['POST'])
def join_room():
    """Join an existing room"""
    data = request.get_json()
    
    if not data or 'room_id' not in data or 'player_name' not in data:
        return jsonify({
            'success': False,
            'error': 'Missing required fields: room_id and player_name'
        }), 400
    
    room_id = data['room_id']
    player_name = data['player_name']
    
    # Try to join the room
    result = room_manager.join_room(room_id, player_name)
    
    if not result:
        return jsonify({
            'success': False,
            'error': 'Room not found or full'
        }), 404
    
    return jsonify({
        'success': True,
        'player_id': result['player_id'],
        'room_state': result['room_state']
    })

@room_routes.route('/status', methods=['GET'])
def room_status():
    """Get room status"""
    room_id = request.args.get('room_id')
    
    if not room_id:
        return jsonify({
            'success': False,
            'error': 'Missing required query parameter: room_id'
        }), 400
    
    # Get the room
    room = room_manager.get_room(room_id)
    
    if not room:
        return jsonify({
            'success': False,
            'error': 'Room not found'
        }), 404
    
    return jsonify({
        'success': True,
        'room_state': room.get_state()
    })

@room_routes.route('/leave', methods=['POST'])
def leave_room():
    """Leave a room"""
    data = request.get_json()
    
    if not data or 'room_id' not in data or 'player_id' not in data:
        return jsonify({
            'success': False,
            'error': 'Missing required fields: room_id and player_id'
        }), 400
    
    room_id = data['room_id']
    player_id = data['player_id']
    
    # Leave the room
    result = room_manager.leave_room(room_id, player_id)
    
    if not result['success']:
        return jsonify({
            'success': False,
            'error': result.get('error', 'Unknown error')
        }), 404
    
    return jsonify({
        'success': True,
        'room_closed': result['room_closed'],
        'room_state': result['room_state']
    })

@room_routes.route('/record-melody', methods=['POST'])
def record_melody():
    """Record a melody for the other player to replay"""
    data = request.get_json()
    
    if not data or 'room_id' not in data or 'player_id' not in data:
        return jsonify({
            'success': False,
            'error': 'Missing required fields: room_id and player_id'
        }), 400
    
    if 'melody' not in data or 'timings' not in data or 'durations' not in data:
        return jsonify({
            'success': False,
            'error': 'Missing melody data: melody, timings, and durations are required'
        }), 400
    
    room_id = data['room_id']
    player_id = data['player_id']
    melody = data['melody']
    timings = data['timings']
    durations = data['durations']
    
    # Get the room
    room = room_manager.get_room(room_id)
    
    if not room:
        return jsonify({
            'success': False,
            'error': 'Room not found'
        }), 404
    
    # Record the melody
    success = room.record_melody(player_id, melody, timings, durations)
    
    if not success:
        return jsonify({
            'success': False,
            'error': 'Failed to record melody. Not your turn or invalid player.'
        }), 400
    
    return jsonify({
        'success': True,
        'turn_complete': True,
        'room_state': room.get_state()
    })

@room_routes.route('/get-challenge', methods=['GET'])
def get_challenge():
    """Get the melody challenge to replay"""
    room_id = request.args.get('room_id')
    player_id = request.args.get('player_id')
    
    if not room_id or not player_id:
        return jsonify({
            'success': False,
            'error': 'Missing required query parameters: room_id and player_id'
        }), 400
    
    # Get the room
    room = room_manager.get_room(room_id)
    
    if not room:
        return jsonify({
            'success': False,
            'error': 'Room not found'
        }), 404
    
    # Get the challenge
    challenge = room.get_challenge(player_id)
    
    if not challenge:
        return jsonify({
            'success': False,
            'error': 'No challenge available or not your turn'
        }), 400
    
    return jsonify({
        'success': True,
        'melody': challenge['melody'],
        'timings': challenge['timings'],
        'durations': challenge['durations'],
        'creator_id': challenge['creator_id']
    })

@room_routes.route('/submit-replay', methods=['POST'])
def submit_replay():
    """Submit a replay attempt and get scored"""
    data = request.get_json()
    
    if not data or 'room_id' not in data or 'player_id' not in data:
        return jsonify({
            'success': False,
            'error': 'Missing required fields: room_id and player_id'
        }), 400
    
    if 'melody' not in data or 'timings' not in data or 'durations' not in data:
        return jsonify({
            'success': False,
            'error': 'Missing melody data: melody, timings, and durations are required'
        }), 400
    
    room_id = data['room_id']
    player_id = data['player_id']
    melody = data['melody']
    timings = data['timings']
    durations = data['durations']
    
    # Get the room
    room = room_manager.get_room(room_id)
    
    if not room:
        return jsonify({
            'success': False,
            'error': 'Room not found'
        }), 404
    
    # Get the challenge melody
    challenge = room.get_challenge(player_id)
    
    if not challenge:
        return jsonify({
            'success': False,
            'error': 'No challenge available or not your turn'
        }), 400
    
    # Compare melodies
    score_result = melody_matcher.compare_melodies(
        challenge['melody'],
        melody,
        timings1=challenge['timings'],
        timings2=timings,
        durations1=challenge['durations'],
        durations2=durations
    )
    
    # Submit the replay attempt
    success, result = room.submit_replay(player_id, melody, timings, durations, score_result)
    
    if not success:
        return jsonify({
            'success': False,
            'error': 'Failed to submit replay. Not your turn or invalid player.'
        }), 400
    
    return jsonify({
        'success': True,
        'score': score_result,
        'turn_complete': True,
        'next_player': result['next_player'],
        'room_state': room.get_state()
    }) 