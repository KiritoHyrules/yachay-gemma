# Proceso 6.4.2 — Stakeholder Needs and Requirements Definition (ISO 15288:2015)
# Aplicado al Problema 2: Deficiencia Estructural en Logros de Aprendizaje

**Input desde 6.4.1:** Clase preferida = Tutor IA (Gemma) como bypass del déficit docente → evolución a modelo híbrido
**Proceso siguiente:** 6.4.3 System Requirements Definition

---

## Actividad A: Preparar la Definición de Necesidades y Requisitos

### A.1 Stakeholders Convocados para Elicitación

| ID | Stakeholder | Clase | Rol |
|---|---|---|---|
| SH-01 | Estudiantes de secundaria pública | Usuario primario | Describen frustración, dificultades de aprendizaje, brecha digital que enfrentan |
| SH-02 | Familias (padres/tutores) | Beneficiario indirecto | Expectativas sobre calidad educativa, frustración ante fracaso escolar |
| SH-03 | Docentes de educación secundaria | Usuario/Operador | Describen limitaciones en su formación, necesidad de apoyo pedagógico, resistencia a evaluación |
| SH-04 | SUTEP (sindicato magisterial) | Stakeholder con poder de veto | Intereses: estabilidad laboral, rechazo a evaluaciones externas, cuotas de contratación |
| SH-05 | UMC-MINEDU (evaluación de calidad) | Adquiriente técnico | Necesidad de datos objetivos de aprendizaje, métricas de mejora |
| SH-06 | MINEDU — Dirección de Educación Básica | Adquiriente/Rector | Necesidad de elevar resultados nacionales (ENLA, PISA), cerrar brecha digital |
| SH-07 | Universidades e Institutos Pedagógicos | Formador | Brecha entre formación inicial y práctica en aula |
| SH-08 | Equipo de desarrollo de la plataforma IA | Implementador | Reciben requisitos para construir el tutor IA con Gemma |

### A.2 Estrategia de Elicitación

| Técnica | Stakeholders | Propósito |
|---|---|---|
| **Focus groups con estudiantes** | SH-01, SH-02 | Capturar experiencia de aprendizaje: ¿qué no entienden? ¿cómo les gustaría aprender? |
| **Entrevistas individuales con docentes** | SH-03 | Entender limitaciones sin exponerlos ante el gremio |
| **Taller de negociación** | SH-04, SH-05, SH-06 | Resolver tensión entre evaluación de calidad y resistencia gremial |
| **Análisis de resultados ENLA/PISA** | SH-05, SH-06 | Extraer necesidades desde los datos de evaluación |
| **Priorización MoSCoW** | SH-05, SH-06, SH-08 | Definir alcance del prototipo hackathon |

### A.3 Sistemas Habilitadores

- Gestor de requisitos con trazabilidad a 6.4.1
- Datos abiertos ENLA, PISA, censo escolar (INEI)
- Restricción: Gemma como motor de IA obligatorio
- Entorno offline-first requerido (79% de colegios sin internet)

---

## Actividad B: Definir las Necesidades de los Stakeholders

### B.1 Necesidades Elicitadas

#### SH-01 — Estudiantes

| ID-N | Necesidad |
|---|---|
| N-01 | "Necesito que alguien me explique matemática de una forma que entienda, no solo copiando fórmulas del pizarrón" |
| N-02 | "Necesito practicar lectura con textos que me interesen, no con fragmentos aburridos de libros viejos" |
| N-03 | "Necesito saber en qué nivel estoy y qué me falta aprender, sin que me comparen con el resto" |
| N-04 | "Necesito poder estudiar en mi casa aunque no tenga internet" |
| N-05 | "Necesito prepararme para el examen de admisión a la universidad, pero en mi colegio no nos enseñan eso" |

#### SH-02 — Familias

| ID-N | Necesidad |
|---|---|
| N-06 | "Necesito saber si mi hijo está aprendiendo algo útil o solo está perdiendo el tiempo en el colegio" |
| N-07 | "Necesito que mi hijo no termine la secundaria sin saber leer bien, como me pasó a mí" |

#### SH-03 — Docentes

