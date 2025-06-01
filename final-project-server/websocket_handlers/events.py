from flask_socketio import SocketIO, emit, join_room, leave_room
from flask import request
from typing import Dict, Any

from game.manager import room_manager

# Initialize SocketIO instance (will be properly configured in app.py)
socketio = SocketIO()

@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    emit('connect_response', {'status': 'connected'})

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    pass  # We'll handle room leave events separately

@socketio.on('join_room')
def handle_join_room(data):
    """Handle a client joining a room's socket events"""
    if not data or 'room_id' not in data or 'player_id' not in data:
        emit('error', {'message': 'Missing required fields: room_id and player_id'})
        return
    
    room_id = data['room_id']
    player_id = data['player_id']
    
    # Check if room exists
    room = room_manager.get_room(room_id)
    if not room:
        emit('error', {'message': 'Room not found'})
        return
    
    # Check if player is in the room
    if player_id not in room.players:
        emit('error', {'message': 'Player not in room'})
        return
    
    # Join the socket.io room with this ID
    join_room(room_id)
    
    # Notify other players
    emit('player_joined', {
        'player_id': player_id,
        'player_name': room.players[player_id]['name'],
        'room_state': room.get_state()
    }, room=room_id, include_self=False)
    
    # Notify the joining player
    emit('room_update', {'room_state': room.get_state()})

@socketio.on('leave_room')
def handle_leave_room(data):
    """Handle a client leaving a room's socket events"""
    if not data or 'room_id' not in data or 'player_id' not in data:
        emit('error', {'message': 'Missing required fields: room_id and player_id'})
        return
    
    room_id = data['room_id']
    player_id = data['player_id']
    
    # Leave the socket.io room
    leave_room(room_id)
    
    # Check if the room still exists
    room = room_manager.get_room(room_id)
    if room and player_id in room.players:
        player_name = room.players[player_id]['name']
        
        # Notify other players before removing
        emit('player_left', {
            'player_id': player_id,
            'player_name': player_name
        }, room=room_id)
    
    # Actually remove from game room
    result = room_manager.leave_room(room_id, player_id)
    
    if result['success'] and not result['room_closed'] and result['room_state']:
        # Notify players of updated state
        emit('room_update', {'room_state': result['room_state']}, room=room_id)

# Game events
@socketio.on('melody_recorded')
def handle_melody_recorded(data):
    """Notify when a melody has been recorded"""
    if not data or 'room_id' not in data:
        return
    
    room_id = data['room_id']
    
    # Get the room
    room = room_manager.get_room(room_id)
    if not room:
        return
    
    # Notify players in the room
    emit('new_challenge', {
        'room_state': room.get_state(),
        'next_player': room.current_turn
    }, room=room_id)

@socketio.on('replay_submitted')
def handle_replay_submitted(data):
    """Notify when a replay has been submitted"""
    if not data or 'room_id' not in data or 'score' not in data:
        return
    
    room_id = data['room_id']
    score = data['score']
    
    # Get the room
    room = room_manager.get_room(room_id)
    if not room:
        return
    
    # Notify players in the room
    emit('score_update', {
        'score': score,
        'room_state': room.get_state(),
        'next_player': room.current_turn
    }, room=room_id)

@socketio.on('turn_changed')
def handle_turn_changed(data):
    """Notify when the turn changes"""
    if not data or 'room_id' not in data:
        return
    
    room_id = data['room_id']
    
    # Get the room
    room = room_manager.get_room(room_id)
    if not room:
        return
    
    # Notify players in the room
    emit('turn_change', {
        'room_state': room.get_state(),
        'current_player': room.current_turn
    }, room=room_id)

def notify_room_update(room_id: str):
    """Utility function to notify all clients in a room of a state update"""
    room = room_manager.get_room(room_id)
    if room:
        socketio.emit('room_update', {'room_state': room.get_state()}, room=room_id) 