# Proceso 6.4.4 — Architecture Definition (ISO/IEC/IEEE 15288:2015)
# Aplicado al Problema 2: Deficiencia Estructural en Logros de Aprendizaje

**Input desde 6.4.3:** SyRS (SR-A01 a SR-E05), RP-01 a RP-10, INT-01 a INT-08, RQ-01 a RQ-08, RES-01 a RES-05, NR-01 a NR-08, MOPs, TPMs, estrategia de verificación (D.3)
**Proceso siguiente:** 6.4.5 Design Definition
**Nota:** ISO 12207:2017 — 6.4.4 es idéntico en estructura a ISO 15288:2015. La NTP-ISO/IEC 12207:2006 cubre este proceso en 5.3.3 (Diseño de la Arquitectura del Sistema). Este documento se alinea con ambos estándares, priorizando 12207 por ser un sistema intensivo en software.

---

## Actividad A: Preparar la Definición de Arquitectura

### A.1 Analizar el Entorno de la Solución

| Factor | Valor | Impacto Arquitectónico |
|---|---|---|
| **Plataforma objetivo** | Dispositivos Android 6+ con 2GB RAM, quad-core 1.2GHz | La arquitectura debe minimizar consumo de recursos. No se pueden usar patrones enterprise pesados. |
| **Conectividad** | 79% de colegios públicos sin internet | **Offline-first es mandatorio.** Toda funcionalidad core debe operar sin red. La nube es solo para sincronización diferida. |
| **Motor de IA** | Gemma (obligatorio por bases hackathon) | El modelo debe ejecutarse on-device (TFLite). No se permite inferencia en la nube. |
| **Tiempo de desarrollo** | 5-7 horas (hackathon) | Arquitectura monolítica con módulos bien separados. Microservicios diferidos a fase 2. |
| **Stack permitido** | Python, JavaScript, Flutter, Android, Firebase, Cloud Run | Firebase como BaaS (backend serverless), Cloud Run para API de reportes. |
| **Distribución** | APK + distribución offline (USB/Bluetooth) | Sin dependencia de Google Play Store. El APK debe ser auto-contenido. |
| **Regulatorio** | Protección de datos de menores (Ley 29733) | Cifrado AES-256 en reposo. Anonimización en reportes. Android Keystore. |
| **Contexto social** | Zonas rurales y periurbanas, estudiantes de 12-17 años | UX liviana, no dependiente de animaciones pesadas. Textos y ejercicios precargados. |

### A.2 Identificar Requisitos Críticos para la Arquitectura

Estos requisitos de 6.4.3 son los **drivers arquitectónicos** principales:

| ID | Requisito | Clasificación | Driver |
|---|---|---|---|
| **NR-01** | Gemma obligatorio | Restricción no negociable | Define el componente de IA on-device |
| **NR-02** | Offline-first | Restricción no negociable | Define arquitectura local-first con sync diferida |
| **SR-B07** | Gemma on-device, compatible con 2GB RAM | Funcional crítico | Define modelo quantizado y framework de inferencia |
| **SR-C01** | SQLite cifrado AES-256 | Funcional crítico | Define capa de persistencia y seguridad |
| **SR-C04** | APK funcional (peso optimizado pero no bloqueante) | Rendimiento | Define estrategia de empaquetado de assets |
| **RNF-05** | Privacidad de menores | Calidad crítico | Define cifrado y anonimización |
| **RNF-04** | Rendimiento en dispositivos básicos | Calidad crítico | Define límites de consumo de recursos |
| **RQ-05** | 100% funcionalidad estudiante offline por ≥7 días | Calidad crítico | Define estrategia de precarga y almacenamiento local |

### A.3 Capturar Preocupaciones de Stakeholders

| Stakeholder | Preocupación | Impacto Arquitectónico |
|---|---|---|
| **Estudiantes (SH-01)** | "Que funcione sin internet en mi casa" | Offline-first. Todo el contenido precargado. |
| **Docentes (SH-03)** | "Que sea fácil de usar, no necesito ser técnico" | Panel docente con ≤3 secciones. Generación de PDF simple. |
| **SUTEP (SH-04)** | "Que no sea una herramienta para evaluarme" | **Sin módulo de analítica docente.** Los datos se anonimizan antes de cualquier agregación. |
| **UMC-MINEDU (SH-05)** | "Que el diagnóstico sea comparable con ENLA" | El algoritmo de diagnóstico DEBE ser trazable y validable externamente. |
| **MINEDU (SH-06)** | "Que escale a nivel nacional" | Arquitectura preparada para multi-tenancy regional en fases 2-3. |
| **Equipo Dev (SH-08)** | "Que se pueda construir en 5-7 horas" | Máxima simplicidad. Componentes mínimos. Sin infraestructura compleja. |

### A.4 Establecer el Enfoque Arquitectónico

| Elemento | Decisión | Justificación |
|---|---|---|
| **Marco de modelado** | **C4 Model** (Context, Containers, Components) | Simple, enfocado en software, no requiere entrenamiento en ArchiMate. Suficiente para el nivel de detalle del prototipo. |
| **Vistas complementarias** | Diagrama de despliegue físico + Diagrama de flujo de datos | Complementan C4 con perspectiva de infraestructura y datos. |
| **Formato de documentación** | Markdown + Mermaid (diagramas como código) | Versionable, liviano, no requiere herramientas especializadas. |
| **Estándar de descripción** | ISO/IEC/IEEE 42010:2011 | Define formalmente viewpoints, views, concerns, correspondence rules. |
| **Registro de decisiones** | ADR (Architecture Decision Records) | Formato ligero: Título, Estado, Contexto, Decisión, Consecuencias. Suficiente para prototipo. |
| **Herramientas** | draw.io / Mermaid / Excalidraw | Cualquier herramienta de diagramación. Los diagramas se versionan como imágenes o código. |

### A.5 Sistemas Habilitadores para la Arquitectura

