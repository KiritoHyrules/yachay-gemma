# Tasks: Yachay Orquestador

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

Estimated changed lines: 2500–3500. 4 stacked PRs: (1) DB+BKT+curriculum, (2) Yachay tools+dispatch, (3) Chat UI+gate, (4) Camino+Perfil+Profe. Runtime harness: `flutter build apk --debug`.

## Phase 1: BKT + Mastery + Curriculum

- [x] 1.1 [DB] RED: test `student_mastery` table creation via v2 migration → GREEN: add `onUpgrade` v2 to `lib/core/database/database_service.dart`
- [x] 1.2 [DART] RED: `BktEngine` tests (P(L)=0→correct→0.15, 3 consec→mastered, incorrect→slip) → GREEN: create `lib/modules/yachay/bkt_engine.dart`
- [x] 1.3 [DART] Create `lib/core/models/topic_mastery.dart` data class
- [x] 1.4 [DART] RED: `CurriculoService` tests (load JSON, DAG traversal, corrupt fallback) → GREEN: create `assets/curriculum/aritmetica_1.json` + `lib/modules/yachay/curriculo_service.dart`
- [x] 1.5 [DART] Modify `lib/core/state/student_state.dart`: add `masteryMap`, `actualizarMastery()`, `cargarMastery()` 
- [x] 1.6 [TEST] REFACTOR: extract shared BKT fixtures

## Phase 2: Chat Screen (Yachay AI Core)

- [x] 2.1 [AI] RED: handler tests for `evaluar_respuesta`, `consultar_estado`, `obtener_siguiente_tema`, `obtener_plan_completo` + system prompt + dispatch (20 tests in `test/modules/yachay/yachay_tools_test.dart`)
- [x] 2.2 [AI] Create `lib/modules/yachay/tool_handlers/evaluar_respuesta.dart` — BKT update + UPSERT mastery
- [x] 2.3 [AI] Create `lib/modules/yachay/tool_handlers/consultar_estado.dart` — SELECT from mastery
- [x] 2.4 [AI] Create `lib/modules/yachay/tool_handlers/obtener_siguiente_tema.dart` — DAG + mastery join
- [x] 2.5 [AI] Create `lib/modules/yachay/tool_handlers/obtener_plan_completo.dart` — full DAG + LEFT JOIN
- [x] 2.6 [AI] Create tools: `generar_nota_progreso.dart`, `generar_resumen_alumno.dart` (mini inferences), `iniciar_conversacion.dart` (replaces `registrar_recomendacion` per apply-phase instructions)
- [x] 2.7 [AI] GREEN: all 7 handlers pass (20/20); RED: dispatch integration test (max rounds=7 constant verified)
- [x] 2.8 [AI] `SystemPrompt.buildYachay()` integrated into `lib/modules/gemma/system_prompt.dart` — Socratic persona, Peruvian Spanish, Quechua terms
- [x] 2.9 [AI] Modify `lib/modules/gemma/gemma_service.dart`: `useYachayOrchestrator` flag, 13 tools, 7r loop (`maxDispatchRounds=7`)
- [x] 2.10 [AI] Modify `lib/modules/gemma/fallback_dispatcher.dart`: Yachay keywords (L2), Yachay L4 text, 13 tools
- [x] 2.11 [AI] Modify `lib/modules/gemma/system_prompt.dart`: delegate to `buildYachay` when gate active + GREEN dispatch constant test

## Phase 3: Camino + Perfil + Teacher Dashboard

- [x] 3.1 [UI] RED: MessageBubble test (right-blue user, left-white+avatar) → GREEN: created `lib/modules/yachay/screens/chat_screen.dart` (ChatMessage, _MessageBubble, _PromptBar, _ContextChipRow, _ThinkingIndicator)
- [x] 3.2 [UI] Created `lib/modules/yachay/screens/chat_screen.dart` — MessageListView(reversed) + ThinkingIndicator + PromptBar + ContextChipRow
- [x] 3.3 [UI] RED: TopicCard color test → GREEN: created `lib/modules/yachay/screens/camino_screen.dart` (TopicProgress, _TopicCard, color-coded progress bars)
- [x] 3.4 [UI] Created `lib/modules/yachay/screens/perfil_screen.dart` (StudentStats, Achievement, _AvatarCard, _StatsGrid, _YachayInsightCard, _AchievementsSection)
- [x] 3.5 [UI] Created `lib/modules/yachay/screens/teacher_dashboard.dart` (TeacherStudentSummary, _StudentRow, _StudentDetailSheet) — renders without Gemma

## Phase 4: Integration

- [x] 4.1 [UI] Created `lib/modules/yachay/screens/yachay_scaffold.dart` (in Phase 3) — BottomNavigationBar (Chat|Camino|Perfil), preserves state with IndexedStack
- [x] 4.2 [DART] Modified `lib/main.dart`: gate (`useYachayOrchestrator` true→YachayScaffold, false→DiagnosticoScreen), added yachay_scaffold import
- [x] 4.3 [TEST] RED→GREEN: 4 integration tests in `test/modules/yachay/yachay_integration_test.dart` (gate ON→Yachay, gate OFF→DiagnosticoScreen, greeting, nav switch)
- [x] 4.4 [DART] `flutter build apk --debug` passed — APK built successfully (pre-existing ~186MB debug size; model external)
- [x] 4.5 [DART] Full `flutter test` — 183/189 pass (6 pre-existing failures unchanged). No refactor needed — imports verified clean.
