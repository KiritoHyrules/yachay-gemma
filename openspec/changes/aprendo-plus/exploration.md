# Exploration: Aprendo+ — Initial Change

**Date**: 2026-07-30
**Phase**: Explore (SDD Phase 2)
**Change**: First project change — zero-to-prototype for AI Competition Gemma 2026

---

## Current State

### Repository
- **Zero source code**. No `.dart` files, no `pubspec.yaml`, no `build.gradle`. No git commits, no git remote configured.
- Working tree contains only: ISO 15288 documentation (5 files), `openspec/` (config + empty specs/changes), `.gga` config, `.atl/` skill registry.
- This is a **greenfield project**. The explore phase is establishing baseline viability and scope.

### Documentation (ISO 15288 Full Trace)
The `IDEA E INVSTIGAION PARA EL PROYECTO/` directory contains 5 exhaustive ISO 15288 documents, all dated July 28-29, 2026:

| Document | ISO Process | Key Output |
|----------|------------|------------|
| **6.4.1** Business Mission Analysis | Problem definition & solution selection | Root cause tree (88% failure rate, 79% without internet, 81% teachers untrained). Three alternatives evaluated. **Alternative 2 (AI Tutor bypass → evolving to Hybrid Alt 3) selected.** |
| **6.4.2** Stakeholder Needs | 8 stakeholders, 20 needs, 5 scenarios | MoSCoW: Must = diagnostic, offline, personalization. Won't = teacher evaluation, infrastructure. Operational concept "Aprendo+" defined with 5 modes. |
| **6.4.3** System Requirements | 64 requirements (25 functional, 10 performance, 8 interfaces, 8 quality, 5 constraints, 8 non-negotiables) | Key constraints: NR-01 (Gemma 4 mandatory), NR-02 (offline-first), NR-07 (Python/JS), NR-08 (Flutter, Firebase, Cloud Run) |
| **6.4.4** Architecture Definition | C4 Model (Context → Containers → Components), 6 ADRs | **Flutter selected** (score 7.65/9 vs Android Native 6.45 vs PWA 4.85). Monolithic modular architecture. 8 IFACE interfaces. ADR-002: Gemma on-device via TFLite/MethodChannel. |
| **6.4.5** Design Definition | Detailed Dart/Kotlin specs, 4 DDRs, library evaluation | Stack: Flutter 3.x + provider + sqflite_sqlcipher + Gemma via llama.cpp MethodChannel. DDR-004: Core components only in phase 1 (diagnostic, 3 math + 2 reading lessons, persistence). Panel docente, sync, dashboard deferred. |

### Design Baseline for Implementation (from 6.4.5 §D.3)
| Component | Files | Estimated Time |
|-----------|-------|---------------|
| Entry point + init | `lib/main.dart` | 30 min |
| Database (encrypted SQLite) | `lib/core/database/database_service.dart` | 45 min |
| Diagnostic algorithm (IRT) | `lib/modules/diagnostico/` | 60 min |
| Diagnostic UI | `lib/modules/diagnostico/diagnostico_screen.dart` | 45 min |
| Lesson UI | `lib/modules/aprendizaje/` | 60 min |
| Learning path UI | `lib/modules/aprendizaje/ruta_screen.dart` | 30 min |
| Gemma wrapper (Dart) | `lib/modules/gemma/gemma_service.dart` | 30 min |
| Gemma engine (Kotlin) | `android/.../GemmaEngine.kt` | 60 min |
| Content creation (assets) | `assets/` (3 lessons JSON + items + media) | 90 min |
| **Total** | | **≈7.5 hours** (tight for 5-7h window) |

---

## Affected Areas

No code is affected (zero source). Areas that WILL be created:

- `lib/core/database/` — SQLite encrypted persistence layer (AES-256 via sqflite_sqlcipher)
- `lib/modules/diagnostico/` — Adaptive diagnostic module (IRT algorithm, 25 items per subject)
- `lib/modules/aprendizaje/` — Lesson rendering engine (JSON-driven content)
- `lib/modules/gemma/` — Gemma 4 service layer (Dart wrapper + Kotlin MethodChannel)
- `android/app/src/main/kotlin/` — Native Gemma engine (llama.cpp for GGUF Q4_0)
- `assets/` — Content: diagnostic item bank (60+ items), 3-5 lessons JSON, videos, images
- `openspec/changes/aprendo-plus/` — SDD artifacts for this change

---

## Key Findings

### 1. Gemma 4 Viability: The Critical Unknown

