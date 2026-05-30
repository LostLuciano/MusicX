#!/bin/bash

# Script untuk push project ke GitHub
# Usage: ./push_to_github.sh "commit message"

set -e

echo "🚀 Music Stem Studio - GitHub Push Script"
echo "=========================================="

# Check if Git LFS is installed
if ! command -v git-lfs &> /dev/null; then
    echo "❌ Git LFS not found. Installing..."
    brew install git-lfs
    git lfs install
fi

# Initialize Git LFS if not already done
git lfs install

# Check if remote exists
if ! git remote get-url origin &> /dev/null; then
    echo "📡 Adding remote repository..."
    git remote add origin https://github.com/LostLuciano/MusicA.git
else
    echo "✅ Remote repository already configured"
fi

# Get commit message
COMMIT_MSG="${1:-Update: $(date +'%Y-%m-%d %H:%M:%S')}"

echo ""
echo "📝 Commit message: $COMMIT_MSG"
echo ""

# Check Git LFS tracked files
echo "🔍 Checking Git LFS tracked files..."
git lfs ls-files

# Add all changes
echo "➕ Adding changes..."
git add .

# Show status
echo ""
echo "📊 Git status:"
git status --short

# Commit changes
echo ""
echo "💾 Committing changes..."
git commit -m "$COMMIT_MSG" || echo "⚠️  No changes to commit"

# Push to GitHub
echo ""
echo "⬆️  Pushing to GitHub..."
git push -u origin main || git push -u origin master

echo ""
echo "✅ Successfully pushed to GitHub!"
echo "🔗 Repository: https://github.com/LostLuciano/MusicA"
echo ""
echo "📦 Don't forget to:"
echo "  1. Check GitHub Actions for build status"
echo "  2. Configure secrets for release builds"
echo "  3. Update ExportOptions.plist with your Team ID"
