# Piano Game

A piano UI game application built with Flutter (client-side) and Python Flask (server-side).

## Features

- Interactive piano keyboard UI
- MIDI playback capabilities
- Multiple game modes (player mode, computer mode)
- Melody matching algorithms
- Firebase integration
- Audio processing and playback

## Project Structure

- `lib/` - Flutter client application
  - `screens/` - UI screens
  - `services/` - Business logic and services
  - `widgets/` - Reusable UI components
- `assets/` - Audio files and resources
  - `piano_notes/` - Individual piano note audio files
  - `soundfonts/` - Soundfont files for MIDI playback
  - `midi/` - MIDI files organized by difficulty
- `algorithms/` - Python algorithms for melody matching
- `static/` - Static files served by Flask

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

*   [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
*   [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/G), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Project Setup and Running

This project consists of a Flutter frontend and a Python Flask backend.

### Prerequisites

*   Flutter SDK installed (check with `flutter doctor`)
*   Python 3.x installed
*   A virtual environment tool for Python (e.g., `venv`)
*   Git for version control

### 1. Clone the Repository

```bash
git clone https://github.com/orhoshen/final-project.git
cd final-project
```

### 2. Setup Python Backend Server

The Python server is located in the `final-project-server` directory.

1.  **Navigate to the server directory:**
    ```bash
    cd final-project-server
    ```
2.  **Create and activate a Python virtual environment:**
    ```bash
    python3 -m venv .venv  # Create a virtual environment (if not already done)
    source .venv/bin/activate # On macOS/Linux
    # .venv\\Scripts\\activate  # On Windows
    ```
3.  **Install Python dependencies:**
    ```bash
    pip install -r requirements.txt
    ```
4.  **Run the Flask server (using `simple_app.py`):**
    ```bash
    PORT=5001 python3 simple_app.py
    ```
    The server will start on `http://localhost:5001`. You should see output indicating it\'s running.
    This `simple_app.py` includes the core melody matching and Socket.IO functionalities needed for the app.

    *(Note: There is also an `app.py` which contains more extensive room management logic that is currently a work in progress and might have unresolved import issues if run directly. For current functionality, use `simple_app.py`.)*

### 3. Run Flutter Frontend (Client)

1.  **Open a new terminal window/tab.**
2.  **Navigate to the project root directory (if you are in `final-project-server`, go one level up):**
    ```bash
    cd .. 
    ```
    (Ensure you are in the `final-project` directory, which contains `pubspec.yaml`)
3.  **Get Flutter dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Run the Flutter app (e.g., on Chrome):**
    ```bash
    flutter run -d chrome
    ```
    The application should open in your Chrome browser and connect to the server.

### Server Endpoints

The server exposes the following key endpoints:
*   `GET /`: Welcome message
*   `GET /api/health`: Health check
*   `POST /api/estimate-difficulty`: Estimates melody difficulty.
    *   Payload: `{"melody": [60, 62, 64, 65]}`
*   `POST /api/compare-melodies`: Compares two melodies.
    *   Payload: `{"melody1": [], "melody2": [], "timings1": [], "timings2": [], "durations1": [], "durations2": []}`
*   `GET /static/melodies.json`: Serves a list of sample melodies.
*   Socket.IO endpoints are available at the root for real-time communication.

### Troubleshooting
*   **Port in use:** If you see an "Address already in use" error for port 5001 when starting the server, ensure no other instances of the server (or other applications) are running on that port. You can kill existing processes using:
    ```bash
    # For macOS/Linux
    lsof -ti:5001 | xargs kill -9
    ```
*   **Flutter Doctor:** If the Flutter app has issues, run `flutter doctor` to diagnose common problems with your Flutter setup.
*   **Server not connecting:** Double-check that the server is running in its own terminal window and that the Flutter app is configured to connect to `http://localhost:5001` (this is the default in the current codebase).
*   **Python/Pip commands:** If `python3` or `pip3` don\'t work, try `python` or `pip` respectively, depending on your system\'s Python installation and PATH configuration.

## About

## API Endpoints

- `/api/health` - Health check endpoint
- `/api/compare-melodies` - Compare two melodies for similarity
- `/api/estimate-difficulty` - Estimate difficulty of a melody
- `/api/soundfonts` - List available soundfont files
- `/api/piano_notes` - List available piano note files

## Supported Platforms

- Web (Chrome)
- Android
- iOS (requires setup)
- macOS (requires setup)
- Windows (requires setup)
- Linux (requires setup)

## Development Guidelines

- Follow feature-based organization for Flutter code
- Implement proper state management
- Separate UI from business logic
- Use repository pattern for data access
- Follow RESTful API design for Flask endpoints
- Implement proper error handling
