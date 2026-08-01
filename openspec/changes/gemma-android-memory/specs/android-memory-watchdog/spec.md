# android-memory-watchdog Specification

> NEW: Pre-inference OOM checkpointing and crash recovery via SQLite

## Purpose

Save user conversation context before each inference call so that, if the native OOM killer terminates the process, the app can recover gracefully on restart — offering a fallback message and preserving the student's question rather than losing it silently (NR-02, N-04).

## Requirements

### Requirement: Pre-Inference OOM Checkpoint

Before every native `generateJni()` or `generateStreamJni()` call, the Kotlin engine SHALL persist the current prompt, system prompt, timestamp, and session identifier to a dedicated `oom_checkpoint` SQLite table.

#### Scenario: Checkpoint saved before generation

- GIVEN a student sends a question "explicame fracciones"
- WHEN `handleGenerate()` or `handleGenerateStream()` is about to call `generateJni()`
- THEN a new row MUST be inserted into `oom_checkpoint` with:
  - `session_id` (current user session)
  - `user_message` (the full prompt)
  - `system_prompt` (the system prompt, if set)
  - `timestamp` (ISO 8601)
  - `pending_tool` (the tool name if in dispatch loop, otherwise NULL)
  - `recovered = 0`

#### Scenario: Checkpoint cleared on successful generation

- GIVEN a checkpoint was saved before generation
- WHEN `generateJni()` returns successfully (no OOM)
- THEN the checkpoint row MUST be deleted or marked as recovered
- AND stale checkpoints SHALL NOT accumulate indefinitely

#### Scenario: Checkpoint survives native OOM kill

- GIVEN a checkpoint was written to SQLite
- WHEN the Linux OOM killer terminates the process during `generateJni()`
- THEN the checkpoint row MUST persist in the database across process restart
- AND `recovered` MUST remain `0`

### Requirement: Crash Recovery on Startup

On app restart, the Dart `GemmaService` SHALL query `oom_checkpoint` for unrecovered rows (`recovered = 0`). If any are found, `cargarModelo()` SHALL return a recovery message instead of loading the model normally.

#### Scenario: Single unrecovered checkpoint on restart

- GIVEN one unrecovered `oom_checkpoint` row exists (`recovered = 0`)
- WHEN the app restarts and `cargarModelo()` is called
- THEN the service MUST detect the pending checkpoint
- AND a recovery message in Spanish SHALL be returned: "Lo siento, tuve que reiniciarme. ¿Podrías repetir tu pregunta?"
- AND the checkpoint SHALL be marked as `recovered = 1` with the recovery message in `recovery_response`

#### Scenario: Multiple unrecovered checkpoints on restart

- GIVEN 3 unrecovered `oom_checkpoint` rows exist from repeated OOM kills
- WHEN the app restarts
- THEN only the most recent checkpoint by timestamp SHALL be recovered
- AND older checkpoints SHALL be marked `recovered = 1` with a cleanup note

#### Scenario: No unrecovered checkpoints

- GIVEN the `oom_checkpoint` table is empty or all rows have `recovered = 1`
- WHEN the app starts normally
- THEN `cargarModelo()` SHALL proceed with normal model loading
- AND no recovery message SHALL be displayed

### Requirement: OOM Checkpoint Table Schema

The `oom_checkpoint` table SHALL be created as part of a v3 database migration in `database_service.dart`.

#### Scenario: Table created on v2→v3 upgrade

- GIVEN the database is at version 2
- WHEN the app upgrades to version 3
- THEN the `oom_checkpoint` table MUST be created with columns:
  - `id` INTEGER PRIMARY KEY AUTOINCREMENT
  - `session_id` TEXT NOT NULL
  - `user_message` TEXT NOT NULL
  - `system_prompt` TEXT
  - `timestamp` TEXT NOT NULL
  - `pending_tool` TEXT
  - `recovered` INTEGER NOT NULL DEFAULT 0
  - `recovery_response` TEXT

#### Scenario: Table created on fresh v3 install

- GIVEN a fresh database at version 3
- WHEN `_onCreate()` runs
- THEN the `oom_checkpoint` table MUST be created alongside existing tables

### Requirement: Checkpoint Cleanup

The checkpoint table SHALL be cleaned on startup: all rows with `recovered = 1` older than 24 hours SHALL be purged.

#### Scenario: Old recovered checkpoints are purged

- GIVEN the `oom_checkpoint` table has recovered checkpoints older than 24 hours
- WHEN the app starts
- THEN those rows MUST be deleted
- AND the table SHALL NOT grow unbounded over multiple sessions
