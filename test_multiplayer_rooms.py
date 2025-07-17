#!/usr/bin/env python3
"""
Multiplayer room functionality test for Piano Game Server
"""
import asyncio
import socketio
import requests
import json
import time
import uuid
from datetime import datetime

SERVER_URL = "https://finalproj-piano-game.uc.r.appspot.com"

class MultiplayerTester:
    def __init__(self):
        self.test_results = []
        self.room_id = None
        self.player1_id = None
        self.player2_id = None
        
    def log_result(self, test_name, success, message=""):
        """Log test result"""
        status = "✅ PASS" if success else "❌ FAIL"
        result = f"{test_name}: {status}"
        if message:
            result += f" - {message}"
        print(result)
        self.test_results.append((test_name, success, message))
        
    async def test_room_creation(self):
        """Test room creation via HTTP API"""
        try:
            # Create a room
            data = {
                "player_name": "TestPlayer1"
            }
            
            response = requests.post(f"{SERVER_URL}/api/room/create", json=data)
            
            if response.status_code == 200:
                result = response.json()
                self.room_id = result.get('room_id')
                self.player1_id = result.get('player_id')
                
                self.log_result("Room Creation", True, f"Room {self.room_id} created")
                return True
            else:
                self.log_result("Room Creation", False, f"HTTP {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            self.log_result("Room Creation", False, f"Error: {str(e)}")
            return False
            
    async def test_room_joining(self):
        """Test joining a room"""
        if not self.room_id:
            self.log_result("Room Joining", False, "No room to join")
            return False
            
        try:
            # Join the room
            data = {
                "room_id": self.room_id,
                "player_name": "TestPlayer2"
            }
            
            response = requests.post(f"{SERVER_URL}/api/room/join", json=data)
            
            if response.status_code == 200:
                result = response.json()
                self.player2_id = result.get('player_id')
                
                self.log_result("Room Joining", True, f"Player {self.player2_id} joined")
                return True
            else:
                self.log_result("Room Joining", False, f"HTTP {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            self.log_result("Room Joining", False, f"Error: {str(e)}")
            return False
            
    async def test_room_status(self):
        """Test room status retrieval"""
        if not self.room_id:
            self.log_result("Room Status", False, "No room to check")
            return False
            
        try:
            params = {
                "room_id": self.room_id,
                "player_id": self.player1_id
            }
            
            response = requests.get(f"{SERVER_URL}/api/room/status", params=params)
            
            if response.status_code == 200:
                result = response.json()
                room_data = result.get('room', {})
                player_count = len(room_data.get('players', {}))
                
                self.log_result("Room Status", True, f"Room has {player_count} players")
                return True
            else:
                self.log_result("Room Status", False, f"HTTP {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            self.log_result("Room Status", False, f"Error: {str(e)}")
            return False
            
    async def test_socketio_room_events(self):
        """Test Socket.IO room events"""
        if not self.room_id or not self.player1_id:
            self.log_result("Socket.IO Room Events", False, "No room or player ID")
            return False
            
        try:
            # Create Socket.IO client
            sio = socketio.AsyncClient()
            events_received = []
            
            @sio.event
            async def connect():
                print("Socket.IO connected for room events test")
                
            @sio.event
            async def room_update(data):
                print(f"Room update received: {data}")
                events_received.append(('room_update', data))
                
            @sio.event
            async def player_joined(data):
                print(f"Player joined event: {data}")
                events_received.append(('player_joined', data))
                
            @sio.event
            async def player_left(data):
                print(f"Player left event: {data}")
                events_received.append(('player_left', data))
                
            # Connect to server
            await sio.connect(SERVER_URL)
            
            # Join the room for events
            await sio.emit('join_room', {
                'room_id': self.room_id,
                'player_id': self.player1_id
            })
            
            # Wait for events
            await asyncio.sleep(3)
            
            # Disconnect
            await sio.disconnect()
            
            if events_received:
                self.log_result("Socket.IO Room Events", True, f"Received {len(events_received)} events")
                return True
            else:
                self.log_result("Socket.IO Room Events", True, "Connected but no events (expected)")
                return True
                
        except Exception as e:
            self.log_result("Socket.IO Room Events", False, f"Error: {str(e)}")
            return False
            
    async def test_melody_recording(self):
        """Test melody recording functionality"""
        if not self.room_id or not self.player1_id:
            self.log_result("Melody Recording", False, "No room or player ID")
            return False
            
        try:
            # Record a melody
            data = {
                "room_id": self.room_id,
                "player_id": self.player1_id,
                "melody": [60, 62, 64, 65, 67],
                "timings": [0, 500, 1000, 1500, 2000],
                "durations": [450, 450, 450, 450, 450]
            }
            
            response = requests.post(f"{SERVER_URL}/api/room/record-melody", json=data)
            
            if response.status_code == 200:
                result = response.json()
                self.log_result("Melody Recording", True, "Melody recorded successfully")
                return True
            else:
                self.log_result("Melody Recording", False, f"HTTP {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            self.log_result("Melody Recording", False, f"Error: {str(e)}")
            return False
            
    async def test_melody_challenge(self):
        """Test getting melody challenge"""
        if not self.room_id or not self.player2_id:
            self.log_result("Melody Challenge", False, "No room or player2 ID")
            return False
            
        try:
            params = {
                "room_id": self.room_id,
                "player_id": self.player2_id
            }
            
            response = requests.get(f"{SERVER_URL}/api/room/get-challenge", params=params)
            
            if response.status_code == 200:
                result = response.json()
                challenge = result.get('challenge')
                if challenge:
                    self.log_result("Melody Challenge", True, f"Challenge received with {len(challenge.get('melody', []))} notes")
                    return True
                else:
                    self.log_result("Melody Challenge", False, "No challenge available")
                    return False
            else:
                self.log_result("Melody Challenge", False, f"HTTP {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            self.log_result("Melody Challenge", False, f"Error: {str(e)}")
            return False
            
    async def test_replay_submission(self):
        """Test melody replay submission"""
        if not self.room_id or not self.player2_id:
            self.log_result("Replay Submission", False, "No room or player2 ID")
            return False
            
        try:
            # Submit a replay
            data = {
                "room_id": self.room_id,
                "player_id": self.player2_id,
                "melody": [60, 62, 64, 65, 67],
                "timings": [0, 500, 1000, 1500, 2000],
                "durations": [450, 450, 450, 450, 450]
            }
            
            response = requests.post(f"{SERVER_URL}/api/room/submit-replay", json=data)
            
            if response.status_code == 200:
                result = response.json()
                score = result.get('score', {})
                final_score = score.get('final_score', 0)
                
                self.log_result("Replay Submission", True, f"Score: {final_score:.2f}")
                return True
            else:
                self.log_result("Replay Submission", False, f"HTTP {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            self.log_result("Replay Submission", False, f"Error: {str(e)}")
            return False
            
    async def run_all_tests(self):
        """Run all multiplayer tests"""
        print("Multiplayer Room Testing")
        print("=" * 50)
        print(f"Target server: {SERVER_URL}")
        print(f"Test started at: {datetime.now()}")
        print()
        
        # Test sequence
        tests = [
            ("Room Creation", self.test_room_creation),
            ("Room Joining", self.test_room_joining),
            ("Room Status", self.test_room_status),
            ("Socket.IO Room Events", self.test_socketio_room_events),
            ("Melody Recording", self.test_melody_recording),
            ("Melody Challenge", self.test_melody_challenge),
            ("Replay Submission", self.test_replay_submission),
        ]
        
        for test_name, test_func in tests:
            print(f"Running: {test_name}")
            success = await test_func()
            if not success:
                print(f"⚠️  {test_name} failed - subsequent tests may fail")
            print()
            
        # Summary
        print("=" * 50)
        print("Test Summary:")
        passed = sum(1 for _, success, _ in self.test_results if success)
        total = len(self.test_results)
        
        for test_name, success, message in self.test_results:
            status = "✅ PASS" if success else "❌ FAIL"
            print(f"{test_name}: {status}")
            if message and not success:
                print(f"  Error: {message}")
                
        print(f"\nResults: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 All multiplayer tests passed!")
        else:
            print("⚠️  Some tests failed - check server configuration")
            
        return passed == total

async def main():
    tester = MultiplayerTester()
    success = await tester.run_all_tests()
    return success

if __name__ == "__main__":
    success = asyncio.run(main())
    exit(0 if success else 1)