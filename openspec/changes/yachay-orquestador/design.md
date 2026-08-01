# Design: Yachay Orquestador

## Technical Approach

Reuse 70% of `ai-reengineering`: dispatch loop, `ActionParser`, `ToolRegistry`, streaming bridge, `FallbackDispatcher`. Add: Chat UI (gemma-vision pattern), BKT engine, 45-node knowledge graph, 7 new tools, Yachay system prompt, teacher dashboard (SQLite-only). Feature gate: `useYachayOrchestrator` (bool, default `true`) replaces `useXmlDispatch`. When `false`, routes to legacy `DiagnosticoScreen`.

## Architecture Decisions

### ADR-1: BKT over Simple Percentage

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Simple % (correct/total) | Fast, no parameters | Rejected — ignores learning rate, guessing, slipping |
| BKT (4-parameter) | Models latent knowledge; P(L) separates knowledge from performance | **Chosen** |
| ELO-based | Continuous ranking; no binary mastery | Rejected — too complex for 45-topic DAG |

BKT estimates latent knowledge (P(L)), not just observed performance. Conservative defaults (P(L₀)=0.0, transit=0.15, slip=0.10, guess=0.20) prevent premature mastery. Student reaches ≥0.90 only after 3+ consecutive correct answers on a subtopic.

### ADR-2: 3 Screens + Teacher Dashboard over Single Screen

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Single chat screen | Simple; everything inline | Rejected — progress and profile buried |
| 3 screens (Chat, Camino, Perfil) + Teacher Dashboard | Slightly more code; clear separation | **Chosen** |

Chat is primary; Camino/Perfil are read-only SQLite views. Teacher Dashboard is separate entry point (no AI dependency). Bottom nav preserves chat state on tab switch.

### ADR-3: Teacher Dashboard Reads SQLite Directly

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Teacher Dashboard calls Gemma | Fresh insights every time | Rejected — requires model loaded |
| Cache Yachay insights during sessions | Pre-computed; always available | **Chosen** |

Yachay writes `yachay_recomendacion` into `student_mastery` during student sessions. Teacher view queries SQLite read-only — works even when model fails to load.

## Data Flow

```
User msg → GemmaService.procesarMensaje()
  ├── useYachayOrchestrator? false → DiagnosticoScreen (legacy)
  └── true:
      ├── model not loaded? → FallbackDispatcher (L1-L4, Yachay extended)
      └── model loaded → Dispatch loop (max 7 rounds):
          ├── sendWithStreaming(prompt, systemPrompt: yachayPrompt)
          ├── findNextAction(output) → ParsedAction
          ├── ToolRegistry.run(tool, args, ctx)
          │   ├── evaluar_respuesta → BKT.update() → SQLite UPSERT
          │   ├── consultar_estado → SQLite SELECT
          │   ├── obtener_siguiente_tema → DAG.traverse() + SQLite
          │   ├── obtener_plan_completo → DAG + SQLite mastery join
          │   ├── generar_nota_progreso → Gemma mini-inference
          │   ├── generar_resumen_alumno → Gemma mini-inference
          │   └── registrar_recomendacion → SQLite UPDATE
          ├── feed tool result → next round
          └── speak → return text → UI renders MessageBubble
```

Teacher dashboard flow (no Gemma):
```
ProfesorDashboardScreen
  ├── SQLite: SELECT alias, last_active, masterCount FROM student_profile
  ├── StudentListView → tap → StudentDetailSheet
  └── SQLite: SELECT topic_id, p_learned, yachay_recomendacion
       FROM student_mastery WHERE student_id = ?
```

## UI Component Tree

```
MaterialApp
├── YachayScaffold (BottomNavigationBar: Chat | Camino | Perfil)
│   ├── ChatScreen
│   │   ├── YachayAppBar (avatar + "Yachay" + grade badge "1° Sec")
│   │   ├── MessageListView (ListView.builder, reversed)
│   │   │   ├── MessageBubble (user → right, blue #1565C0 bg, white text)
│   │   │   ├── MessageBubble (yachay → left, white bg, avatar leading)
│   │   │   └── ThinkingIndicator ("Yachay está pensando..." animated dots)
│   │   ├── ContextChipRow (4 FilterChips: Explicar, Practicar, Mi progreso, Cambiar tema)
│   │   └── PromptBar (TextField + IconButton.send + IconButton.mic[disabled])
│   ├── CaminoScreen
│   │   ├── TopicProgressList (ListView)
│   │   │   └── TopicCard (icon + name + LinearProgressIndicator + color bar)
│   │   └── YachayIntervention (bottom sheet, on topic tap)
│   └── PerfilScreen
│       ├── StudentAvatarCard (CircleAvatar + name + grade)
│       ├── StatsGrid (3 cards: tiempo total, ejercicios, precisión)
│       ├── YachayInsightCard ("Lo que Yachay sabe de vos")
│       └── AchievementsList (GridView, deterministic rules)
└── (separate entry) DashboardScreen
    ├── StudentListView (ListView)
    │   └── StudentRow (name, lastActive, "N/45 mastered", accuracy%)
    └── StudentDetailSheet (scrollable topic list, yachay_recomendacion)
```

