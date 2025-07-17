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
  - `soundfonts/` - Soundfont files for MIDI playbook
  - `midi/` - MIDI files organized by difficulty
- `static/` - Static files and sample melodies

## Server

The Piano Game Server is now maintained in a separate repository for better deployment and maintenance:

**Server Repository**: https://github.com/AlonHermoni/final-project-server

The server provides:
- RESTful API for melody comparison and room management
- WebSocket support for real-time multiplayer gameplay
- Sophisticated melody matching algorithms
- Google Cloud App Engine deployment configuration

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

### 2. Setup Server Connection

The server is now maintained in a separate repository. You have two options:

#### Option A: Use the Production Server (Recommended)
1. **Switch to production environment:**
   ```bash
   ./switch_env.sh production
   ```
2. **Update the project ID in `.env.production`:**
   - Edit `.env.production` and replace `YOUR_PROJECT_ID` with the actual Google Cloud project ID
   - Run `./switch_env.sh production` again

#### Option B: Run Local Development Server
1. **Clone the server repository:**
   ```bash
   git clone https://github.com/AlonHermoni/final-project-server.git
   cd final-project-server
   ```
2. **Follow the server setup instructions in that repository**
3. **Switch to development environment:**
   ```bash
   ./switch_env.sh development
   ```

### 3. Run Flutter Frontend (Client)

1.  **Ensure you are in the project root directory (containing `pubspec.yaml`):**
    ```bash
    pwd  # Should show the piano_game_consolidated directory
    ```
2.  **Get Flutter dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the Flutter app (e.g., on Chrome):**
    ```bash
    flutter run -d chrome
    ```
    The application should open in your Chrome browser and connect to the configured server.

### Environment Configuration

The app uses environment variables for server configuration:

- **Development**: `./switch_env.sh development` (uses localhost:5001)
- **Production**: `./switch_env.sh production` (uses deployed server)

Check current environment:
```bash
./switch_env.sh
```

### Troubleshooting

*   **Server Connection Issues:** 
    - Check your environment configuration with `./switch_env.sh`
    - For production: Ensure the server is deployed and accessible
    - For development: Ensure the local server is running
*   **Flutter Doctor:** If the Flutter app has issues, run `flutter doctor` to diagnose common problems with your Flutter setup.
*   **Environment Variables:** Check that `.env` file exists and contains the correct server URL

## Architecture

This application follows a client-server architecture:

- **Client**: Flutter application (this repository)
- **Server**: Python Flask server (separate repository)

The client communicates with the server via HTTP REST API and WebSocket connections for real-time multiplayer functionality.

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

# Piano Game - Android Build Troubleshooting Report

## Date: May 21, 2024

## Recent Updates (Chrome/Web Build)

### Date: Current

#### 1. Unified Analytics Report
- Implemented consistent analytics dialog across all game modes (Computer, Player, Multiplayer)
- Dialog never auto-dismisses - stays open until user clicks a button
- Added tracking for:
  - **response_time_ms**: Client → Server → Client round-trip time (includes matching algorithm)
  - **matching_time_nocom_ms**: Server-side pure matching latency (excluding communication overhead)
- Analytics data is displayed using the shared `AnalysisReportWidget` component

#### 2. UI & Flow Improvements
- **End Game Button**: Added to all game modes, navigates directly to Main Menu
- **Next Round Button**: Properly swaps active player and starts the next turn in Player mode
- **Round Logic**: Changed to best-of-3 per player (6 total rounds) for equal turns
- **Multiplayer UI**: Updated to match the look and feel of local Player mode

#### 3. Melody Bank Expansion
- Expanded from 8 to 20+ classical melodies in `static/melodies.json`
- Added well-known pieces including:
  - Ode to Joy (Beethoven)
  - Für Elise (Beethoven)
  - Eine kleine Nachtmusik (Mozart)
  - Spring from Four Seasons (Vivaldi)
  - Moonlight Sonata (Beethoven)
  - Prelude in C Major (Bach)
  - Gymnopédie No.1 (Satie)
  - The Blue Danube (Strauss)
  - Swan Lake Theme (Tchaikovsky)
  - Minuet in G (Bach)
  - Ave Maria (Schubert)
  - Turkish March (Mozart)
  - Morning Mood (Grieg)
- All melodies limited to ≤ 20 notes for appropriate game difficulty

#### 4. Repeat Button Feature
- Added Repeat button to all game modes
- Allows players to replay the reference melody
- Limited to 2 uses per round
- Shows remaining repeat count
- Disabled after maximum uses reached

#### 5. Technical Improvements
- Fixed all 24 analyzer warnings (down to 0)
- Updated deprecated Color APIs to use `withValues(alpha:)`
- Replaced `dart:html` with modern `dart:js_interop` and `package:web`
- Replaced print statements with `debugPrint()`
- Fixed unused variables and imports
- Improved code organization and consistency