| Habilitador | Propósito | Estado |
|---|---|---|
| **Android Studio + Flutter SDK** | Entorno de desarrollo para APK | A verificar antes del 1 agosto |
| **Gemma modelo quantizado (TFLite)** | Motor de IA on-device | A verificar disponibilidad y peso |
| **Firebase project** | Backend para sync y reportes | A crear durante hackathon |
| **Cloud Run** | API de reportes anonimizados | A crear durante hackathon |
| **Dispositivo de prueba** | Android 6+, 2GB RAM para testing | A conseguir antes del 1 agosto |

---

## Actividad B: Desarrollar Puntos de Vista de Arquitectura (Viewpoints)

Siguiendo ISO/IEC/IEEE 42010:2011. Para un sistema intensivo en software como Aprendo+, se definen los siguientes viewpoints:

| ID | Viewpoint | Preocupaciones que aborda | Stakeholders | Tipo de modelo |
|---|---|---|---|---|
| **VP-01** | **Funcional** | ¿Qué funciones realiza el sistema? ¿Cómo se relacionan con los requisitos? | SH-01, SH-03, SH-05, SH-06 | Diagrama de bloques funcionales, flujo de datos |
| **VP-02** | **Lógico (Software)** | ¿Cómo se estructuran los componentes de software? ¿Qué responsabilidades tienen? | SH-08 | C4 Container/Component, modelo de dominio |
| **VP-03** | **Físico (Despliegue)** | ¿Dónde se ejecuta cada componente? ¿Qué recursos consume? | SH-08 | Diagrama de despliegue, topología de red |
| **VP-04** | **Datos** | ¿Cómo se almacenan, fluyen y protegen los datos? | SH-04, SH-05, SH-06 | Diagrama de flujo de datos, modelo de datos |
| **VP-05** | **Escenarios** | ¿Cómo interactúan los usuarios con el sistema en situaciones reales? | SH-01, SH-03 | Diagramas de secuencia, flujos de usuario |

---

## Actividad C: Desarrollar Modelos y Vistas de Arquitecturas Candidatas

### C.1 Vista Funcional (VP-01) — ¿Qué hace el sistema?

```
┌──────────────────────────────────────────────────────────────┐
│                    APRENDO+ — FUNCIONES                      │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  F1: DIAGNÓSTICO │  │  F2: APRENDIZAJE│  │F3: PRÁCTICA  │ │
│  │  Adaptativo      │  │  Personalizado  │  │  Adaptativa  │ │
│  │  (SR-A01-A06)    │  │  (SR-B01-B07)   │  │  (SR-B02)    │ │
│  └────────┬────────┘  └────────┬────────┘  └──────┬───────┘ │
│           │                    │                    │         │
│           ▼                    ▼                    ▼         │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              CAPA DE PERSISTENCIA LOCAL                 │ │
│  │  (SR-C01, SQLite + AES-256)                             │ │
│  └─────────────────────────────────────────────────────────┘ │
│           │                    │                    │         │
│           ▼                    ▼                    ▼         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  F4: PANEL      │  │ F5: SINCRONIZ.  │  │F6: DASHBOARD │ │
│  │  DOCENTE        │  │  Diferida       │  │  MINEDU      │ │
│  │  (SR-D01-D06)   │  │  (SR-C02-C03)   │  │(SR-E01-E05)  │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│                                                              │
│  [OFFLINE] F1-F4 operan sin internet                        │
│  [ONLINE]  F5-F6 requieren conectividad                     │
└──────────────────────────────────────────────────────────────┘
```

### C.2 Vista Lógica — C4 Model (VP-02)

#### C.2.1 Nivel 1: Diagrama de Contexto

