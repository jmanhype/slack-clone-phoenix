# SlackClone Mobile Client

A comprehensive React Native mobile application for the SlackClone backend system, featuring real-time messaging, biometric authentication, and offline capabilities.

## 🚀 Features

### Core Functionality
- **Real-time Messaging**: WebSocket-powered chat with Phoenix Channels
- **Biometric Authentication**: Touch ID, Face ID, and Fingerprint login
- **Offline Support**: Message queuing and background synchronization
- **File Sharing**: Image, video, audio, and document uploads
- **Voice Messages**: Audio recording and playback
- **Push Notifications**: Firebase Cloud Messaging integration

### User Experience
- **Native Navigation**: Stack, Tab, and Drawer navigators
- **Animations**: Smooth transitions and gesture-based interactions
- **Dark Mode**: System-aware theme switching
- **Accessibility**: Screen reader support and assistive technology
- **Platform Optimization**: iOS and Android specific features

### Technical Features
- **TypeScript**: Full type safety throughout the application
- **Redux Toolkit**: State management with persistence
- **Encrypted Storage**: Secure token and sensitive data storage
- **Background Sync**: Offline message queue with retry logic
- **Phoenix Sockets**: Real-time WebSocket communication
- **Gesture Handling**: Swipe actions and pull-to-refresh

## 📋 Prerequisites

- Node.js 16+ 
- React Native CLI
- Xcode (for iOS development)
- Android Studio (for Android development)
- CocoaPods (for iOS dependencies)

## 🛠 Installation

1. **Clone and navigate to mobile directory**:
   ```bash
   cd /Users/speed/Downloads/experiments/slack_clone/mobile
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **iOS setup**:
   ```bash
   cd ios && pod install && cd ..
   ```

4. **Android setup**:
   - Ensure Android SDK and emulator are configured
   - Update `android/local.properties` with SDK path

## 🏃‍♂️ Running the App

### Development
```bash
# Start Metro bundler
npm start

# Run on iOS (requires Xcode)
npm run ios

# Run on Android (requires Android Studio/Emulator)
npm run android
```

### Production Builds
```bash
# Build Android APK
npm run build:android

# Build iOS Archive
npm run build:ios
```

## 🔧 Configuration

### Backend Connection
Update the API endpoint in `/src/services/api.ts`:
```typescript
const API_BASE_URL = 'https://your-backend-url.com/api';
const WS_URL = 'wss://your-backend-url.com/socket';
```

### Push Notifications
1. Configure Firebase project
2. Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
3. Update notification settings in `/src/services/notifications.ts`

### Environment Variables
Create `.env` file in project root:
```bash
API_BASE_URL=https://your-api-url.com
WS_URL=wss://your-websocket-url.com
FIREBASE_PROJECT_ID=your-firebase-project
```

## 📱 App Architecture

### Directory Structure
```
src/
├── components/         # Reusable UI components
├── screens/           # Screen components
│   ├── auth/          # Authentication screens
│   └── main/          # Main app screens
├── services/          # External services
├── store/             # Redux store and slices
├── hooks/             # Custom React hooks
├── utils/             # Utility functions
├── contexts/          # React contexts
└── types/             # TypeScript definitions
```

### Key Services
- **SocketService**: Phoenix WebSocket management
- **NotificationService**: Push notification handling
- **BackgroundSyncService**: Offline message synchronization
- **StorageService**: Encrypted data persistence

### State Management
- **Redux Toolkit** with encrypted persistence
- **Slices**: Auth, Messages, Channels, Workspaces, UI
- **Async Thunks**: API integration and side effects

## 🔐 Security

- **Encrypted Storage**: Sensitive data protection
- **Biometric Authentication**: Device-level security
- **Token Management**: Automatic refresh and secure storage
- **Certificate Pinning**: Network security (recommended for production)

## 📊 Performance

- **Lazy Loading**: Component and screen level
- **Image Optimization**: Automatic compression and caching
- **Memory Management**: Efficient list rendering with FlatList
- **Background Processing**: Non-blocking operations
- **Device Performance**: Adaptive features based on device capabilities

## ♿ Accessibility

- **Screen Reader Support**: VoiceOver (iOS) and TalkBack (Android)
- **Dynamic Type**: Automatic font scaling
- **High Contrast**: Support for accessibility display settings
- **Keyboard Navigation**: Full keyboard support
- **Semantic Labels**: Descriptive accessibility hints

## 🧪 Testing

```bash
# Run unit tests
npm test

# Run tests with coverage
npm test -- --coverage

# Run specific test file
npm test MessageBubble.test.tsx
```

### Test Structure
- **Unit Tests**: Component and service testing
- **Integration Tests**: Redux store and API integration
- **E2E Tests**: Complete user workflows (recommended: Detox)

## 📦 Dependencies

### Core
- React Native 0.72.6
- React Navigation 6.x
- Redux Toolkit 1.9.7
- TypeScript 4.8.4

### Communication
- Phoenix WebSocket client
- Firebase Cloud Messaging
- React Native NetInfo

### UI/UX
- React Native Reanimated
- React Native Gesture Handler
- React Native Vector Icons
- React Native SVG

### Storage & Security
- React Native Encrypted Storage
- React Native Keychain
- React Native Biometrics
- AsyncStorage

### Media & Files
- React Native Image Picker
- React Native Document Picker
- React Native Audio Recorder Player
- React Native Sound

## 🐛 Troubleshooting

### Common Issues

1. **iOS Build Fails**:
   ```bash
   cd ios && pod deintegrate && pod install && cd ..
   ```

2. **Android Build Fails**:
   ```bash
   npx react-native clean-project-auto
   ```

3. **Metro Bundle Issues**:
   ```bash
   npx react-native start --reset-cache
   ```

4. **Socket Connection Issues**:
   - Verify backend WebSocket endpoint
   - Check network connectivity
   - Review Phoenix Channel configuration

## 📝 Development Guidelines

### Code Style
- Use TypeScript strict mode
- Follow React Native best practices
- Implement proper error boundaries
- Use functional components with hooks
- Apply consistent naming conventions

### Performance Best Practices
- Use FlatList for large datasets
- Implement lazy loading where appropriate
- Optimize images and assets
- Monitor memory usage
- Profile using Flipper or React DevTools

### Security Best Practices
- Never hardcode sensitive data
- Use encrypted storage for tokens
- Implement proper input validation
- Regular dependency updates
- Security testing and audits

## 🤝 Contributing

1. Follow the existing code structure
2. Add tests for new features
3. Update documentation
4. Follow TypeScript best practices
5. Test on both iOS and Android platforms

## 📄 License

This project is part of the SlackClone application suite.

## 🔗 Related Projects

- **Backend**: Phoenix/Elixir API server
- **Web Dashboard**: Next.js administration interface
- **Documentation**: Complete system architecture guides

---

**Note**: This mobile client is designed to work with the SlackClone Phoenix backend. Ensure the backend is running and accessible before testing the mobile application.