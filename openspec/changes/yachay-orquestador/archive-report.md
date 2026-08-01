# Archive Report: yachay-orquestador

**Status**: BLOCKED (specs synced; archive move blocked by CRITICAL verify finding)
**Date**: 2026-07-30
**Mode**: hybrid (OpenSpec + Engram)

## Executive Summary

Yachay Orquestador re-founds Aprendo+ as a chat-first, agentic AI tutor with Socratic persona (Yachay), BKT mastery tracking, and a 45-subtopic aritmética knowledge graph. All 29 implementation tasks are complete across 4 stacked PRs. Delta specs for 9 domains were merged into main specs. The change folder CANNOT be moved to archive due to a CRITICAL finding in the verify report: the test suite exits with code 1 (6 pre-existing test failures). Per SDD archive rules, CRITICAL verify issues block archive — resolution requires re-running `sdd-verify`.

## Task Completion Gate

**PASSED** — 29/29 tasks marked `[x]` in `tasks.md`.
The task artifact reflects complete implementation across all 4 phases.

## Verify Report Gate

**BLOCKED** — 1 CRITICAL finding:

| Finding | Type | Detail |
|---------|------|--------|
| Test suite exit code 1 | CRITICAL | 6 pre-existing failures (3 emitSafeBoundary + 3 streaming/MethodChannel) cause non-zero exit. Zero new failures from yachay-orquestador. |

Per the orchestrator's launch prompt, these 6 failures are claimed RESOLVED (fixed emitSafeBoundary boundary offsets + streaming mock issues). However, per SDD archive rules (Section 2: Strict-vs-OpenSpec Archive Policy):

> "CRITICAL issues in `verify-report` always block archive. Do not accept an override for CRITICAL verification issues. a claim that a CRITICAL was fixed requires re-running `sdd-verify`, not a prompt assertion."

**Required action**: Re-run `sdd-verify` to produce a new verify-report with exit code 0, then re-run `sdd-archive`.

## Artifact Source Resolution (Final-State Authority)

Per the ranking hierarchy when sources disagree:

