# Proceso 6.4.3 — System Requirements Definition (ISO/IEC/IEEE 15288:2015)
# Aplicado al Problema 2: Deficiencia Estructural en Logros de Aprendizaje

**Input desde 6.4.2:** StRS (RF-01 a RF-15, RNF-01 a RNF-06), ConOps "Aprendo+" con 5 modos, escenarios E-01 a E-05, 20 necesidades N-01 a N-20, criterios CA-01 a CA-04, medidas MOE-01 a MOE-03 + MOP-01, conflictos C-01 a C-03
**Proceso siguiente:** 6.4.4 Architecture Definition

---

## Tailoring del Proceso (ISO/IEC/IEEE 12207:2006 — Anexo A)

### A.1 Identificación del Entorno del Proyecto

| Característica | Valor | Impacto en Tailoring |
|---|---|---|
| **Modelo de ciclo de vida** | Iterativo incremental (hackathon → piloto → nacional) | Procesos técnicos 6.4.1 a 6.4.9 activos; 6.4.10 a 6.4.14 diferidos |
| **Actividad actual** | Fase 1: Prototipo de hackathon (AI Competition Gemma 2026) | Enfoque en 6.4.1 a 6.4.5 con nivel de detalle proporcional al alcance del prototipo |
| **Tamaño del sistema** | APK ≤50MB, Android 6+, Gemma on-device | Requisitos de rendimiento y tamaño son críticos y no negociables |
| **Aspectos críticos** | Privacidad de menores, offline-first, equidad educativa | RNF-05 (privacidad) y RNF-01 (offline) son de máxima prioridad |
| **Plazo** | Hackathon: 1-2 agosto 2026 | Tailoring agresivo: solo lo esencial para demo funcional |
| **Partes involucradas** | Equipo de desarrollo (SH-08), Gemma como motor obligatorio | Gemma es restricción no negociable de las bases de la competencia |

### A.2 Decisiones de Tailoring para este Proceso (6.4.3)

| Actividad | Decisión | Justificación |
|---|---|---|
| **A: Preparar definición** | **Completa** | Estrategia técnica y sistemas habilitadores son necesarios para toda ingeniería |
| **B: Definir requisitos** | **Completa** | Transformación StRS → SyRS es el núcleo de este proceso |
| **C: Analizar requisitos** | **Completa** | Clasificación, riesgos técnicos y rationale son esenciales para arquitectura |
| **D: Analizar integridad/Verificar** | **Simplificada** | MOPs/TPMs se definen; verificación formal completa se difiere a fase piloto |
| **E: Gestionar requisitos** | **Simplificada** | Trazabilidad bidireccional completa; gestión de baseline simplificada para prototipo |

### A.3 Restricciones No Negociables (Bases de la Hackathon + Contexto)

| ID | Restricción | Origen |
|---|---|---|
| **NR-01** | **Gemma 4** como motor de IA obligatorio (no se permite otro modelo) | Bases AI Competition Gemma 2026 |
| **NR-02** | **Offline-first**: 79% de colegios sin internet | Problema 1 (infraestructura) — contexto operativo real |
| **NR-03** | APK **≤50MB** con contenidos base | Dispositivos de bajo costo en zonas rurales |
| **NR-04** | Compatible con **Android 6+** (2GB RAM mínimo) | Hardware existente en colegios públicos |
| **NR-05** | **Sin ranking ni evaluación docente** | Conflicto C-01 resuelto en 6.4.2 (SUTEP vs UMC) |
| **NR-06** | Track: **IA para Impacto Social** (ODS) | Bases de la competencia |
| **NR-07** | Lenguajes permitidos: **Python y JavaScript** | Bases de la competencia |
| **NR-08** | Ecosistema permitido: **Flutter, Android, Firebase, Cloud Run** | Bases de la competencia |

---

## Actividad A: Preparar la Definición de Requisitos del Sistema

### A.1 Estrategia Técnica de Transformación StRS → SyRS

El proceso 6.4.3 transforma la **vista orientada al usuario** (Stakeholder Requirements de 6.4.2) en la **vista técnica de ingeniería** (System Requirements). La estrategia es:

1. **Cada RF de 6.4.2 se traduce a uno o más SR** con lenguaje técnico preciso, medible y verificable
2. **Cada RNF de 6.4.2 se traduce a especificaciones técnicas** con valores cuantitativos
3. **Se agregan requisitos de sistema** que el stakeholder no ve pero son indispensables: persistencia local, sincronización, arquitectura de datos, gestión de sesiones, manejo de errores
4. **Se definen las fronteras del sistema** (qué está dentro y fuera del alcance del prototipo)
5. **Se establecen las Medidas de Rendimiento (MOPs) y Medidas Técnicas de Desempeño (TPMs)** derivadas de las MOE de 6.4.2

### A.2 Sistemas Habilitadores Identificados

| Sistema Habilitador | Rol en 6.4.3 | Estado |
|---|---|---|
| **Gemma (Google)** | Motor de IA on-device para diagnóstico adaptativo, generación de ejercicios, detección de patrones de error | Obligatorio (NR-01) |
| **SQLite / IndexedDB** | Almacenamiento local cifrado del progreso del estudiante (offline) | Requerido por RNF-05 |
| **Android SDK (API 23+)** | Plataforma base para APK compatible con Android 6+ | Requerido por NR-04 |
| **Flutter** | Framework de UI cross-platform (si se usa) | Permitido por bases |
| **Firebase** | Backend para sincronización diferida y dashboard MINEDU | Permitido por bases |
| **Cloud Run** | Servicio cloud para API de reportes y sincronización | Permitido por bases |
| **AES-256** | Cifrado de datos en reposo (datos de menores) | Requerido por RNF-05 |
| **xAPI/SCORM** | Estándar de portabilidad de datos de aprendizaje | Requerido por ciclo de vida (retiro) |

