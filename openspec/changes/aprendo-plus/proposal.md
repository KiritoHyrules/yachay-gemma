# Proposal: Aprendo+ — Initial Zero-to-Prototype Change

## Intent

Build the offline-first AI tutoring app for AI Competition Gemma 2026 (Aug 1-2, 5-7h window). Address 88% competency failure in Peruvian secondary schools via on-device diagnostic assessment and adaptive lesson delivery. Greenfield — zero code to working prototype.

## Scope

### In Scope
- Flutter 3.x project scaffold (SR-Arq-01, SR-C01)
- Encrypted SQLite persistence — sqflite_sqlcipher AES-256 (N-08, SR-F-02)
- Adaptive IRT diagnostic — 25 math + 25 reading items (N-01, N-02, SR-F-01)
- Lesson engine — 3 math + 2 reading JSON-driven lessons (N-03, SR-F-03, SR-F-05)
- Gemma 4 MethodChannel bridge with fallback responses (N-04, NR-01, SR-NF-04)
- Three UI screens: diagnostic, lesson, learning path (N-05, SR-UI-01, SR-UI-02)

### Out of Scope
- Panel docente, Firebase sync, Cloud Run API, dashboard MINEDU (Phase 2)
- xAPI/SCORM export, teacher evaluation, full 10/10 lesson catalog

## Capabilities

### New Capabilities
- `andamiaje-flutter`: Project scaffold, pubspec, analysis_options, Android build config
- `persistencia-cifrada`: SQLite schema migrations, content precarga, AES-256 encryption
- `diagnostico-adaptativo`: IRT algorithm with 50-item bank, competency level output
- `motor-lecciones`: JSON-driven lesson renderer, offline-first, rich media support
- `puente-gemma`: MethodChannel bridge (Dart ↔ Kotlin/llama.cpp), fallback mode
- `interfaz-aprendiz`: Diagnostic, lesson, and learning path screens (Material Design 3)

### Modified Capabilities
None — greenfield project.

## Approach

**Approach B** (exploration-recommended): Core Only with Canned AI + Gemma Integration Attempt.

Pre-author diagnostic items and lesson content as JSON before hackathon. Build diagnostic → lesson → path flow end-to-end with precanned content first. Implement Gemma MethodChannel bridge with pre-authored fallback responses; attempt live inference only if pre-hackathon verifications pass.

If Gemma 4 exceeds 2GB RAM limit, demo with Gemini API and document on-device architecture for Phase 2. Time budget: 5.5-6.5h per DDR-004 baseline, with 60min buffer for Gemma integration.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/core/database/` | New | sqflite_sqlcipher service, migrations, repositories |
| `lib/modules/diagnostico/` | New | IRT algorithm, item bank, diagnostic UI |
| `lib/modules/aprendizaje/` | New | Lesson engine + UI, learning path screen |
| `lib/modules/gemma/` | New | Dart service + Kotlin MethodChannel bridge |
| `android/.../kotlin/` | New | GemmaEngine.kt (llama.cpp native) |
| `assets/` | New | 50 diagnostic items, 5 lesson JSONs, media |
| `pubspec.yaml` | New | Flutter deps (provider, sqflite_sqlcipher, etc.) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Gemma 4 GGUF doesn't fit 2GB RAM (R1) | High | Pre-hackathon verifications. Fallback: Gemini API demo + document on-device architecture |
| llama.cpp Android + Gemma 4 incompatibility (R2) | High | Test before Aug 1. Alternative: MediaPipe LLM Inference |
| Time estimate exceeds 5-7h window (R3) | Med | Aggressive trim: fewer lessons, simpler UI, plain sqflite |
| Content authoring takes >90min (R4) | Med | Pre-author JSON on July 31; hackathon: wire only |
| sqflite_sqlcipher build fails on Windows (R5) | Med | Fallback: plain sqflite; document encryption as Phase 2 |

## Rollback Plan

N/A — greenfield project. No existing code to revert. If proposal is rejected, discard `openspec/changes/aprendo-plus/`.

## Dependencies

- **Prerequisite (CRITICAL)**: Complete 7 Gemma 4 pre-hackathon verifications before Aug 1
- Flutter SDK 3.x, Android SDK, Kotlin toolchain installed
- Android device/emulator with 2GB RAM profile
- HuggingFace access for Gemma 4 GGUF Q4_0 download

## Success Criteria

- [ ] App launches on Android with Flutter debug build
- [ ] Student completes diagnostic and receives competency level
- [ ] Student views and completes at least 1 pre-authored lesson
- [ ] Learning path screen shows progress visualization
- [ ] Gemma model loads and returns inference OR fallback serves correctly
- [ ] All data persists encrypted in SQLite across app restarts
