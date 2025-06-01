import time
import uuid
from typing import Dict, List, Optional, Any
from .room import Room, generate_room_id

class RoomManager:
    """Manager class for handling multiple game rooms"""
    
    def __init__(self, inactive_timeout: int = 300):
        """Initialize the room manager with empty rooms dictionary"""
        self.rooms: Dict[str, Room] = {}
        self.inactive_timeout = inactive_timeout  # 5 minutes by default
        
    def create_room(self, creator_name: str) -> Dict[str, Any]:
        """Create a new room and return room info"""
        # Generate a unique room ID
        room_id = generate_room_id()
        while room_id in self.rooms:
            room_id = generate_room_id()
            
        # Generate a player ID for the creator
        creator_id = str(uuid.uuid4())
        
        # Create the room
        self.rooms[room_id] = Room(room_id, creator_id, creator_name)
        
        return {
            "room_id": room_id,
            "player_id": creator_id,
            "room_state": self.rooms[room_id].get_state()
        }
        
    def join_room(self, room_id: str, player_name: str) -> Optional[Dict[str, Any]]:
        """Join an existing room and return room info"""
        if room_id not in self.rooms:
            return None
            
        room = self.rooms[room_id]
        
        # If room is inactive or full, return None
        if not room.active or len(room.players) >= 2:
            return None
            
        # Generate a player ID for the joiner
        player_id = str(uuid.uuid4())
        
        # Add player to the room
        success = room.add_player(player_id, player_name)
        if not success:
            return None
            
        return {
            "room_id": room_id,
            "player_id": player_id,
            "room_state": room.get_state()
        }
        
    def get_room(self, room_id: str) -> Optional[Room]:
        """Get a room by its ID"""
        return self.rooms.get(room_id)
        
    def leave_room(self, room_id: str, player_id: str) -> Dict[str, Any]:
        """Handle a player leaving a room"""
        if room_id not in self.rooms:
            return {"success": False, "error": "Room not found"}
            
        room = self.rooms[room_id]
        success = room.remove_player(player_id)
        
        # If room is empty or inactive, mark for cleanup
        room_closed = False
        if len(room.players) == 0 or not room.active:
            room.active = False
            room_closed = True
            
        return {
            "success": success,
            "room_closed": room_closed,
            "room_state": room.get_state() if success else None
        }
        
    def list_active_rooms(self) -> List[Dict[str, Any]]:
        """List all active rooms with basic info"""
        active_rooms = []
        for room_id, room in self.rooms.items():
            if room.active:
                active_rooms.append({
                    "room_id": room_id,
                    "player_count": len(room.players),
                    "creator_name": next(iter(room.players.values()))["name"] if room.players else "Unknown"
                })
        return active_rooms
        
    def cleanup_inactive_rooms(self) -> int:
        """Remove inactive rooms and return count of removed rooms"""
        inactive_rooms = []
        
        # Find inactive rooms
        for room_id, room in self.rooms.items():
            if room.is_inactive(self.inactive_timeout) or not room.active:
                inactive_rooms.append(room_id)
                
        # Remove inactive rooms
        for room_id in inactive_rooms:
            del self.rooms[room_id]
            
        return len(inactive_rooms)

# Create a singleton instance
room_manager = RoomManager() 