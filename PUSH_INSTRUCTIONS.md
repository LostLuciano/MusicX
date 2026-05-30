# 📤 Push to GitHub Instructions

## Prerequisites Checklist

Before pushing to GitHub, ensure you have:

- [x] Git installed
- [x] Git LFS installed (`brew install git-lfs` or download from https://git-lfs.github.com/)
- [x] GitHub account
- [x] Repository created: https://github.com/LostLuciano/MusicA

## Step-by-Step Instructions

### 1. Initialize Git LFS

```bash
# Install Git LFS (if not already installed)
brew install git-lfs  # macOS
# or download from https://git-lfs.github.com/ for Windows

# Initialize Git LFS
git lfs install
```

### 2. Verify Git LFS Tracking

Check that `.gitattributes` includes:
```
*.mlmodelc filter=lfs diff=lfs merge=lfs -text
**/*.mlmodelc/** filter=lfs diff=lfs merge=lfs -text
*.caf filter=lfs diff=lfs merge=lfs -text
*.m4a filter=lfs diff=lfs merge=lfs -text
```

### 3. Initialize Git Repository (if not already done)

```bash
cd "d:\IPA Project\KIro\MusicP\flutter_app"

# Initialize git
git init

# Add remote
git remote add origin https://github.com/LostLuciano/MusicA.git
```

### 4. Add and Commit Files

```bash
# Add all files
git add .

# Check status
git status

# Commit
git commit -m "Initial commit: Music Stem Studio v1.0.0

Features:
- AI-powered stem separation (6 stems)
- Chord detection with CRNN
- Beat & tempo analysis with TCN
- Multi-track recording
- Project library management
- User profile & settings
- Studio settings with model checker
- CoreML models integrated
- GitHub Actions CI/CD configured"
```

### 5. Push to GitHub

```bash
# Push to main branch
git push -u origin main

# Or if using master branch
git push -u origin master
```

### 6. Verify Upload

1. Go to https://github.com/LostLuciano/MusicA
2. Check that all files are uploaded
3. Verify Git LFS files are tracked (look for "Stored with Git LFS" badge)
4. Check GitHub Actions tab for build status

## Using the Push Scripts

### On macOS/Linux:

```bash
# Make script executable
chmod +x push_to_github.sh

# Run script
./push_to_github.sh "Your commit message"
```

### On Windows:

```cmd
# Run batch script
push_to_github.bat "Your commit message"
```

## Important Notes

### Git LFS Files

The following large files are tracked with Git LFS:
- `ios/Runner/*.mlmodelc/` (CoreML models, ~65 MB total)
- `ios/Runner/*.caf` (Audio samples)
- `ios/Runner/*.m4a` (Audio samples)

### GitHub Actions

After pushing, GitHub Actions will automatically:
1. Build iOS debug version
2. Run tests and analysis
3. Upload IPA artifact (if build succeeds)

### Secrets Configuration

For release builds, configure these secrets in GitHub:
1. Go to repository Settings → Secrets and variables → Actions
2. Add the following secrets:
   - `IOS_CERTIFICATE_BASE64`
   - `IOS_CERTIFICATE_PASSWORD`
   - `IOS_PROVISIONING_PROFILE_BASE64`

## Troubleshooting

### Git LFS Not Working

```bash
# Reinstall Git LFS
git lfs install --force

# Fetch all LFS files
git lfs fetch --all

# Pull LFS files
git lfs pull
```

### Large Files Error

If you get "file too large" error:
```bash
# Ensure Git LFS is tracking the files
git lfs track "*.mlmodelc"
git lfs track "**/*.mlmodelc/**"

# Add .gitattributes
git add .gitattributes
git commit -m "Add Git LFS tracking"
```

### Push Rejected

If push is rejected:
```bash
# Pull first
git pull origin main --rebase

# Then push
git push origin main
```

### Authentication Issues

If you have authentication issues:
```bash
# Use personal access token
git remote set-url origin https://YOUR_TOKEN@github.com/LostLuciano/MusicA.git
```

## Post-Push Checklist

After successful push:

- [ ] Verify all files uploaded
- [ ] Check Git LFS files are tracked
- [ ] Review GitHub Actions build status
- [ ] Update ExportOptions.plist with your Team ID
- [ ] Configure GitHub secrets for release builds
- [ ] Test clone on another machine
- [ ] Update README if needed

## Next Steps

1. **Configure CI/CD Secrets** (for release builds)
2. **Test Build** on GitHub Actions
3. **Create Release** when ready
4. **Update Documentation** as needed
5. **Share Repository** with team

## Support

If you encounter issues:
1. Check [BUILD_GUIDE.md](BUILD_GUIDE.md) troubleshooting section
2. Review GitHub Actions logs
3. Check Git LFS status: `git lfs ls-files`
4. Verify remote: `git remote -v`

---

**Ready to push?** Run the push script or follow the manual steps above! 🚀
