@echo off
REM Script untuk push project ke GitHub (Windows)
REM Usage: push_to_github.bat "commit message"

echo.
echo 🚀 Music Stem Studio - GitHub Push Script
echo ==========================================
echo.

REM Check if Git is installed
where git >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Git not found. Please install Git first.
    pause
    exit /b 1
)

REM Check if Git LFS is installed
where git-lfs >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Git LFS not found. Please install Git LFS first.
    echo Download from: https://git-lfs.github.com/
    pause
    exit /b 1
)

REM Initialize Git LFS
git lfs install

REM Check if remote exists
git remote get-url origin >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo 📡 Adding remote repository...
    git remote add origin https://github.com/LostLuciano/MusicA.git
) else (
    echo ✅ Remote repository already configured
)

REM Get commit message
set "COMMIT_MSG=%~1"
if "%COMMIT_MSG%"=="" (
    for /f "tokens=1-4 delims=/ " %%a in ('date /t') do set MYDATE=%%c-%%a-%%b
    for /f "tokens=1-2 delims=: " %%a in ('time /t') do set MYTIME=%%a:%%b
    set "COMMIT_MSG=Update: %MYDATE% %MYTIME%"
)

echo.
echo 📝 Commit message: %COMMIT_MSG%
echo.

REM Check Git LFS tracked files
echo 🔍 Checking Git LFS tracked files...
git lfs ls-files

REM Add all changes
echo ➕ Adding changes...
git add .

REM Show status
echo.
echo 📊 Git status:
git status --short

REM Commit changes
echo.
echo 💾 Committing changes...
git commit -m "%COMMIT_MSG%" || echo ⚠️  No changes to commit

REM Push to GitHub
echo.
echo ⬆️  Pushing to GitHub...
git push -u origin main || git push -u origin master

echo.
echo ✅ Successfully pushed to GitHub!
echo 🔗 Repository: https://github.com/LostLuciano/MusicA
echo.
echo 📦 Don't forget to:
echo   1. Check GitHub Actions for build status
echo   2. Configure secrets for release builds
echo   3. Update ExportOptions.plist with your Team ID
echo.
pause