---

## Actividad B: Definir los Requisitos del Sistema

### B.1 Límites del Sistema (System Boundaries)

**Dentro del alcance del prototipo (hackathon):**
- Módulo de diagnóstico adaptativo (lectura y matemática, 3ro de secundaria)
- Motor de tutoría IA con Gemma on-device
- 10 lecciones de matemática + 10 de lectura (contenido base precargado)
- Panel docente con datos agregados y generación de actividades
- Almacenamiento local y sincronización diferida
- APK Android ≤50MB

**Fuera del alcance del prototipo (diferido):**
- Contenido completo de todo el currículo de secundaria (Fase 3)
- Módulo multilingüe (quechua/aimara) — RNF-06, fase 2+
- Preparación para examen de admisión universitaria — N-05, Could
- Capacitación TIC para docentes — N-11, Could
- Cierre de brecha digital nacional — N-19, es Problema 1
- Operación, mantenimiento y retiro del sistema — procesos 6.4.12 a 6.4.14

### B.2 Contexto del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENTORNO OPERACIONAL                          │
│                                                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐      │
│  │ Estudiante│    │  Docente  │    │    MINEDU / UMC     │      │
│  │  (SH-01) │    │  (SH-03) │    │    (SH-05, SH-06)    │      │
│  └────┬─────┘    └────┬─────┘    └──────────┬───────────┘      │
│       │               │                      │                  │
│       ▼               ▼                      ▼                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │                                                      │      │
│  │              SISTEMA "Aprendo+" (SoI)                │      │
│  │                                                      │      │
│  │  ┌─────────────┐ ┌─────────────┐ ┌───────────────┐  │      │
│  │  │  Módulo     │ │   Motor     │ │   Panel       │  │      │
│  │  │ Diagnóstico │ │   Gemma     │ │   Docente     │  │      │
│  │  │ Adaptativo  │ │  on-device  │ │   Analytics   │  │      │
│  │  └─────────────┘ └─────────────┘ └───────────────┘  │      │
│  │  ┌─────────────┐ ┌─────────────┐ ┌───────────────┐  │      │
│  │  │  Almacen.   │ │ Sincroniz.  │ │  Dashboard    │  │      │
│  │  │  Local      │ │  Diferida   │ │  MINEDU       │  │      │
│  │  │  (SQLite)   │ │  (Firebase) │ │  (Cloud Run)  │  │      │
│  │  └─────────────┘ └─────────────┘ └───────────────┘  │      │
│  │                                                      │      │
│  └──────────────────────────────────────────────────────┘      │
│       │               │                      │                  │
│       ▼               ▼                      ▼                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐      │
│  │Disposit. │    │ Internet │    │  Servidores MINEDU   │      │
│  │Android 6+│    │(cuando   │    │  / UMC (reportes)    │      │
│  │2GB RAM   │    │hay)      │    │                      │      │
│  └──────────┘    └──────────┘    └──────────────────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### B.3 Requisitos Funcionales del Sistema (SyRS)

#### SR-Grupo A: Diagnóstico Adaptativo (derivado de RF-01, RF-02, RF-03)

| ID-SR | Requisito del Sistema | StRS Origen | Rationale |
|---|---|---|---|
| **SR-A01** | El sistema DEBE ejecutar una evaluación diagnóstica adaptativa en lectura y matemática que seleccione ítems de un banco local según el modelo de respuesta al ítem (IRT simplificado), ajustando la dificultad tras cada respuesta del estudiante | RF-01, N-03 | Sin diagnóstico preciso, la ruta personalizada no puede calibrarse. Debe funcionar offline (NR-02). |
| **SR-A02** | El banco de ítems diagnósticos DEBE incluir ≥30 ítems de lectura y ≥30 de matemática para 3ro de secundaria, organizados en 5 niveles de dificultad (equivalentes a 1ro primaria a 2do secundaria) | RF-01, N-03 | Necesario para discriminar el nivel real del estudiante independientemente de su grado formal. |
| **SR-A03** | El algoritmo de selección de ítems DEBE converger al nivel del estudiante en ≤25 ítems (≈20-25 minutos) con un margen de error de ±1 nivel | RF-01, CA-01 | Límite de atención de adolescentes de 12-17 años. Precisión ≥80% vs ENLA. |
| **SR-A04** | El sistema DEBE mapear el nivel numérico resultante a etiquetas positivas predefinidas: Nivel 1="Explorador", Nivel 2="Aprendiz", Nivel 3="Practicante", Nivel 4="Aventurero", Nivel 5="Experto" | RF-02, N-03 | Evita estigmatización por grado escolar. Lenguaje de gamificación no competitiva. |
| **SR-A05** | El sistema DEBE generar una ruta de aprendizaje como secuencia ordenada de ≥5 lecciones, donde cada lección tiene: (a) ID de tema, (b) nivel de dificultad, (c) prerequisitos, (d) estimación de tiempo (15-20 min) | RF-03, N-01, N-03 | La ruta es el plan de acción concreto que el estudiante sigue. Debe ser secuencial y progresiva. |
| **SR-A06** | El sistema DEBE permitir al estudiante reiniciar el diagnóstico en cualquier momento si desea re-evaluar su nivel | RF-03 | Flexibilidad para estudiantes que sienten que el diagnóstico no reflejó su nivel real. |

#### SR-Grupo B: Motor de Tutoría con IA (derivado de RF-04, RF-05, RF-06, RF-07)

