import time
import string
import random
from typing import Dict, List, Optional, Any, Tuple

class Room:
    """Room class for managing multiplayer piano games"""
    
    def __init__(self, room_id: str, creator_id: str, creator_name: str):
        """Initialize a new room with creator as the first player"""
        self.room_id = room_id
        self.players = {creator_id: {"name": creator_name, "score": 0}}
        self.current_turn = creator_id  # Creator starts
        self.challenge_melody = None    # The melody to be replayed
        self.turn_count = 0
        self.last_activity = time.time()
        self.active = True
        
    def add_player(self, player_id: str, player_name: str) -> bool:
        """Add a new player to the room"""
        # Only allow two players max
        if len(self.players) >= 2:
            return False
            
        self.players[player_id] = {"name": player_name, "score": 0}
        self.last_activity = time.time()
        return True
        
    def remove_player(self, player_id: str) -> bool:
        """Remove a player from the room"""
        if player_id in self.players:
            del self.players[player_id]
            self.last_activity = time.time()
            
            # If room is empty, mark as inactive
            if len(self.players) == 0:
                self.active = False
            
            # If it was this player's turn, switch turns
            if self.current_turn == player_id and len(self.players) > 0:
                self.current_turn = next(iter(self.players.keys()))
                
            return True
        return False
        
    def record_melody(self, player_id: str, melody: List[int], 
                     timings: List[float], durations: List[float]) -> bool:
        """Record a melody challenge from a player"""
        if player_id not in self.players or player_id != self.current_turn:
            return False
            
        self.challenge_melody = {
            "creator_id": player_id,
            "melody": melody,
            "timings": timings,
            "durations": durations
        }
        
        # Switch turn to the other player
        self._switch_turn()
        self.last_activity = time.time()
        return True
        
    def get_challenge(self, player_id: str) -> Optional[Dict[str, Any]]:
        """Get the current melody challenge for a player to replay"""
        if not self.challenge_melody or player_id != self.current_turn:
            return None
            
        return self.challenge_melody
        
    def submit_replay(self, player_id: str, melody: List[int], 
                     timings: List[float], durations: List[float], 
                     score_result: Dict[str, Any]) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """Submit a replay attempt and update player's score"""
        if not self.challenge_melody or player_id != self.current_turn:
            return False, None
            
        # Update player's score
        if 'final_score' in score_result:
            self.players[player_id]["score"] += score_result['final_score']
            
        # Increment turn count
        self.turn_count += 1
        
        # Switch turns
        self._switch_turn()
        
        # Clear challenge melody for next round
        challenge_creator = self.challenge_melody["creator_id"]
        self.challenge_melody = None
        
        self.last_activity = time.time()
        
        return True, {
            "score": score_result,
            "turn_complete": True,
            "next_player": self.current_turn,
            "turn_count": self.turn_count
        }
        
    def _switch_turn(self) -> None:
        """Switch the current turn to the other player"""
        if len(self.players) <= 1:
            return
            
        # Find the other player
        for player_id in self.players:
            if player_id != self.current_turn:
                self.current_turn = player_id
                break
                
    def is_inactive(self, timeout_seconds: int = 300) -> bool:
        """Check if room is inactive for specified timeout (default 5 minutes)"""
        return time.time() - self.last_activity > timeout_seconds
        
    def get_state(self) -> Dict[str, Any]:
        """Get the current state of the room for clients"""
        player_list = []
        for player_id, player_data in self.players.items():
            player_list.append({
                "id": player_id,
                "name": player_data["name"],
                "score": player_data["score"]
            })
            
        return {
            "room_id": self.room_id,
            "active": self.active,
            "players": player_list,
            "current_turn": self.current_turn,
            "has_challenge": self.challenge_melody is not None,
            "turn_count": self.turn_count,
            "last_activity": int(self.last_activity)
        }


def generate_room_id(length: int = 6) -> str:
    """Generate a random room ID with specified length"""
    chars = string.ascii_uppercase + string.digits
    return ''.join(random.choice(chars) for _ in range(length)) 