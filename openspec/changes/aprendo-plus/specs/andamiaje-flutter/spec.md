# andamiaje-flutter Specification

## Purpose

Flutter 3.x project scaffold for Aprendo+. Establishes build configuration, dependency management, static analysis, and entry point wiring for the offline-first Android target.

## Requirements

### Requirement: Project Scaffold

The project MUST initialize as a Flutter 3.x application targeting Android with Dart SDK constraints defined in `pubspec.yaml` and strict linting via `analysis_options.yaml`.

#### Scenario: Scaffold validates

- GIVEN a developer runs `flutter pub get`
- WHEN all dependencies from `pubspec.yaml` resolve
- THEN the project compiles with `flutter build apk --debug` without errors
- AND `dart analyze` reports zero issues under the strict lint rules

### Requirement: Dependency Declaration

`pubspec.yaml` SHALL declare the following runtime dependencies with locked compatible versions: `flutter`, `provider`, `sqflite_sqlcipher`, `connectivity_plus`, `pdf`, `printing`. Dev dependencies SHALL include `flutter_lints` with the recommended lint set.

#### Scenario: Dependencies resolve

- GIVEN `pubspec.yaml` lists all required packages
- WHEN `flutter pub get` executes
- THEN all packages resolve without version conflicts
- AND `pubspec.lock` is generated

### Requirement: Android Build Configuration

`android/app/build.gradle` MUST configure `minSdkVersion 23` (Android 6.0), `targetSdkVersion 34`, and `compileSdkVersion 34`. ProGuard rules in `android/app/proguard-rules.pro` SHALL preserve SQLCipher native symbols.

#### Scenario: Build targets correct API levels

- GIVEN the Android build.gradle is configured
- WHEN the APK is built
- THEN `minSdkVersion` is 23 and `targetSdkVersion` is 34
- AND the app installs on Android 6.0+ devices

### Requirement: Application Entry Point

`lib/main.dart` SHALL initialize the Flutter app with a `Provider`-based dependency injection root, create the encrypted database service, and mount the diagnostic screen as the initial route within a `MaterialApp` (Material Design 3).

#### Scenario: App launches to diagnostic

- GIVEN a fresh app install on an Android device
- WHEN the user opens the app
- THEN `main()` initializes Provider and the database
- AND the diagnostic screen is displayed as the first route
