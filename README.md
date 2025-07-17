# 🎹 Piano Game - Real-time Multiplayer Piano Game

A sophisticated piano UI game application built with Flutter (client-side) and Python Flask (server-side) with real-time multiplayer capabilities.

## ✨ Features

- **Interactive Piano Keyboard**: Responsive piano UI with visual feedback
- **Real-time Multiplayer**: WebSocket-powered multiplayer with <500ms latency
- **Multiple Game Modes**: 
  - Computer Mode: Play against AI
  - Player Mode: Local multiplayer
  - Multiplayer Mode: Online real-time multiplayer
- **Advanced Melody Matching**: Sophisticated algorithms for melody comparison
- **MIDI Playback**: Full MIDI support with custom soundfonts
- **Audio Processing**: High-quality audio playback and recording
- **Cloud Deployment**: Production-ready deployment on Google Cloud Run

## 🏗️ Project Structure

- `lib/` - Flutter client application
  - `screens/` - UI screens for different game modes
  - `services/` - Business logic and WebSocket services
  - `widgets/` - Reusable UI components
- `assets/` - Audio files and resources
  - `piano_notes/` - Individual piano note audio files
  - `soundfonts/` - Soundfont files for MIDI playbook
  - `midi/` - MIDI files organized by difficulty
- `static/` - Static files and sample melodies
- `final-project-server/` - Python Flask server with WebSocket support

## 🌐 Server Architecture

The server provides a hybrid HTTP + WebSocket architecture:

**Production Server**: https://piano-game-server-1065551791970.us-central1.run.app

**Server Features**:
- RESTful API for melody comparison and room management
- WebSocket support for real-time multiplayer gameplay
- Sophisticated melody matching algorithms with timing analysis
- Google Cloud Run deployment with auto-scaling
- Docker containerization for consistent deployment

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK**: Install from [flutter.dev](https://flutter.dev/docs/get-started/install)
- **Git**: For version control
- **Chrome**: For web development and testing

### 1. Clone the Repository

```bash
git clone https://github.com/orhoshen/final-project.git
cd final-project
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the Application

The application is pre-configured to use the production server hosted on Google Cloud Run.

```bash
# Run on Chrome (recommended for development)
flutter run -d chrome

# Or run on other platforms
flutter run -d android  # For Android
flutter run -d ios      # For iOS
flutter run -d macos    # For macOS
flutter run -d windows  # For Windows
```

The app will automatically connect to the production server at:
`https://piano-game-server-1065551791970.us-central1.run.app`

## 🐳 Docker Development (Optional)

If you want to run the server locally using Docker:

### 1. Build the Docker Image

```bash
cd final-project-server
docker build -t piano-game-server .
```

### 2. Run the Container

```bash
docker run -p 5001:8080 piano-game-server
```

### 3. Switch to Local Development

```bash
# Create local environment file
echo "FLASK_SERVER_URL=http://localhost:5001" > .env

# Run the Flutter app
flutter run -d chrome
```

## 🌍 Environment Configuration

The app uses environment variables for server configuration:

### Production (Default)
- Uses Google Cloud Run server
- WebSocket support enabled
- Auto-scaling and high availability

### Local Development
- Uses local server (requires Docker or manual setup)
- Useful for server development and testing

### Switch Environments

Create a `.env` file in the root directory:

```bash
# For production (default)
FLASK_SERVER_URL=https://piano-game-server-1065551791970.us-central1.run.app

# For local development
FLASK_SERVER_URL=http://localhost:5001
```

## 🎮 Game Modes

### 1. Computer Mode
- Play against AI
- Practice melody matching
- Difficulty-based scoring

### 2. Player Mode
- Local multiplayer (same device)
- Turn-based gameplay
- Performance analytics

### 3. Multiplayer Mode
- Real-time online multiplayer
- WebSocket-powered communication
- <500ms latency for competitive gameplay

## 🔧 Troubleshooting

### Common Issues

1. **Server Connection Failed**
   ```bash
   # Check server status
   curl https://piano-game-server-1065551791970.us-central1.run.app/api/health
   
   # Should return: {"status": "healthy", "socketio": "enabled"}
   ```

2. **Flutter Doctor Issues**
   ```bash
   flutter doctor
   # Fix any issues reported
   ```

3. **WebSocket Connection Problems**
   - Ensure you're using Chrome for web development
   - Check that the server supports WebSocket connections
   - Verify firewall settings don't block WebSocket connections

4. **Build Errors**
   ```bash
   # Clean and rebuild
   flutter clean
   flutter pub get
   flutter build web
   ```

### Debug Mode

For detailed debugging information:

```bash
# Run with verbose logging
flutter run -d chrome --verbose

# Or build with debug info
flutter build web --debug
```

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
