# Proceso 6.4.1 — Business or Mission Analysis (ISO/IEC/IEEE 15288:2015)
# Aplicado al Problema Público 2: Deficiencia Estructural en los Logros de Aprendizaje y Calidad Pedagógica

---

## Actividad A: Preparar el Análisis de Negocio/Misión

### A.1 Revisión de Problemas y Oportunidades desde la Estrategia Organizacional

**Fuente:** SECTOR EDUCACION — Marco Lógico Sector Educación Perú

**Brechas de capacidad identificadas en los sistemas existentes:**

El sistema educativo peruano produce egresados de secundaria que mayoritariamente no alcanzan competencias básicas. Las brechas críticas son:

- **Brecha de resultados de aprendizaje:** 88% de estudiantes de quinto de secundaria no alcanza nivel satisfactorio. Solo 12.8% en Matemática y 11.3% en Lectura logran el nivel esperado (ENLA 2025).
- **Brecha digital:** 79% de instituciones educativas públicas sin internet. 60% sin equipamiento tecnológico adecuado. 81% de docentes requiere capacitación urgente en TIC.
- **Brecha de idoneidad docente:** El porcentaje de plazas cubiertas en concursos docentes cayó desde 41.5% en 2015 a niveles mínimos — los postulantes no alcanzan puntajes básicos de lógica y lectura.
- **Brecha de formación inicial:** Universidades e institutos pedagógicos egresan profesionales con severas lagunas en razonamiento lógico y comprensión lectora.

**Meta organizacional deseada:** Garantizar que los egresados de educación secundaria pública alcancen competencias satisfactorias en lectura, matemática y pensamiento lógico, preparándolos para la educación superior y el mercado laboral.

### A.2 Estrategia de Análisis

Se aplica la MML CEPAL como sistema habilitador para ejecutar las actividades 6.4.1, con el mismo mapeo metodológico del Problema 1.

### A.3 Sistemas Habilitadores

- Metodológico: MML CEPAL (ARBOL DE PROBLEMAS)
- Normativo: ISO 15288:2015, ISO 12207:2006 (NTP), ISO 24748-3
- Referencia técnica: INCOSE SE Handbook, SEBoK, CMMI V2.0 (TEORIA ALIAGA)
- Restricción tecnológica externa: Gemma como motor de IA obligatorio (BASES DE LA HACKATON)

---

## Actividad B: Definir el Espacio del Problema

### B.1 Identificación de Interesados

| Stakeholder | Posición | Fuerza | Intensidad |
|---|---|---|---|
| **Estudiantes y familias** (población objetivo) | Demandan conocimientos útiles, comprensión lectora sólida y pensamiento lógico | Baja (sin poder de decisión sobre políticas pedagógicas) | Muy Alta (frustración ante fracaso académico y brecha tecnológica) |
| **Magisterio y SUTEP** (operadores del servicio) | Priorizan remuneraciones, estabilidad laboral y nombramiento automático | Muy Alta (capacidad de movilización gremial y presión política) | Alta (resistencia activa a evaluaciones de idoneidad y pruebas de conocimientos lógicos) |
| **UMC-MINEDU y Defensoría del Pueblo** (evaluadores/rectores) | Medir objetivamente resultados de aprendizaje (ENLA, PISA), salvaguardar meritocracia docente | Media (mandato legal de evaluar) | Alta (presión política y sindical constante para flexibilizar estándares) |
| **Universidades e Institutos Pedagógicos** (formadores) | Formar docentes | Media | Baja-Media (deterioro histórico en calidad de formación inicial) |

### B.2 Definición del Problema (sin referir solución)

**Problema Central:** El sistema educativo público peruano adolece de una deficiencia estructural en los logros de aprendizaje, evidenciada en que el 88% de los estudiantes de quinto de secundaria no alcanza el nivel satisfactorio en competencias básicas. Las causas se bifurcan en la insuficiente idoneidad profesional del cuerpo docente —producto de una formación inicial deteriorada y una carrera pública magisterial politizada que resiste las evaluaciones de calidad— y en la profunda brecha digital que mantiene al 79% de colegios públicos sin internet y al 81% de docentes sin capacitación en TIC. Esta situación produce un analfabetismo funcional masivo y excluye sistemáticamente a los egresados de la educación superior.

### B.3 Árbol de Causas