## BKT Algorithm

**Table**: `student_mastery(student_id TEXT, topic_id TEXT, p_learned REAL, attempts INT, correct INT, consecutive_correct INT, last_interaction TEXT, yachay_recomendacion TEXT, PRIMARY KEY(student_id, topic_id))`

**Dart formula** (`lib/modules/yachay/bkt_engine.dart`):
```dart
class BktEngine {
  static const pLearn0 = 0.0;   // P(L₀)
  static const pTransit = 0.15; // P(T)
  static const pGuess = 0.20;   // P(G)
  static const pSlip = 0.10;    // P(S)
  static const masteryThreshold = 0.90;

  static double updatePLearned(double currentPL, bool correct) {
    if (correct) {
      // P(L|correct) = P(L) + (1-P(L)) * P(T)  (learning forward)
      return currentPL + (1.0 - currentPL) * pTransit;
    } else {
      // P(L|incorrect) = P(L) * (1-P(S)) / (P(L)*(1-P(S)) + (1-P(L))*P(G))
      final slipTerm = currentPL * (1.0 - pSlip);
      final guessTerm = (1.0 - currentPL) * pGuess;
      return slipTerm / (slipTerm + guessTerm);
    }
  }

  static bool isMastered(double pLearned) => pLearned >= masteryThreshold;
}
```

**Query**: `consultar_estado(tema)` → `SELECT p_learned, attempts, consecutive_correct FROM student_mastery WHERE topic_id = ?`.

## Curriculum JSON (`assets/curriculum/aritmetica_1.json`)

15 competencies, ~45 subtopics, prerequisite DAG:
```json
{
  "materia": "Aritmética",
  "grado": 1,
  "competencias": [
    {
      "id": "arit_nn",
      "titulo": "Números Naturales",
      "descripcion": "Comprender y operar con números naturales",
      "dificultad": 1,
      "subtemas": [
        { "id": "arit_nn_01a", "titulo": "Valor Posicional", "prerrequisitos": [],
          "ejemplo": "¿Qué valor tiene el 5 en 352?" },
        { "id": "arit_nn_01b", "titulo": "Lectura y Escritura", "prerrequisitos": ["arit_nn_01a"],
          "ejemplo": "Escribe 1208 en palabras" },
        { "id": "arit_nn_02a", "titulo": "Suma sin llevar", "prerrequisitos": ["arit_nn_01a"],
          "ejemplo": "Calcula 234 + 512" }
      ]
    }
  ]
}
```

`CurriculoService` loads JSON at startup, builds in-memory DAG (`Map<String, SubTemaNode>`), exposes `obtenerSiguienteTema()` and `obtenerPlanCompleto()`.

## Tool Extensions (7 new, total 13)

| # | Tool | Handler | SQL / Action |
|---|------|---------|-------------|
| 1 | `evaluar_respuesta(tema, correcta)` | `lib/modules/yachay/tools/evaluar_respuesta.dart` | BKT update + UPSERT `student_mastery` |
| 2 | `consultar_estado(tema)` | `lib/modules/yachay/tools/consultar_estado.dart` | `SELECT` from `student_mastery` |
| 3 | `obtener_siguiente_tema()` | `lib/modules/yachay/tools/obtener_siguiente_tema.dart` | DAG traversal + mastery join |
| 4 | `obtener_plan_completo()` | `lib/modules/yachay/tools/obtener_plan_completo.dart` | Full DAG + `LEFT JOIN student_mastery` |
| 5 | `generar_nota_progreso(tema)` | `lib/modules/yachay/tools/generar_nota_progreso.dart` | Mini Gemma inference (1-2 sentence note) |
| 6 | `generar_resumen_alumno()` | `lib/modules/yachay/tools/generar_resumen_alumno.dart` | Mini Gemma inference + cache in memory |
| 7 | `registrar_recomendacion(texto)` | `lib/modules/yachay/tools/registrar_recomendacion.dart` | `UPDATE student_mastery SET yachay_recomendacion = ?` |

