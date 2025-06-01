# Piano Game Server

This Flask-based server provides the backend for a multiplayer piano game with melody matching algorithms. It supports real-time communication via WebSockets and features a room-based game system.

## Overview

The Piano Game Server allows players to create or join game rooms where they take turns creating melodies for the other player to replay. The server analyzes and scores the replayed melodies using sophisticated algorithms that consider both pitch and timing accuracy.

## Directory Structure

```
flask_server/
├── algorithms/      
│   └── melody_matcher.py   # Core melody matching algorithms
├── game/            
│   ├── room.py             # Room class for game state management
│   └── manager.py          # RoomManager for handling multiple rooms
├── api/             
│   └── room_routes.py      # HTTP API endpoints
├── socket/          
│   └── events.py           # WebSocket event handlers
├── tests/           
│   └── test_game.py        # Test script for HTTP and WebSocket testing
├── app.py                  # Main application file
├── requirements.txt        # Python dependencies
└── app.yaml               # App Engine configuration
```

## Components

### Melody Matcher

Located in `algorithms/melody_matcher.py`, the MelodyMatcher class implements the algorithms for comparing melodies:

- **DTW (Dynamic Time Warping)**: Main algorithm that compares melody sequences considering both pitch and timing differences
- **Levenshtein Distance**: Measures edit distance between sequences
- **LCS (Longest Common Subsequence)**: Identifies common subsequences in melodies
- **Cosine Similarity**: Compares overall distribution of notes

These algorithms are combined with customizable weights to provide accurate scoring of melody replay attempts.

### Room Management

The game uses a room-based system with two key classes:

- **Room** (`game/room.py`): Manages individual game room state including:
  - Player tracking
  - Turn management
  - Melody challenge storage
  - Score tracking

- **RoomManager** (`game/manager.py`): Singleton managing all active rooms:
  - Room creation and cleanup
  - Player joining/leaving logic
  - Room listing and lookup

Rooms automatically close after 5 minutes of inactivity.

### API Endpoints

All HTTP API endpoints are defined in `api/room_routes.py` and mounted under `/api/room/`:

#### Room Management:

- `GET /api/room/list` - List available rooms
- `POST /api/room/create` - Create a new room
- `POST /api/room/join` - Join an existing room
- `GET /api/room/status` - Get current room state
- `POST /api/room/leave` - Leave a room

#### Gameplay:

- `POST /api/room/record-melody` - Submit a melody for the other player
- `GET /api/room/get-challenge` - Get the melody to replay
- `POST /api/room/submit-replay` - Submit replay attempt and get scored

#### Single-Player:

- `POST /api/compare-melodies` - Compare melodies without room/game management

### WebSocket Events

The WebSocket events are defined in `socket/events.py` and provide real-time updates for the game:

#### Server → Client Events:
- `room_update` - Room state has changed
- `player_joined` - New player has joined the room
- `player_left` - Player has left the room
- `new_challenge` - New melody challenge is available
- `score_update` - Score has been updated

#### Client → Server Events:
- `join_room` - Connect to a specific room's events
- `leave_room` - Disconnect from room events
- `melody_recorded` - Notify when a melody has been recorded
- `replay_submitted` - Notify when a replay has been submitted
- `turn_changed` - Notify when the active player has changed

## Game Flow

1. **Room Creation**:
   - Player 1 creates a room via `/api/room/create`
   - System generates room code and player ID

2. **Joining**:
   - Player 2 joins via `/api/room/join` with room code
   - Both players connect to WebSocket events

3. **Gameplay Loop**:
   - Player 1 records a melody via `/api/room/record-melody`
   - Server notifies Player 2 of new challenge via WebSocket
   - Player 2 gets the challenge via `/api/room/get-challenge`
   - Player 2 attempts to replay it and submits via `/api/room/submit-replay`
   - Server scores the attempt using MelodyMatcher
   - Players switch roles for next turn
   - Continue until a player leaves

4. **Leaving**:
   - Players can leave via `/api/room/leave`
   - Rooms auto-close when empty or inactive for 5 minutes

## Data Formats

### Melody Format:
```json
{
  "melody": [60, 62, 64, 65, 67], // MIDI note numbers
  "timings": [0, 500, 1000, 1500, 2000], // Note start times in ms
  "durations": [450, 450, 450, 450, 800] // Note durations in ms
}
```

### Score Response Format:
```json
{
  "final_score": 0.87,
  "pitch_accuracy": 0.95,
  "timing_accuracy": 0.82,
  "matching_runtime_nocom": 23.5,
  "note_details": [
    {
      "index": 0,
      "target_note": 60,
      "target_note_name": "C4",
      "played_note": 60,
      "played_note_name": "C4",
      "is_correct_pitch": true,
      "onset_error": 15,
      "duration_error": 25,
      "target_onset": 0,
      "played_onset": 15,
      "target_duration": 450,
      "played_duration": 475
    },
    // Additional notes...
  ]
}
```

## Deployment to Google Cloud

This server is configured for deployment to Google Cloud App Engine:

1. Ensure the Google Cloud SDK is installed
2. Update app.yaml if necessary
3. Run deployment command: `gcloud app deploy`

The app.yaml is configured for Python 3.9 with eventlet support for WebSockets:

```yaml
runtime: python39
entrypoint: gunicorn -b :$PORT app:app --worker-class eventlet

instance_class: F1

automatic_scaling:
  target_cpu_utilization: 0.65
  min_instances: 1
  max_instances: 10
  
network:
  session_affinity: true

env_variables:
  FLASK_APP: "app.py"
  FLASK_ENV: "production"
```

## Testing

A test script is provided in `tests/test_game.py` that can test both HTTP API endpoints and WebSocket functionality. To run:

1. Update the SERVER_URL variable to point to your server
2. Run with Python: `python tests/test_game.py`

The test script will create rooms, join them, record melodies, and test the replay scoring functionality.

## Dependencies

- Flask: Web framework
- Flask-SocketIO: WebSocket support
- Eventlet: WSGI server for WebSockets
- NumPy: Used in melody matching algorithms

All dependencies are listed in requirements.txt. 