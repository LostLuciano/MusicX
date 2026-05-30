# Build Unsigned iOS IPA - GitHub Actions

**Status**: ✅ Simplified & Ready

---

## Overview

Workflow ini build **unsigned IPA** untuk testing dan development. Tidak memerlukan code signing certificates.

---

## Workflow Details

### File
`.github/workflows/ios-build.yml`

### Trigger
- Push ke `master` atau `main` branch
- Manual trigger via `workflow_dispatch`

### Output
- **Artifact**: `MusicA-unsigned-ipa` (IPA file)
- **Logs**: Build logs jika ada error

---

## Build Process

### 1. Checkout Repository
```yaml
- Checkout code dengan LFS support
- Pull semua LFS objects (CoreML models)
```

### 2. Setup Flutter
```yaml
- Install Flutter 3.24.0
- Cache dependencies
```

### 3. Install Dependencies
```yaml
- flutter pub get
- pod install --repo-update
```

### 4. Build iOS App
```bash
flutter build ios --release --no-codesign
```

### 5. Create Archive
```bash
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

### 6. Export IPA
```bash
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ../ExportOptions.plist
```

### 7. Upload Artifact
- IPA file tersimpan sebagai artifact
- Retention: 30 hari

---

## Directory Structure

```
flutter_app/
├── .github/
│   └── workflows/
│       └── ios-build.yml          ← Workflow file
├── ios/
│   ├── Runner.xcworkspace/
│   ├── Pods/
│   ├── build/
│   │   ├── Runner.xcarchive/      ← Archive
│   │   └── ipa/
│   │       └── Runner.ipa         ← Output IPA
│   └── Podfile
├── ExportOptions.plist            ← Export config
└── pubspec.yaml
```

---

## How to Use

### 1. Push to GitHub
```bash
git add .
git commit -m "Build unsigned IPA"
git push origin master
```

### 2. Monitor Build
1. Go to: https://github.com/LostLuciano/MusicA
2. Click **Actions** tab
3. Select **Build Unsigned iOS IPA** workflow
4. View build progress

### 3. Download IPA
1. Wait for build to complete (green checkmark)
2. Scroll to **Artifacts** section
3. Download `MusicA-unsigned-ipa`
4. Extract ZIP file
5. Get `Runner.ipa`

---

## Build Times

| Step | Time |
|------|------|
| Checkout & LFS | ~2 min |
| Flutter setup | ~3 min |
| Dependencies | ~5 min |
| Build iOS | ~10 min |
| Archive | ~2 min |
| Export IPA | ~2 min |
| **Total** | **~24 min** |

---

## Troubleshooting

### Error: "No such file or directory"

**Cause**: Directory path incorrect

**Solution**: Workflow sudah fixed dengan path yang benar:
- ✅ `flutter pub get` (no cd needed)
- ✅ `cd ios` untuk pod install
- ✅ `cd ios` untuk xcodebuild

### Error: "Pod install failed"

**Cause**: CocoaPods cache issue

**Solution**: Workflow includes `--repo-update`
```bash
pod install --repo-update
```

### Error: "LFS objects not found"

**Cause**: Git LFS not pulled

**Solution**: Workflow includes LFS setup
```yaml
- uses: actions/checkout@v4
  with:
    lfs: true
```

### Error: "Code signing required"

**Cause**: Trying to sign without certificates

**Solution**: Workflow uses `--no-codesign`
```bash
flutter build ios --release --no-codesign
CODE_SIGN_IDENTITY=""
CODE_SIGNING_REQUIRED=NO
```

### Build Hangs

**Cause**: CocoaPods taking too long

**Solution**: 
1. Check GitHub Actions logs
2. Wait for build to complete
3. If timeout, manually run locally:
   ```bash
   cd ios
   pod install --repo-update
   cd ..
   flutter build ios --release --no-codesign
   ```

---

## Local Build (Alternative)

Jika GitHub Actions error, build locally:

### 1. Setup
```bash
cd flutter_app
flutter pub get
cd ios
pod install --repo-update
cd ..
```

### 2. Build
```bash
flutter build ios --release --no-codesign
```

### 3. Create Archive
```bash
cd ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

### 4. Export IPA
```bash
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ../ExportOptions.plist
```

### 5. Get IPA
```bash
ls -la build/ipa/
# Output: Runner.ipa
```

---

## ExportOptions.plist

File ini mengontrol export settings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string></string>
</dict>
</plist>
```

---

## Monitoring Builds

### View Build Status
1. Go to Actions tab
2. Click workflow run
3. View logs in real-time

### Build Statuses

| Status | Meaning |
|--------|---------|
| 🟡 Queued | Waiting to start |
| 🔵 In Progress | Currently building |
| 🟢 Success | Build completed |
| 🔴 Failed | Build error |

### Download Artifacts

```bash
# Using GitHub CLI
gh run list --repo LostLuciano/MusicA
gh run download <RUN_ID> -n MusicA-unsigned-ipa
```

---

## Next Steps

### After Getting IPA

1. **Test on Device**
   - Use Xcode to install on device
   - Or use Apple Configurator 2

2. **Distribute**
   - Send to testers
   - Upload to TestFlight
   - Submit to App Store

3. **Sign for Distribution**
   - Get signing certificates
   - Use signed IPA for App Store

---

## Performance Tips

### Speed Up Builds

1. **Cache Flutter**
   - Already enabled in workflow
   - Saves ~3 minutes

2. **Cache CocoaPods**
   - Add to workflow:
   ```yaml
   - uses: actions/cache@v3
     with:
       path: ios/Pods
       key: ${{ runner.os }}-pods-${{ hashFiles('ios/Podfile.lock') }}
   ```

3. **Parallel Jobs**
   - Currently single job
   - Can add multiple jobs if needed

---

## Debugging

### Enable Debug Logging

Add to workflow:
```yaml
env:
  RUNNER_DEBUG: 1
```

### View Full Logs

1. Click on failed step
2. Expand all sections
3. Look for error details

### Common Issues

| Issue | Solution |
|-------|----------|
| Timeout | Increase timeout or check logs |
| Out of disk | Clean artifacts |
| LFS quota | Upgrade GitHub LFS |
| Slow build | Enable caching |

---

## Resources

- **Workflow File**: `.github/workflows/ios-build.yml`
- **Export Config**: `ExportOptions.plist`
- **Build Guide**: `BUILD_GUIDE.md`
- **GitHub Actions Docs**: https://docs.github.com/en/actions

---

## Summary

✅ **Simplified workflow** untuk build unsigned IPA
✅ **No code signing** diperlukan
✅ **Automatic LFS** support
✅ **Artifact upload** untuk download
✅ **Error handling** dengan logs

**Status**: Ready for use

---

**Last Updated**: May 30, 2026  
**Workflow Version**: 1.0  
**Status**: ✅ Production Ready