```
              ╔══════════════════════════════════════════════╗
              ║   DEFICIENCIA ESTRUCTURAL EN LOGROS DE      ║
              ║   APRENDIZAJE Y CALIDAD PEDAGÓGICA          ║
              ╚══════════════════════════════════════════════╝
                                   ▲
        ┌──────────────────────────┴──────────────────────────┐
        │                                                      │
┌───────────────────────────────┐      ┌──────────────────────────────────┐
│ INSUFICIENTE IDONEIDAD        │      │ ALTO ANALFABETISMO DIGITAL EN    │
│ PROFESIONAL Y DEFICIENCIAS    │      │ AULAS + DESCONEXIÓN TECNOLÓGICA  │
│ METODOLÓGICAS DEL CUERPO      │      │ GENERALIZADA                     │
│ DOCENTE                       │      │ (Causa Directa B)                │
│ (Causa Directa A)             │      │                                  │
└───────────────┬───────────────┘      └────────────────┬─────────────────┘
                │                                       │
┌───────────────┴───────────────┐      ┌────────────────┴─────────────────┐
│ DETERIORO HISTÓRICO EN LA     │      │ ABANDONO HISTÓRICO DE            │
│ CALIDAD DE LA FORMACIÓN       │      │ INFRAESTRUCTURA FÍSICA ESTATAL:  │
│ INICIAL DOCENTE               │      │ ~80% colegios públicos sin       │
│ (universidades e institutos   │      │ internet (Causa Subyacente B.2)  │
│ pedagógicos)                  │      │                                  │
│ (Causa Subyacente A.2)        │      │                                  │
└───────────────┬───────────────┘      └────────────────┬─────────────────┘
                │                                       │
┌───────────────┴──────────────────┐    ┌──────────────┴──────────────────┐
│ POLITIZACIÓN SISTEMÁTICA DE LA   │    │ Matriz presupuestaria y de      │
│ CARRERA PÚBLICA MAGISTERIAL      │    │ planificación que considera la  │
│ → Flexibilización de barreras    │    │ tecnología como un lujo y no    │
│   de ingreso por presión gremial │    │ como derecho habilitante        │
│ → Resistencia a PUN y            │    │ (Causa Raíz B.3-A)              │
│   evaluaciones de idoneidad      │    ├─────────────────────────────────┤
│ → Plazas cubiertas cayeron de    │    │ 81% de docentes formados bajo   │
│   41.5% (2015) a niveles mínimos │    │ paradigmas analógicos, sin      │
│ (Causa Raíz A.3)                 │    │ capacitación continua           │
│                                  │    │ obligatoria y certificada en TIC│
│                                  │    │ (Causa Raíz B.3-B)              │
└──────────────────────────────────┘    └─────────────────────────────────┘
```

### B.4 Árbol de Efectos

```
    ╔══════════════════════════════════════════════════════════════════╗
    ║ CRISIS MACROECONÓMICA ESTRUCTURAL                               ║
    ║ → Perú anula su capacidad de absorber tecnología compleja y     ║
    ║   transitar hacia la economía del conocimiento                   ║
    ║ → Dependencia perpetua de exportación de materias primas        ║
    ║   sin valor agregado → estancamiento del IDH                    ║
    ╚══════════════════════════════════════════════════════════════════╝
                                      ▲
    ┌─────────────────────────────────┴─────────────────────────────────┐
    │ DEGRADACIÓN SEVERA DE LA PRODUCTIVIDAD LABORAL NACIONAL           │
    │ → Millones de jóvenes forzados a empleos rutinarios, manuales e   │
    │   informales con bajísima remuneración                            │
    └─────────────────────────────────┬─────────────────────────────────┘
                                      ▲
    ┌─────────────────────────────────┴─────────────────────────────────┐
    │ EFECTOS DIRECTOS                                                   │
    │ 1. ANLFABETISMO FUNCIONAL MASIVO: egresan con certificado pero    │
    │    sin capacidad de entender contratos, interpretar estadísticas   │
    │    o redactar argumentos lógicos                                   │
    │ 2. EXCLUSIÓN DE EDUCACIÓN SUPERIOR: barrera insalvable para        │
    │    acceder a universidades o formación técnica                     │
    └────────────────────────────────────────────────────────────────────┘
                                      ▲
    ╔══════════════════════════════════════════════════════════════════╗
    ║   DEFICIENCIA ESTRUCTURAL EN LOGROS DE APRENDIZAJE              ║
    ╚══════════════════════════════════════════════════════════════════╝
```

---

## Actividad C: Caracterizar el Espacio de la Solución

### C.1 Restricciones de Negocio

