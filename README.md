# Music Stem Studio 🎵

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.24.0-02569B?logo=flutter)
![iOS](https://img.shields.io/badge/iOS-14.0+-000000?logo=apple)
![CoreML](https://img.shields.io/badge/CoreML-Enabled-FF6F00?logo=apple)
![License](https://img.shields.io/badge/License-MIT-green)

**AI-Powered Music Production Studio for iOS**

[Features](#-features) • [Installation](#-installation) • [Build Guide](#-build-guide) • [Architecture](#-architecture) • [Contributing](#-contributing)

</div>

---

## 📖 Overview

Music Stem Studio adalah aplikasi studio musik profesional untuk iOS yang menggunakan AI untuk memisahkan audio menjadi stem individual, mendeteksi chord, dan menganalisis tempo. Dibangun dengan Flutter dan memanfaatkan Apple Neural Engine untuk performa optimal.

### ✨ Key Features

#### 🎛️ **Stem Mixer (AI-Powered Separation)**
- Pisahkan audio menjadi 6 stem individual:
  - 🎤 Vocals
  - 🥁 Drums
  - 🎸 Bass
  - 🎹 Piano
  - 🎸 Guitar
  - 🎵 Other
- Kontrol volume per stem
- Mode solo/mute untuk setiap stem
- Real-time mixing dengan zero-latency
- Menggunakan HTDemucs CoreML model

#### 🎼 **Chord Viewer (Harmoni Analysis)**
- Deteksi akor otomatis dari audio
- Visualisasi chord progression secara real-time
- 170+ jenis chord yang didukung
- Segmentasi chord dengan timestamp akurat
- Menggunakan CRNN (Convolutional Recurrent Neural Network)

#### 🥁 **Beat & Tempo Analyzer**
- Deteksi BPM (tempo) otomatis
- Beat tracking dengan akurasi tinggi
- Downbeat detection
- Metronome visual dan audio
- Menggunakan TCN (Temporal Convolutional Network)

#### 🎙️ **Multi-Track Recording**
- Rekam gitar via audio interface
- Rekam dengan kamera (audio + video)
- Multiple takes per project
- Playback dengan sync sempurna

#### 📚 **Project Library**
- Manajemen project yang terorganisir
- Auto-save functionality
- Import audio/video files
- Export dan share hasil rekaman

#### 👤 **User Profile & Settings**
- Customizable profile dengan foto
- Studio settings (buffer size, sample rate)
- CoreML processing mode selection
- Model availability checker

---

## 🚀 Installation

### Prerequisites
- macOS (for iOS development)
- Xcode 15.0+
- Flutter SDK 3.24.0+
- CocoaPods 1.12.0+
- Git LFS (for model files)

### Quick Start

```bash
# Clone repository
git clone https://github.com/LostLuciano/MusicA.git
cd MusicA/flutter_app

# Install Git LFS and pull models
brew install git-lfs
git lfs install
git lfs pull

# Install dependencies
flutter pub get
cd ios && pod install && cd ..

# Run on simulator
flutter run

# Build for device
flutter build ios --release
```

For detailed build instructions, see [BUILD_GUIDE.md](BUILD_GUIDE.md)

---

## 🏗️ Architecture

### Tech Stack
- **Frontend**: Flutter/Dart
- **iOS Native**: Swift
- **Audio Engine**: AVAudioEngine
- **ML Framework**: CoreML + Apple Neural Engine
- **DSP**: STFT/iSTFT Pipeline
- **State Management**: Provider

### Project Structure
```
flutter_app/
├── lib/
│   ├── core/           # Core utilities & constants
│   ├── features/       # Feature modules
│   │   ├── home/
│   │   ├── player/
│   │   ├── recorder/
│   │   ├── stem_mixer/
│   │   ├── chord_viewer/
│   │   ├── beat_tempo/
│   │   └── profile/
│   ├── models/         # Data models
│   ├── services/       # Business logic services
│   ├── state/          # State management
│   └── widgets/        # Reusable widgets
├── ios/
│   └── Runner/
│       ├── *.mlmodelc/              # CoreML models
│       ├── FlutterMethodChannelBridge.swift
│       ├── CoreMLStemSeparator.swift
│       ├── ChordDetectionManager.swift
│       ├── BeatDetectionManager.swift
│       └── AudioEngineManager.swift
└── .github/
    └── workflows/      # CI/CD pipelines
```

### CoreML Models

| Model | Purpose | Size | Architecture |
|-------|---------|------|--------------|
| HTDemucs FP32 | Stem Separation (High Quality) | ~45 MB | Dense U-Net |
| HTDemucs FP16 | Stem Separation (Optimized) | ~23 MB | Dense U-Net |
| Chordcrnn | Chord Detection | ~8 MB | CRNN |
| ConvTCN | Beat & Tempo Detection | ~12 MB | TCN |

For detailed model specifications, see [AI_MODEL_REQUIREMENTS.md](ios/AI_MODEL_REQUIREMENTS.md)

---

## 🎨 Screenshots

<div align="center">

| Home Screen | Stem Mixer | Chord Viewer |
|-------------|------------|--------------|
| ![Home](docs/screenshots/home.png) | ![Mixer](docs/screenshots/mixer.png) | ![Chords](docs/screenshots/chords.png) |

| Beat Analyzer | Recording | Profile |
|---------------|-----------|---------|
| ![Beat](docs/screenshots/beat.png) | ![Record](docs/screenshots/record.png) | ![Profile](docs/screenshots/profile.png) |

</div>

---

## 🔧 Configuration

### Studio Settings
- **Buffer Size**: 64, 128, 256, 512 samples
- **Sample Rate**: 44.1 kHz, 48.0 kHz
- **Processing Mode**: CPU Only, GPU Accel, Neural Engine
- **Auto-Save**: Configurable interval (1-30 minutes)
- **Metronome**: Auto-enable on recording

### Performance Tuning
- **Low Latency**: Buffer size 64-128 (higher CPU usage)
- **Balanced**: Buffer size 256 (recommended)
- **Low CPU**: Buffer size 512 (higher latency)

---

## 🤖 CI/CD

GitHub Actions workflows are configured for automated builds:

### Workflows
- **iOS Debug Build**: Runs on every push
- **iOS Release Build**: Runs on main branch (requires signing)

### Setup GitHub Secrets
For release builds, add these secrets:
```
IOS_CERTIFICATE_BASE64
IOS_CERTIFICATE_PASSWORD
IOS_PROVISIONING_PROFILE_BASE64
```

See [BUILD_GUIDE.md](BUILD_GUIDE.md) for detailed CI/CD setup.

---

## 📊 Performance

### Processing Times (iPhone 14 Pro)
- **Stem Separation**: ~2-3 seconds per track
- **Chord Detection**: ~1 second per track
- **Beat Detection**: ~0.5 seconds per track

### System Requirements
- **Minimum**: iOS 14.0
- **Recommended**: iOS 16.0+
- **Device**: iPhone 12 or later (for Neural Engine)
- **Storage**: 200 MB free space

---

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter drive --target=test_driver/app.dart

# Analyze code
flutter analyze
```

---

## 🐛 Troubleshooting

### Common Issues

**Models not loading?**
```bash
git lfs pull
```

**Build errors?**
```bash
flutter clean
flutter pub get
cd ios && pod install
```

**CocoaPods issues?**
```bash
cd ios
pod deintegrate
pod install
```

For more troubleshooting, see [BUILD_GUIDE.md](BUILD_GUIDE.md#-troubleshooting)

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines
- Follow Flutter style guide
- Write tests for new features
- Update documentation
- Ensure CI/CD passes

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **HTDemucs**: Hybrid Transformer Demucs for source separation
- **Chordcrnn**: CRNN-based chord recognition
- **ConvTCN**: Temporal Convolutional Network for beat tracking
- **Flutter Team**: Amazing cross-platform framework
- **Apple**: CoreML and Neural Engine

---

## 📧 Contact

- **GitHub**: [@LostLuciano](https://github.com/LostLuciano)
- **Repository**: [MusicA](https://github.com/LostLuciano/MusicA)

---

<div align="center">

**Made with ❤️ for Musicians Worldwide**

⭐ Star this repo if you find it helpful!

</div>