```
┌──────────────────────────────────────────────────────────────────┐
│                        CONTEXTO DEL SISTEMA                      │
│                                                                  │
│   ┌──────────┐                    ┌──────────────────────────┐   │
│   │Estudiante│──Usa app──────►    │                          │   │
│   │(SH-01)   │                    │     APRENDO+             │   │
│   └──────────┘                    │  (Sistema de Tutoría     │   │
│                                   │   con IA)                │   │
│   ┌──────────┐                    │                          │   │
│   │ Docente  │──Ve dashboard──►   │  [Android APK]           │   │
│   │(SH-03)   │                    │  [PWA — fase 2]          │   │
│   └──────────┘                    │                          │   │
│                                   └───────┬──────────────────┘   │
│   ┌──────────┐                            │                      │
│   │ MINEDU   │──Ve reportes──────────────►│  (solo online)       │
│   │ UMC      │                            │                      │
│   │(SH-05/06)│                    ┌───────▼──────────────────┐   │
│   └──────────┘                    │   Firebase / Cloud Run  │   │
│                                   │   (Backend Cloud)       │   │
│                                   └──────────────────────────┘   │
│                                                                  │
│   ┌──────────┐                    ┌──────────────────────────┐   │
│   │ SUTEP    │──Audita que no────►│  Verificación externa    │   │
│   │(SH-04)   │  hay ranking       │  (CA-03, fase 2)        │   │
│   └──────────┘                    └──────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

#### C.2.2 Nivel 2: Diagrama de Contenedores

```
┌────────────────────────────────────────────────────────────────────┐
│  ESTUDIANTE (SH-01)              DOCENTE (SH-03)                   │
│  ┌────────────────────┐          ┌────────────────────┐            │
│  │  App Android       │          │  App Android       │            │
│  │  (Modo Estudiante) │          │  (Modo Docente)    │            │
│  │                    │          │                    │            │
│  │ ┌──────────────┐   │          │ ┌──────────────┐   │            │
│  │ │ Diagnóstico  │   │          │ │ Panel        │   │            │
│  │ │ Adaptativo   │   │          │ │ Analytics    │   │            │
│  │ └──────────────┘   │          │ └──────────────┘   │            │
│  │ ┌──────────────┐   │          │ ┌──────────────┐   │            │
│  │ │ Motor Gemma  │   │          │ │ Generador    │   │            │
│  │ │ on-device    │   │          │ │ PDF Aula     │   │            │
│  │ └──────────────┘   │          │ └──────────────┘   │            │
│  │ ┌──────────────┐   │          │                    │            │
│  │ │ Lecciones    │   │          │                    │            │
│  │ │ (JSON local) │   │          │                    │            │
│  │ └──────────────┘   │          │                    │            │
│  └────────┬───────────┘          └────────┬───────────┘            │
│           │                               │                        │
│           │ [OFFLINE]                     │ [OFFLINE]               │
│           ▼                               ▼                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                 SQLite (AES-256 cifrado)                     │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐  │   │
│  │  │ Perfil   │  │ Registro │  │ Contenido│  │ Ejercicios  │  │   │
│  │  │ Estudiante│ │ Interacc.│  │ Lecciones│  │ Generados   │  │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────────┘  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ═══════════════ [SOLO CUANDO HAY INTERNET] ════════════════════   │
│           │                                                         │
│           ▼                                                         │
│  ┌────────────────────┐    ┌────────────────────┐                  │
│  │ Firebase (Backend)  │───►│  Cloud Run (API)   │                  │
│  │ • Sync diferida     │    │  • Reportes        │                  │
│  │ • Auth anónimo      │    │  • Analytics       │◄─── MINEDU       │
│  │ • Almacenamiento    │    │  • Dashboard       │    (SH-05,06)    │
│  └────────────────────┘    └────────────────────┘                  │
└────────────────────────────────────────────────────────────────────┘
```

#### C.2.3 Nivel 3: Diagrama de Componentes (App Android)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    APK APRENDO+ (Android)                           │
│                                                                     │
│  ┌──────────────────────┐    ┌──────────────────────────────┐      │
│  │ Módulo Diagnóstico   │    │ Módulo Aprendizaje           │      │
│  │ (SR-A01 a A06)       │    │ (SR-B01 a B07)               │      │
│  │                      │    │                              │      │
│  │ • Banco de ítems     │    │ • Lecciones JSON precargadas │      │
│  │ • Algoritmo IRT      │    │ • Textos lectura (≥50)       │      │
│  │ • Selector adaptativo│    │ • Vista de lección           │      │
│  │ • Conversor nivel →  │    │ • Input de respuestas        │      │
│  │   etiqueta positiva  │    │ • Generador de ruta          │      │
│  └──────────┬───────────┘    └──────────────┬───────────────┘      │
│             │                               │                      │
│             ▼                               ▼                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Motor Gemma (TFLite on-device)                  │  │
│  │              (SR-B02, SR-B07, NR-01)                         │  │
│  │                                                              │  │
│  │  • Inferencia local (sin API)                                │  │
│  │  • Generación de explicaciones alternativas                  │  │
│  │  • Detección de patrones de error                            │  │
│  │  • Generación de ejercicios de refuerzo                      │  │
│  │  • Modelo quantizado (INT4/INT8)                             │  │
│  └──────────────────────────────────────────────────────────────┘  │
│             │                               │                      │
│             ▼                               ▼                      │
│  ┌──────────────────────┐    ┌──────────────────────────────┐      │
│  │ Módulo Persistencia  │    │ Módulo Panel Docente         │      │
│  │ (SR-C01 a C06)       │    │ (SR-D01 a D06)               │      │
│  │                      │    │                              │      │
│  │ • SQLite Helper      │    │ • Dashboard agregado         │      │
│  │ • AES-256 encrypt    │    │ • Generador PDF              │      │
│  │ • Android Keystore   │    │ • Sin ranking docente        │      │
│  │ • Migration manager  │    │ • Sin datos individuales     │      │
│  └──────────┬───────────┘    └──────────────────────────────┘      │
│             │                                                       │
│             ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Módulo Sincronización (Firebase)                │  │
│  │              (SR-C02, SR-C03, SR-C06, INT-03, INT-04)        │  │
│  │                                                              │  │
│  │  • Detector de conectividad                                  │  │
│  │  • Cola de sync con reintento                                │  │
│  │  • Idempotencia garantizada                                  │  │
│  │  • Tolerancia a interrupciones                               │  │
│  │  [SOLO ACTIVO CUANDO HAY INTERNET]                           │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Capa de UI (Flutter / Jetpack Compose)           │  │
│  │  • Navegación: Diagnóstico → Ruta → Lección → Práctica       │  │
│  │  • Tema: colores positivos, sin números de grado             │  │
│  │  • Gamificación opcional: logros individuales, no competencia │  │
│  │  • Accesibilidad: texto escalable, alto contraste             │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### C.3 Vista Física — Diagrama de Despliegue (VP-03)

```
┌──────────────────────────────────────────────────────────────────┐
│  DISPOSITIVO ANDROID (2GB RAM, 16GB storage, Android 6+)        │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  APK APRENDO+ (.apk)                                    │     │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │     │
│  │  │Dart/Flutter│ │Gemma    │ │Lecciones │ │Textos     │  │     │
│  │  │Código UI  │ │TFLite   │ │JSON (10) │ │Lectura(50)│  │     │
│  │  │(≈8MB)    │ │(≈30MB*) │ │(≈2MB)   │ │(≈3MB)    │  │     │
│  │  └──────────┘ └──────────┘ └──────────┘ └───────────┘  │     │
│  └────────────────────────────────────────────────────────┘     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  SQLite DB (interno, cifrado AES-256)                   │     │
│  │  • student_profile                                      │     │
│  │  • interaction_log                                      │     │
│  │  • generated_exercises                                  │     │
│  └────────────────────────────────────────────────────────┘     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Android Keystore (claves de cifrado)                   │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘

    │ [SOLO CUANDO HAY CONECTIVIDAD]
    ▼