| ID-SR | Requisito del Sistema | StRS Origen | Rationale |
|---|---|---|---|
| **SR-B01** | Cada lección DEBE estar estructurada como un objeto JSON local que contiene: (a) título del tema, (b) video/animación ≤3 min (formato WebM/MP4 comprimido), (c) ejemplo resuelto paso a paso (texto + imágenes), (d) 5-10 ejercicios interactivos con opciones múltiples y respuesta abierta corta, (e) retroalimentación por tipo de error | RF-04, N-01, N-02 | Estructura uniforme para todas las lecciones. Debe caber en APK ≤50MB (NR-03). |
| **SR-B02** | El sistema DEBE ejecutar Gemma on-device para: (a) generar explicaciones alternativas cuando el estudiante no comprende la primera, (b) detectar patrones de error a partir de ≥3 respuestas incorrectas del mismo tipo, (c) generar 5 ejercicios de refuerzo específicos para el patrón detectado | RF-05, N-01, NR-01 | Gemma es obligatorio. Debe funcionar sin internet (NR-02). Versión ligera requerida para 2GB RAM. |
| **SR-B03** | El sistema DEBE registrar cada interacción del estudiante en una tabla local: {timestamp, lesson_id, exercise_id, response, is_correct, error_type (si aplica), time_spent_seconds} | RF-05, N-15 | Necesario para detección de patrones de error y para sincronización posterior. |
| **SR-B04** | El sistema NO DEBE imponer límites de tiempo para completar ejercicios ni lecciones. El estudiante avanza a su propio ritmo. Los errores NO reducen puntaje visible ni desbloquean contenido | RF-06, N-03 | Diseño anti-estigma. El estudiante no debe sentir presión ni vergüenza. |
| **SR-B05** | El sistema DEBE mantener una biblioteca local de ≥50 textos de lectura por nivel, organizados en ≥5 géneros: noticias, cuentos, artículos científicos, historias, biografías. Cada texto DEBE tener: título, género, nivel de dificultad (1-5), extensión en palabras (200-800), 5 preguntas de comprensión | RF-07, N-02 | Diversidad de géneros para engagement. Textos cortos para dispositivos básicos. |
| **SR-B06** | El sistema DEBE seleccionar textos de lectura según: (a) nivel actual del estudiante, (b) género preferido (si el estudiante indica preferencia), (c) textos no leídos previamente | RF-07, N-02 | Personalización sin necesidad de IA para selección de textos (reglas simples bastan). |
| **SR-B07** | El sistema DEBE ejecutar la inferencia de Gemma completamente on-device, sin llamadas a API externa durante el modo offline. La versión de Gemma utilizada DEBE ser compatible con dispositivos de 2GB RAM | RF-04, RF-05, RNF-01, NR-02 | Restricción no negociable: 79% sin internet. Gemma debe correr localmente. |

#### SR-Grupo C: Arquitectura Offline y Sincronización (derivado de RF-08, RF-09, RF-10)

| ID-SR | Requisito del Sistema | StRS Origen | Rationale |
|---|---|---|---|
| **SR-C01** | El sistema DEBE almacenar localmente en base de datos SQLite cifrada (AES-256): (a) perfil del estudiante (nombre, nivel diagnóstico, ruta actual), (b) registro completo de interacciones (SR-B03), (c) contenido de lecciones y textos precargados, (d) ejercicios generados por IA | RF-08, RF-09, RNF-01, RNF-05 | Offline-first significa que TODO debe estar disponible localmente. Cifrado obligatorio por datos de menores. |
| **SR-C02** | El sistema DEBE detectar automáticamente la disponibilidad de conectividad (WiFi o datos móviles) y, al detectarla, iniciar el proceso de sincronización diferida en segundo plano sin interrumpir la experiencia del usuario | RF-09, N-04 | Sincronización transparente. El estudiante no debe tener que activarla manualmente. |
| **SR-C03** | El proceso de sincronización DEBE transmitir al servidor (Firebase/Cloud Run): (a) registro de interacciones no sincronizadas, (b) nivel actual del estudiante, (c) métricas de progreso (lecciones completadas, tiempo total, patrones de error detectados). La sincronización DEBE ser idempotente y tolerante a interrupciones | RF-09, N-15 | Idempotencia evita duplicación de datos. Tolerancia a interrupciones es crítica en zonas con señal intermitente. |
| **SR-C04** | El archivo APK DEBE tener un tamaño ≤50MB incluyendo: (a) código de la aplicación, (b) modelo de Gemma optimizado (quantizado), (c) contenido de las primeras 10 lecciones de matemática y 10 de lectura, (d) banco de ítems diagnósticos, (e) biblioteca de textos base | RF-10, N-04, NR-03 | Restricción no negociable. Dispositivos de bajo costo tienen almacenamiento limitado. |
| **SR-C05** | El sistema DEBE implementar un mecanismo de descarga incremental de contenido adicional (lecciones futuras) cuando haya conectividad, sin exceder el límite de almacenamiento disponible en el dispositivo | RF-09 | Permite expandir contenido sin sobrecargar el dispositivo. |
| **SR-C06** | En caso de interrupción de conexión durante la sincronización, el sistema DEBE reanudar desde el último punto confirmado sin duplicar registros ni perder datos | RF-09, N-04 | Zonas rurales tienen señal intermitente. La integridad de datos es crítica. |

#### SR-Grupo D: Panel Docente (derivado de RF-11, RF-12, RF-13)

