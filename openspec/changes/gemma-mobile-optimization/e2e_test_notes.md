# E2E Test Notes: Gemma 4 Mobile Optimization

## Device Requirements for E2E Testing

- **Target device**: 3.8 GB RAM Android device (or any 3-4 GB device)
- **Model file**: `gemma-4-E2B-it-IQ2_XXS.gguf` (~2.0 GB) pushed to `/data/data/com.aprendoplus.app/files/`
- **IQ2_M fallback**: `google_gemma-4-E2B-it-IQ2_M.gguf` (~2.6 GB) pushed to same location

## Pre-test Setup

```bash
# 1. Build the APK
flutter build apk --debug

# 2. Install on device
adb install build/app/outputs/flutter-apk/app-debug.apk

# 3. Push IQ2_XXS model (required for low-RAM path)
adb push gemma-4-E2B-it-IQ2_XXS.gguf /data/data/com.aprendoplus.app/files/

# 4. Push IQ2_M model (fallback)
adb push google_gemma-4-E2B-it-IQ2_M.gguf /data/data/com.aprendoplus.app/files/
```

## Test Scenario: 7-Round Yachay Dispatch on 3.8 GB Device

### Setup
1. Install APK on 3.8 GB device
2. Ensure both IQ2_XXS and IQ2_M GGUF files are in app files directory
3. Launch Aprendo+ app

### Expected Behavior
1. **RAM Detection**: Logcat should show:
   ```
   GemmaEngine: RAM: ~3800MB → tier: iq2_m  (for 3.8 GB)
   OR
   GemmaEngine: RAM: ~3400MB → tier: iq2_xxs (for <3.5 GB)
   ```

2. **Model Selection**: Logcat should show:
   - IQ2_XXS path loaded for <3.5 GB devices
   - IQ2_M path loaded for ≥3.5 GB devices
   - Fallback message if IQ2_XXS file is missing

3. **No OOM**: Model loading must complete without `OutOfMemoryError`
   - Estimated memory: ~2.71 GB total (IQ2_XXS, 768 ctx, Q8_0 KV)
   - Device has ~1.09 GB margin on 3.8 GB

4. **Yachay 7-Round Dispatch**:
   - Send: "Hola Yachay, quiero aprender sobre fracciones"
   - Verify greeting response in Spanish
   - Continue conversation through at least 7 rounds
   - Each round should complete within 30 seconds
   - Response must be coherent Spanish educational content

5. **Fallback Verification** (remove IQ2_XXS file):
   - Delete `gemma-4-E2B-it-IQ2_XXS.gguf`
   - Restart app
   - Logcat should show: "IQ2_XXS model not found — falling back to IQ2_M"
   - App loads IQ2_M successfully

## Verification Commands

```bash
# Check device RAM tier detection in logs
adb logcat -s GemmaEngine:D gemma_engine_jni:D | grep "tier\|RAM\|n_ctx\|threads\|Flash\|Q8"

# Expected log entries:
# GemmaEngine: RAM: XXXXMB → tier: iq2_m|iq2_xxs
# gemma_engine_jni: Model loaded successfully. n_ctx=768, threads=1

# Monitor for OOM
adb logcat | grep -i "outofmemory\|oom"

# Check APK size (should be under 50 MB for the APK itself)
ls -lh build/app/outputs/flutter-apk/app-debug.apk
```

## Pass Criteria

- [ ] IQ2_XXS model loads on ≤3 GB device without OOM
- [ ] IQ2_M model loads on ≥4 GB device without OOM
- [ ] Fallback to IQ2_M works when IQ2_XXS file is missing
- [ ] 7-round Yachay dispatch produces coherent Spanish within 30s/round
- [ ] No native crash or ANR during inference
- [ ] RAM detection correctly classifies the device tier
