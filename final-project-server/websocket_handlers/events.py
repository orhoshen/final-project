from flask_socketio import emit, join_room, leave_room
from flask import request
from typing import Dict, Any

from game.manager import room_manager

def register_socketio_events(socketio):
    """Register all WebSocket events with the socketio instance"""
    
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
        
        # Send current room state to joining player
        emit('room_update', room.get_state())

    @socketio.on('leave_room')
    def handle_leave_room(data):
        """Handle a client leaving a room's socket events"""
        if not data or 'room_id' not in data:
            return
        
        room_id = data['room_id']
        leave_room(room_id)

    @socketio.on('melody_recorded')
    def handle_melody_recorded(data):
        """Handle when a player has recorded a melody"""
        if not data or 'room_id' not in data:
            return
        
        room_id = data['room_id']
        room = room_manager.get_room(room_id)
        if not room:
            return
        
        # Notify other players that a new challenge is available
        emit('new_challenge', {
            'room_state': room.get_state(),
            'message': 'New melody challenge available!'
        }, room=room_id, include_self=False)

    @socketio.on('replay_submitted')
    def handle_replay_submitted(data):
        """Handle when a player has submitted a replay"""
        if not data or 'room_id' not in data or 'score' not in data:
            return
        
        room_id = data['room_id']
        score = data['score']
        
        room = room_manager.get_room(room_id)
        if not room:
            return
        
        # Notify all players about the score update
        emit('score_update', {
            'room_state': room.get_state(),
            'score': score,
            'message': f'Score received: {score.get("final_score", 0):.2f}'
        }, room=room_id)

    @socketio.on('turn_changed')
    def handle_turn_changed(data):
        """Handle when the active player changes"""
        if not data or 'room_id' not in data:
            return
        
        room_id = data['room_id']
        room = room_manager.get_room(room_id)
        if not room:
            return
        
        # Notify all players about the turn change
        emit('room_update', room.get_state(), room=room_id)