| ID-SR | Requisito del Sistema | StRS Origen | Rationale |
|---|---|---|---|
| **SR-D01** | El panel docente DEBE mostrar datos agregados del grupo (≥30 estudiantes) en formato de dashboard: (a) % de avance por lección, (b) distribución de niveles (Explorador/Aprendiz/Practicante/Aventurero/Experto), (c) top 3 temas con mayor dificultad, (d) tiempo promedio de uso semanal | RF-11, N-08, N-15 | El docente necesita visión general para planificar su clase. Datos anonimizados. |
| **SR-D02** | El panel docente NO DEBE mostrar el nivel individual de ningún estudiante por nombre. Los datos individuales solo son accesibles como tendencia grupal. No existe pantalla de "lista de estudiantes con su nivel" | RF-13, N-13, N-14 | Resolución del conflicto C-01. Protección contra uso para evaluación docente. |
| **SR-D03** | El sistema DEBE generar una actividad de aula imprimible en formato PDF cuando el docente seleccione un tema de dificultad. El PDF DEBE incluir: (a) objetivo de aprendizaje, (b) instrucciones para el docente, (c) material para el estudiante (ejercicios), (d) duración estimada, (e) criterios de éxito | RF-12, N-08, N-09 | Material listo para usar. Ahorra tiempo de preparación del docente. |
| **SR-D04** | La generación de la actividad de aula DEBE completarse en ≤2 minutos desde que el docente solicita el tema | RF-12 | El docente no puede esperar. Debe ser inmediato. |
| **SR-D05** | El panel docente DEBE ser accesible desde: (a) la misma app Android (modo docente), (b) versión web (PWA) para colegios con internet | RF-11 | Flexibilidad de acceso. PWA para colegios urbanos con conectividad. |
| **SR-D06** | El sistema NO DEBE generar, almacenar ni transmitir ningún dato que permita comparar el desempeño de un docente con otro. No existen rankings, leaderboards ni métricas comparativas entre docentes | RF-13, N-13, N-14 | Resolución del conflicto C-01. Garantía para SUTEP. |

#### SR-Grupo E: Dashboard MINEDU y Métricas (derivado de RF-14, RF-15)

| ID-SR | Requisito del Sistema | StRS Origen | Rationale |
|---|---|---|---|
| **SR-E01** | El sistema DEBE generar reportes anonimizados a 4 niveles jerárquicos: escuela, UGEL, región, nacional. Cada reporte DEBE incluir: (a) % de estudiantes por nivel, (b) progreso promedio (meses de aprendizaje ganados), (c) tiempo promedio de uso semanal, (d) top 5 temas con mayor avance, (e) top 5 temas con mayor dificultad | RF-14, N-15, N-18, N-20 | MINEDU necesita evidencia para toma de decisiones. Datos anonimizados por ley. |
| **SR-E02** | El reporte a nivel regional DEBE generarse en ≤30 segundos desde la solicitud | RF-14 | Respuesta rápida para dashboards ejecutivos. |
| **SR-E03** | El sistema DEBE calcular la métrica "meses de aprendizaje ganados" como: (nivel_actual − nivel_diagnóstico_inicial) × factor_de_conversión, donde el factor se calibra contra datos históricos de ENLA | RF-15, N-15, N-20 | Métrica comprensible para tomadores de decisiones. Trazable a evaluaciones internas. |
| **SR-E04** | La API de reportes para MINEDU DEBE retornar exclusivamente datos agregados. Cualquier intento de consulta que pueda identificar a un estudiante individual DEBE ser rechazado con error 403 | RF-14, RNF-05 | Protección de datos de menores. Cumplimiento legal. |
| **SR-E05** | El sistema DEBE almacenar el historial de progreso de cada estudiante en formato compatible con xAPI/SCORM para garantizar portabilidad si el estudiante cambia de plataforma | RF-15, C.2.4 (Retiro) | Interoperabilidad. El historial acompaña al estudiante. |

### B.4 Requisitos de Rendimiento y Capacidad

| ID-RP | Atributo | Requisito | Criterio de Verificación |
|---|---|---|---|
| **RP-01** | **Tiempo de diagnóstico** | El diagnóstico adaptativo DEBE completarse en ≤30 minutos (≤25 ítems) | Cronometrar desde inicio hasta resultado en pruebas con 30 estudiantes |
| **RP-02** | **Tiempo de carga de lección** | Una lección DEBE cargar completamente en ≤5 segundos en dispositivo con 2GB RAM, Android 6, quad-core 1.2GHz | Medir con Android Profiler en dispositivo de referencia |
| **RP-03** | **Tiempo de respuesta de ejercicio** | La retroalimentación tras responder un ejercicio DEBE aparecer en ≤1 segundo | Medir con Android Profiler |
| **RP-04** | **Tiempo de generación de actividad** | La actividad de aula imprimible DEBE generarse en ≤2 minutos | Cronometrar desde solicitud hasta PDF listo |
| **RP-05** | **Tiempo de reporte regional** | El reporte regional DEBE generarse en ≤30 segundos | Medir tiempo de respuesta de API |
| **RP-06** | **Tamaño de APK** | El APK DEBE ocupar ≤50MB incluyendo contenido base | Verificar con `ls -la` o Android Studio |
| **RP-07** | **Uso de RAM** | La app NO DEBE consumir más de 500MB de RAM en uso continuo | Medir con Android Profiler durante 1 hora |
| **RP-08** | **Estabilidad** | La app NO DEBE crashear en 1 hora de uso continuo | Test de estrés: 60 minutos de uso sin interrupción |
| **RP-09** | **Capacidad de sincronización** | El sistema DEBE soportar sincronización de hasta 30 días de uso offline (≈2000 registros) sin pérdida ni duplicación | Prueba: 30 días simulados offline → sincronizar → verificar integridad |
| **RP-10** | **Precisión de diagnóstico** | El diagnóstico DEBE correlacionar ≥0.7 con resultados ENLA en muestra de 200 estudiantes | CA-01: correlación de Pearson |

### B.5 Requisitos de Interfaces del Sistema (ICD — Interface Control Description)