┌──────────────────────────────────────────────────────────────────┐
│  GOOGLE CLOUD (us-east1 / southamerica)                          │
│                                                                  │
│  ┌────────────────────┐    ┌────────────────────────────┐        │
│  │ Firebase           │    │ Cloud Run                  │        │
│  │ • Firestore (sync) │    │ • API /reportes            │        │
│  │ • Auth (anónimo)   │    │ • API /dashboard           │        │
│  │ • Storage (assets) │    │ • Python/Node.js           │        │
│  └────────────────────┘    │ • Autenticación MINEDU      │        │
│                            │ • Rate limiting             │        │
│                            └────────────────────────────┘        │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐      │
│  │ MINEDU / UMC (SH-05, SH-06)                            │      │
│  │ Dashboard web → consulta API → datos anonimizados      │      │
│  └────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────┘
```

*El peso del modelo Gemma es estimado. El valor real se verificará al obtener el modelo quantizado. Si el peso total del APK supera 100MB, se justifica técnicamente (P-08 de 6.2.1).*

### C.4 Vista de Datos — Modelo y Flujo (VP-04)

#### C.4.1 Esquema Lógico de Datos

```
┌──────────────────────────────────────────────────────────────────┐
│                     SQLite (Local, cifrado)                      │
│                                                                  │
│  ┌───────────────────┐   ┌───────────────────┐                  │
│  │ student_profile   │   │ interaction_log   │                  │
│  │───────────────────│   │───────────────────│                  │
│  │ id (PK)           │   │ id (PK)           │                  │
│  │ student_alias     │◄──│ student_id (FK)   │                  │
│  │ diagnostic_level  │   │ lesson_id         │                  │
│  │ math_level        │   │ exercise_id       │                  │
│  │ reading_level     │   │ response          │                  │
│  │ current_lesson_id │   │ is_correct        │                  │
│  │ learning_path     │   │ error_type        │                  │
│  │ total_time_min    │   │ time_spent_sec    │                  │
│  │ last_sync_ts      │   │ timestamp         │                  │
│  └───────────────────┘   │ sync_status       │                  │
│                          └───────────────────┘                  │
│  ┌───────────────────┐   ┌───────────────────┐                  │
│  │ lesson_content    │   │ generated_exercise│                  │
│  │───────────────────│   │───────────────────│                  │
│  │ id (PK)           │   │ id (PK)           │                  │
│  │ subject           │   │ student_id (FK)   │                  │
│  │ title             │   │ lesson_id         │                  │
│  │ difficulty_level  │   │ error_type        │                  │
│  │ video_path        │   │ prompt            │                  │
│  │ explanation_json  │   │ correct_answer    │                  │
│  │ content_json      │   │ generated_by      │                  │
│  └───────────────────┘   └───────────────────┘                  │
└──────────────────────────────────────────────────────────────────┘

    │ [SINCRONIZACIÓN — solo cuando hay internet]
    ▼

┌──────────────────────────────────────────────────────────────────┐
│              Firebase Firestore (Cloud, no cifrado)              │
│                                                                  │
│  ┌───────────────────┐   ┌───────────────────┐                  │
│  │ sync_log          │   │ aggregated_metrics│                  │
│  │───────────────────│   │───────────────────│                  │
│  │ anonymous_id      │   │ school_id         │                  │
│  │ interaction_json  │   │ region_code       │                  │
│  │ sync_timestamp    │   │ avg_level         │                  │
│  └───────────────────┘   │ students_count    │                  │
│                          │ time_period       │                  │
│  [SIN DATOS PERSONALES]  │ metrics_json      │                  │
│  [SIN NOMBRES]           └───────────────────┘                  │
│  [SIN IDENTIFICADORES]                                          │
└──────────────────────────────────────────────────────────────────┘
```

#### C.4.2 Flujo de Datos Offline → Online

```
  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
  │ Estudiante  │────►│ App Android │────►│  SQLite     │
  │ interactúa  │     │ procesa     │     │  (local)    │
  │ con lección │     │ respuesta   │     │  INSERT     │
  └─────────────┘     └──────┬──────┘     └─────────────┘
                             │
                     [¿Hay internet?]
                             │
              ┌──────────────┴──────────────┐
              ▼                              ▼
           [SÍ]                           [NO]
              │                              │
              ▼                              ▼
  ┌─────────────────────┐     ┌─────────────────────────┐
  │ Marcar sync_status  │     │ Mantener sync_status =  │
  │ = 'pending'         │     │ 'pending'               │
  │ Enviar a Firebase   │     │ Acumular en cola local  │
  └──────────┬──────────┘     └────────────┬────────────┘
             │                              │
             ▼                              │
  ┌─────────────────────┐                   │
  │ Firebase confirma   │                   │
  │ Marcar sync_status  │                   │
  │ = 'synced'          │                   │
  └─────────────────────┘                   │
             │                              │
             ▼                              ▼
  ┌─────────────────────────────────────────────────────┐
  │         Cloud Run: agregar + anonimizar             │
  │         → Dashboard MINEDU (solo online)            │
  └─────────────────────────────────────────────────────┘
```

### C.5 Vista de Escenarios — Flujos Clave (VP-05)

#### Escenario 1: Estudiante completa diagnóstico (offline)

```
Estudiante         App Android        Gemma TFLite       SQLite
    │                   │                   │               │
    │ Abre app          │                   │               │
    │──────────────────►│                   │               │
    │                   │ Carga ítems      │               │
    │                   │ locales           │               │
    │                   │──────────────────►│               │
    │                   │                   │               │
    │ Presenta ítem 1   │                   │               │
    │◄──────────────────│                   │               │
    │                   │                   │               │
    │ Selecciona resp.  │                   │               │
    │──────────────────►│                   │               │
    │                   │ Evalúa respuesta  │               │
    │                   │──────────────────►│               │
    │                   │                   │               │
    │                   │ Selecciona ítem N │               │
    │                   │ (adaptativo)      │               │
    │                   │◄──────────────────│               │
    │                   │                   │               │
    │ ... (25 ítems)    │                   │               │
    │                   │                   │               │
    │                   │ Resultado final   │               │
    │                   │◄──────────────────│               │
    │                   │                   │               │
    │ "Eres Explorador" │                   │               │
    │◄──────────────────│                   │               │
    │                   │ Guarda perfil ───►│               │
    │                   │───────────────────┴───────────────│
