# gemma-native-removal Specification

## Purpose

Defines the removal of all llama.cpp native code, CMake build configuration, and the Kotlin JNI bridge after flutter_gemma migration.

## Requirements

### Requirement: Native Build Removal

The system MUST build successfully without CMake, NDK native compilation, or JNI linking.

#### Scenario: APK builds without native compilation

- GIVEN the migration to flutter_gemma is complete
- WHEN `flutter build apk --debug` is executed
- THEN the build completes without invoking CMake or native compilers
- AND build.gradle contains no externalNativeBuild, noCompress 'gguf', or abiFilters blocks referencing native code
- AND the cpp/ directory is absent from the project tree

#### Scenario: No missing plugin errors at startup

- GIVEN GemmaEngine.kt is deleted
- AND MainActivity.kt no longer registers GemmaEngine MethodChannel
- WHEN the app starts on a device
- THEN no MissingPluginException or method-not-implemented errors are logged for 'gemma_engine' channel
- AND the Keystore MethodChannel remains functional

### Requirement: Legacy Branch Preservation

The system SHALL retain the llama.cpp implementation on a git branch for emergency rollback.

#### Scenario: Rollback via git checkout

- GIVEN migration is committed on the main branch
- WHEN the legacy-llamacpp branch is checked out
- THEN all original cpp/, GemmaEngine.kt, CMake config, and build.gradle settings are restored
- AND `flutter build apk --debug` succeeds with the original MethodChannel engine