| ID-INT | Interfaz | Dirección | Protocolo/Formato | Descripción |
|---|---|---|---|---|
| **INT-01** | App Android ↔ Gemma on-device | Bidireccional | API local (TensorFlow Lite / ML Kit) | La app envía contexto del estudiante (nivel, tema, historial de errores) a Gemma; Gemma retorna explicación, ejercicio generado o detección de patrón de error |
| **INT-02** | App Android ↔ SQLite local | Bidireccional | SQL (SQLite) | Lectura/escritura de perfil del estudiante, registro de interacciones, contenido de lecciones |
| **INT-03** | App Android ↔ Firebase | Salida (sync) | HTTPS/REST | Envío de registros de interacción no sincronizados al servidor cuando hay conectividad |
| **INT-04** | Firebase ↔ Cloud Run | Bidireccional | HTTPS/REST | Cloud Run procesa datos sincronizados, calcula métricas, genera reportes |
| **INT-05** | Cloud Run ↔ Dashboard MINEDU | Salida | HTTPS/REST + JSON | API de reportes anonimizados para dashboard MINEDU/UMC |
| **INT-06** | App Android ↔ Sistema de archivos | Salida | PDF | Generación de actividad de aula imprimible |
| **INT-07** | App Android ↔ Bluetooth/USB | Entrada | Transferencia de archivos | Distribución del APK en zonas sin internet (alternativa a Play Store) |
| **INT-08** | App Android ↔ Pantalla del dispositivo | Salida | UI Flutter/Android | Interfaz de usuario para estudiante y docente |

### B.6 Requisitos de Calidad del Sistema

| ID-RQ | Atributo | Requisito | Criterio |
|---|---|---|---|
| **RQ-01** | **Seguridad de datos** | Todos los datos de estudiantes en reposo DEBEN cifrarse con AES-256. Las claves DEBEN almacenarse en Android Keystore | Auditoría de seguridad: verificar cifrado con herramienta de análisis |
| **RQ-02** | **Privacidad** | Los reportes para MINEDU/UMC DEBEN ser estrictamente anonimizados. La API de reportes DEBE rechazar consultas que expongan datos individuales | Prueba de penetración: intentar extraer datos individuales desde API de reportes |
| **RQ-03** | **Usabilidad (estudiante)** | ≥80% de 30 adolescentes en prueba califican la app como "fácil de usar" y "me gustaría seguir usándola" | Prueba de usabilidad con SUS (System Usability Scale) ≥68 |
| **RQ-04** | **Usabilidad (docente)** | 10 docentes sin inducción previa logran generar una actividad de aula en ≤20 minutos desde que abren la app | Prueba cronometrada con docentes reales |
| **RQ-05** | **Disponibilidad offline** | 100% de funcionalidades del estudiante operan sin conexión por ≥7 días continuos | Test de aislamiento: dispositivo sin SIM ni WiFi por 7 días |
| **RQ-06** | **Compatibilidad** | La app DEBE funcionar en Android 6.0 (API 23) y superior, con 2GB RAM mínimo | Prueba en emuladores y dispositivos reales con especificaciones mínimas |
| **RQ-07** | **Internacionalización** | La arquitectura DEBE soportar cambio de idioma (español, quechua, aimara) sin modificaciones de código | Verificar que textos están externalizados en archivos de recursos |
| **RQ-08** | **Portabilidad de datos** | Los datos de progreso DEBEN exportarse en formato xAPI/SCORM | Verificar que el export genera archivo válido según estándar |

### B.7 Restricciones de Diseño

| ID-RES | Restricción | Descripción | Impacto |
|---|---|---|---|
| **RES-01** | Gemma on-device | El modelo de IA DEBE ejecutarse localmente, no en la nube | Requiere versión quantizada de Gemma compatible con 2GB RAM |
| **RES-02** | Sin evaluación docente | El sistema NO DEBE medir, comparar ni evaluar el desempeño de docentes | Diseño UX: sin rankings, sin comparativas, sin métricas docentes |
| **RES-03** | Contenido en APK | Las primeras 20 lecciones (10 matemática + 10 lectura) DEBEN estar precargadas | Limita contenido inicial; expansión requiere descarga incremental |
| **RES-04** | Sin internet requerido | El sistema DEBE funcionar 100% sin conexión para el estudiante | Arquitectura: todo el procesamiento es local; sync es opcional |
| **RES-05** | Lenguajes de la hackathon | Python y JavaScript son los lenguajes permitidos | Backend (Cloud Run) en Python o Node.js; frontend en Flutter/Dart |

---

## Actividad C: Analizar los Requisitos del Sistema

### C.1 Clasificación de Requisitos

| Tipo | Cantidad | IDs |
|---|---|---|
| **Funcionales** | 25 | SR-A01 a SR-A06, SR-B01 a SR-B07, SR-C01 a SR-C06, SR-D01 a SR-D06, SR-E01 a SR-E05 |
| **Rendimiento** | 10 | RP-01 a RP-10 |
| **Interfaces** | 8 | INT-01 a INT-08 |
| **Calidad** | 8 | RQ-01 a RQ-08 |
| **Restricciones** | 5 | RES-01 a RES-05 |
| **No negociables** | 8 | NR-01 a NR-08 |
| **Total** | **64** | |

### C.2 Riesgos Técnicos Identificados