```

#### Escenario 2: Estudiante aprende lección (offline)

```
Estudiante         App Android        Gemma TFLite       SQLite
    │                   │                   │               │
    │ Selecciona        │                   │               │
    │ lección           │                   │               │
    │──────────────────►│                   │               │
    │                   │ Carga lección ───►│               │
    │                   │ JSON local        │               │
    │                   │◄──────────────────│               │
    │                   │                   │               │
    │ Video 3 min       │                   │               │
    │◄──────────────────│                   │               │
    │                   │                   │               │
    │ Ejercicio 1       │                   │               │
    │◄──────────────────│                   │               │
    │                   │                   │               │
    │ Responde          │                   │               │
    │──────────────────►│                   │               │
    │                   │ Procesa respuesta │               │
    │                   │──────────────────►│               │
    │                   │                   │               │
    │                   │ Feedback + n      │               │
    │                   │◄──────────────────│               │
    │                   │                   │               │
    │                   │ Registra interac.─►               │
    │                   │───────────────────┴───────────────│
    │                   │                   │               │
    │ [Si error]        │ Detecta patrón    │               │
    │                   │──────────────────►│               │
    │                   │ Genera 5 ejerc.  │               │
    │                   │ extra             │               │
    │                   │◄──────────────────│               │
    │                   │                   │               │
    │ Ejercicio extra   │                   │               │
    │◄──────────────────│                   │               │
