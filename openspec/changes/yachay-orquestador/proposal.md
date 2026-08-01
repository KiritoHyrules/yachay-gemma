# Proposal: Yachay Orquestador — Re-found Aprendo+ as Agentic AI Tutor

## Intent

Re-found Aprendo+ so Gemma IS the app — not a help button. Yachay (Quechua: "learn") becomes a Socratic AI tutor persona that orchestrates the entire student experience through natural conversation. Mastery learning drives progression via Bayesian Knowledge Tracing (BKT). A teacher dashboard reads from SQLite, no AI required.

## Scope

### In Scope
- **Chat-first UI**: Single-screen conversational interface (message bubbles, prompt bar, context chips, streaming) replacing diagnostic→ruta→leccion tunnel
- **Yachay persona + system prompt**: Socratic method, Peruvian Spanish, 7 XML-dispatched tools (5 existing + `evaluar_respuesta`, `siguiente_paso`)
- **BKT mastery engine**: Per-topic `TopicMastery` tracking in SQLite (`student_mastery` table), P(L) updated per interaction
- **Knowledge graph**: `curriculo_aritmetica.json` with ~15 competencies for Aritmética 1°, prerequisite DAG, ~45 subtopics, in-memory traversal
- **Camino screen**: Visual progress map reading mastery data
- **Perfil screen**: Student profile powered by Yachay's insights
- **Teacher dashboard**: Read-only SQLite view (progreso grupal, alertas, temas difíciles)

### Out of Scope
- Complete 1°-5° curriculum (only 1° for MVP)
- Voice input/output
- GBNF grammar
- Model fine-tuning
- Online sync/analytics

## Capabilities

### New Capabilities
- `yachay-chat`: Chat-first UI with Yachay persona, context chips, streaming tokens, inline exercise widgets
- `yachay-mastery`: BKT per-topic mastery model, student_mastery DB table, BKT update algorithm
- `yachay-curriculum`: Aritmética knowledge graph JSON, in-memory graph traversal, Gemma-queryable via tools
- `yachay-camino`: Progress map visualization from SQLite mastery data
- `yachay-dashboard`: Teacher dashboard (group progress, alerts, difficult topics) — SQLite-only, no Gemma

### Modified Capabilities
- `ai-tool-dispatcher`: Tool set extended (6→7 tools), system prompt rewritten for Socratic persona, dispatch loop unchanged
- `ai-fallback`: 4-layer fallback extended with curriculum-aware keyword routing
- `ai-sampling`: Sampling config reused, system prompt replaced

## Approach

**Reuse 70% of ai-reengineering**: dispatch loop, action parser, tool registry, streaming bridge, fallback dispatcher remain unchanged. **New**: Chat UI screen (gemma-vision pattern), BKT engine, knowledge graph JSON + parser, system prompt rewrite. **Phased delivery**:

| Phase | Deliverable | Lines |
|-------|-------------|-------|
| 1. BKT engine | `TopicMastery` model, `student_mastery` DB migration, BKT formula | ~300 |
| 2. Chat screen | `YachayChatScreen`, message list, prompt bar, context chips | ~400 |
| 3. Camino + Perfil | Progress map + profile screens reading SQLite | ~350 |
| 4. Teacher dashboard | Group progress view, alerts, SQLite queries | ~250 |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/main.dart` | Modified | Home → YachayChatScreen, feature gate |
| `lib/modules/chat/` | New | Chat UI, YachayChatState, message widgets |
| `lib/modules/yachay/` | New | BKT engine, knowledge graph, system prompt |
| `lib/core/models/topic_mastery.dart` | New | TopicMastery, StudentMentalModel |
| `lib/core/database/database_service.dart` | Modified | Migration v2: student_mastery table |
| `lib/modules/profe/` | New | Teacher dashboard |
| `lib/modules/gemma/gemma_service.dart` | Modified | Extended tool registry, Yachay system prompt |
| `lib/modules/gemma/system_prompt.dart` | Modified | Socratic persona, tool descriptions |
| `lib/modules/diagnostico/` | Removed (gated) | Diagnostic becomes tool call |
| `lib/modules/aprendizaje/` | Removed (gated) | Ruta/Leccion replaced by chat |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Model quality on 2GB RAM degrades Socratic fidelity | Medium | 4-layer fallback; socratic filter post-processing |
| Knowledge graph content creation effort | High | AI-assisted generation, 1° scope limit |
| BKT with sparse data misclassifies readiness | Medium | Conservative P(L₀)=0.0, 90% mastery threshold |
| Students confused by chat-first interface | Low | Context chips + onboarding message from Yachay |

## Rollback Plan

Feature flag `useYachayOrchestrator` (default `true`). When `false`, `main.dart` routes to legacy `DiagnosticoScreen`. All new code lives in `lib/modules/chat/`, `lib/modules/yachay/`, `lib/modules/profe/` — zero existing code deleted.

## Dependencies

- `ai-reengineering` (archived): dispatch loop, action parser, tool registry, streaming, fallback — all reused
- Existing DB: SQLCipher encrypted SQLite (extended with migration v2)
- Existing state: `StudentState` extended with `StudentMentalModel`

## Success Criteria

- [ ] Student types "quiero aprender fracciones" → Yachay responds with Socratic question, not direct answer
- [ ] 3 correct consecutive answers on a subtopic → mastery updated to ≥90%, next topic unlocked
- [ ] Teacher dashboard shows per-student progress without calling Gemma
- [ ] `flutter build apk --debug` succeeds, APK under 50MB
- [ ] Feature flag `useYachayOrchestrator=false` restores legacy DiagnosticScreen