| ID-RT | Riesgo | Probabilidad | Impacto | Mitigación | Requisito Afectado |
|---|---|---|---|---|---|
| **RT-01** | Gemma no cabe en APK ≤50MB en versión quantizada | Media | Alto | Usar Gemma 2B quantizado a 4-bit (INT4). Si no cabe, usar solo subset de capacidades para el prototipo | SR-B07, SR-C04, RES-01 |
| **RT-02** | Inferencia de Gemma en dispositivo de 2GB RAM es demasiado lenta (>5 seg por respuesta) | Media | Alto | Optimizar con TensorFlow Lite. Si no funciona, fallback a reglas heurísticas simples para el prototipo | SR-B02, SR-B07, RP-02, RP-03 |
| **RT-03** | Sincronización falla en zonas con señal intermitente, perdiendo datos | Baja | Alto | Implementar cola de sincronización con confirmación de recepción. Reintento automático con backoff exponencial | SR-C03, SR-C06, RP-09 |
| **RT-04** | APK >50MB al incluir contenido de 20 lecciones + modelo Gemma | Media | Alto | Comprimir videos a WebM de baja resolución. Usar animaciones vectoriales (SVG) en lugar de video. Modelo Gemma quantizado | SR-C04, RP-06 |
| **RT-05** | Firebase no disponible en zonas sin internet (obvio), pero el estudiante necesita feedback inmediato | Baja | Medio | Ya mitigado por diseño offline-first. Firebase solo para sync diferida | SR-C01, SR-C02 |
| **RT-06** | Cifrado AES-256 en dispositivo de bajo costo impacta rendimiento | Baja | Medio | Usar Android Keystore (hardware-backed en dispositivos modernos). Fallback a software en dispositivos antiguos | RQ-01, RQ-02 |

### C.3 Rationale y Supuestos de Diseño

| ID-SUP | Supuesto | Justificación | Verificación |
|---|---|---|---|
| **SUP-01** | Gemma 2B quantizado a INT4 cabe en ≤25MB y corre en 2GB RAM | Modelos quantizados de 2B params típicamente ocupan ~1-2GB en FP16, ~500MB en INT8, ~250MB en INT4. Gemma tiene versiones optimizadas para edge | Verificar con benchmark en dispositivo de referencia |
| **SUP-02** | Un estudiante de 3ro de secundaria puede completar el diagnóstico en 20-25 minutos sin fatiga | Estudios de atención en adolescentes sugieren que 25 min es el límite para tareas cognitivas sostenidas | Validar en prueba de usabilidad con estudiantes reales |
| **SUP-03** | 20 lecciones base (10 mate + 10 lectura) son suficientes para demostrar el concepto en la hackathon | El jurado evalúa la propuesta, no el contenido completo. 20 lecciones demuestran la mecánica | Aceptar como alcance del prototipo |
| **SUP-04** | Firebase + Cloud Run son suficientes para el backend del prototipo | Servicios serverless de Google escalan automáticamente y son gratuitos en tier bajo | Verificar límites de free tier |
| **SUP-05** | Los docentes pueden usar el panel sin capacitación previa si la UX es intuitiva | Panel diseñado con ≤3 secciones principales y lenguaje no técnico | Validar en prueba de usabilidad (RQ-04) |

---

## Actividad D: Analizar Integridad y Verificar

### D.1 Medidas de Rendimiento (MOPs) — Derivadas de MOE de 6.4.2

| ID-MOP | Medida | Definición | Meta | MOE Origen |
|---|---|---|---|---|
| **MOP-01** | Tasa de superación de nivel | % de estudiantes que mejoran ≥1 nivel en diagnóstico tras 3 meses de uso regular | ≥60% | MOE-01 |
| **MOP-02** | Meses de aprendizaje ganados | (nivel_final − nivel_inicial) × factor_de_conversión | ≥6 meses en 1 año | MOE-02 |
| **MOP-03** | Retención mensual | % de estudiantes activos (≥1 sesión/semana) al mes 3 | ≥70% | MOP-01 (6.4.2) |
| **MOP-04** | Precisión del diagnóstico | Correlación de Pearson entre diagnóstico app y ENLA presencial | ≥0.7 | CA-01 |
| **MOP-05** | Satisfacción docente | % de docentes que reportan "ahorro de tiempo" y "no me sentía evaluado" | ≥80% | CA-02 |
| **MOP-06** | Tasa de uso offline | % de sesiones completadas sin conexión a internet | ≥70% | Nueva (contexto) |

### D.2 Medidas Técnicas de Desempeño (TPMs)

| ID-TPM | Medida | Definición | Meta | Requisito Asociado |
|---|---|---|---|---|
| **TPM-01** | Tamaño de APK | Tamaño del archivo APK instalado | ≤50MB | SR-C04, RP-06 |
| **TPM-02** | Tiempo de carga de lección | Tiempo desde tap hasta lección completamente renderizada | ≤5 segundos | RP-02 |
| **TPM-03** | Latencia de retroalimentación | Tiempo desde respuesta del estudiante hasta feedback de IA | ≤1 segundo | RP-03 |
| **TPM-04** | Consumo de RAM | Memoria RAM utilizada durante uso continuo | ≤500MB | RP-07 |
| **TPM-05** | Tasa de éxito de sincronización | % de sincronizaciones completadas sin pérdida ni duplicación | ≥99% | SR-C03, RP-09 |
| **TPM-06** | Tiempo de generación de actividad | Tiempo desde solicitud hasta PDF listo | ≤2 minutos | SR-D04, RP-04 |
| **TPM-07** | Precisión de detección de patrones | % de patrones de error correctamente identificados por Gemma | ≥80% tras 10 lecciones | SR-B02 |
| **TPM-08** | Estabilidad (crash-free rate) | % de sesiones sin crash en 1 hora de uso | ≥99.9% | RP-08 |

### D.3 Criterios de Verificación por Requisito