| ID-N | Necesidad |
|---|---|
| N-08 | "Necesito material didáctico listo para usar en clase. No tengo tiempo de crearlo desde cero para 40 alumnos" |
| N-09 | "Necesito una herramienta que me ayude a explicar conceptos difíciles sin que yo tenga que ser un experto en todo" |
| N-10 | "Necesito que mis alumnos practiquen más, pero no tengo tiempo de corregir 40 cuadernos todas las semanas" |
| N-11 | "Necesito capacitación en tecnología, pero que sea práctica y aplicable al aula, no teoría que nunca uso" |
| N-12 | "No quiero que me evalúen con una prueba externa. Pero sí quisiera saber cómo mejorar sin que me castiguen por los resultados" |

#### SH-04 — SUTEP

| ID-N | Necesidad |
|---|---|
| N-13 | "Necesito garantías de que ninguna herramienta tecnológica va a reemplazar puestos de trabajo docente" |
| N-14 | "Necesito que cualquier sistema que mida resultados de aprendizaje no se use para despedir o sancionar docentes" |

#### SH-05 — UMC-MINEDU

| ID-N | Necesidad |
|---|---|
| N-15 | "Necesito datos de progreso de aprendizaje a nivel de cada estudiante, no solo promedios nacionales cada 2 años" |
| N-16 | "Necesito evidencia objetiva de qué intervenciones pedagógicas funcionan y cuáles no" |
| N-17 | "Necesito que los resultados de aprendizaje no dependan de la suerte de qué docente te tocó" |

#### SH-06 — MINEDU

| ID-N | Necesidad |
|---|---|
| N-18 | "Necesito que los 2+ millones de estudiantes de secundaria pública alcancen al menos nivel básico en lectura y matemática" |
| N-19 | "Necesito cerrar la brecha digital: 79% de colegios sin internet no puede ser una sentencia de exclusión" |
| N-20 | "Necesito que la inversión en tecnología educativa demuestre resultados medibles" |

### B.2 Conflictos entre Stakeholders

| Conflicto | Stakeholders | Naturaleza |
|---|---|---|
| C-01 | SH-04 (SUTEP) ↔ SH-05 (UMC) | SUTEP rechaza cualquier evaluación; UMC necesita medir para mejorar. La herramienta no debe ser percibida como mecanismo de evaluación docente. |
| C-02 | SH-03 (Docentes) ↔ SH-08 (Equipo IA) | Docentes temen ser reemplazados por IA. La comunicación debe enfatizar que la IA asiste, no reemplaza. |
| C-03 | SH-01 (estudiantes sin internet) ↔ SH-08 (plataforma online) | 79% sin internet obliga a diseño offline-first |

### B.3 Priorización MoSCoW

| Prioridad | Necesidades |
|---|---|
| **Must** | N-01 (explicación comprensible), N-03 (diagnóstico de nivel), N-04 (offline), N-08 (material listo para usar), N-18 (nivel básico en lectura y matemática) |
| **Should** | N-02 (contenido interesante), N-09 (asistencia al docente), N-10 (corrección automática), N-15 (datos por estudiante), N-13 (garantía de no reemplazo laboral) |
| **Could** | N-05 (preparación universitaria), N-11 (capacitación TIC para docentes), N-16 (evidencia de intervenciones) |
| **Won't (fase 1)** | N-12 (autodiagnóstico docente sin sanción — requiere acuerdo gremial), N-19 (cerrar brecha digital — es el Problema 1) |

---

## Actividad C: Desarrollar Conceptos y Escenarios del Ciclo de Vida

### C.1 Concepto de Operaciones (OpsCon) Refinado

**Nombre del sistema:** Tutor IA de Aprendizaje Personalizado — "Aprendo+" (con Gemma)

**Descripción operacional:** Aplicación que provee experiencias de aprendizaje personalizadas a estudiantes de secundaria pública en lectura y matemática, compensando déficits de formación docente y brecha digital. El estudiante recibe una evaluación diagnóstica adaptativa, la IA (Gemma) diseña una ruta de aprendizaje personalizada, el estudiante avanza a su ritmo con contenido interactivo, y el docente recibe material didáctico listo para reforzar en clase. Opera offline-first.

