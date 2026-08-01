# Design: Android Memory Management (OOM Prevention)

## Technical Approach

Apply 5 Android memory management optimizations to prevent OOM kills when loading Gemma 4 GGUF models. Changes span vendored C++, native JNI, Kotlin bridge, and Dart service — saving ~500-600 MB effective RAM without model re-quantization.

## Memory Budget

```
BEFORE (IQ2_M, MAP_POPULATE ON, Q8_0 KV, totalMem)
───────────────────────────────────────
Model weights (prefaulted):   2.60 GB  ████████████
KV cache (Q8_0):              0.09 GB  ▌
Runtime buffers:              0.50 GB  ██
Backend overhead:             0.10 GB  ▌
OS/system apps:               1.50 GB  ██████
───────────────────────────────────────
TOTAL required:               4.79 GB ⚠️ OOM on 4 GB device

AFTER (IQ2_XXS, MAP_POPULATE OFF, Q4_0 KV, availMem)
───────────────────────────────────────
Model weights (demand-paged): 2.00 GB  █████████   → saves 200-400 MB (MAP_POPULATE off)
KV cache (Q4_0):              0.05 GB  ▏           → saves ~47 MB vs Q8_0
Runtime buffers:              0.50 GB  ██
Backend overhead:             0.10 GB  ▌
OS/system apps:               1.50 GB  ██████
───────────────────────────────────────
TOTAL effective:              4.15 GB → ~4.15 GB with margin ✓ (availMem-based, no pre-fault)
Savings:                      247-447 MB + OOM prevention
```

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|----------|--------|----------|-----------|
| MAP_POPULATE | Vendor patch: false | JNI-side workaround | No public llama.cpp API for prefetch control. 1-char vendor patch is minimal, private fork exempt from upstream contribution policy |
| RAM detection | availMem | totalMem, /proc/meminfo | totalMem ignores competing apps. availMem is Android API 1+, represents actual allocatable memory |
| KV cache tiers | 3-tier (Q4_0/Q8_0/F16) | 2-tier, 4-tier | 3 tiers maps naturally to device classes. Q4_0 for <1.8 GB, Q8_0 for 1.8-3 GB, F16 for >3 GB |
| onTrimMemory integration | ComponentCallbacks2 | Custom lifecycle observer | Standard Android API since API 14; no dependency overhead |
| OOM checkpoint storage | SQLite (encrypted) | SharedPreferences, file | SQLite already wired with SQLCipher; writes survive native process kill; encrypted |
| Checkpoint timing | Before every generateJni call | After predict, batched | Must be BEFORE inference to survive OOM during the call |

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `android/app/src/main/cpp/llama.cpp/src/llama-model.cpp` | Modify | Line 1529: `true` → `false` in `init_mappings()` |
| `android/app/src/main/cpp/gemma_engine.cpp` | Modify | New `jstring jramTier` param on `loadModelJni`, conditional KV types, explicit `load_mode` |
| `android/app/src/main/kotlin/com/aprendoplus/app/GemmaEngine.kt` | Modify | `availMem` in `detectRamTier`, `ComponentCallbacks2` impl, OOM checkpoint methods, 3-tier RAM |
| `lib/core/database/database_service.dart` | Modify | `oom_checkpoint` table, v3 migration, cleanup on startup |
| `lib/modules/gemma/gemma_service.dart` | Modify | OOM recovery check in `cargarModelo()`, fallback dispatch for recovery message |

## MAP_POPULATE Patch (Vendor Code)

Location: `llama-model.cpp:1529`

```diff
- ml.init_mappings(true, use_mlock ? &pimpl->mlock_mmaps : nullptr);
+ ml.init_mappings(false, use_mlock ? &pimpl->mlock_mmaps : nullptr);
```

This is a 1-character vendored code change. The private fork (Aprendo+ hackathon) is exempt from llama.cpp upstream contribution policy per the AGENTS.md "Private forks are exempt" clause. The patch disables kernel pre-faulting of the GGUF file; pages are demand-paged on first access.

## RAM Tier Thresholds

```
availMem <  1800 MB → low  → IQ1_S model hint + Q4_0 KV
availMem  1800–3000 MB → med  → IQ2_XXS model hint + Q8_0 KV
availMem >  3000 MB → high → IQ2_M model hint + F16 KV
```