| Restricción | Descripción |
|---|---|
| **Restricción política** | Alta politización de la carrera magisterial. El gremio (SUTEP) tiene poder de veto sobre reformas que impliquen evaluación de idoneidad. |
| **Restricción presupuestaria** | Formación docente y capacitación en TIC requieren inversión sostenida. La brecha digital (79% sin internet) es una restricción estructural del Problema 1. |
| **Restricción institucional** | Deterioro histórico de la formación inicial en universidades e institutos pedagógicos. La UMC del MINEDU enfrenta presión política para flexibilizar estándares. |
| **Restricción de la hackathon** | Uso obligatorio de Google Gemma como motor de IA en la solución. El prototipo debe alinearse con tracks de impacto social de la AI Competition Gemma. |
| **Restricción de infraestructura** | 79% de colegios sin internet limita soluciones que requieran conectividad permanente. |

### C.2 Condiciones Ambientales y del Entorno

- **Entorno político:** Carrera magisterial altamente sindicalizada. Resistencia histórica a evaluaciones estandarizadas de docentes. Flexibilización de barreras de ingreso por presión gremial.
- **Entorno regulatorio:** Ley de Reforma Magisterial, Currículo Nacional de Educación Básica, evaluaciones ENLA y PISA como marcos de referencia.
- **Entorno social:** Familias que dependen de la escuela pública como única vía de movilidad social, pero reciben un servicio de baja calidad que perpetúa la desigualdad.
- **Entorno tecnológico:** Docentes formados bajo paradigmas analógicos (81% sin capacitación TIC). Infraestructura digital inexistente en la mayoría de colegios públicos.

### C.3 Características Críticas de Calidad

| Característica | Implicancia |
|---|---|
| **Efectividad pedagógica** | La solución debe demostrar mejora medible en competencias de lectura y matemática (hoy 12.8% y 11.3%). |
| **Equidad** | No puede beneficiar solo a colegios urbanos con internet; debe considerar zonas rurales y periurbanas. |
| **Aceptabilidad gremial** | Debe contemplar la resistencia del magisterio a ser evaluado. Cualquier solución que implique evaluación externa enfrentará oposición frontal. |
| **Sostenibilidad** | La formación y capacitación docente requieren continuidad más allá de un piloto. |
| **Escalabilidad** | Debe ser replicable a nivel nacional (más de 500,000 docentes en servicio). |

### C.4 Interfaces Críticas

- **Interfaz Docente ↔ Tecnología:** El 81% de docentes no está capacitado en TIC. Cualquier solución tecnológica debe ser accesible para este perfil.
- **Interfaz MINEDU ↔ SUTEP:** La viabilidad de cualquier reforma depende de la negociación con el gremio.
- **Interfaz Universidad/Instituto Pedagógico ↔ Escuela:** La brecha entre formación inicial y práctica en aula debe cerrarse.
- **Interfaz Estudiante ↔ Contenido:** El estudiante debe recibir experiencias de aprendizaje que desarrollen pensamiento lógico, no solo memorización.

### C.5 Concepto Preliminar de Operaciones (ConOps preliminar)

Se vislumbra un sistema que permita:
1. Diagnosticar las brechas de aprendizaje a nivel de cada estudiante y cada aula.
2. Proporcionar al docente herramientas pedagógicas adaptativas que no requieran expertise tecnológica avanzada.
3. Ofrecer experiencias de aprendizaje personalizadas a estudiantes, compensando las deficiencias de formación docente.
4. Medir el progreso en tiempo real generando evidencia para la toma de decisiones del MINEDU.
5. Operar con capacidades offline en zonas sin conectividad.

---

## Actividad D: Evaluar Clases de Solución Alternativas

### D.1 Árbol de Objetivos (MML Paso 3)

**Objetivo Central:** Estudiantes de educación secundaria pública egresan con competencias satisfactorias en lectura, matemática y pensamiento lógico.

**Medios (desde las causas raíz):**
1. Carrera pública magisterial basada en mérito y evaluación de idoneidad implementada → docentes competentes en aula
2. Formación inicial docente de calidad en universidades e institutos pedagógicos
3. Infraestructura digital + capacitación docente en TIC generalizada
4. Tecnología concebida como derecho habilitante en el presupuesto público

### D.2 Identificación de Acciones Operativas (MML Paso 4)

| Medio-Raíz | Acciones Operativas |
|---|---|
| Carrera magisterial meritocrática | A1. Reforma de la PUN con evaluación de competencias lógicas. A2. Incentivos salariales por desempeño en resultados de aprendizaje. A3. Desvinculación de docentes con desempeño insuficiente recurrente. |
| Formación inicial de calidad | B1. Acreditación obligatoria de facultades de educación. B2. Examen nacional de egreso para docentes. |
| Infraestructura digital + capacitación | C1. Programa nacional de conectividad escolar. C2. Capacitación masiva en TIC para docentes en servicio. |
| Tecnología como derecho habilitante | D1. Tutor inteligente basado en IA para estudiantes como apoyo al docente. D2. Plataforma de diagnóstico y aprendizaje adaptativo. |