**Model**: `google/gemma-4-E2B-it-qat-mobile-transformers` (published July 2026 — 28 days ago)
- 2.3B effective params, QAT (Quantization-Aware Training) with wNa8o8 mobile schema
- GGUF Q4_0 format: ~500MB-1GB on disk, ~1-1.5GB RAM during CPU inference
- **Apache 2.0 license** (no restrictions, commercial use OK)
- 128K context, thinking mode, system prompt natively supported

**The RAM math is tight**:
- Device target: 2GB total RAM
- Android OS: ~500-600MB
- Available for app: ~1.2-1.4GB
- Gemma model in memory: ~1-1.5GB → **1GB leaves 200-400MB for everything else**

**Integration path**: llama.cpp for Android with GGUF Q4_0 via Kotlin MethodChannel. Google's gemma.cpp does NOT support this model yet. MediaPipe LLM Inference is an alternative if Google releases wNa8o8 Android support.

**7 verification items ALL pending** (from 6.4.5 §A.2.2):
1. ❌ Download model from HuggingFace
2. ❌ Verify actual GGUF weight
3. ❌ Test inference on CPU (laptop)
4. ❌ Measure RAM during inference
5. ❌ Evaluate educational response quality
6. ❌ Create Android project with model loaded
7. ❌ Measure latency on 2GB RAM device