**Modos de operación:**
- **Modo diagnóstico:** Evaluación adaptativa inicial que determina el nivel real del estudiante (no su grado escolar) en lectura y matemática — en 20-30 minutos
- **Modo aprendizaje:** Lecciones interactivas de 15-20 minutos con explicaciones, ejemplos, ejercicios y retroalimentación inmediata de IA
- **Modo práctica:** Banco de ejercicios generados por IA según el nivel y los errores detectados
- **Modo docente:** Panel con datos agregados y anonimizados del progreso del grupo + actividades sugeridas para el aula
- **Modo offline:** Contenidos precargados en el dispositivo. Sincronización de progreso cuando haya conectividad

**Escenarios de uso:**

| Escenario | Actor | Flujo |
|---|---|---|
| **E-01: Estudiante se diagnostica** | SH-01 | Abre la app → prueba adaptativa de 25 min → la IA determina que está en nivel "5to de primaria" en matemática aunque cursa 3ro de secundaria → la IA diseña una ruta para cerrar esa brecha sin vergüenza ni comparación |
| **E-02: Estudiante aprende matemática offline** | SH-01 | En casa, sin internet → abre lección "Fracciones: concepto visual" → ve animación, resuelve ejercicios → la IA detecta que confunde denominador con numerador → genera 5 ejercicios extra específicos para ese error → la estudiante comprende |
| **E-03: Docente usa material en clase** | SH-03 | Abre panel docente → ve que el 70% del grupo falló en "comprensión de inferencias" → descarga actividad de 20 minutos lista para imprimir → la aplica en clase sin necesidad de prepararla |
| **E-04: MINEDU monitorea progreso** | SH-06 | Dashboard anonimizado por región → ve que en Ayacucho los estudiantes mejoraron 15% en comprensión lectora en 3 meses usando la app → decide expandir el piloto |
| **E-05: Estudiante sincroniza progreso** | SH-01 | Usó la app 1 semana sin internet en zona rural → llega a cabina de internet → sincroniza → su progreso se actualiza → la IA recalibra su ruta con los datos nuevos |

### C.2 Conceptos de Otras Etapas del Ciclo de Vida

#### C.2.1 Adquisición

- **Fase 1 (Hackathon):** Prototipo con Gemma: módulo de diagnóstico adaptativo + 10 lecciones de matemática y 10 de lectura para 3ro de secundaria. Interfaz offline-first.
- **Fase 2 (Piloto):** 100 colegios en 3 regiones. Evaluación de impacto con grupo control. Entrenamiento de Gemma con datos reales de interacción estudiante-plataforma.
- **Fase 3 (Nacional):** Despliegue progresivo. Contenido completo para todo el currículo de secundaria.

#### C.2.2 Despliegue

- App Android (APK liviano, <50MB con contenidos base). Compatible con Android 6+ (dispositivos de bajo costo).
- Versión web progresiva (PWA) para colegios con internet.
- Distribución inicial vía APK offline (USB, Bluetooth) en zonas sin conectividad.
- Alianza con programas sociales (Qali Warma, Juntos) para distribución de tablets con la app precargada.

#### C.2.3 Soporte y Mantenimiento

- Actualización trimestral de contenidos.
- Reentrenamiento de Gemma con datos de interacción (mejora continua de explicaciones y detección de errores).
- Mesa de ayuda para docentes (WhatsApp + telefónica).
- Comunidad de docentes que comparten experiencias de uso.

#### C.2.4 Retiro

- Los datos de progreso del estudiante son exportables y portables (estándar xAPI/SCORM).
- El historial de aprendizaje acompaña al estudiante aunque cambie de plataforma.

---

## Actividad D: Transformar Necesidades en Requisitos de Stakeholders

### D.1 Requisitos Funcionales (StRS)

#### Grupo RF-01: Diagnóstico Adaptativo