### D.3 Configuración de Alternativas

**Alternativa 1 — "Reforma magisterial estructural":** Enfoque en cambios normativos: reforma de la PUN, acreditación de facultades de educación, examen de egreso, incentivos por desempeño. La mejora en aprendizaje se espera como consecuencia de docentes más idóneos.

**Alternativa 2 — "Tutor de IA como bypass":** Plataforma de aprendizaje adaptativo con IA (Gemma) que entrega directamente al estudiante experiencias personalizadas de aprendizaje, compensando —en el corto plazo— las deficiencias del docente. No requiere cambios normativos ni enfrenta resistencia gremial. El docente mantiene su rol pero con una herramienta de apoyo inteligente. Gemma analiza el nivel de cada estudiante, adapta contenidos, y genera ejercicios de pensamiento lógico.

**Alternativa 3 — "Modelo híbrido docente + IA":** Combina la reforma magisterial progresiva de la Alt 1 con la plataforma de IA de la Alt 2. La IA (Gemma) actúa como asistente pedagógico que potencia al docente —no lo reemplaza— y como tutor personalizado para el estudiante. Incluye módulo offline. La plataforma genera datos de progreso que alimentan la evaluación docente con evidencia objetiva (reduciendo la resistencia gremial al basarse en datos, no en pruebas externas).

### D.4 Análisis Comparativo

| Criterio | Alt 1 (Reforma) | Alt 2 (Tutor IA) | Alt 3 (Híbrido) |
|---|---|---|---|
| **Viabilidad política** | Muy Baja (resistencia gremial) | Alta (no confronta al gremio) | Media (reduce resistencia con datos) |
| **Viabilidad técnica** | Alta (cambios normativos) | Media (requiere contenido de calidad + datos) | Media-Alta |
| **Costo** | Medio | Alto (desarrollo + infraestructura) | Alto |
| **Plazo** | Largo (5-10 años) | Medio (2-3 años) | Largo (3-7 años) |
| **Ataca causas raíz** | Sí (meritocracia, formación) | Parcial (no corrige formación docente) | Sí (ambas) |
| **Cumple requisito Gemma** | No aplica | Sí | Sí |
| **Opera sin internet** | Sí | Depende de conectividad | Sí (módulo offline previsto) |
| **Resistencia gremial** | Muy Alta | Baja (herramienta de apoyo, no de control) | Baja-Media (datos, no pruebas) |
| **Escalabilidad** | Nacional | Limitada por conectividad | Nacional (offline + sync) |
| **Medición de impacto** | Lenta (años) | Inmediata (datos en tiempo real) | Inmediata |

---

## Actividad E: Seleccionar la Clase de Solución Preferida

### E.1 Selección

**Clase de solución preferida: Alternativa 2 — Tutor de IA como primer paso, evolucionando hacia Alternativa 3.**

**Justificación:**

1. **Viabilidad inmediata:** La Alternativa 2 es prototipable en el marco de la hackathon. No requiere cambios normativos ni vencer resistencia gremial para demostrar impacto. Gemma puede implementarse como motor de tutoría inteligente en el track de "IA para Impacto Social" de la competencia.
2. **Evidencia como palanca de cambio:** Los datos de progreso de aprendizaje generados por la plataforma constituyen evidencia objetiva que, en una fase posterior, puede usarse para justificar la reforma magisterial (Alternativa 3) reduciendo la resistencia gremial.
3. **Bypass estratégico:** Mientras la reforma magisterial avanza (proceso lento y politizado), la IA entrega resultados inmediatos a los estudiantes que hoy están en el sistema.
4. **Pertinencia con MML:** Ataca la rama causal B (brecha digital + TIC docente) directamente y crea condiciones para atacar la rama A (idoneidad docente) con datos.

### E.2 Trazabilidad Bidireccional

