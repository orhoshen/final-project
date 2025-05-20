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

## Setup Instructions

### Prerequisites

- Flutter SDK (version 3.3+)
- Dart SDK
- Python 3.8+
- Firebase account (optional for full functionality)

### Flutter Setup

1. Install dependencies:
   ```
   flutter pub get
   ```

2. Run the app on your preferred platform:
   ```
   flutter run -d chrome  # For web
   flutter run            # For default device
   ```

### Flask Server Setup

1. Create a virtual environment (optional but recommended):
   ```
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install required packages:
   ```
   pip install -r requirements.txt
   ```

3. Run the server:
   ```
   python app.py
   ```
   The server will run on port 5001 by default (changed from 5000 to avoid conflicts with AirPlay on macOS).

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
