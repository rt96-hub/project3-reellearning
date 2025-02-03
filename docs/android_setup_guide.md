# Android Development Setup Guide

## Setting up Android SDK Command-line Tools

1. Locate your Android SDK path:
   - Open Android Studio
   - Go to Settings/Preferences (File > Settings)
   - Navigate to Appearance & Behavior > System Settings > Android SDK
   - Note the "Android SDK Location" path

2. Add SDK platform-tools to your system PATH:
   - Open Windows Search
   - Type "Environment Variables"
   - Click "Edit the system environment variables"
   - Click "Environment Variables"
   - Under "System Variables", find and select "Path"
   - Click "Edit"
   - Click "New"
   - Add these paths (replace <SDK_PATH> with your actual SDK path):
     ```
     <SDK_PATH>\platform-tools
     <SDK_PATH>\cmdline-tools\latest\bin
     ```

3. Install command-line tools:
   - Open Command Prompt as Administrator
   - Run: `sdkmanager --install "cmdline-tools;latest"`
   - Run: `flutter doctor --android-licenses`
   - Accept all licenses when prompted 