| Problema/Necesidad | Solución (Alt 2 → Alt 3) | Trazabilidad |
|---|---|---|
| 88% sin nivel satisfactorio en secundaria | Tutor IA adaptativo que personaliza aprendizaje | Efecto Directo → Plataforma IA |
| Docentes sin capacitación TIC (81%) | Interfaz simple, no requiere expertise tecnológica | Causa Raíz B.3-B → Diseño UX accesible |
| 79% colegios sin internet | Módulo offline con sincronización diferida | Causa Subyacente B.2 → Módulo offline |
| Resistencia gremial a evaluaciones | Datos de progreso como evidencia, no pruebas externas | Causa Raíz A.3 → Datos como palanca |
| Formación inicial deteriorada | Tutor IA compensa vacíos del docente en razonamiento lógico | Causa Subyacente A.2 → IA como apoyo |
| Analfabetismo funcional masivo | Ejercicios de pensamiento lógico, comprensión lectora | Efecto Directo 1 → Contenido IA |

---

## Outcomes (Resultados del Proceso 6.4.1.2)

| # | Outcome ISO 15288 | Estado |
|---|---|---|
| 1 | Espacio del problema definido | ✓ 88% sin nivel satisfactorio, politización magisterial, brecha digital 79%, formación docente deteriorada |
| 2 | Espacio de solución caracterizado | ✓ Restricciones políticas (SUTEP), técnicas (79% sin internet), hackathon (Gemma) |
| 3 | Conceptos preliminares de ciclo de vida | ✓ ConOps: diagnosticar, asistir al docente, personalizar aprendizaje, medir progreso, operar offline |
| 4 | Clases de solución analizadas | ✓ 3 alternativas evaluadas con criterios de viabilidad política, técnica, costo, plazo y resistencia gremial |
| 5 | Clase de solución preferida | ✓ Alternativa 2 (Tutor IA con Gemma) como primer paso → evolución a Alternativa 3 (Híbrido) |
| 6 | Sistemas habilitadores disponibles | ✓ MML CEPAL, ISO 15288/12207, CMMI (medición de madurez), Gemma como motor de IA |
| 7 | Trazabilidad establecida | ✓ Matriz problema↔solución con mapeo causa↔acción |

---

## Alineación con ISO/IEC 12207

| Proceso 12207 | Actividad | Aporte |
|---|---|---|
| **5.1.1 Inicio (Adquisición)** | Tarea 5.1.1.1: Describir necesidad | Necesidad de un sistema de tutoría inteligente para compensar brecha de aprendizaje |
| **5.1.1 Inicio** | Tarea 5.1.1.2: Requerimientos de negocio, organizativos y usuario | Requerimientos: interfaz simple (docentes sin TIC), offline (79% sin internet), personalizado (88% no satisfactorio) |
| **5.1.1 Inicio** | Tarea 5.1.1.6: Opciones de adquisición | Alt 2 (desarrollar) vs Alt 1 (reforma interna) vs Alt 3 (combinación) |
| **5.3.2 Análisis de Requerimientos** | Tarea 5.3.2.1: Funciones y capacidades | ConOps con 5 funciones documentadas en C.5 |
| **24748-3** | Market Analysis | 88% de estudiantes sin nivel satisfactorio = mercado de 2+ millones de usuarios |
| **24748-3** | Context Map | Mapa de stakeholders: estudiantes, docentes, SUTEP, UMC, universidades |
| **24748-3** | Portfolio of opportunity areas | 3 clases de solución con evolución escalonada |

---

## Base para Evaluación de Riesgos (MML Paso 9)

| Supuesto | Probabilidad | Evaluación |
|---|---|---|
| "Los docentes adoptan voluntariamente la herramienta de IA en el aula" | Media | ✓ Incluir en MML. Mitigación: diseño UX que no requiera capacitación previa. |
| "El SUTEP no bloquea el despliegue de la plataforma" | Media | ✓ Incluir. Mitigación: la herramienta no evalúa al docente, solo apoya al estudiante. |
| "Se logra financiamiento para desarrollo y mantenimiento de la plataforma" | Media | ✓ Incluir. Vincular a presupuesto público como derecho habilitante. |
| "La conectividad rural mejora lo suficiente para operación online" | Baja | ✓ Incluir. Mitigación: módulo offline desde el día 1. |
| "El gobierno mantiene continuidad de la política de transformación digital educativa" | Baja | **Supuesto Fatal** si no hay mitigación. La plataforma como producto independiente del ciclo político reduce este riesgo. |

---

**Documento generado según:** ISO/IEC/IEEE 15288:2015 — Proceso 6.4.1 Business or Mission Analysis
**Fuentes:** SECTOR EDUCACION, ARBOL DE PROBLEMAS, TEORIA ALIAGA (CMMI, INCOSE), BASES DE LA HACKATON (ISO 12207, 24748-3, Gemma)
**Fecha:** 28 de julio de 2026