| ID-SR | Método de Verificación | Procedimiento |
|---|---|---|
| **SR-A01 a SR-A06** | **Prueba** | Ejecutar diagnóstico con 30 estudiantes reales. Medir tiempo, precisión vs ENLA, conversión a etiquetas positivas |
| **SR-B01** | **Inspección** | Verificar estructura JSON de cada lección. Contar elementos requeridos |
| **SR-B02, SR-B07** | **Prueba + Demostración** | Ejecutar Gemma on-device en dispositivo de 2GB RAM. Verificar que genera explicaciones y detecta patrones sin conexión |
| **SR-B03** | **Inspección** | Verificar esquema de tabla SQLite. Confirmar campos requeridos |
| **SR-B04** | **Prueba** | Intentar imponer límite de tiempo. Verificar que no existe pantalla de "tiempo agotado" |
| **SR-B05, SR-B06** | **Inspección** | Contar textos en biblioteca. Verificar géneros y niveles |
| **SR-C01** | **Prueba + Análisis** | Verificar cifrado AES-256 en SQLite. Confirmar Android Keystore |
| **SR-C02, SR-C03** | **Prueba** | Simular 30 días offline → conectar → verificar sync completa sin duplicación |
| **SR-C04** | **Inspección** | Medir tamaño de APK con `ls -la` |
| **SR-C05, SR-C06** | **Prueba** | Interrumpir conexión a mitad de sync → verificar reanudación |
| **SR-D01, SR-D02** | **Demostración** | Navegar panel docente. Verificar que no hay datos individuales por nombre |
| **SR-D03, SR-D04** | **Prueba** | Solicitar actividad → cronometrar → verificar PDF generado |
| **SR-D05** | **Demostración** | Acceder panel desde app Android y desde PWA |
| **SR-D06** | **Inspección** | Revisar código y UX: confirmar ausencia de rankings |
| **SR-E01 a SR-E05** | **Prueba + Análisis** | Solicitar reportes a 4 niveles. Verificar anonimización. Intentar extraer datos individuales (debe fallar con 403) |
| **RP-01 a RP-10** | **Prueba** | Medir cada métrica con herramientas de profiling |
| **RQ-01 a RQ-08** | **Prueba + Análisis** | Auditoría de seguridad, pruebas de usabilidad, test de aislamiento |

### D.4 Evaluación de Calidad de los Requisitos

#### Trazabilidad
Cada SR tiene trazabilidad ascendente (→ StRS de 6.4.2) y descendente (→ verificación en D.3). La matriz completa está en la sección E.2.

#### Consistencia
- No hay contradicciones entre SRs. Los conflictos C-01 a C-03 de 6.4.2 están resueltos en SR-D02, SR-D06, SR-C01.
- SR-B07 (Gemma on-device) es consistente con NR-01 (Gemma obligatorio) y NR-02 (offline-first).
- SR-C04 (APK ≤50MB) es consistente con NR-03.

#### Verificabilidad
Cada SR tiene un método de verificación asignado en D.3 (Prueba, Inspección, Demostración, Análisis). Los criterios son cuantitativos.

#### Viabilidad
- **SR-B02, SR-B07 (Gemma on-device en 2GB RAM):** Riesgo RT-01 y RT-02. Mitigación: Gemma quantizado INT4. Si no funciona, fallback heurístico para prototipo.
- **SR-C04 (APK ≤50MB):** Riesgo RT-04. Mitigación: compresión agresiva, animaciones vectoriales.
- Resto de requisitos: viables con tecnologías actuales.

---

## Actividad E: Gestionar los Requisitos del Sistema

### E.1 Trazabilidad Bidireccional Completa