| ID-R | Requisito | Necesidad | Criterio de aceptación |
|---|---|---|---|
| RF-01 | El sistema DEBE aplicar una evaluación diagnóstica adaptativa en lectura y matemática que ajuste la dificultad según las respuestas del estudiante | N-03, N-15 | La evaluación determina el nivel real del estudiante (grado equivalente) en ≤30 minutos con precisión ≥80% vs. prueba ENLA presencial |
| RF-02 | El sistema DEBE presentar el resultado del diagnóstico en lenguaje positivo ("estás en nivel 'Explorador', tu siguiente meta es 'Aventurero'") sin usar grados escolares que estigmaticen | N-03 | ≥90% de estudiantes en prueba de usabilidad reportan que el resultado "no los hizo sentir mal" |
| RF-03 | El sistema DEBE generar automáticamente una ruta de aprendizaje personalizada basada en las brechas detectadas en el diagnóstico | N-01, N-03 | La ruta incluye ≥5 lecciones secuenciadas por nivel de dificultad creciente |

#### Grupo RF-02: Aprendizaje Personalizado

| ID-R | Requisito | Necesidad | Criterio de aceptación |
|---|---|---|---|
| RF-04 | El sistema DEBE presentar cada lección con: (a) video/animación explicativa ≤3 min, (b) ejemplo resuelto paso a paso, (c) 5-10 ejercicios interactivos, (d) retroalimentación inmediata específica al error cometido | N-01, N-02 | ≥70% de estudiantes mejoran su puntaje en el tema después de completar la lección (medido en pre-test/post-test) |
| RF-05 | El sistema DEBE detectar patrones de error del estudiante (ej. "confunde denominador con numerador", "no identifica idea principal en textos de más de 200 palabras") y generar ejercicios de refuerzo específicos para ese patrón | N-01 | La IA identifica correctamente ≥3 patrones de error distintos en 80% de estudiantes después de 10 lecciones completadas |
| RF-06 | El sistema DEBE permitir al estudiante avanzar a su propio ritmo, sin límites de tiempo ni penalizaciones por error | N-03 | Estudiante completa lección en cualquier tiempo. No hay pantalla de "tiempo agotado". Errores no reducen puntaje visible. |
| RF-07 | El sistema DEBE generar ejercicios de lectura con textos de géneros variados (noticias, cuentos, artículos científicos, historias) seleccionados según la edad e intereses del estudiante | N-02 | Biblioteca de ≥50 textos por nivel, con ≥5 géneros distintos |

#### Grupo RF-03: Operación Offline

| ID-R | Requisito | Necesidad | Criterio de aceptación |
|---|---|---|---|
| RF-08 | El sistema DEBE funcionar completamente sin conexión a internet: diagnóstico, lecciones, ejercicios y retroalimentación inmediata | N-04 | Todas las funcionalidades del estudiante operan 100% offline. Verificado en dispositivo sin SIM ni WiFi durante 7 días. |
| RF-09 | El sistema DEBE almacenar localmente todo el progreso del estudiante y sincronizar automáticamente al detectar conectividad, sin pérdida de datos | N-04 | Progreso de 30 días de uso offline se sincroniza correctamente. Prueba: interrupción de conexión a mitad de sincronización → reanuda sin duplicar ni perder datos. |
| RF-10 | El APK base DEBE ocupar ≤50MB incluyendo contenidos de las primeras 10 lecciones | N-04 | Tamaño verificado de APK ≤50MB |

#### Grupo RF-04: Soporte al Docente

| ID-R | Requisito | Necesidad | Criterio de aceptación |
|---|---|---|---|
| RF-11 | El sistema DEBE proporcionar al docente un panel con datos agregados y anonimizados de su grupo: % de avance, temas con mayor dificultad, distribución de niveles | N-08, N-15 | Panel muestra datos de ≥30 estudiantes. No permite identificar el nivel individual de un estudiante por nombre (anonimizado) |
| RF-12 | El sistema DEBE generar actividades de aula listas para usar (imprimibles o proyectables) basadas en los temas donde el grupo mostró mayor dificultad | N-08, N-09 | La actividad se genera en ≤2 minutos. Incluye: objetivo, instrucciones para el docente, material para el estudiante, duración estimada. |
| RF-13 | El sistema DEBE operar como herramienta de APOYO, no de evaluación: en ninguna pantalla se muestra un ranking de docentes ni se compara su desempeño | N-13, N-14 | Verificación UX: no existen pantallas de ranking o comparación entre docentes |

#### Grupo RF-05: Monitoreo y Evidencia

