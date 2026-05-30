# GitHub Actions Build Guide

## Overview

GitHub Actions workflows are configured to automatically build iOS IPA files on every push to `master` or `main` branch.

## Workflows

### 1. iOS Debug Build
- **Trigger**: Every push to `master`, `main`, or `develop`
- **Job**: `build-ios-debug`
- **Output**: Debug IPA file
- **Time**: ~15-20 minutes

### 2. iOS Release Build
- **Trigger**: Push to `master` or `main` only
- **Job**: `build-ios-release`
- **Output**: Release IPA + GitHub Release
- **Time**: ~20-25 minutes
- **Requires**: Signing certificates (optional)

## Workflow File

Location: `.github/workflows/ios-build.yml`

### Key Environment Variables

```yaml
FLUTTER_PROJECT_DIR: .          # Root directory (no subfolder)
IPA_NAME: MusicA.ipa            # Output IPA name
FLUTTER_VERSION: 3.24.0         # Flutter version
```

## Build Steps

### Debug Build Process

1. **Checkout** - Clone repository with LFS
2. **LFS Pull** - Download large model files
3. **Flutter Setup** - Install Flutter SDK
4. **Dependencies** - Run `flutter pub get`
5. **Analysis** - Run `flutter analyze`
6. **Xcode Setup** - Install latest Xcode
7. **CocoaPods** - Install iOS dependencies
8. **Build** - `flutter build ios --debug`
9. **Archive** - Create xcarchive
10. **Export** - Generate IPA file
11. **Upload** - Store IPA as artifact

### Release Build Process

Same as debug, plus:
- Create GitHub Release
- Tag with version number
- Attach IPA to release

## Monitoring Builds

### View Build Status

1. Go to https://github.com/LostLuciano/MusicA
2. Click **Actions** tab
3. Select workflow run
4. View logs in real-time

### Common Build Statuses

| Status | Meaning | Action |
|--------|---------|--------|
| 🟡 Queued | Waiting to start | Wait |
| 🔵 In Progress | Currently building | Monitor logs |
| 🟢 Success | Build completed | Download artifact |
| 🔴 Failed | Build error | Check logs |

## Troubleshooting

### Error: "No such file or directory"

**Cause**: Working directory path is incorrect

**Solution**: Ensure `FLUTTER_PROJECT_DIR` is set correctly
```yaml
FLUTTER_PROJECT_DIR: .  # Root, not flutter_app/
```

### Error: "Pod install failed"

**Cause**: CocoaPods cache issue

**Solution**: Workflow includes `--repo-update` flag
```bash
pod install --repo-update
```

### Error: "LFS objects not found"

**Cause**: Git LFS not properly initialized

**Solution**: Workflow includes LFS setup
```yaml
- uses: actions/checkout@v4
  with:
    lfs: true
```

### Error: "Code signing required"

**Cause**: Trying to sign without certificates

**Solution**: Workflow uses `--no-codesign` flag
```bash
flutter build ios --debug --no-codesign
```

### Error: "Xcode build failed"

**Cause**: Various iOS build issues

**Solution**: Check logs for specific error
1. Go to Actions → Failed workflow
2. Expand "Build iOS App" step
3. Look for error message
4. Common fixes:
   - Update CocoaPods: `pod repo update`
   - Clean build: `flutter clean`
   - Update Flutter: `flutter upgrade`

## Downloading Artifacts

### From GitHub UI

1. Go to Actions tab
2. Click on workflow run
3. Scroll to "Artifacts" section
4. Click IPA file to download

### From Command Line

```bash
# List artifacts
gh run list --repo LostLuciano/MusicA

# Download artifact
gh run download <RUN_ID> -n ios-debug-ipa
```

## Configuring Secrets

For release builds with code signing:

### 1. Generate Certificates

```bash
# Export certificate as base64
base64 -i certificate.p12 | pbcopy

# Export provisioning profile as base64
base64 -i profile.mobileprovision | pbcopy
```

### 2. Add GitHub Secrets

1. Go to repository Settings
2. Click Secrets and variables → Actions
3. Add new secrets:
   - `IOS_CERTIFICATE_BASE64` - Certificate file
   - `IOS_CERTIFICATE_PASSWORD` - Certificate password
   - `IOS_PROVISIONING_PROFILE_BASE64` - Provisioning profile

### 3. Uncomment in Workflow

In `.github/workflows/ios-build.yml`, uncomment:
```yaml
# - name: Import Certificates
# - name: Install Provisioning Profile
```

## Performance Tips

### Speed Up Builds

1. **Cache Flutter**
   - Already enabled in workflow
   - Saves ~5 minutes per build

2. **Cache CocoaPods**
   - Add to workflow:
   ```yaml
   - uses: actions/cache@v3
     with:
       path: ios/Pods
       key: ${{ runner.os }}-pods-${{ hashFiles('ios/Podfile.lock') }}
   ```

3. **Parallel Jobs**
   - Debug and release can run in parallel
   - Currently sequential to save resources

### Reduce Build Size

1. **Strip Debug Symbols**
   ```yaml
   - name: Strip Debug Symbols
     run: strip build/ios/Release-iphoneos/Runner.app/Runner
   ```

2. **Compress IPA**
   ```bash
   zip -r MusicA.ipa.zip MusicA.ipa
   ```

## Debugging Workflow

### Enable Debug Logging

Add to workflow step:
```yaml
env:
  RUNNER_DEBUG: 1
```

### View Full Logs

1. Click on failed step
2. Expand all sections
3. Look for error details

### Test Locally

```bash
# Simulate workflow locally
cd flutter_app
flutter pub get
flutter build ios --debug --no-codesign
```

## Maintenance

### Update Flutter Version

Edit `.github/workflows/ios-build.yml`:
```yaml
FLUTTER_VERSION: 3.24.0  # Change this
```

### Update Xcode Version

Edit workflow:
```yaml
- uses: maxim-lobanov/setup-xcode@v1
  with:
    xcode-version: 'latest-stable'  # or specific version
```

### Update CocoaPods

Workflow automatically updates:
```bash
pod install --repo-update
```

## Best Practices

1. **Always test locally first**
   ```bash
   flutter build ios --debug --no-codesign
   ```

2. **Keep workflow simple**
   - Avoid complex logic
   - Use standard actions

3. **Monitor build times**
   - Track trends
   - Optimize if > 30 minutes

4. **Document changes**
   - Update this guide
   - Add comments to workflow

5. **Use meaningful commit messages**
   - Helps identify which build caused issues

## Useful Commands

```bash
# View workflow runs
gh run list --repo LostLuciano/MusicA

# View specific run
gh run view <RUN_ID> --repo LostLuciano/MusicA

# Download artifact
gh run download <RUN_ID> -n ios-debug-ipa

# View logs
gh run view <RUN_ID> --log --repo LostLuciano/MusicA
```

## Support

### Common Issues

| Issue | Solution |
|-------|----------|
| Build timeout | Increase timeout in workflow |
| Out of disk space | Clean artifacts regularly |
| LFS quota exceeded | Upgrade GitHub LFS quota |
| Slow builds | Enable caching, use faster runner |

### Resources

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Flutter CI/CD](https://docs.flutter.dev/deployment/cd)
- [Xcode Build Guide](https://developer.apple.com/documentation/xcode)

---

**Last Updated**: 2024
**Workflow Version**: 2.0
**Status**: ✅ Production Ready