**The risk**: If items 3, 4, 6, 7 fail (model doesn't fit, too slow, or crashes), the core value proposition (AI tutor on-device) is compromised.

### 2. NR-07 (Python/JavaScript) Is About Backend, Not App

NR-07 from the hackathon bases states "Python and JavaScript" as allowed languages. However, NR-08 explicitly permits Flutter (Dart), Firebase, and Cloud Run. The architecture correctly interprets NR-07 as applicable to the **backend** (Cloud Run API in Python or Node.js), while the app uses Flutter/Dart. No contradiction.

### 3. Documentation Is Over-Engineered for 5-7 Hours

The ISO docs total ~2,800 lines of exhaustive requirements engineering. 64 system requirements, 8 interface definitions, 6 ADRs, 4 DDRs. This is appropriate for a production system but constitutes **significant specification overhead** for a 5-7h hackathon. The delta between what the docs specify and what can realistically be built is large:
- Specified: 10 math + 10 reading lessons, panel docente, Firebase sync, Cloud Run dashboard, xAPI/SCORM export
- Realistic: 3 math + 2 reading lessons, diagnostic module, basic Gemma integration, local persistence

The docs themselves acknowledge this in DDR-004 (§D.3 of 6.4.5), correctly scoping phase 1 to core components.

### 4. No CI/CD, No Tests, No Build Pipeline

- `openspec/config.yaml` confirms: `tdd: false`, no test runner, no linter, no formatter
- No `pubspec.yaml` exists yet — Flutter project must be created from scratch
- No Firebase project configured
- No device for testing acquired

---

## Approaches

### Approach A: Full Specification Scope (Not Recommended)
Attempt all components from 6.4.5 §D.3 baseline (7.5h estimate for 5-7h window).

| Pros | Cons | Complexity |
|------|------|------------|
| Maximum demo impact | **Won't finish**. Estimate already exceeds window | High |
| All core flows functional | Will have shallow, buggy implementations across the board | |
| | Risk of demo failure — nothing works end-to-end | |

### Approach B: Core Only — Diagnostic + 3 Lessons + Canned AI (Recommended)
Implement ONLY: (1) Diagnostic module with IRT algorithm, (2) 3 math + 2 reading lessons from precanned JSON, (3) SQLite persistence with encryption, (4) Gemma as **fallback-only** — use pre-authored explanations for the demo, attempt Gemma integration if time permits.

| Pros | Cons | Complexity |
|------|------|------------|
| Fits 5-7h window (~5h estimate) | Less impressive AI demo | Medium |
| Diagnostic → Lesson flow is end-to-end functional | Doesn't showcase Gemma's adaptive capabilities live | |
| No dependency on unverified Gemma Android integration | But the architecture preserves the integration point | |
| Can still show Gemma model loaded and basic prompt-response | | |
| Demo is reliable — no risk of model inference failures during presentation | | |

### Approach C: AI-First — Skip Content, Focus on Gemma Demo
Skip authored lessons entirely. Build diagnostic + a live chat-style Gemma tutoring interface. The AI generates explanations and exercises in real-time.

| Pros | Cons | Complexity |
|------|------|------------|
| Maximizes Gemma showcase | **Highest risk**: depends entirely on unverified Android integration | High |
| Fewest assets to create | If Gemma doesn't work on device, demo fails completely | |
| Most aligned with "AI Competition Gemma" branding | Less structured learning experience | |
| | No precanned offline content — if model is slow (>10s), UX is terrible | |

---

## Recommendation

**Approach B — Core Only with Canned AI + Gemma Integration Attempt**

**Rationale**:

1. **Reliability over ambition**: A demo that works end-to-end (Student opens app → Takes diagnostic → Gets level → Completes lesson → Gets feedback) is more impressive to judges than a technically ambitious demo that crashes or times out.

2. **Gemma as a feature, not the foundation**: Pre-authoring 3 math + 2 reading lessons as JSON assets guarantees content quality and availability offline. The Gemma integration becomes a *differentiator* — "look, it also generates adaptive explanations" — rather than the sole dependency.

3. **Architecture preserves the north star**: The MethodChannel bridge (`GemmaService` → `GemmaEngine.kt`) is architecturally the right place. Even if only the `fallback` path runs during the demo, the integration point is proven and documented.

4. **Time allocation**:
   - 30 min: Flutter project init + pubspec + dependencies
   - 45 min: SQLite encrypted DB + schema + content precarga
   - 60 min: Diagnostic algorithm + item bank (30 math + 30 reading items)
   - 45 min: Diagnostic UI
   - 60 min: Lesson engine + UI (JSON-driven rendering)
   - 60 min: Content authoring (3 math lessons + 2 reading lessons)
   - 45 min: Gemma MethodChannel setup + fallback service
   - 60 min: **Buffer**: Gemma integration attempt, polish, testing
   - **Total**: ~5.5-6.5 hours

5. **Pre-hackathon sprint (July 30-31)**: The 7 verification items MUST be completed before hackathon start. This is the single most impactful preparation step:
   - **Critical path**: Item 3 (test inference), Item 4 (measure RAM), Item 6 (Android project)
   - **Nice to have**: Items 5 (quality), Item 7 (latency benchmark)

---

## Risks

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| **R1** | Gemma 4 GGUF Q4_0 doesn't fit in 1GB available RAM or crashes on 2GB device | CRITICAL | Pre-hackathon verification (items 3, 4, 6, 7). If fails: use Gemini API for demo, document on-device architecture for phase 2. Keep fallback responses in all Gemma service calls. |
| **R2** | llama.cpp Android bindings incompatible with Gemma 4's architecture (per-layer embeddings, 2-bit decoding, hybrid attention) | HIGH | Test items 3 and 6 before Aug 1. Alternative: MediaPipe LLM Inference if Google releases wNa8o8 Android support. Ultimate fallback: Gemini API. |
| **R3** | 5-7 hour estimate exceeds actual time (Flutter init delays, dependency conflicts, Android build issues) | HIGH | Trim scope aggressively: 2 lessons instead of 5, simpler diagnostic UI, skip encryption if sqflite_sqlcipher has build issues (use plain sqflite for demo). |
| **R4** | Content authoring (item bank + lessons) takes longer than estimated (90 min) | MEDIUM | Prepare content structure BEFORE hackathon. Author the JSON files on July 31. During hackathon, only wire them into the app. |
| **R5** | sqflite_sqlcipher build fails due to SQLCipher native compilation issues on Windows | MEDIUM | Fallback to plain sqflite for demo. Document encryption as phase 2 requirement. |
| **R6** | No device available with Android 6+ 2GB RAM for testing | MEDIUM | Use Android emulator with 2GB RAM profile. Less accurate but sufficient for demo. If available, borrow a low-end device. |
| **R7** | NR-07 (Python/JS) misinterpreted by judges as applying to the app, not just backend | LOW | Document in proposal that NR-08 explicitly permits Flutter. Backend (Cloud Run) complies with NR-07. |

---

## Ready for Proposal

**Yes**. The exploration phase is complete. The project is well-understood through 5 ISO 15288 documents, architecture is fully defined, design is detailed down to class/function signatures, and the critical unknown (Gemma 4 on-device viability) has a clear verification path and fallback strategy.

**What the orchestrator should tell the user**:

The exploration confirms this is a greenfield Flutter project with extensive requirements documentation already done. The key action item is the **pre-hackathon Gemma verification sprint** — 7 items must be completed before Aug 1 start. The recommended approach (Approach B) balances reliability with AI showcase: build a working diagnostic→lesson flow with precanned content, and integrate Gemma as a differentiating feature rather than the sole dependency. The time estimate is tight (5.5-6.5h) but achievable if content is pre-authored on July 31.

**Immediate next step**: `sdd-propose` for a proposal that formalizes the scope, marks the verification sprint as a prerequisite, and establishes the fallback strategy for Gemma.
