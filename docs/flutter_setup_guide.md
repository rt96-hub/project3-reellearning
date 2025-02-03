# Flutter Setup and Development Guide (Windows)

This tutorial walks you through:

- **Downloading and installing** all necessary programs
- **Initializing** your first Flutter project
- **Developing, testing, and running** your Flutter app
- **Building** your final APK or app bundle

Below are all the main steps and common terminal commands you’ll use.

---

## 1. Install Necessary Programs

### 1.1 Install the Flutter SDK

1. **Download Flutter SDK**  
   - Go to [Flutter’s official website](https://docs.flutter.dev/get-started/install/windows).
   - Download the latest stable Flutter SDK (usually a `.zip` file).
2. **Extract the SDK**  
   - Extract to a location like: `C:\src\flutter` (avoid folders like `C:\Program Files` which require admin privileges).
3. **Add Flutter to PATH**  
   - Open “Settings” → “System” → “About” → “Advanced system settings” → “Environment Variables…”  
   - Under **System variables** or **User variables**, find **Path** and add the path to `C:\src\flutter\bin`.

### 1.2 Install Android Studio (or Command-Line Tools)

1. **Download & Install**  
   - Go to [Android Studio](https://developer.android.com/studio) and install.
2. **Run Android Studio**  
   - Complete the initial setup wizard, ensuring you install the **Android SDK** and **Platform Tools**.
3. **Install Additional SDK Components**  
   - Open the **SDK Manager** inside Android Studio.  
   - Install the desired **Android SDK** version (e.g., the latest stable) and **System Images** for emulators.

### 1.3 Optional: Install Visual Studio Code

- If you prefer VS Code over Android Studio for editing, [download VS Code](https://code.visualstudio.com/download) and install the **Dart-Code** / **Flutter** extensions.

---

## 2. Verify Your Setup

Use the ```flutter doctor``` command to verify your environment:

```
flutter doctor
```

This checks the Flutter installation, Android SDK setup, connected devices, etc.  
- If there are any issues (shown in red), follow the suggestions to fix them.

---

## 3. Create Your First Flutter Project

Open a new terminal (Command Prompt or PowerShell) in your desired workspace folder, then run:

```
flutter create my_first_app
```

This command creates a new directory named `my_first_app` with the default Flutter template.

**Project Structure** (simplified):

```
my_first_app/
├─ android/
├─ ios/
├─ lib/
│ └─ main.dart # where your main code lives
├─ pubspec.yaml # Flutter/Dart dependencies
└─ test/ # for unit/widget tests
```



---

## 4. Editing & Running the App

### 4.1 Open the Project in Your IDE

- If using **Android Studio**:
  - Click “Open” and select `my_first_app/`.
- If using **VS Code**:
  - Go to “File” → “Open Folder…”, then select `my_first_app/`.

### 4.2 Start an Android Emulator

- **Option A** (Android Studio): Use the **AVD Manager** to create and start an emulator.  
- **Option B** (Command line):  
  1. List available devices:
     ```
     flutter devices
     ```
  2. If you have a single emulator configured, you can start it with:
     ```
     emulator -avd <AVD_NAME>
     ```
     (Requires the Android SDK’s platform tools on your PATH.)

### 4.3 Run the App

Inside your project directory, run:

```
flutter run
```

- This compiles and installs the app on the connected emulator or a device (if you have one plugged in).
- **Hot Reload**: With the app running, make changes in your code and save—Flutter will inject the updated code. Check your terminal/logs for messages about changes reloading.

---

## 5. Development Flow

1. **Write UI** in Dart using Flutter’s [widgets](https://api.flutter.dev/flutter/widgets/widgets-library.html).  
2. **Use Hot Reload** to see changes in (near) real-time.  
3. **Manage dependencies** in `pubspec.yaml`:
   - To add a package (example: `http`), add to `dependencies:` section:
     ```
     dependencies:
       flutter:
         sdk: flutter
       http: ^0.13.5
     ```
   - Then run:
     ```
     flutter pub get
     ```

4. **Testing**:  
   - Create test files in the `test/` folder (e.g., `widget_test.dart`).  
   - Run tests with:
     ```
     flutter test
     ```

---

## 6. Building for Release

### 6.1 Android APK or App Bundle

In your project folder:

- Build an **APK**:
  ```
  flutter build apk
  ```

- Build an **App Bundle** (recommended for Play Store):
  ```
  flutter build appbundle
  ```
  
Flutter will generate the artifact inside `build/app/outputs/`. For full instructions on signing and publishing, see [Flutter’s official docs](https://docs.flutter.dev/deployment/android).

### 6.2 iOS Build

> Note: Requires a Mac to run Xcode or CLI tools.

- Build for **iOS**:
  ```
  flutter build ios
  ```
- Then open `ios/Runner.xcworkspace` in Xcode to archive and submit to the App Store.

---

## 7. Recap of Common Commands

| Command                          | Purpose                                            |
|---------------------------------|----------------------------------------------------|
| ```flutter doctor```      | Checks environment setup                           |
| ```flutter create my_app``` | Creates a new Flutter project                     |
| ```flutter devices```     | Lists connected devices/emulators                  |
| ```flutter run```         | Runs app on available emulator/device              |
| ```flutter pub get```     | Fetches dependencies listed in `pubspec.yaml`      |
| ```flutter build apk```   | Builds a release-ready APK (Android)               |
| ```flutter build appbundle``` | Builds an Android App Bundle (preferred for Play Store) |
| ```flutter build ios```   | Builds an iOS archive (requires Xcode/macOS)       |
| ```flutter test```        | Runs automated tests in the `test/` folder         |

---

## 8. Next Steps

- **Learn Dart** basics: Check out [Dart’s official docs](https://dart.dev/guides) to familiarize yourself with the language features.  
- **Dive into Flutter widgets**: Explore [Flutter widget catalog](https://flutter.dev/docs/development/ui/widgets) to understand layouts, animations, gestures, etc.  
- **Set up CI/CD**: Tools like [GitHub Actions](https://github.com/features/actions) or [Bitrise](https://bitrise.io/) can automate your build, test, and release processes.

---

**Happy coding!** This tutorial should get you up and running with Flutter on Windows. If you need more plugins, UI frameworks, or advanced features (like Firebase, push notifications, or platform channels), consult the official Flutter documentation and package repositories at [pub.dev](https://pub.dev/).

flutter emulators --launch Medium_Phone_API_35