| ID-R | Requisito | Necesidad | Criterio de aceptación |
|---|---|---|---|
| RF-14 | El sistema DEBE generar reportes anonimizados a nivel de escuela, UGEL, región y nacional con: % de estudiantes por nivel, progreso promedio, tiempo de uso, temas con mayor avance | N-15, N-18, N-20 | Reporte regional se genera en ≤30 segundos. Datos anonimizados: imposible identificar a un estudiante individual desde el reporte agregado. |
| RF-15 | El sistema DEBE medir el progreso de cada estudiante como la diferencia entre su diagnóstico inicial y su nivel actual, reportando "meses de aprendizaje ganados" | N-15, N-20 | Métrica "meses de aprendizaje ganados" es calculable y trazable a las evaluaciones dentro de la plataforma |

### D.2 Requisitos No Funcionales

| ID-RNF | Atributo | Requisito | Criterio de aceptación |
|---|---|---|---|
| RNF-01 | **Offline-first** | El sistema DEBE ser usable sin conexión para TODAS las funcionalidades del estudiante | Verificación: test de 7 días sin conectividad |
| RNF-02 | **Usabilidad para adolescentes** | La interfaz DEBE ser atractiva para estudiantes de 12-17 años, con lenguaje cercano, gamificación opcional (logros, no competencia) y diseño inclusivo | Prueba de usabilidad con 30 adolescentes: ≥80% califica la app como "fácil de usar" y "me gustaría seguir usándola" |
| RNF-03 | **Usabilidad para docentes** | El panel docente DEBE ser operable por un docente sin capacitación previa en ≤15 minutos de exploración | Prueba: 10 docentes sin inducción logran generar una actividad de aula en ≤20 min desde que abren la app |
| RNF-04 | **Rendimiento en dispositivos básicos** | El sistema DEBE funcionar fluidamente en dispositivos con 2GB RAM, Android 6, procesador quad-core 1.2GHz | Lección carga en ≤5 segundos. Ejercicio responde en ≤1 segundo. Sin crashes en 1 hora de uso continuo. |
| RNF-05 | **Privacidad de menores** | Los datos de estudiantes DEBEN almacenarse con cifrado. Los reportes para MINEDU DEBEN ser estrictamente anonimizados y agregados | Auditoría de seguridad: datos en reposo cifrados con AES-256. API de reportes no expone datos individuales. |
| RNF-06 | **Multilingüe (fase 2+)** | El sistema DEBE tener arquitectura preparada para incorporar contenidos en quechua y aimara (alineado con Problema 4) | La interfaz soporta cambio de idioma sin modificaciones de código |

### D.3 Medidas de Efectividad y Desempeño

| Medida | Tipo | Definición | Meta |
|---|---|---|---|
| MOE-01 | Efectividad | % de estudiantes que mejoran ≥1 nivel en lectura o matemática después de 3 meses de uso regular (≥3 sesiones/semana) | ≥60% |
| MOE-02 | Efectividad | Reducción de la brecha entre el grado escolar y el nivel real: "meses de aprendizaje ganados" promedio por estudiante | ≥6 meses en 1 año de uso |
| MOE-03 | Efectividad | Comparación ENLA: estudiantes que usaron la app vs. grupo control pareado | Diferencia estadísticamente significativa (p<0.05) a favor del grupo app |
| MOP-01 | Desempeño | Estudiantes activos (≥1 sesión/semana) sobre total de estudiantes con acceso | ≥70% de retención al mes 3 |

### D.4 Criterios de Aceptación del Stakeholder

| Criterio | Validador | Condición |
|---|---|---|
| CA-01 | UMC-MINEDU (SH-05) | El diagnóstico adaptativo de la plataforma correlaciona ≥0.7 con resultados de prueba ENLA presencial en una muestra de 200 estudiantes |
| CA-02 | Docentes (SH-03) | ≥80% de docentes en piloto reportan que la plataforma "les ahorra tiempo de preparación de clases" y "no sintieron que los evaluaba" |
| CA-03 | SUTEP (SH-04) | Verificación independiente de que el sistema no genera rankings ni comparaciones entre docentes, ni datos que puedan usarse para sanciones |
| CA-04 | MINEDU (SH-06) | Evidencia de mejora en al menos 15% de estudiantes del piloto en 6 meses |