All 7 follow existing `ToolSpec(name, description, params, handler)` pattern. Registered in `_inicializarRegistry()` alongside existing 6.

## System Prompt Design

`lib/modules/yachay/yachay_system_prompt.dart` replaces `SystemPrompt.build()`:

```
Eres Yachay, un tutor socrático de aritmética para estudiantes de 1° de secundaria
en Perú. NUNCA des respuestas directas — guía con preguntas. Usá español peruano
cálido (sumaq = bonito, allin = bien hecho). Celebrá cuando el estudiante domina
un tema. Referenciá los temas que ya domina por su nombre. Sugerí el siguiente paso
usando obtener_siguiente_tema().

REGLAS:
1. Preguntá, no respondás. Si preguntan "¿cuánto es 3/4 + 1/2?", respondé:
   "¿Qué necesitás para sumar fracciones con distinto denominador?"
2. Si el estudiante se frustra, ofrecé apoyo emocional y reducí dificultad.
3. Usá ejemplos del contexto peruano: soles, mercados, chacras, cevicherías.
4. Al iniciar conversación con nuevo estudiante, presentate: "¡Hola! Soy Yachay,
   tu tutor de aritmética. ¿Qué querés aprender hoy?"
5. NUNCA des respuestas literales a ejercicios.
6. Si el estudiante responde bien 3 veces seguidas, felicitalo con entusiasmo.
```

Tool list appended by `SystemPrompt.build(tools)` as before (XML format unchanged).

## Teacher Dashboard Data Flow

Yachay writes insights during student sessions:
1. `registrar_recomendacion(texto)` → `UPDATE student_mastery SET yachay_recomendacion = ?`  
2. `evaluar_respuesta` → UPSERT into `student_mastery`

Teacher view reads SQLite directly:
1. `SELECT s.alias, COUNT(sm.topic_id) as mastered FROM student_profile s LEFT JOIN student_mastery sm ON s.id = sm.student_id WHERE sm.p_learned >= 0.90 GROUP BY s.id`  
2. Detail: `SELECT topic_id, p_learned, yachay_recomendacion FROM student_mastery WHERE student_id = ?`

No Gemma calls. Works offline. Read-only — teacher cannot modify student data.

## Sequence Diagram