```

---

## Actividad D: Evaluar Alternativas de Arquitectura y Seleccionar

### D.1 Alternativas Evaluadas

Para el framework de desarrollo de la app Android, se evaluaron tres alternativas:

| Alternativa | Descripción |
|---|---|
| **Alt A: APK Nativo Android (Kotlin/Jetpack Compose)** | Desarrollo nativo con Android SDK, Jetpack Compose para UI, TFLite para Gemma |
| **Alt B: PWA (Progressive Web App)** | Aplicación web con Service Workers para offline, IndexedDB para almacenamiento local |
| **Alt C: APK Flutter (Dart)** | Framework cross-platform de Google. Compila a código nativo ARM. Soporte TFLite via plugin. |

### D.2 Criterios de Evaluación

| ID | Criterio | Peso | Descripción |
|---|---|---|---|
| **CR-01** | **Offline-first real** | 0.25 | Capacidad de operar 100% sin internet. Service Workers no garantizan acceso a TFLite ni SQLite completo |
| **CR-02** | **Velocidad de desarrollo (5-7h)** | 0.30 | Tiempo para tener un prototipo funcional con diagnóstico + 3-5 lecciones. Hot reload, tooling |
| **CR-03** | **Gemma on-device (TFLite)** | 0.20 | Compatibilidad con TensorFlow Lite para inferencia local |
| **CR-04** | **Rendimiento en 2GB RAM** | 0.15 | Consumo de recursos en dispositivos de bajo costo |
| **CR-05** | **Persistencia offline robusta** | 0.05 | SQLite completo vs IndexedDB limitado |
| **CR-06** | **Alcance futuro (PWA fase 2)** | 0.05 | Posibilidad de extender a versión web para colegios con internet |

### D.3 Matriz de Evaluación

| Criterio | Peso | Alt A: Android Nativo | Alt B: PWA | Alt C: Flutter |
|---|---|---|---|---|
| **CR-01** Offline-first | 0.25 | 9 (Excelente: SQLite nativo, TFLite directo) | 4 (Limitado: Service Workers no acceden a TFLite fácilmente) | 8 (Muy bueno: SQLite via plugin, TFLite via plugin) |
| **CR-02** Velocidad desarrollo | 0.30 | 4 (Más lento: dos lenguajes si hay iOS futuro, boilerplate) | 7 (Rápido: web estándar, hot reload) | 8 (Muy rápido: hot reload, widgets, ecosistema) |
| **CR-03** Gemma on-device | 0.20 | 8 (TFLite nativo Android) | 3 (WebGPU/WebNN incipiente, no estable para Gemma) | 7 (TFLite via flutter_tflite) |
| **CR-04** Rendimiento 2GB RAM | 0.15 | 8 (Código nativo optimizado) | 5 (Overhead del navegador) | 7 (Compilado a ARM nativo) |
| **CR-05** Persistencia offline | 0.05 | 9 (SQLite + Room) | 5 (IndexedDB, límites de storage) | 8 (SQLite via sqflite) |
| **CR-06** Alcance futuro PWA | 0.05 | 3 (Solo Android) | 9 (Web = universal) | 8 (Flutter Web para PWA fase 2) |
| **TOTAL PONDERADO** | **1.00** | **6.45** | **4.85** | **7.65** |

### D.4 Selección

**Alternativa seleccionada: Alt C — APK Flutter (Dart)**

**Justificación técnica:**

1. **Mejor balance velocidad/offline:** Flutter permite desarrollo rápido (hot reload, widgets preconstruidos) sin sacrificar acceso nativo a TFLite y SQLite. En 5-7 horas, Flutter produce más funcionalidad que desarrollo nativo.

2. **Gemma on-device viable:** El plugin `flutter_tflite` o `google_ai_edge` permite ejecutar Gemma quantizado directamente en el dispositivo. Android Nativo también lo permite, pero con más boilerplate.

3. **Alcance futuro:** Flutter Web permite compilar la misma base de código a PWA para la fase 2 (colegios con internet), satisfaciendo CR-06 sin reescribir.

4. **Google ecosystem:** Flutter + Firebase + Gemma son productos Google. La integración entre ellos está optimizada y documentada.

5. **Rechazo de PWA (Alt B):** Aunque PWA es excelente para alcance web, el requisito offline-first con inferencia de IA on-device y SQLite completo no es viable en navegador en 2026. Service Workers no tienen acceso confiable a TFLite ni a almacenamiento SQL robusto.

### D.5 Análisis de Riesgos de la Alternativa Seleccionada

| Riesgo | Severidad | Mitigación |
|---|---|---|
| **Tamaño del APK elevado** (Flutter bridge + Gemma + assets) | Media | Aceptado por P-08 (6.2.1). El peso NO es bloqueante para el prototipo. Si es >100MB, justificar. Optimizar en fase 2. |
| **flutter_tflite no compatible con versión específica de Gemma** | Media | Verificar compatibilidad ANTES del 1 de agosto. Fallback: Google AI Edge para Android. |
| **Rendimiento del bridge Dart↔TFLite** | Baja | El overhead del bridge es mínimo para inferencia de texto. No afecta latencia de ejercicios. |
| **Curva de aprendizaje Flutter** (si el equipo no lo conoce) | Media | Usar solo widgets básicos. No usar state management complejo (provider simple). |

---

## Actividad E: Relacionar la Arquitectura con el Diseño (hacia 6.4.5)

### E.1 Asignación de Requisitos a Componentes de Software

| SyRS (6.4.3) | Componente Arquitectónico | Responsabilidad |
|---|---|---|
| **SR-A01 a A06** | Módulo Diagnóstico Adaptativo | Evaluación IRT simplificada, 25 ítems, etiquetas positivas |
| **SR-B01 a B07** | Módulo Aprendizaje + Motor Gemma | Lecciones JSON, textos, ejercicios, inferencia IA |
| **SR-C01 a C06** | Módulo Persistencia + Módulo Sincronización | SQLite cifrado, sync diferida, tolerancia a fallos |
| **SR-D01 a D06** | Módulo Panel Docente | Dashboard agregado, generación PDF, sin ranking |
| **SR-E01 a E05** | API Cloud Run (Dashboard MINEDU) | Reportes anonimizados, métricas, xAPI/SCORM export |
| **INT-01** | Módulo Aprendizaje ↔ Motor Gemma | API local via TFLite |
| **INT-02** | Todos los módulos ↔ Módulo Persistencia | SQLite via sqflite |
| **INT-03, INT-04** | Módulo Sincronización ↔ Firebase/Cloud Run | HTTPS/REST |
| **INT-06** | Módulo Panel Docente ↔ Sistema de archivos | Generación PDF |
| **INT-07** | Distribución offline (no es módulo de código) | APK via USB/Bluetooth |
| **INT-08** | Capa de UI ↔ Pantalla | Flutter widgets |

### E.2 Interfaces Definidas (Nivel Arquitectónico)

| ID | Entre | Y | Tipo | Especificación |
|---|---|---|---|---|
| **IFACE-01** | UI Flutter | Módulo Diagnóstico | Función Dart | `startDiagnostic() → DiagnosticResult` |
| **IFACE-02** | UI Flutter | Módulo Aprendizaje | Función Dart | `loadLesson(id) → Lesson`, `submitAnswer(id, response) → Feedback` |
| **IFACE-03** | Módulo Aprendizaje | Motor Gemma | TFLite Interpreter | `runInference(prompt) → TextResponse` |
| **IFACE-04** | Todos los módulos | Módulo Persistencia | sqflite API | `insert(T, data)`, `query(T, where)`, `update(T, id, data)` |
| **IFACE-05** | Módulo Sincronización | Firebase Firestore | REST/Protobuf | `firestore.collection('sync_log').add(data)` |
| **IFACE-06** | Módulo Panel Docente | Sistema de archivos | dart:io | `generatePdf(activityData) → File` |
| **IFACE-07** | Cloud Run API | Dashboard MINEDU | HTTPS/JSON | `GET /api/reportes?nivel=region&region=Ayacucho` |
| **IFACE-08** | Firebase Auth | App Android | SDK | Autenticación anónima para sync |

### E.3 Principios Rectores para el Diseño (6.4.5)

| Principio | Descripción |
|---|---|
| **Monolito modular** | El APK es un solo ejecutable, pero el código se organiza en módulos independientes con interfaces claras (IFACE-01 a IFACE-06). Refactorizar a microservicios en fase 2 si es necesario. |
| **Offline-first por defecto** | Toda nueva funcionalidad se asume offline. La conectividad es una mejora, no un requisito. |
| **Simplicidad sobre sofisticación** | No se usarán patrones enterprise (CQRS, Event Sourcing, Saga) en fase 1. Un monolito con SQLite local es suficiente. |
| **Datos anonimizados desde el origen** | Los datos que salen del dispositivo YA están anonimizados. El backend NUNCA recibe nombres ni identificadores reales. |
| **Componentes reemplazables** | El Motor Gemma, el Módulo de Persistencia y el Panel Docente se diseñan para ser reemplazados o actualizados independientemente. |

---

## Actividad F: Gestionar la Arquitectura Seleccionada

### F.1 Architecture Decision Records (ADR)

#### ADR-001: Framework de Desarrollo

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | Se requiere un framework para construir el APK del prototipo en 5-7 horas. Debe soportar TFLite on-device, SQLite offline, y permitir evolución a PWA en fase 2. |
| **Decisión** | Usar **Flutter (Dart)** como framework de desarrollo. |
| **Consecuencias positivas** | Desarrollo rápido (hot reload). Widgets preconstruidos. Plugins para TFLite, SQLite, Firebase. Compilación a código ARM nativo. Misma base de código para Android y futura PWA (Flutter Web). |
| **Consecuencias negativas** | APK más grande que nativo (bridge de Flutter ~8MB extra). Posible incompatibilidad con versión específica de Gemma (verificar antes del 1 agosto). |
| **Alternativas consideradas** | Android Nativo (Kotlin, descartado por velocidad de desarrollo). PWA (descartado por limitaciones de TFLite y SQLite). |

#### ADR-002: Modelo de IA On-Device

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | NR-01 obliga a usar Gemma. NR-02 obliga a funcionar sin internet. Se requiere inferencia de texto on-device en dispositivos con 2GB RAM. |
| **Decisión** | Usar **Gemma quantizado via TensorFlow Lite** en el dispositivo. Toda la inferencia es local. No se realizan llamadas a Gemini API durante el uso del estudiante. |
| **Consecuencias positivas** | Cumple NR-01 y NR-02. Sin costo de API. Sin dependencia de red. Latencia predecible. |
| **Consecuencias negativas** | El modelo quantizado ocupa espacio en el APK (P-08: aceptado, no bloqueante). Rendimiento de inferencia en 2GB RAM debe verificarse (RT-02 de 6.4.3). La calidad de generación de texto es menor que en la nube. |
| **Alternativas consideradas** | Gemini API (descartado: requiere internet, viola NR-02). Sin IA (descartado: incumple NR-01). |

#### ADR-003: Arquitectura de Persistencia

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | SR-C01 exige almacenamiento local cifrado. RNF-05 exige AES-256. Los datos deben sincronizarse cuando haya internet. |
| **Decisión** | **SQLite + AES-256 + Android Keystore.** Firebase Firestore solo para datos agregados y anonimizados en la nube. |
| **Consecuencias positivas** | SQLite es nativo en Android, robusto, sin dependencias externas. AES-256 vía `sqflite_sqlcipher`. Keystore protege la clave de cifrado en hardware. |
| **Consecuencias negativas** | La sincronización es responsabilidad del código (no automática). Se debe implementar la cola de sync, reintentos e idempotencia manualmente. |
| **Alternativas consideradas** | Firebase Firestore offline (descartado: no ofrece cifrado a nivel de campo requerido por RNF-05). Realm (descartado: dependencia pesada para prototipo). |

#### ADR-004: Backend Cloud

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | Se requiere un backend para sincronización y reportes. La hackathon permite Firebase y Cloud Run. 5-7 horas impiden infraestructura compleja. |
| **Decisión** | **Firebase (Firestore + Auth) para sync. Cloud Run para API de reportes.** Sin base de datos relacional en la nube. Sin Kubernetes. |
| **Consecuencias positivas** | Serverless: sin administrar servidores. Escalabilidad automática. Free tier suficiente para prototipo. Integración nativa con Flutter. |
| **Consecuencias negativas** | Dependencia de Google Cloud. Firestore no es relacional (consultas limitadas). Los reportes complejos requieren Cloud Run con lógica de agregación. |
| **Alternativas consideradas** | Supabase (descartado: no está en stack permitido). Backend propio con Node.js + PostgreSQL en VPS (descartado: requiere administración, excede tiempo hackathon). |

#### ADR-005: Estrategia de Contenido Offline

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | SR-C04 requiere que el contenido base esté disponible sin internet. 3-5 lecciones de demo para la hackathon. |
| **Decisión** | **Contenido precargado en el APK como assets JSON.** Sin descarga inicial. Sin streaming. |
| **Consecuencias positivas** | Funciona 100% offline desde el primer uso. Sin dependencia de red para contenido educativo. El estudiante puede usar la app inmediatamente después de instalarla. |
| **Consecuencias negativas** | El contenido está fijo en el APK. Actualizar contenido requiere nuevo APK. En fase 2 se implementará descarga incremental de nuevas lecciones (SR-C05). |
| **Alternativas consideradas** | Descarga on-demand al instalar (descartado: requiere internet en primera ejecución, viola NR-02). |

#### ADR-006: Estrategia de Arquitectura para el Prototipo

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | 5-7 horas de desarrollo. Arquitecturas distribuidas (microservicios, CQRS, Event Sourcing) no son viables en este plazo. |
| **Decisión** | **Monolito modular.** Todo el código en un solo APK, organizado en módulos con interfaces claras (IFACE-01 a IFACE-06). Refactorizar a microservicios en fase 2 si la escala lo exige. |
| **Consecuencias positivas** | Desarrollo y debug en un solo proyecto. Sin latencia de red entre componentes. Sin infraestructura de orquestación. Ideal para hackathon. |
| **Consecuencias negativas** | Acoplamiento en tiempo de compilación (todos los módulos en un APK). Escalar componentes individuales requiere refactorización. No hay aislamiento de fallos entre módulos. |
| **Alternativas consideradas** | Microservicios desde fase 1 (descartado: inviable en 5-7h). Serverless functions por módulo (descartado: requiere internet, viola NR-02). |

### F.2 Trazabilidad Bidireccional

| Necesidad (6.4.2) | StRS (6.4.2) | SyRS (6.4.3) | Componente Arquitectónico (6.4.4) | Verificación (6.4.9) |
|---|---|---|---|---|
| N-01 (explicación comprensible) | RF-04, RF-05 | SR-B01, SR-B02, SR-B03 | Módulo Aprendizaje + Motor Gemma | Prueba: ≥70% mejoran post-test |
| N-02 (contenido interesante) | RF-02, RF-07 | SR-B05, SR-B06 | Módulo Aprendizaje (textos JSON) | Inspección: ≥50 textos, ≥5 géneros |
| N-03 (diagnóstico sin estigma) | RF-01 a RF-03, RF-06 | SR-A01 a SR-A06, SR-B04 | Módulo Diagnóstico | Prueba: precisión ≥80% vs ENLA |
| N-04 (offline) | RF-08 a RF-10 | SR-C01 a SR-C06, RQ-05 | Módulo Persistencia + Módulo Sincronización | Prueba: 7 días sin internet |
| N-08 (material listo) | RF-11, RF-12 | SR-D01, SR-D03, SR-D04 | Módulo Panel Docente | Prueba: PDF en ≤2 min |
| N-13 (garantía no reemplazo) | RF-13, RNF-05 | SR-D02, SR-D06, RES-02 | Módulo Panel Docente (sin ranking) | Inspección: sin ranking en UX |
| N-14 (no sanción docente) | RF-13, RNF-05 | SR-D02, SR-D06, RES-02 | Módulo Panel Docente + API Cloud Run | Inspección: sin comparativas |
| N-15 (datos por estudiante) | RF-01, RF-02, RF-14, RF-15 | SR-A01, SR-B03, SR-C01, SR-E01 a E05 | Módulo Diagnóstico + Módulo Persistencia + API Cloud Run | Prueba: reportes anonimizados |
| N-18 (nivel básico) | RF-14, RF-15 | SR-E01, SR-E03 | API Cloud Run (métrica "meses ganados") | Análisis: MOE-01, MOE-02 |
| N-20 (resultados medibles) | RF-14, RF-15 | SR-E01, SR-E03 | API Cloud Run + Dashboard MINEDU | Análisis: CA-04 (≥15%) |

### F.3 Control de Evolución de la Arquitectura

| Cambio previsto | Fase | Impacto | Acción |
|---|---|---|---|
| **De monolito a microservicios** | Fase 2 (piloto) | Alto | Extraer Módulo Diagnóstico y Módulo Aprendizaje como servicios independientes si los datos del piloto muestran necesidad |
| **De APK a APK + PWA** | Fase 2 | Medio | Compilar Flutter Web para PWA. Misma base de código. |
| **De 3-5 lecciones a currículo completo** | Fase 3 | Medio | Implementar descarga incremental (SR-C05). Backend de contenido. |
| **De Firebase a infraestructura MINEDU** | Fase 3 | Alto | Migrar de Firebase a servidores del estado peruano. Requiere plan de migración de datos. |
| **De español a multilingüe** | Fase 2+ | Bajo | Arquitectura ya preparada (RNF-06, RQ-07). Solo agregar archivos de recursos. |

---

## Alineación con ISO/IEC 12207

### ISO/IEC 12207:2017 (Versión Armonizada)

| Proceso 15288:2015 | Proceso 12207:2017 | Relación |
|---|---|---|
| **6.4.4** Architecture Definition | **6.4.4** Architecture Definition (System/Software) | **Idéntico** en propósito y outcomes. La versión 12207:2017 especializa para software: mecanismos de objetos persistentes, interfaz de usuario, almacenamiento de datos (secciones C.2, C.4 de este documento). |

### NTP-ISO/IEC 12207:2006

| Proceso 12207:2006 | Tarea | Aporte a Aprendo+ |
|---|---|---|
| **5.3.3.1** Establecer arquitectura a alto nivel | Identificar elementos hardware, software y operaciones manuales. Asegurar distribución de requisitos. Documentar la arquitectura y los requisitos asignados a cada elemento. | Secciones C.2 (C4 containers), C.3 (despliegue), E.1 (asignación requisitos→componentes). |
| **5.3.3.2** Evaluar la arquitectura | Evaluar según: (a) trazabilidad a req. del sistema, (b) consistencia, (c) adecuación de normas, (d) viabilidad de elementos software, (e) viabilidad de operación y mantenimiento. | Sección D (evaluación de alternativas, criterios CR-01 a CR-06), sección D.5 (riesgos). |

### ISO/IEC/IEEE 24748-3 (Guía de Aplicación 12207)

| Directriz 24748-3 | Aplicación en Aprendo+ |
|---|---|
| **Neutralidad metodológica:** No mandata una única vista ni marco específico | Se eligió C4 Model por simplicidad y enfoque en software, sin excluir otras vistas |
| **Alineamiento de expectativas:** Definir notaciones, nivel de detalle, enfoque V&V | A.4 define C4 + Mermaid + draw.io, nivel de detalle apropiado para prototipo |
| **Propiedades de calidad:** Arquitectura escalable, portable, resiliente, segura | ADR-006 acepta deuda técnica de monolito para fase 1, con roadmap de refactorización |
| **Bucle de retroalimentación:** Si la arquitectura no puede cumplir requisitos, reactivar 6.4.2/6.4.3 | D.5 analiza riesgos. SI se descubre inviabilidad de Gemma on-device, se escala a revisión de NR-01 |

---

## Outcomes del Proceso 6.4.4 (ISO/IEC/IEEE 15288:2015 — 6.4.4.2)

| # | Outcome | Estado | Evidencia |
|---|---|---|---|
| **a)** | Se definen las directrices de la arquitectura, incluyendo puntos de vista, modelos y plantillas de diseño | ✅ | Actividad A.4 (enfoque: C4 + Mermaid + ADR), B (5 viewpoints VP-01 a VP-05) |
| **b)** | Se generan alternativas de arquitectura para el sistema de interés | ✅ | Actividad D.1 (3 alternativas: Android Nativo, PWA, Flutter) |
| **c)** | Se selecciona la alternativa arquitectónica preferida que equilibre los requisitos y los riesgos de diseño | ✅ | Actividad D.4 (Flutter seleccionado, puntaje 7.65/9). D.5 (análisis de riesgos con mitigación) |
| **d)** | La arquitectura seleccionada es formalmente descrita y documentada mediante vistas consistentes | ✅ | Actividad C (5 vistas: Funcional C.1, Lógica C.2 con C4 Niveles 1-3, Física C.3, Datos C.4, Escenarios C.5) |
| **e)** | Las interfaces críticas internas y externas son identificadas y definidas de manera formal | ✅ | Actividad E.2 (8 interfaces IFACE-01 a IFACE-08 con tipo y especificación) |
| **f)** | Se establece la trazabilidad bidireccional entre la arquitectura del sistema y los requisitos del sistema | ✅ | Actividad F.2 (matriz Necesidad→StRS→SyRS→Componente→Verificación), E.1 (asignación SyRS→componentes) |

---

**Documento generado según:** ISO/IEC/IEEE 15288:2015 — 6.4.4 Architecture Definition | ISO/IEC/IEEE 42010:2011 — Architecture Description
**Input:** 6.4.3 (SyRS, MOPs, TPMs, restricciones)
**Output hacia:** 6.4.5 Design Definition
**Documentación 15289:** Architecture Definition Strategy, System Architecture Description (SAD), System Architecture Rationale (ADRs), Documentation Tree, Preliminary Interface Definition, Architecture Traceability Matrix
**Alineación 12207:** 12207:2017 6.4.4 (idéntico), 12207:2006 5.3.3.1-5.3.3.2, 24748-3 (guía de aplicación)
**Fecha:** 29 de julio de 2026