| Necesidad (6.4.2) | StRS (6.4.2) | SyRS (este documento) | Verificación |
|---|---|---|---|
| N-01 (explicación comprensible) | RF-04, RF-05 | SR-B01, SR-B02, SR-B03 | Prueba + Demostración |
| N-02 (contenido interesante) | RF-02, RF-07 | SR-B05, SR-B06 | Inspección |
| N-03 (diagnóstico sin estigma) | RF-01, RF-02, RF-03, RF-06 | SR-A01 a SR-A06, SR-B04 | Prueba |
| N-04 (offline) | RF-08, RF-09, RF-10 | SR-C01 a SR-C06, RQ-05 | Prueba + Análisis |
| N-05 (preparación universitaria) | — (Could, fuera de alcance) | — | — |
| N-06, N-07 (familias) | — (implícitas en N-01, N-03) | SR-A04, SR-B04 | Prueba |
| N-08 (material listo) | RF-11, RF-12 | SR-D01, SR-D03, SR-D04 | Prueba + Demostración |
| N-09 (asistencia al docente) | RF-09, RF-12 | SR-D03, SR-D04 | Prueba |
| N-10 (corrección automática) | RF-05 | SR-B02, SR-B03 | Prueba |
| N-11 (capacitación TIC) | — (Could, fuera de alcance) | — | — |
| N-12 (autodiagnóstico docente) | — (Won't, requiere acuerdo gremial) | — | — |
| N-13 (garantía no reemplazo) | RF-13, RNF-05 | SR-D02, SR-D06, RES-02 | Inspección |
| N-14 (no sanción docente) | RF-13, RNF-05 | SR-D02, SR-D06, RES-02 | Inspección |
| N-15 (datos por estudiante) | RF-01, RF-02, RF-14, RF-15 | SR-A01, SR-B03, SR-C01, SR-C03, SR-E01 a SR-E05 | Prueba + Análisis |
| N-16 (evidencia de intervenciones) | — (Could) | SR-E03, MOP-02 | Análisis |
| N-17 (resultados no dependen del docente) | — (implícita en N-15) | SR-A01, SR-B01 | Prueba |
| N-18 (nivel básico lectura/matemática) | RF-14, RF-15 | SR-E01, SR-E03, MOP-01, MOP-02 | Prueba |
| N-19 (cerrar brecha digital) | — (Won't, es Problema 1) | — | — |
| N-20 (resultados medibles) | RF-14, RF-15 | SR-E01, SR-E03, MOP-04, MOP-05 | Análisis |

### E.2 Línea Base de Requisitos del Sistema

La siguiente tabla constituye la **línea base técnica** aprobada para el prototipo de hackathon. Cualquier cambio requiere justificación y actualización de trazabilidad.

| ID | Requisito | Prioridad | Estado |
|---|---|---|---|
| SR-A01 a SR-A06 | Diagnóstico adaptativo | Must | Definido |
| SR-B01 a SR-B07 | Motor de tutoría IA | Must | Definido |
| SR-C01 a SR-C06 | Offline y sincronización | Must | Definido |
| SR-D01 a SR-D06 | Panel docente | Must | Definido |
| SR-E01 a SR-E05 | Dashboard MINEDU y métricas | Should | Definido |
| RP-01 a RP-10 | Rendimiento | Must | Definido |
| INT-01 a INT-08 | Interfaces | Must | Definido |
| RQ-01 a RQ-08 | Calidad | Must | Definido |
| RES-01 a RES-05 | Restricciones de diseño | Must | Definido |
| NR-01 a NR-08 | No negociables | Must | Definido |

### E.3 Mapeo con ISO/IEC 12207:2006 y 12207:2017

| Proceso 15288:2015 | Proceso 12207:2017 | Proceso 12207:2006 | Aporte |
|---|---|---|---|
| **6.4.3** System Requirements Definition | **6.4.3** System/Software Requirements Definition | **5.3.2** Análisis de requerimientos del sistema | SR-A01 a SR-E05 como especificación técnica |
| **6.4.3** | **6.4.3** | **5.3.4** Análisis de requerimientos software | SR-B01 a SR-B07 (requisitos específicos de software) |
| **6.4.3.b** | **6.4.3.b** | **5.3.2.1** Describir funciones y capacidades | RP-01 a RP-10 (rendimiento) |
| **6.4.3.b** | **6.4.3.b** | **5.3.4.1** Especificaciones de calidad | RQ-01 a RQ-08 |
| **6.4.3.b** | **6.4.3.b** | **5.3.4.1.b** Interfaces externas | INT-01 a INT-08 |
| **6.4.3.c** | **6.4.3.c** | **5.3.2.2** Evaluar requisitos | D.4 (trazabilidad, consistencia, verificabilidad, viabilidad) |
| **6.4.3.d** | **6.4.3.d** | **5.3.4.2** Evaluar requisitos software | D.1 (MOPs), D.2 (TPMs), D.3 (verificación) |
| **6.4.3.e** | **6.4.3.e** | **5.3.4.3** Revisiones conjuntas | E.1 (trazabilidad), E.2 (baseline) |
| **24748-3** | **24748-3** | **Anexo A** Tailoring | Sección Tailoring (A.1 a A.3) |

### E.4 Base para Arquitectura (6.4.4)

Los siguientes requisitos del sistema son **entradas directas** para el proceso 6.4.4 (Architecture Definition):

| Requisito | Impacto en Arquitectura |
|---|---|
| SR-B07 (Gemma on-device) | Define componente de IA local. Requiere selección de modelo quantizado y framework de inferencia |
| SR-C01 (SQLite cifrado) | Define capa de persistencia local con cifrado |
| SR-C02, SR-C03 (Sincronización) | Define componente de sync con Firebase y Cloud Run |
| SR-D05 (Panel multi-plataforma) | Define arquitectura de UI (Flutter para Android + PWA) |
| SR-E04 (API anonimizada) | Define capa de API con control de acceso y filtros de anonimización |
| INT-01 a INT-08 | Define las 8 interfaces que la arquitectura debe implementar |
| RES-01 a RES-05 | Define restricciones que la arquitectura debe respetar |

---

## Outcomes del Proceso 6.4.3 (ISO/IEC/IEEE 15288:2015 — 6.4.3.2)

| # | Outcome | Estado | Evidencia |
|---|---|---|---|
| **a)** | Se define la descripción del sistema, incluyendo sus interfaces, funciones y límites | ✅ | Sección B.1 (límites), B.2 (contexto), B.3-B.7 (funciones), B.5 (interfaces ICD) |
| **b)** | Se definen los requisitos del sistema (funcionales, desempeño, no funcionales, interfaces) y restricciones de diseño | ✅ | SR-A01 a SR-E05 (25 funcionales), RP-01 a RP-10 (10 rendimiento), RQ-01 a RQ-08 (8 calidad), INT-01 a INT-08 (8 interfaces), RES-01 a RES-05 (5 restricciones) |
| **c)** | Se definen las medidas de rendimiento críticas | ✅ | MOP-01 a MOP-06 (6 medidas de rendimiento), TPM-01 a TPM-08 (8 medidas técnicas) |
| **d)** | Se realiza el análisis de los requisitos del sistema | ✅ | Sección C (clasificación, riesgos, rationale), Sección D (verificación, evaluación de calidad) |
| **e)** | Se encuentran disponibles los sistemas habilitadores necesarios | ✅ | Sección A.2 (Gemma, SQLite, Android SDK, Firebase, Cloud Run, AES-256, xAPI) |

---

**Documento generado según:** ISO/IEC/IEEE 15288:2015 — 6.4.3 System Requirements Definition
**Input:** 6.4.2 (StRS: RF-01 a RF-15, RNF-01 a RNF-06, ConOps, escenarios, necesidades N-01 a N-20)
**Output hacia:** 6.4.4 Architecture Definition
**Documentación 15289:** SyRS (System Requirements Specification), ICD (Interface Control Description), Verification Procedures, MOPs/TPMs, Traceability Matrix
**Alineación 12207:** 5.3.2 (Análisis de req. sistema), 5.3.4 (Análisis de req. software), 5.3.2.1-5.3.2.2, 5.3.4.1-5.3.4.3, Anexo A (Tailoring)
**Fecha:** 29 de julio de 2026