```
Student      ChatScreen      GemmaService      ToolRegistry      BKTEngine      SQLite
  │              │                 │                 │                │             │
  │ "hola Yachay"│                 │                 │                │             │
  │─────────────>│                 │                 │                │             │
  │              │ procesarMensaje │                 │                │             │
  │              │────────────────>│                 │                │             │
  │              │                 │ sendWithStreaming│               │             │
  │              │                 │─────────────────│                │             │
  │              │  onToken("¡Hola!")                 │                │             │
  │              │<────────────────│                 │                │             │
  │              │  render bubble  │                 │                │             │
  │              │                 │                 │                │             │
  │ "practicar"  │                 │                 │                │             │
  │─────────────>│                 │                 │                │             │
  │              │ procesarMensaje │                 │                │             │
  │              │────────────────>│                 │                │             │
  │              │                 │ sendWithStreaming│               │             │
  │              │                 │─────────(round 1)│               │             │
  │              │                 │ <action name="   │                │             │
  │              │                 │   obtener_siguiente_tema"/>       │             │
  │              │                 │<────────────────│                │             │
  │              │                 │ run("obtener_siguiente_tema")     │             │
  │              │                 │─────────────────>│               │             │
  │              │                 │                  │ DAG.traverse()│             │
  │              │                 │                  │──────────────>│             │
  │              │                 │                  │  SELECT p_learned            │
  │              │                 │                  │──────────────────────────────>│
  │              │                 │                  │  [{topic: arit_nn_01a, ...}] │
  │              │                 │                  │<──────────────────────────────│
  │              │                 │  result: {id: "arit_nn_01a", titulo: "Valor..."}│
  │              │                 │<─────────────────│                │             │
  │              │                 │ sendWithStreaming│                │             │
  │              │                 │─────────(round 2)│                │             │
  │              │                 │ "¡Empecemos con Valor Posicional! ¿Listo?"      │
  │              │                 │<────────────────│                │             │
  │              │  render bubble  │                 │                │             │
  │<─────────────│                 │                 │                │             │
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/modules/chat/yachay_chat_screen.dart` | Create | Chat-first UI with message list, prompt bar, context chips |
| `lib/modules/chat/widgets/message_bubble.dart` | Create | Right-aligned blue (user) / left-aligned white (Yachay) bubbles |
| `lib/modules/chat/widgets/prompt_bar.dart` | Create | Text input + send + mic placeholder, adapted from gemma-vision |
| `lib/modules/chat/widgets/context_chips.dart` | Create | 4 FilterChip: Explicar, Practicar, Mi progreso, Cambiar tema |
| `lib/modules/yachay/bkt_engine.dart` | Create | BKT formula: P(L|obs) update, mastery check |
| `lib/modules/yachay/curriculo_service.dart` | Create | JSON loader, in-memory DAG, prerequisite traversal |
| `lib/modules/yachay/yachay_system_prompt.dart` | Create | Socratic persona prompt builder, replaces SystemPrompt |
| `lib/modules/yachay/tools/evaluar_respuesta.dart` | Create | BKT update handler |
| `lib/modules/yachay/tools/consultar_estado.dart` | Create | Mastery query handler |
| `lib/modules/yachay/tools/obtener_siguiente_tema.dart` | Create | DAG next-topic handler |
| `lib/modules/yachay/tools/obtener_plan_completo.dart` | Create | Full curriculum + mastery handler |
| `lib/modules/yachay/tools/generar_nota_progreso.dart` | Create | Mini-inference for note |
| `lib/modules/yachay/tools/generar_resumen_alumno.dart` | Create | Mini-inference for profile |
| `lib/modules/yachay/tools/registrar_recomendacion.dart` | Create | Store teacher insight handler |
| `lib/modules/camino/camino_screen.dart` | Create | Progress map with TopicCard list |
| `lib/modules/camino/widgets/topic_card.dart` | Create | Color-coded topic progress card |
| `lib/modules/camino/widgets/yachay_intervention.dart` | Create | Bottom sheet with Yachay note |
| `lib/modules/perfil/perfil_screen.dart` | Create | Student profile with stats, insights, achievements |
| `lib/modules/perfil/widgets/achievements_list.dart` | Create | Deterministic achievement grid |
| `lib/modules/profe/dashboard_screen.dart` | Create | Teacher student list |
| `lib/modules/profe/student_detail_sheet.dart` | Create | Per-student mastery breakdown |
| `lib/core/models/topic_mastery.dart` | Create | TopicMastery data class |
| `lib/core/database/database_service.dart` | Modify | Migration v2: add `student_mastery` table |
| `lib/core/state/student_state.dart` | Modify | Add `StudentMentalModel` field, mastery methods |
| `lib/modules/gemma/gemma_service.dart` | Modify | `useYachayOrchestrator` flag, register 7 new tools, dispatch loop → 7 rounds |
| `lib/modules/gemma/fallback_dispatcher.dart` | Modify | Layer 2 Yachay keywords, Layer 4 Yachay persona |
| `lib/main.dart` | Modify | Feature gate `useYachayOrchestrator`, provider wiring for BKT/Curriculum services |
| `lib/modules/gemma/system_prompt.dart` | Replace | Delegate to `YachaySystemPrompt` when gate active |
| `assets/curriculum/aritmetica_1.json` | Create | 15 competencies, ~45 subtopics, prerequisite DAG |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | BKT formula edge cases (P(L)=0, P(L)=1, streak reset) | Dart test with known inputs |
| Unit | DAG traversal: locked/unlocked/max-progress states | Mock SQLite queries |
| Unit | Tool handlers return valid ToolResult for all params | Call handlers with mock ToolContext |
| Widget | MessageBubble renders user vs Yachay correctly | Flutter widget test |
| Widget | TopicCard color coding (green/yellow/white/gray) | Provide mock P(L) values |
| Integration | Dispatch loop: user msg → tool call → correct tool executes | Mock Gemma output with XML action tags |
| Integration | Teacher dashboard renders without Gemma model | Test with empty/missing model |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

Feature flag `useYachayOrchestrator` (default `true`) in `GemmaService`. When `false`, `main.dart` routes to legacy `DiagnosticoScreen`. DB migration v2 (`student_mastery` table) runs `onUpgrade` — additive, non-destructive. No data migration required.

## Open Questions

- [ ] Confirm 2GB RAM devices handle 7-round dispatch + BKT + streaming without OOM
- [ ] Teacher dashboard: how does teacher access it? (separate app? gesture? PIN-protected menu?)
- [ ] Mini-inference for `generar_nota_progreso` and `generar_resumen_alumno` — separate lightweight prompt or re-entrant dispatch loop?
