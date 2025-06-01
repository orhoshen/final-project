import requests
import socketio
import time
import json
import random
import sys

# Server URL - change this to your actual server URL when deployed
SERVER_URL = "http://localhost:5000"

# Example melodies for testing
EXAMPLE_MELODY_1 = {
    "melody": [60, 62, 64, 65, 67],  # C4, D4, E4, F4, G4
    "timings": [0, 500, 1000, 1500, 2000],  # Start times in ms
    "durations": [400, 400, 400, 400, 600]  # Durations in ms
}

EXAMPLE_MELODY_2 = {
    "melody": [60, 62, 64, 62, 60],  # C4, D4, E4, D4, C4
    "timings": [0, 550, 1050, 1600, 2100],  # Slightly different timings
    "durations": [450, 450, 450, 450, 650]  # Slightly different durations
}

# Test HTTP API endpoints
def test_http_endpoints():
    print("\n--- Testing HTTP API Endpoints ---\n")
    
    # 1. Create a room as Player 1
    print("Creating a room as Player 1...")
    create_response = requests.post(
        f"{SERVER_URL}/api/room/create",
        json={"player_name": "Player One"}
    )
    
    if not create_response.ok:
        print(f"Failed to create room: {create_response.text}")
        return False
    
    create_data = create_response.json()
    room_id = create_data["room_id"]
    player1_id = create_data["player_id"]
    
    print(f"Room created with ID: {room_id}")
    print(f"Player 1 ID: {player1_id}")
    
    # 2. Join the room as Player 2
    print("\nJoining the room as Player 2...")
    join_response = requests.post(
        f"{SERVER_URL}/api/room/join",
        json={
            "room_id": room_id,
            "player_name": "Player Two"
        }
    )
    
    if not join_response.ok:
        print(f"Failed to join room: {join_response.text}")
        return False
    
    join_data = join_response.json()
    player2_id = join_data["player_id"]
    
    print(f"Player 2 joined with ID: {player2_id}")
    
    # 3. Check room status
    print("\nChecking room status...")
    status_response = requests.get(f"{SERVER_URL}/api/room/status?room_id={room_id}")
    
    if not status_response.ok:
        print(f"Failed to get room status: {status_response.text}")
        return False
    
    status_data = status_response.json()
    print(f"Room status: {json.dumps(status_data['room_state'], indent=2)}")
    
    # 4. Player 1 records a melody
    print("\nPlayer 1 recording a melody...")
    record_response = requests.post(
        f"{SERVER_URL}/api/room/record-melody",
        json={
            "room_id": room_id,
            "player_id": player1_id,
            "melody": EXAMPLE_MELODY_1["melody"],
            "timings": EXAMPLE_MELODY_1["timings"],
            "durations": EXAMPLE_MELODY_1["durations"]
        }
    )
    
    if not record_response.ok:
        print(f"Failed to record melody: {record_response.text}")
        return False
    
    print("Melody recorded successfully.")
    
    # 5. Player 2 gets the challenge
    print("\nPlayer 2 getting the challenge...")
    challenge_response = requests.get(
        f"{SERVER_URL}/api/room/get-challenge?room_id={room_id}&player_id={player2_id}"
    )
    
    if not challenge_response.ok:
        print(f"Failed to get challenge: {challenge_response.text}")
        return False
    
    challenge_data = challenge_response.json()
    print("Challenge received successfully.")
    print(f"Melody to replay: {challenge_data['melody']}")
    
    # 6. Player 2 submits a replay attempt
    print("\nPlayer 2 submitting replay attempt...")
    replay_response = requests.post(
        f"{SERVER_URL}/api/room/submit-replay",
        json={
            "room_id": room_id,
            "player_id": player2_id,
            "melody": EXAMPLE_MELODY_2["melody"],
            "timings": EXAMPLE_MELODY_2["timings"],
            "durations": EXAMPLE_MELODY_2["durations"]
        }
    )
    
    if not replay_response.ok:
        print(f"Failed to submit replay: {replay_response.text}")
        return False
    
    replay_data = replay_response.json()
    print("Replay submitted successfully.")
    print(f"Score: {replay_data['score']['final_score']:.2f}")
    print(f"Pitch accuracy: {replay_data['score']['pitch_accuracy']:.2f}")
    if 'timing_accuracy' in replay_data['score']:
        print(f"Timing accuracy: {replay_data['score']['timing_accuracy']:.2f}")
    
    # 7. Test the single-player compare-melodies endpoint
    print("\nTesting single-player melody comparison...")
    compare_response = requests.post(
        f"{SERVER_URL}/api/compare-melodies",
        json={
            "melody1": EXAMPLE_MELODY_1["melody"],
            "melody2": EXAMPLE_MELODY_2["melody"],
            "timings1": EXAMPLE_MELODY_1["timings"],
            "timings2": EXAMPLE_MELODY_2["timings"],
            "durations1": EXAMPLE_MELODY_1["durations"],
            "durations2": EXAMPLE_MELODY_2["durations"]
        }
    )
    
    if not compare_response.ok:
        print(f"Failed to compare melodies: {compare_response.text}")
        return False
    
    compare_data = compare_response.json()
    print("Melody comparison successful.")
    print(f"Score: {compare_data['result']['final_score']:.2f}")
    print(f"Runtime: {compare_data['result']['matching_runtime_nocom']:.2f} ms")
    
    # 8. Player 1 leaves the room
    print("\nPlayer 1 leaving the room...")
    leave_response = requests.post(
        f"{SERVER_URL}/api/room/leave",
        json={
            "room_id": room_id,
            "player_id": player1_id
        }
    )
    
    if not leave_response.ok:
        print(f"Failed to leave room: {leave_response.text}")
        return False
    
    leave_data = leave_response.json()
    print("Player 1 left successfully.")
    print(f"Room closed: {leave_data['room_closed']}")
    
    return True

