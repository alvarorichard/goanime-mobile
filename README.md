# GoAnime Mobile

A Flutter-based mobile implementation of the popular [GoAnime TUI](https://github.com/alvarorichard/GoAnime) application. This mobile app brings the anime streaming experience to your iOS and Android devices with a beautiful, intuitive interface.

> [!WARNING]
> Running this code may cause unexpected behavior, mild existential crises, or the sudden urge to refactor everything. Proceed with caution! This mobile project is still in early development phase and may be unstable.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.9.2 or higher)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter extensions
- For iOS development: [Xcode](https://developer.apple.com/xcode/) (macOS only)
- [Git](https://git-scm.com/)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/alvarorichard/goanime-mobile.git
cd goanime-mobile
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the Application

#### For Development (Debug Mode)
```bash
# Run on connected device or emulator
flutter run

# Run on specific device
flutter devices  # List available devices
flutter run -d <device_id>
```

#### For Android
```bash
flutter run --release -d android
```

#### For iOS (macOS only)
```bash
flutter run --release -d ios
```

## Building for Production

### Android APK

#### Build APK
```bash
# Build release APK
flutter build apk --release

# Build APK for specific architecture (smaller file size)
flutter build apk --release --target-platform android-arm64
```

The APK file will be located at: `build/app/outputs/flutter-apk/app-release.apk`

#### Build App Bundle (Recommended for Play Store)
```bash
flutter build appbundle --release
```

The AAB file will be located at: `build/app/outputs/bundle/release/app-release.aab`

### iOS App

> **Note**: iOS builds require a macOS machine with Xcode installed and a valid Apple Developer account for distribution.

#### Build for iOS
```bash
# Build iOS app
flutter build ios --release

# Build IPA for distribution
flutter build ipa --release
```

The IPA file will be located at: `build/ios/ipa/`

#### Additional iOS Setup
1. Open `ios/Runner.xcworkspace` in Xcode
2. Configure signing & capabilities with your Apple Developer account
3. Set your Bundle Identifier
4. Configure deployment target (iOS 12.0+)

## Development Setup

### Android Setup
1. Install Android Studio
2. Set up Android SDK and emulator
3. Enable Developer Options and USB Debugging on your Android device

### iOS Setup (macOS only)
1. Install Xcode from the App Store
2. Install Xcode Command Line Tools: `xcode-select --install`
3. Set up iOS Simulator or connect a physical iOS device
4. Sign in with your Apple ID in Xcode

### Flutter Doctor
Run the following command to check your Flutter installation:
```bash
flutter doctor
```

## Supported Platforms

- **Android**: API level 21+ (Android 5.0+)
- **iOS**: iOS 12.0+
- **Web**: Modern web browsers (experimental)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Based on the original [GoAnime TUI](https://github.com/alvarorichard/GoAnime) project
- Built with [Flutter](https://flutter.dev/)
- Video playback powered by [Chewie](https://pub.dev/packages/chewie)

## Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/alvarorichard/goanime-mobile/issues) page
2. Create a new issue if your problem isn't already reported
3. Provide as much detail as possible including:
   - Device information
   - Flutter version
   - Error messages or screenshots

## Updates

Stay updated with the latest features and bug fixes by watching this repository and checking the [Releases](https://github.com/alvarorichard/goanime-mobile/releases) page.

---

**Happy Hacking!**