---

## Actividad E: Gestionar la Definición de Necesidades y Requisitos

### E.1 Acuerdo Formal de Stakeholders

| Stakeholder | Acepta | Método |
|---|---|---|
| MINEDU (SH-06) | Todos los RF y RNF | Acta de validación con Director de Educación Básica |
| UMC (SH-05) | RF-01, RF-02, RF-14, RF-15, CA-01 | Validación técnica de métricas |
| SUTEP (SH-04) | RF-13, RNF-05, CA-03 | Acuerdo de garantías de no uso para evaluación docente |
| Docentes (SH-03) | RF-11, RF-12, RNF-03, CA-02 | Prueba de usabilidad piloto |

### E.2 Trazabilidad Completa

| Necesidad | Requisito | Problema 6.4.1 | Clase de Solución |
|---|---|---|---|
| N-01 (explicación comprensible) | RF-04, RF-05 | Efecto Directo 1: Analfabetismo funcional | Tutor IA personalizado |
| N-03 (diagnóstico sin estigma) | RF-01, RF-02 | Efecto Directo 1 | Evaluación adaptativa |
| N-04 (offline) | RF-08, RF-09, RF-10, RNF-01 | Causa Directa B: 79% sin internet | Diseño offline-first |
| N-08 (material listo) | RF-11, RF-12 | Causa Raíz A.3: Docentes sin tiempo/formación | Asistente docente IA |
| N-13 (garantía no reemplazo) | RF-13, RNF-05 | Causa Raíz A.3: Resistencia gremial | Diseño de apoyo, no evaluación |
| N-15 (datos por estudiante) | RF-01, RF-02, RF-14, RF-15 | Causa Raíz A.3 | Datos como evidencia |

### E.3 Resolución de Conflictos

| Conflicto | Resolución |
|---|---|
| C-01: SUTEP vs. UMC | La plataforma mide progreso del ESTUDIANTE, no del docente. Los datos de grupo son anonimizados. No existe pantalla de "ranking de docentes". El sistema se audita externamente para verificar cumplimiento. |
| C-02: Docentes temen ser reemplazados | Comunicación: "Aprendo+ no reemplaza al docente. Le da superpoderes." El docente recibe material listo que potencia su clase. En zonas sin docente de matemática, la app es mejor que nada; donde sí hay docente, la app es su asistente. |
| C-03: Offline vs. Contenido rico | Contenidos precargados en APK. Videos comprimidos, animaciones vectoriales. La IA opera on-device (Gemma en su versión ligera). Sincronización diferida para nuevos contenidos. |

---

## Alineación con ISO/IEC 12207

| Proceso | Equivalente |
|---|---|
| **5.1.1.1** Describir necesidad | Mapeado a N-01 a N-20 |
| **5.1.1.2** Requerimientos de negocio, organizativos y de usuario | Mapeado a RF-01 a RF-15 (usuario) y RNF-01 a RNF-06 (organizativos) |
| **5.3.2.1** Análisis de uso previsto | OpsCon con 5 modos y 5 escenarios |
| **5.3.4.1** Requisitos software perspectiva usuario | RNF-02 (usabilidad adolescente), RF-06 (sin límites de tiempo ni penalizaciones), RF-02 (lenguaje positivo) |
| **F.1.3.1** Requirements Elicitation | Actividad A (estrategia) + B (necesidades elicitadas por stakeholder) |
| **24748-3** Funcionales vs. No funcionales | RF-01 a RF-15 + RNF-01 a RNF-06 |
| **24748-3** User stories | Escenarios E-01 a E-05 |
| **24748-3** Usability testing input | CA-01, CA-02 |

---

**Documento generado según:** ISO/IEC/IEEE 15288:2015 — 6.4.2
**Input:** 6.4.1 (problema-2-logros-aprendizaje.md)
**Output hacia:** 6.4.3
**Documentación 15289:** ConOps/OpsCon, StRS, Life Cycle Concepts, 5 Escenarios Operacionales, 4 Criterios de Aceptación
**Fecha:** 29 de julio de 2026