# Test WebSocket events
def test_websocket_events():
    print("\n--- Testing WebSocket Events ---\n")
    
    # Create a room first using HTTP
    create_response = requests.post(
        f"{SERVER_URL}/api/room/create",
        json={"player_name": "Socket Player 1"}
    )
    
    if not create_response.ok:
        print(f"Failed to create room for WebSocket test: {create_response.text}")
        return False
    
    create_data = create_response.json()
    room_id = create_data["room_id"]
    player1_id = create_data["player_id"]
    
    print(f"Room created with ID: {room_id}")
    
    # Setup socketio clients
    client1 = socketio.Client()
    client2 = socketio.Client()
    
    # Event trackers
    events_received = {
        'client1': [],
        'client2': []
    }
    
    # Event handlers
    @client1.event
    def connect():
        print("Client 1 connected to server")
    
    @client1.on('room_update')
    def on_room_update_1(data):
        print("Client 1 received room_update event")
        events_received['client1'].append('room_update')
    
    @client1.on('player_joined')
    def on_player_joined_1(data):
        print(f"Client 1 received player_joined event: {data['player_name']} joined")
        events_received['client1'].append('player_joined')
    
    @client1.on('new_challenge')
    def on_new_challenge_1(data):
        print("Client 1 received new_challenge event")
        events_received['client1'].append('new_challenge')
    
    @client2.event
    def connect():
        print("Client 2 connected to server")
    
    @client2.on('room_update')
    def on_room_update_2(data):
        print("Client 2 received room_update event")
        events_received['client2'].append('room_update')
    
    @client2.on('score_update')
    def on_score_update_2(data):
        print("Client 2 received score_update event")
        events_received['client2'].append('score_update')
    
    # Connect clients
    try:
        print("Connecting socketio clients...")
        client1.connect(SERVER_URL)
        client2.connect(SERVER_URL)
        
        # Pause to allow connections to establish
        time.sleep(1)
        
        # Join room with both clients
        print("\nJoining socketio room with client 1...")
        client1.emit('join_room', {'room_id': room_id, 'player_id': player1_id})
        
        # Add second player via HTTP
        join_response = requests.post(
            f"{SERVER_URL}/api/room/join",
            json={
                "room_id": room_id,
                "player_name": "Socket Player 2"
            }
        )
        player2_id = join_response.json()["player_id"]
        
        print(f"\nJoining socketio room with client 2... (player id: {player2_id})")
        client2.emit('join_room', {'room_id': room_id, 'player_id': player2_id})
        
        # Wait for events to process
        time.sleep(1)
        
        # Emit melody recorded event
        print("\nRecording melody via HTTP...")
        record_response = requests.post(
            f"{SERVER_URL}/api/room/record-melody",
            json={
                "room_id": room_id,
                "player_id": player1_id,
                "melody": EXAMPLE_MELODY_1["melody"],
                "timings": EXAMPLE_MELODY_1["timings"],
                "durations": EXAMPLE_MELODY_1["durations"]
            }
        )
        
        print("\nEmitting melody_recorded event via websocket...")
        client1.emit('melody_recorded', {'room_id': room_id})
        
        # Wait for events to process
        time.sleep(1)
        
        # Submit replay via HTTP and then emit event
        print("\nSubmitting replay via HTTP...")
        replay_response = requests.post(
            f"{SERVER_URL}/api/room/submit-replay",
            json={
                "room_id": room_id,
                "player_id": player2_id,
                "melody": EXAMPLE_MELODY_2["melody"],
                "timings": EXAMPLE_MELODY_2["timings"],
                "durations": EXAMPLE_MELODY_2["durations"]
            }
        )
        
        replay_data = replay_response.json()
        
        print("\nEmitting replay_submitted event via websocket...")
        client2.emit('replay_submitted', {
            'room_id': room_id,
            'score': replay_data['score']
        })
        
        # Wait for events to process
        time.sleep(1)
        
        # Emit turn changed event
        print("\nEmitting turn_changed event via websocket...")
        client1.emit('turn_changed', {'room_id': room_id})
        
        # Wait for final events to process
        time.sleep(1)
        
        # Print event summary
        print("\n--- WebSocket Event Summary ---")
        print(f"Client 1 events received: {events_received['client1']}")
        print(f"Client 2 events received: {events_received['client2']}")
        
        # Disconnect clients
        client1.disconnect()
        client2.disconnect()
        
        return True
        
    except Exception as e:
        print(f"WebSocket test error: {str(e)}")
        
        # Try to disconnect clients
        try:
            if client1.connected:
                client1.disconnect()
            if client2.connected:
                client2.disconnect()
        except:
            pass
            
        return False

if __name__ == "__main__":
    print("=== Piano Game Server Test Script ===\n")
    
    # Run HTTP tests
    http_success = test_http_endpoints()
    
    if http_success:
        print("\n✅ HTTP API tests completed successfully!")
    else:
        print("\n❌ HTTP API tests failed!")
        
    # Run WebSocket tests if HTTP was successful
    if http_success:
        ws_success = test_websocket_events()
        
        if ws_success:
            print("\n✅ WebSocket tests completed successfully!")
        else:
            print("\n❌ WebSocket tests failed!")
    
    print("\nTest script completed.") 