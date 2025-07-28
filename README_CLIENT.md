# 🎹 Piano Game Client

**Cross-platform multiplayer piano game with real-time WebSocket communication**

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-blue?logo=dart)](https://dart.dev)
[![Web](https://img.shields.io/badge/Platform-Web-green)](https://flutter.dev/web)
[![Android](https://img.shields.io/badge/Platform-Android-green)](https://flutter.dev/docs/deployment/android)
[![iOS](https://img.shields.io/badge/Platform-iOS-green)](https://flutter.dev/docs/deployment/ios)

## 🎯 Overview

The Piano Game Client is a cross-platform Flutter application that delivers an engaging multiplayer piano gaming experience. Players can challenge themselves against AI, compete 1v1 with friends, or join real-time multiplayer rooms for competitive melody matching gameplay.

### ✨ Key Features

- 🎮 **Three Game Modes**: 
  - **VS Computer**: Challenge AI with melody matching
  - **VS Player**: 1v1 melody replay competitions
  - **Multiplayer**: Real-time online gameplay with room system
- 🌐 **Cross-Platform**: Web, Android, iOS, Windows, Linux, macOS
- ⚡ **Real-time Communication**: WebSocket + HTTP hybrid architecture
- 🎵 **Advanced Audio Engine**: MIDI support with piano soundfonts
- 🏆 **Binary Scoring System**: Clear win/lose outcomes (70% threshold)
- 🎹 **Interactive Piano**: Visual piano keyboard with note feedback
- 📱 **Responsive Design**: Optimized for all screen sizes

## 🏗️ Architecture

```
┌─────────────────┐    WebSocket     ┌─────────────────┐
│   Flutter UI    │ ◄─────────────► │   Server        │
│   Components    │    + HTTP        │   Events        │
└─────────────────┘                 └─────────────────┘
        │                                   │
┌───────▼────────┐                 ┌────────▼────────┐
│   Game Logic   │                 │   Room          │
│   • Scoring    │                 │   Management    │
│   • Timing     │                 │   • Players     │
│   • Audio      │                 │   • Turns       │
└────────────────┘                 │   • Challenges  │
                                   └─────────────────┘
```

### 🎮 Game Modes

#### VS Computer Mode
- **Objective**: Match AI-generated melodies as accurately as possible
- **Scoring**: Binary system - 1 point for ≥70% accuracy, 0 for <70%
- **Difficulty**: Adaptive based on melody complexity
- **Latency**: ~320ms average response time

#### VS Player Mode  
- **Objective**: 1v1 melody replay challenges
- **Gameplay**: Take turns creating and replaying melodies
- **Scoring**: Same binary system as VS Computer
- **Competition**: Direct player vs player scoring

#### Multiplayer Mode
- **Objective**: Real-time competitive gameplay
- **Rooms**: 2-player rooms with automatic matching
- **Real-time**: WebSocket-based live updates
- **Features**: Room codes, spectator mode, turn-based play

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.24+
- Dart SDK 3.3+
- Platform-specific requirements:
  - **Web**: Modern browser with WebAssembly support
  - **Android**: Android Studio, Android SDK
  - **iOS**: Xcode, iOS SDK
  - **Desktop**: Platform-specific build tools

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/piano-game-client.git
   cd piano-game-client
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   ```bash
   # Copy the environment template
   cp .env.example .env
   
   # Edit .env with your server URL
   FLASK_SERVER_URL=https://your-server-url.com
   ```

4. **Run the application**
   ```bash
   # Web (recommended for development)
   flutter run -d chrome
   
   # Android
   flutter run -d android
   
   # iOS
   flutter run -d ios
   ```

## 🏗️ Building for Production

### Web Deployment
```bash
# Build for web
flutter build web --release

# Deploy to hosting (example with Firebase)
firebase deploy --only hosting
```

### Android APK/Bundle
```bash
# Build APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

### iOS App Store
```bash
# Build for iOS
flutter build ios --release

# Open in Xcode for signing and upload
open ios/Runner.xcworkspace
```

### Desktop Applications
```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## ⚙️ Configuration

### Environment Variables (.env)

```bash
# Server Configuration
FLASK_SERVER_URL=https://piano-server-1065551791970.us-central1.run.app
FLASK_SERVER_HOST=piano-server-1065551791970.us-central1.run.app
FLASK_SERVER_PORT=443

# Client Settings
AUTO_START_SERVER=false
SERVER_RETRY_COUNT=3
SERVER_HEALTH_CHECK_INTERVAL=60
```

### Audio Configuration

The game includes pre-configured audio assets:
- **Piano Notes**: Individual note samples (C4-C6)
- **MIDI Soundfonts**: High-quality piano sounds
- **Note Duration**: Configurable timing and sustain

### Performance Settings

- **WebSocket Reconnection**: Automatic with exponential backoff
- **Audio Latency**: Optimized for real-time gameplay
- **Network Timeout**: 30 seconds for API calls
- **Room Cleanup**: 5 minutes inactivity timeout

## 🎮 Gameplay Guide

### Getting Started

1. **Launch the app** and choose your game mode
2. **VS Computer**: Start immediately with AI challenges
3. **VS Player**: Create or join a 1v1 challenge
4. **Multiplayer**: Enter room code or create new room

### Playing Melodies

1. **Listen** to the target melody (played automatically)
2. **Replay** the melody using the on-screen piano
3. **Submit** your attempt for scoring
4. **Review** detailed feedback and accuracy metrics

### Scoring System

- **Perfect Match (100%)**: All notes correct with good timing
- **Good Match (70-99%)**: Most notes correct, minor timing issues
- **Passing (≥70%)**: Earns 1 point (win)
- **Failing (<70%)**: Earns 0 points (loss)

### Multiplayer Rooms

- **Room Codes**: 6-character alphanumeric codes
- **Player Limit**: 2 players per room
- **Turn System**: Alternating melody creation and replay
- **Real-time Updates**: Live score and status updates

## 🔧 Development

### Project Structure

```
piano-game-client/
├── lib/
│   ├── main.dart              # Application entry point
│   ├── config/                # Configuration files
│   ├── models/                # Data models
│   │   ├── game_room.dart     # Room state management
│   │   └── firebase_models.dart # Firebase integration
│   ├── providers/             # State management
│   ├── screens/               # UI screens
│   │   ├── landing_page.dart  # Home screen
│   │   ├── computer_mode_screen.dart # VS Computer
│   │   ├── player_mode_screen.dart   # VS Player
│   │   └── multiplayer_*.dart # Multiplayer screens
│   ├── services/              # Business logic
│   │   ├── enhanced_websocket_service.dart # WebSocket
│   │   ├── multiplayer_service.dart # Game logic
│   │   ├── audio_*.dart       # Audio handling
│   │   └── server_manager.dart # Server communication
│   └── widgets/               # Reusable components
│       ├── piano_keyboard.dart # Interactive piano
│       └── server_status_widget.dart # Connection status
├── assets/                    # Game assets
│   ├── images/               # Icons and graphics
│   ├── piano_notes/          # Audio samples
│   └── soundfonts/           # MIDI soundfonts
├── web/                      # Web platform files
├── android/                  # Android platform files
├── ios/                      # iOS platform files
└── [other platforms]/        # Desktop platform files
```

### Key Services

#### WebSocket Service (`enhanced_websocket_service.dart`)
- Manages real-time server communication
- Handles connection retry logic
- Processes game events and room updates

#### Multiplayer Service (`multiplayer_service.dart`)
- Coordinates game state between players
- Manages room lifecycle and player actions
- Integrates WebSocket events with UI updates

#### Audio Services
- **Web**: `audio_web.dart` - Browser-based audio
- **Mobile**: `audio_non_web.dart` - Native audio APIs
- **MIDI**: `midi_service.dart` - MIDI file processing

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Platform Testing
```bash
# Test on different platforms
flutter test --platform=chrome
flutter test --platform=vm
```

### Performance Testing
```bash
# Profile app performance
flutter run --profile
flutter run --trace-startup
```

## 📱 Platform-Specific Features

### Web
- **Progressive Web App** (PWA) support
- **WebAssembly** for optimal performance
- **Browser audio** with low-latency playback
- **Responsive design** for all screen sizes

### Android
- **Material Design** 3.0 styling
- **Android 14** compatibility
- **Adaptive icons** and splash screens
- **Hardware back button** support

### iOS
- **Cupertino design** elements
- **iOS 16+** compatibility
- **App Store** optimization
- **iPhone and iPad** support

### Desktop
- **Native window management**
- **Keyboard shortcuts**
- **File system integration**
- **Multi-monitor** support

## 📊 Performance Metrics

- **App Launch**: <3 seconds cold start
- **WebSocket Connection**: <2 seconds establishment
- **Audio Latency**: <100ms for note playback
- **Memory Usage**: ~50MB base, scales with audio cache
- **Network Usage**: Minimal - only for game events
- **Battery Impact**: Optimized for mobile devices

## 🔒 Privacy & Security

- **No Personal Data**: Game doesn't collect personal information
- **Room Codes**: Temporary, expire after inactivity
- **Secure WebSocket**: TLS encryption for all communications
- **Local Storage**: Only for game preferences and settings

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Flutter/Dart style conventions
- Add tests for new features
- Update documentation for API changes
- Test on multiple platforms before submitting

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Related Projects

- **Piano Game Server**: [Flask-SocketIO backend](https://github.com/yourusername/piano-game-server)
- **Live Demo**: [https://piano-game-demo.web.app](https://piano-game-demo.web.app)

## 📞 Support

For questions and support:
- 📧 Create an issue in this repository
- 📖 Check the [Flutter documentation](https://flutter.dev/docs)
- 🎮 Review the [gameplay guide](#-gameplay-guide)

## 🎯 Roadmap

- [ ] **Tournament Mode**: Multi-player tournaments
- [ ] **Custom Melodies**: User-created melody challenges
- [ ] **Leaderboards**: Global and friend leaderboards
- [ ] **Achievements**: Unlock system with rewards
- [ ] **Themes**: Customizable UI themes
- [ ] **Offline Mode**: Practice without internet

---

**🎹 Built with ❤️ for music lovers and competitive gamers**

*Play, Compete, and Master the Piano Game Experience!*