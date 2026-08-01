# gemma-mobile-manifest Specification

> NEW: Android manifest hardening for low-RAM AI inference

## Purpose

Signal the Android OS to allocate a larger JVM heap and release GPU memory for native inference, improving stability on 3.8 GB devices (SR-B07).

## Requirements

### Requirement: Large Heap Declaration

The `<application>` element in `AndroidManifest.xml` SHALL include `android:largeHeap="true"` to signal the OS to increase the Dalvik/ART heap limit.

#### Scenario: App starts with largeHeap enabled

- GIVEN the APK is installed on a 4 GB device
- WHEN the app process starts
- THEN `ActivityManager.isLargeHeap()` MUST return true at runtime
- AND the JVM heap limit SHALL be higher than the device default

### Requirement: RAM Feature Declaration

The manifest SHALL include `<uses-feature android:name="android.hardware.ram" android:required="false"/>` to declare the app's RAM dependency without blocking installation on low-RAM devices.

#### Scenario: App installs on 2 GB device despite RAM declaration

- GIVEN `android:required="false"` on the RAM feature
- WHEN the APK is installed on a 2 GB device
- THEN installation MUST succeed
- AND Google Play SHALL NOT filter the app from low-RAM device listings

### Requirement: Hardware Acceleration Disabled

The `<application>` element SHALL include `android:hardwareAccelerated="false"` to free GPU memory for native Gemma 4 tensor allocations.

#### Scenario: GPU memory available for native inference

- GIVEN `hardwareAccelerated="false"` on a 4 GB device
- WHEN the app renders Flutter UI
- THEN Flutter SHALL use Skia software rendering
- AND GPU memory SHALL be available for native C++ allocations
- AND UI responsiveness SHALL remain acceptable at 60 fps for non-animated content
