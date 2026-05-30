# Music Stem Studio - Build Guide

## 📋 Prerequisites

### Required Software
- **macOS** (for iOS builds)
- **Xcode** 15.0 or later
- **Flutter SDK** 3.24.0 or later
- **CocoaPods** 1.12.0 or later
- **Git LFS** (for large model files)

### Install Git LFS
```bash
# macOS
brew install git-lfs
git lfs install

# After cloning the repo
git lfs pull
```

## 🔧 Setup Instructions

### 1. Clone Repository
```bash
git clone https://github.com/LostLuciano/MusicA.git
cd MusicA/flutter_app
```

### 2. Install Flutter Dependencies
```bash
flutter pub get
```

### 3. Install iOS Dependencies
```bash
cd ios
pod install
cd ..
```

### 4. Verify CoreML Models
Check that the following models are present in `ios/Runner/`:
- ✅ `dun_tfc_tdf_b9_l3_w_6stems_32_fp32_v2.0.1.mlmodelc` (Stem Separation - FP32)
- ✅ `dunlight_tfc_tdf_b9_l3_w_subv1_cirm_6stems_64_fp16_v2.0.0.mlmodelc` (Stem Separation - FP16)
- ✅ `Chordcrnn.mlmodelc` (Chord Detection)
- ✅ `convtcn20_2048_fp16.mlmodelc` (Beat & Tempo Detection)

These models are tracked with Git LFS and should be automatically downloaded.

## 🏗️ Building the App

### Debug Build (No Code Signing)
```bash
# Build for simulator
flutter build ios --debug --simulator

# Build for device (requires signing)
flutter build ios --debug
```

### Release Build (Requires Code Signing)
```bash
flutter build ios --release
```

### Create IPA File
```bash
# Using Xcode
cd ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ../ExportOptions.plist
```

## 🔐 Code Signing Setup

### For Development
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to "Signing & Capabilities"
4. Select your Team
5. Xcode will automatically manage provisioning profiles

### For Distribution
1. Create an App ID in Apple Developer Portal
2. Create a Distribution Certificate
3. Create a Distribution Provisioning Profile
4. Update `ExportOptions.plist` with your Team ID
5. Configure signing in Xcode

## 🤖 GitHub Actions CI/CD

### Automated Builds
The repository includes GitHub Actions workflows for automated builds:

- **Debug Build**: Runs on every push to `main` or `develop`
- **Release Build**: Runs only on `main` branch (requires secrets)

### Required GitHub Secrets
For release builds, configure these secrets in your repository:

```
IOS_CERTIFICATE_BASE64          # Base64 encoded .p12 certificate
IOS_CERTIFICATE_PASSWORD        # Password for the certificate
IOS_PROVISIONING_PROFILE_BASE64 # Base64 encoded provisioning profile
```

### Encoding Certificates
```bash
# Encode certificate
base64 -i certificate.p12 | pbcopy

# Encode provisioning profile
base64 -i profile.mobileprovision | pbcopy
```

## 📱 Running on Device

### Via Xcode
1. Open `ios/Runner.xcworkspace`
2. Select your device
3. Click Run (⌘R)

### Via Flutter CLI
```bash
flutter run --release
```

## 🧪 Testing

### Run Unit Tests
```bash
flutter test
```

### Run Integration Tests
```bash
flutter drive --target=test_driver/app.dart
```

## 🐛 Troubleshooting

### CocoaPods Issues
```bash
cd ios
pod deintegrate
pod install
```

### Build Cache Issues
```bash
flutter clean
flutter pub get
cd ios
pod install
```

### Git LFS Issues
```bash
git lfs fetch --all
git lfs pull
```

### Model Files Not Found
Ensure Git LFS is installed and models are pulled:
```bash
git lfs install
git lfs pull
```

Check `.gitattributes` includes:
```
*.mlmodelc filter=lfs diff=lfs merge=lfs -text
**/*.mlmodelc/** filter=lfs diff=lfs merge=lfs -text
```

## 📊 Model Information

### Stem Separation Models
- **FP32 Model**: Higher quality, larger size (~45 MB)
- **FP16 Model**: Optimized for mobile, smaller size (~23 MB)
- Both models support 6-stem separation: vocals, drums, bass, guitar, piano, other

### Chord Detection Model
- **CRNN Architecture**: Convolutional Recurrent Neural Network
- **Size**: ~8 MB
- **Classes**: 170 chord types

### Beat Detection Model
- **TCN Architecture**: Temporal Convolutional Network
- **Size**: ~12 MB
- **Features**: BPM detection, beat tracking, downbeat detection

## 🚀 Performance Optimization

### Neural Engine Acceleration
The app uses Apple's Neural Engine (ANE) for optimal performance:
- Stem separation: ~2-3 seconds per track
- Chord detection: ~1 second per track
- Beat detection: ~0.5 seconds per track

### Buffer Size Settings
Adjust in app settings for latency vs. CPU trade-off:
- **64 samples**: Lowest latency, highest CPU
- **256 samples**: Balanced (recommended)
- **512 samples**: Lower CPU, higher latency

## 📝 Version Information

- **App Version**: 1.0.0
- **Build Number**: 1
- **Flutter SDK**: 3.24.0
- **Minimum iOS**: 14.0
- **Target iOS**: 17.0

## 🔗 Useful Links

- [Flutter Documentation](https://docs.flutter.dev/)
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)
- [CoreML Documentation](https://developer.apple.com/documentation/coreml)
- [GitHub Repository](https://github.com/LostLuciano/MusicA)

## 📧 Support

For issues or questions:
- Open an issue on GitHub
- Check existing documentation
- Review troubleshooting section

---

**Note**: This app requires a physical iOS device for full functionality. The simulator does not support CoreML Neural Engine acceleration.