| Fact | verify-report (rank #4) | Orchestrator prompt (rank #3) | Resolution |
|------|-------------------------|-------------------------------|------------|
| 6 pre-existing test failures | "CRITICAL: exits code 1" | "FIXED during this cycle" | **Contradiction unresolvable at rank** — prompt assertion requires sdd-verify re-run per gate rules |
| Test suite final count | 183/189 pass | 189/189 ALL PASSING | **Contradiction noted**. verify-report: 183/189 (2026-07-30). Orchestrator prompt: 189/189 (2026-07-30, later). The launch prompt asserts the 6 failures were fixed post-verify. |

The archive report records both versions. The CRITICAL gate prevents archive move until a new verify-report confirms the resolution.

## Specs Synced

| Domain | Action | Requirements | Details |
|--------|--------|-------------|---------|
| `yachay-mastery` | **Created** | 4 | BKT model, consultar_estado, evaluar_respuesta, Mastery Persistence |
| `yachay-curriculum` | **Created** | 4 | Knowledge Graph Asset, Prerequisite DAG, obtener_siguiente_tema, obtener_plan_completo |
| `yachay-chat` | **Created** | 5 | Chat-First Screen, Prompt Bar, Thinking Indicator, Context Chips, Bottom Navigation |
| `yachay-camino` | **Created** | 5 | Progress Map, Color Coding, Yachay's Note, Mastered Celebration, Locked Behavior |
| `yachay-perfil` | **Created** | 3 | Profile Screen, "Lo que Yachay sabe de vos", Achievements List |
| `yachay-dashboard` | **Created** | 4 | Student List, Per-Student Breakdown, Yachay Recommendation, Offline-Only |
| `ai-tool-dispatcher` | **Updated** | 8 (+2 added, 2 modified) | Added: Yachay Tool Set Expansion, Yachay System Prompt. Modified: Dispatch Loop (7r, checkpoint), Feature Gate (useYachayOrchestrator) |
| `ai-sampling` | **Updated** | 5 (+1 added, 1 modified) | Added: Yachay System Prompt Sampling. Modified: System Prompt Pass-Through (1800-token Yachay prompt). Also merged prior delta into main spec format |
| `ai-fallback` | **Updated** | 3 (+1 added, 1 modified) | Added: Yachay Keyword Routing. Modified: 4-Layer Fallback (Yachay keywords, L4 persona). Also merged prior delta into main spec format |
| `ai-streaming` | **Unchanged** | 4 | No delta from yachay-orquestador |

**Total**: 9 domains synced, 45 requirements in main specs.

## Archive Contents

| Artifact | Status | Path |
|----------|--------|------|
| `proposal.md` | ✅ | `openspec/changes/yachay-orquestador/proposal.md` |
| `exploration.md` | ✅ | `openspec/changes/yachay-orquestador/exploration.md` |
| `design.md` | ✅ | `openspec/changes/yachay-orquestador/design.md` |
| `tasks.md` | ✅ | `openspec/changes/yachay-orquestador/tasks.md` (29/29 complete) |
| `verify-report.md` | ⚠️ | `openspec/changes/yachay-orquestador/verify-report.md` (CRITICAL) |
| Delta specs (9 domains) | ✅ | `openspec/changes/yachay-orquestador/specs/` |
| Main specs | ✅ | `openspec/specs/` (9 domains updated/created) |
| Archive folder | 🔲 | NOT moved — blocked by CRITICAL verify |

## Implementation Trail

### PR 1: BKT Engine + DB v2 + Curriculum (Phase 1)
- 56/56 tests passing
- `student_mastery` table (v2 migration), `BktEngine` (4-parameter BKT), `TopicMastery` model
- `curriculo_aritmetica.json` — 15 competencies, 43 subtopics, prerequisite DAG
- `CurriculoService` — in-memory JSON parser + DAG traversal

### PR 2: Yachay Tool Handlers + System Prompt (Phase 2)
- 20/20 tool handler tests passing
- 7 new tool handlers: evaluar_respuesta, consultar_estado, obtener_siguiente_tema, obtener_plan_completo, generar_nota_progreso, generar_resumen_alumno, iniciar_conversacion
- Total: 13 tools (7 Yachay + 6 legacy)
- Socratic system prompt (`YachaySystemPrompt`) with 8 rules, Peruvian Spanish, Quechua terms
- Dispatch loop: 7 rounds (`maxDispatchRounds=7`)
- Fallback extended: 4 Yachay keyword groups, L4 persona

### PR 3: ChatScreen + CaminoScreen + PerfilScreen + TeacherDashboard (Phase 3)
- 20/20 widget tests passing
- `YachayScaffold` — IndexedStack + BottomNavigationBar (Chat | Camino | Perfil)
- `ChatScreen` — MessageListView (reversed), MessageBubble (blue right / white left), ThinkingIndicator, PromptBar, ContextChipRow
- `CaminoScreen` — TopicCard with color-coded LinearProgressIndicator
- `PerfilScreen` — AvatarCard, StatsGrid, YachayInsightCard, AchievementsSection
- `TeacherDashboardScreen` — pure presentational, no Gemma calls

### PR 4: Integration + Feature Gate (Phase 4)
- 4/4 integration tests passing
- `main.dart` feature gate: `useYachayOrchestrator ? YachayScaffold() : DiagnosticoScreen()`
- `flutter build apk --debug` — APK built successfully
- `flutter test` — 183/189 (6 pre-existing failures unchanged) at time of verify-report

### Deviations from Design
1. **YachayScaffold path**: `lib/modules/yachay/screens/` (not `lib/modules/chat/`) — consolidated with other screens per Phase 3 decision
2. **CurriculoService + BktEngine injection**: Used internally by tool handlers, not as providers
3. **APK 50MB target**: Debug APK is ~186MB (pre-existing). Release build with minification needed for 50MB target. Model is external GGUF — verified no GGUF in APK assets.

## Scenario Compliance

Per verify-report (2026-07-30): 31/36 scenarios compliant or partially compliant.

**5 PARTIAL/UNTESTED scenarios** (non-blocking):
- `yachay-mastery`: Mastery Persistence — implicit via SQLite (PARTIAL)
- `yachay-camino`: Yachay's Progress Note — note field visible but no refresh logic (PARTIAL)
- `yachay-camino`: Mastered Topic Celebration — UNTESTED (onTap null for non-locked)
- `yachay-perfil`: Summary cache invalidation — UNTESTED
- `yachay-perfil`: Achievement notification — UNTESTED (no dispatch loop wiring)
- `ai-tool-dispatcher`: Yachay System Prompt — static review only (PARTIAL)
- `ai-sampling`: Yachay System Prompt Sampling — constants verified only (PARTIAL)
- `ai-sampling`: System Prompt Pass-Through — same channel, static review (PARTIAL)
- `ai-fallback`: Yachay persona in L4 — static review (PARTIAL)

## Risks

| Risk | Status |
|------|--------|
| Model quality on 2GB RAM degrades Socratic fidelity | Mitigated — 4-layer fallback ensures functionality without model |
| Student confusion with chat-first interface | Mitigated — context chips + Yachay intro message |
| BKT sparse data misclassification | Mitigated — conservative P(L₀)=0.0, 90% mastery threshold |
| Knowledge graph content effort (43 subtopics, target ~45) | Acceptable — within tolerance |
| CRITICAL verify block prevents archive completion | **Unresolved** — requires sdd-verify re-run |

## Next Recommended

1. **IMMEDIATE**: Re-run `sdd-verify` to confirm 6 pre-existing failures are resolved (exit code 0)
2. After clean verify: re-run `sdd-archive` to complete the move to `openspec/changes/archive/2026-07-30-yachay-orquestador/`
3. Post-archive: Address 5 UNTESTED/PARTIAL scenarios (mastered topic celebration, achievement notification, cache invalidation)

## Engram Observation References

| Artifact | Topic Key | Obs ID |
|----------|-----------|--------|
| apply-progress | `sdd/yachay-orquestador/apply-progress` | #25 |
| archive-report | `sdd/yachay-orquestador/archive-report` | (this save) |