Thresholds set conservatively: 1800 MB accounts for ~200 MB OS reserve below model+KV+buffers. 3000 MB upper boundary ensures comfortable F16 KV headroom.

## onTrimMemory Handler

```kotlin
class GemmaEngine(...) : MethodChannel.MethodCallHandler, ComponentCallbacks2 {
    init {
        context.registerComponentCallbacks(this)
    }

    override fun onTrimMemory(level: Int) {
        when (level) {
            TRIM_MEMORY_RUNNING_MODERATE -> { /* flush non-critical buffers */ }
            TRIM_MEMORY_RUNNING_CRITICAL -> {
                // signal native to reduce n_batch to 64 for next decode
                trimNativeBatch(64)
            }
            TRIM_MEMORY_UI_HIDDEN -> { /* log only, no forced unload */ }
        }
    }

    override fun onLowMemory() {
        trimNativeBatch(32)
        // flush all cached token buffers
    }

    fun unregister() {
        context.unregisterComponentCallbacks(this)
    }
}
```

## OOM Watchdog Flow

```
1. Student sends question → GemmaService.procesarMensaje()
2. Kotlin handleGenerate() called
3. saveOomCheckpoint(userMessage, systemPrompt) → SQLite INSERT
4. generateJni() called — native inference
5a. SUCCESS → clearOomCheckpoint() → SQLite DELETE
5b. OOM KILL → process dies → checkpoint persists on disk

--- APP RESTART ---
6. GemmaService.cargarModelo() called
7. recoverFromOom() → query oom_checkpoint WHERE recovered=0
8. If found → mark recovered=1, return recovery message to Dart
9. Dart returns "Lo siento, tuve que reiniciarme..." to UI
```

## Database Migration (v2 → v3)

```sql
CREATE TABLE oom_checkpoint (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    user_message TEXT NOT NULL,
    system_prompt TEXT,
    timestamp TEXT NOT NULL,
    pending_tool TEXT,
    recovered INTEGER NOT NULL DEFAULT 0,
    recovery_response TEXT
);
```

Cleanup on startup: `DELETE FROM oom_checkpoint WHERE recovered=1 AND timestamp < datetime('now', '-1 day')`.

## JNI Signature Change

```diff
// GemmaEngine.kt
- private external fun loadModelJni(path: String): Long
+ private external fun loadModelJni(path: String, ramTier: String): Long

// gemma_engine.cpp
- JNIEXPORT jlong JNICALL Java_com_aprendoplus_app_GemmaEngine_loadModelJni(JNIEnv*, jobject, jstring)
+ JNIEXPORT jlong JNICALL Java_com_aprendoplus_app_GemmaEngine_loadModelJni(JNIEnv*, jobject, jstring, jstring)

// gemma_engine.cpp loadModelJni body:
std::string ramTier = jstringToString(env, jramTier);
if (ramTier == "iq2_xxs" || ramTier == "low") {
    ctx_params.type_k = GGML_TYPE_Q4_0;
    ctx_params.type_v = GGML_TYPE_Q4_0;
} else {
    ctx_params.type_k = GGML_TYPE_Q8_0;
    ctx_params.type_v = GGML_TYPE_Q8_0;
}
```

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit (Dart) | OOM checkpoint recovery flow | Mock DB with checkpoints; verify recovery message returned, normal path when empty |
| Unit (Kotlin) | `detectRamTier` with availMem | Mock `ActivityManager.MemoryInfo` with availMem values at tier boundaries |
| Integration | Build + schema migration | `flutter build apk --debug`; verify v3 migration creates `oom_checkpoint` |
| E2E | OOM recovery on real device | Trigger OOM via large prompt; restart app; verify recovery message displayed |

## Threat Matrix

N/A — no routing, shell, subprocess, or executable-file classification. SQLite writes use existing encrypted database; no new network or file I/O paths.

## Migration / Rollout

No user-visible migration required. MAP_POPULATE patch is build-time only. RAM detection change is transparent — it changes which model variant is selected, which falls back to existing IQ2_M when IQ2_XXS absent. OOM checkpoint table created on v3 migration; empty table is no-op. onTrimMemory listener is defensive, has no effect under normal operation. Rollback: revert commit.
