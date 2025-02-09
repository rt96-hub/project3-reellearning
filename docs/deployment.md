# Build and Release Guidelines

Below is a single markdown document describing how to build and deploy your Flutter Android app, integrating both local build instructions and the automated CI/CD approach that uses GitHub Actions and Google Drive as outlined in your coworker’s documents.

---

## Overview

This guide explains:
1. How to build and sign the Flutter APK locally for testing or manual distribution.  
2. How these steps integrate with the GitHub Actions workflow (.github/workflows/build_and_deploy.yml) to automate builds and uploads to Google Drive.

---

## 1. Prerequisites

### 1.1 Local Setup
- Install Flutter SDK (matching the version used in your GitHub Actions workflow, e.g., 3.16.5).
- Install Java (JDK 17 recommended).
- Android Studio or Android SDK tools for local development.

### 1.2 Keystore for Signing
- Generate or use an existing keystore.  
- Base64-encode it for storing as a GitHub secret if you plan to use the CI/CD pipeline:
```
base64 keystore.jks > keystore_base64.txt
```

### 1.3 Google Drive Service Account (For Automated Distribution)
- Create a new project in Google Cloud Console and enable Drive API.
- Create a service account with appropriate Drive folder permissions.
- Download the JSON file and base64-encode it:
```
base64 credentials.json > credentials_base64.txt
```

- Add these encoded strings (and your folder/file IDs) as GitHub secrets:
  - `GDRIVE_CREDENTIALS`
  - `GDRIVE_FOLDER_ID`
  - `GDRIVE_FILE_ID`
  - `VERSION_FILE_ID`

---

## 2. Local Build & Signing

If you need to build the APK locally for testing or manual distribution, follow these steps:

1. **Configure signing in android/app/build.gradle**  
   If you want a manual setup, you can create a key.properties file and load it in the Gradle script. Or you can directly reference the debug signing config. For production, typically you do:
```
signingConfigs {
    release {
        storeFile file("keystore.jks")
        storePassword System.getenv("STORE_PASSWORD")
        keyAlias System.getenv("KEY_ALIAS")
        keyPassword System.getenv("KEY_PASSWORD")
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
    }
}
```

2. **Build the release APK:**
```
flutter build apk --release
```
3. **Locate the signed APK** in:
```
build/app/outputs/flutter-apk/app-release.apk
```
4. **Distribute the APK** via any preferred channel (e.g., email, file-sharing service, or direct web download).

---

## 3. Continuous Integration (CI) with GitHub Actions

Your coworker’s setup includes a GitHub Actions YAML file (.github/workflows/build_and_deploy.yml) that automates the entire process:

1. **Trigger Conditions:**
   - Push to the main branch
   - Tag creation (e.g., pushing a version tag v1.0.0)
   - Manual triggers (workflow_dispatch)

2. **Actions Steps** (simplified list):
   1. Checkout the repository  
   2. Set up Java (JDK 17)  
   3. Install the specified Flutter version  
   4. Install dependencies (flutter pub get)  
   5. Decode the keystore from your base64 GitHub secret if needed  
   6. Build the signed APK (using your keystore secrets)  
   7. Upload the APK to Google Drive using your service account  
   8. Update the version.json file with new version info and release notes  

You can review the core steps in the snippet below. Just note that your secrets must already exist in the GitHub repository settings:

```
name: Build and Deploy
on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up Java
      uses: actions/setup-java@v3
      with:
        java-version: '17'

    - name: Set up Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.5'
        channel: 'stable'

    - name: Get dependencies
      run: flutter pub get

    - name: Decode Keystore
      env:
        KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
      run: |
        echo $KEYSTORE_BASE64 | base64 -d > android/app/keystore.jks

    - name: Build APK
      env:
        KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
        KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        STORE_PASSWORD: ${{ secrets.STORE_PASSWORD }}
      run: |
        flutter build apk --release \
          --build-name=$(echo ${GITHUB_REF_NAME#v}) \
          --build-number=$GITHUB_RUN_NUMBER

    # ... Next steps for Google Drive upload and version file update ...
```

This workflow ensures every commit or version tag triggers a fresh build, signs your APK, and distributes it automatically.

---

## 4. Distribution Through Google Drive

After the workflow completes, Google Drive will host your `.apk` and the updated `version.json`, containing information like:
- Version number
- Build number
- Download link
- Release notes

Within your app, you can optionally check that `version.json` for updates and prompt the user to install a new version if available.

---

## 5. Integrating Local & CI Processes

1. **Local Testing:** You can run ```flutter run``` or ```flutter build apk --release``` locally for quick checks.  
2. **Automated Release:** Push your changes to main or tag a release in Git; GitHub Actions does the rest.

### Key Points:
- Ensure the `signingConfig` in your Gradle matches what the CI pipeline expects.  
- Keep your keystore and service account credentials safe by using GitHub secrets.  
- The same steps (build, sign, upload) happen locally or in CI, guaranteeing consistent builds.

---

## 6. Recommended File Structure

Below is a simplified view of key files in your Flutter project:

```
your_flutter_project/
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   └── keystore.jks (excluded from version control, stored in GH secret)
│   └── gradle.properties (optional config)
│
├── lib/
│   └── main.dart
├── .github/
│   └── workflows/
│       └── build_and_deploy.yml
├── pubspec.yaml
├── build/ (ignored)
└── ...
```

---

## 7. Security Considerations

- **Keystore**: Never commit the keystore file directly to your repository.  
- **GitHub Secrets**: Use repository-level or organization-level secrets for your keystore and service account.  
- **Drive Permissions**: The service account has only the minimal permissions to upload files to the designated folder.  

---

## 8. Conclusion

With this setup:  
1. **Locally**: You can build the app using ```flutter build apk --release```.  
2. **Remotely**: The GitHub Actions workflow automatically performs the same steps, uploads the APK to Google Drive, and updates version metadata.  

This integration ensures consistent, reliable, and secure distribution of your Flutter Android app to testers or end users without manually handling every deployment.
