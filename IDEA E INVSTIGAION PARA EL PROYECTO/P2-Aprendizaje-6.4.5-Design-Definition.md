# Proceso 6.4.5 — Design Definition (ISO/IEC/IEEE 15288:2015)
# Aplicado al Problema 2: Deficiencia Estructural en Logros de Aprendizaje

**Input desde 6.4.4:** Arquitectura seleccionada (Flutter monolito modular), Diagramas C4 Niveles 1-3, Componentes definidos, 6 ADRs, 8 Interfaces (IFACE-01 a IFACE-08)
**Proceso siguiente:** 6.4.7 Implementation
**Nota:** ISO 12207:2017 6.4.5 es idéntico en estructura a ISO 15288:2015. La NTP-ISO/IEC 12207:2006 cubre este proceso en 5.3.5 (Diseño de Arquitectura del Software, 7 tareas) y 5.3.6 (Diseño Detallado del Software, 8 tareas). Según 24748-3, el diseño detallado no requiere exhaustiva documentación previa a la codificación y se ejecuta concurrentemente con la implementación — esto es especialmente relevante para el contexto de hackathon de 5-7 horas.

---

## Tailoring del Proceso para Hackathon

Siguiendo el Anexo A de ISO 12207:2006 y la guía 24748-3:

| Actividad | Nivel | Justificación |
|---|---|---|
| **A: Preparar diseño** | Completo | Definir stack tecnológico real es crítico antes de codificar |
| **B: Establecer características** | Completo para componentes core; ligero para auxiliares | Diseño detallado de diagnóstico y aprendizaje; esquemas de datos; interfaces |
| **C: Evaluar alternativas** | Completo | Librerías Flutter a usar — decisión con impacto directo en 5-7h |
| **D: Gestionar diseño** | Simplificado | DDRs para decisiones clave; trazabilidad de componentes core |

---

## Actividad A: Preparar la Definición de Diseño

### A.1 Estrategia de Definición de Diseño

| Elemento | Decisión | Justificación |
|---|---|---|
| **Enfoque de diseño** | **Diseño concurrente con implementación** | 24748-3 lo permite explícitamente. En 5-7h, diseño y código se solapan. El diseño se documenta al nivel suficiente para guiar la codificación, no al nivel de especificación militar. |
| **Nivel de detalle** | **Code-to specifications** para componentes core (diagnóstico, aprendizaje, persistencia). **Wireframe-level** para componentes diferidos (panel docente, dashboard MINEDU) | El prototipo debe demostrar funcionalidad core. Los componentes diferidos solo necesitan definición de interfaz para ser implementados en fase 2. |
| **Formato de diseño** | **Markdown + diagramas Mermaid + snippets Dart** | Auto-contenido, versionable, sin dependencia de herramientas externas. |
| **Principio rector** | **Suficiente para que otro desarrollador pueda codificar sin preguntar** | 5.3.6.2 de ISO 12207:2006: "el diseño detallado de las interfaces deberá permitir la codificación sin necesidad de más información" |

### A.2 Identificación de Tecnologías Clave

#### A.2.1 Stack Tecnológico Confirmado

| Capa | Tecnología | Versión | Licencia | Peso estimado en APK | Investigación |
|---|---|---|---|---|---|
| **Framework** | Flutter (Dart) | 3.x stable | BSD-3 | ~8MB (bridge) | Seleccionado en ADR-001 (6.4.4). Hot reload crítico para hackathon. |
| **State Management** | **provider** | 6.1.5+1 | MIT | ~50KB | 11K likes en pub.dev, 1M+ downloads. Simplicidad sobre sofisticación. No requiere Riverpod/Bloc para este alcance. |
| **Persistencia** | **sqflite** | 2.4.3 | BSD-2 | ~2MB (nativo) | 5.5K likes, 2.5M downloads. Estándar de facto para SQLite en Flutter. Soporta raw SQL, transacciones, batches, migraciones. |
| **Cifrado BD** | **sqflite_sqlcipher** | 3.4.0 | MIT | ~4MB (SQLCipher nativo) | Fork de sqflite con AES-256 vía SQLCipher 4.x. API idéntica + parámetro `password`. Requiere ProGuard rule: `-keep class net.sqlcipher.** { *; }`. |
| **IA on-device** | **Gemma 4 E2B IT QAT Mobile** (`google/gemma-4-E2B-it-qat-mobile-transformers`) | GGUF Q4_0 | **Apache 2.0** | ~500MB-1GB (GGUF), ~1-1.5GB (memoria en inferencia) | 2.3B params efectivos. 128K contexto. 35 capas. QAT nativo (wNa8o8). Diseñado explícitamente para dispositivos móviles. Ver investigación completa en A.2.2. |
| **Conectividad** | **connectivity_plus** | 7.3.1 | BSD-3 | ~100KB | 4K likes, 3M downloads. API: `Connectivity().checkConnectivity()` + stream `onConnectivityChanged`. Detecta WiFi, mobile, ethernet, none. |
| **PDF** | **pdf** (dart) + **printing** | 3.13.0 | Apache 2.0 | ~2MB | 3K likes, 1.2M downloads. Soporta MultiPage, fuentes TrueType, imágenes, SVG. API estilo Flutter widgets. |
| **Backend** | **cloud_firestore** (Firebase) | Latest | Apache 2.0 | ~3MB | SDK oficial Google. Firestore NoSQL para sync logs y métricas agregadas. |
| **API Cloud** | **Cloud Run** (Python/Node.js) | N/A | N/A | No en APK | Serverless. Solo se usa para dashboard MINEDU (fase 2). |

#### A.2.2 INVESTIGACIÓN: Gemma 4 E2B QAT Mobile — Modelo real para on-device

**Modelo seleccionado:** `google/gemma-4-E2B-it-qat-mobile-transformers`
**Licencia:** Apache 2.0 (sin restricciones — uso comercial libre)
**Paper técnico:** [arxiv.org/abs/2607.02770](https://arxiv.org/abs/2607.02770)

**Especificaciones técnicas del modelo:**

| Especificación | Valor | Significado para Aprendo+ |
|---|---|---|
| **Parámetros efectivos** | 2.3B (5.1B total con embeddings) | PLE (Per-Layer Embeddings): cada capa del decoder tiene su propio embedding pequeño. Las tablas de embedding son grandes pero solo se usan para lookups rápidos → el costo computacional real es de ~2.3B params. |
| **Capas** | 35 | Modelo profundo para razonamiento de calidad |
| **Contexto** | 128K tokens | Más que suficiente para conversaciones educativas completas |
| **Vocabulario** | 262K tokens | Soporte multilingüe nativo (español incluido en 140+ idiomas) |
| **Modalidades** | Texto + Imagen + Audio | Solo usamos texto para el prototipo. Imagen y audio disponibles para fase 2. |
| **Atención** | Híbrida: sliding window (512 tokens) + global attention | La última capa siempre es global → conciencia profunda en contexto largo sin alto costo de memoria |
| **Optimización** | QAT (Quantization-Aware Training) wNa8o8 | Entrenado CON cuantización, no cuantizado después. Esquema custom para mobile: capas de decoding a 2 bits, KV cache optimizado, activaciones estáticas. |
| **Thinking mode** | Configurable (`<think>` token) | Razonamiento paso a paso para explicaciones educativas de calidad |
| **System prompt** | Nativo (rol `system`) | Permite dar instrucciones fijas: "Eres un tutor de matemáticas para secundaria en Perú" |

**🎯 Por qué Gemma 4 E2B vs otras opciones:**

| Comparación | Gemma 2 2B IT (viejo) | Gemma 4 E2B QAT Mobile (nuevo) |
|---|---|---|
| Licencia | Gemma (requiere aceptar términos) | **Apache 2.0** — libre |
| Parámetros | 2.6B | 2.3B efectivos |
| Optimización mobile | No (post-training quantization) | **Sí** (QAT nativo, wNa8o8 schema) |
| Decoding layers | Todas a la misma precisión | Capas de decoding a **2 bits** (mayor ahorro VRAM) |
| KV cache | Estándar | **Optimizado** para mobile |
| Contexto | 8K | **128K** |
| Modalidades | Solo texto | **Texto + Imagen + Audio** |
| Thinking mode | No | **Sí** (razonamiento paso a paso) |
| System prompt | No nativo | **Sí** nativo |
| Peso en disco (GGUF Q4_0) | ~1.3GB | ~500MB-1GB (estimado, verificar) |

**📦 Formatos disponibles del modelo:**

| Formato | Uso | Tamaño estimado |
|---|---|---|
| **Unquantized QAT (Q4_0)** | Investigación, compilación custom | ~2.5GB BF16 |
| **GGUF (Q4_0)** | llama.cpp, Ollama, amplia compatibilidad | ~1-1.5GB |
| **Mobile-optimized (wNa8o8)** ⭐ | **NUESTRO CASO** — eficiencia mobile pura | ~500MB-1GB |
| **Compressed Tensors (w4a16)** | vLLM, servidores | ~1.5GB |

**Arquitectura de integración (actualizada):**

```
┌──────────────────────────────────────────────────────┐
│           ARQUITECTURA DE INFERENCIA                 │
│           Gemma 4 E2B QAT Mobile                     │
│                                                      │
│  ┌──────────────────────┐                            │
│  │ Dart/Flutter (UI)    │                            │
│  │  gemma_service.dart  │  ← Interfaz en Dart        │
│  │  • generate(prompt)  │                            │
│  │  • explain(topic)    │                            │
│  │  • detectErrors()    │                            │
│  └──────────┬───────────┘                            │
│             │ MethodChannel('gemma_engine')          │
│             ▼                                        │
│  ┌──────────────────────┐                            │
│  │ Android Native (Kotlin)                           │
│  │  GemmaEngine.kt      │                            │
│  │  • Carga GGUF Q4_0                               │
│  │  • Tokenización (262K vocab)                      │
│  │  • Inferencia CPU-only                            │
│  └──────────┬───────────┘                            │
│             │                                         │
│             ▼                                         │
│  ┌──────────────────────────────────────────┐        │
│  │ Gemma 4 E2B IT QAT Mobile                │        │
│  │ • 2.3B params efectivos                  │        │
│  │ • 35 capas, 128K contexto                │        │
│  │ • 2-bit decoding layers                  │        │
│  │ • KV cache optimizado                    │        │
│  │ • Formato GGUF Q4_0 o wNa8o8             │        │
│  │ • Licencia Apache 2.0                    │        │
│  └──────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────┘
```

**Plan de verificación pre-hackathon (obligatorio antes del 1 agosto):**

| # | Verificación | Método | Estado |
|---|---|---|---|
| 1 | Obtener Gemma 4 E2B IT QAT Mobile | Descargar de Hugging Face: `google/gemma-4-E2B-it-qat-mobile-transformers` (GGUF Q4_0) | ❌ Pendiente |
| 2 | Verificar peso real del modelo GGUF Q4_0 | `ls -la gemma-4-e2b-it-q4_0.gguf` | ❌ Pendiente |
| 3 | Probar inferencia en CPU (laptop) | `llama.cpp` o `ollama run gemma-4-e2b-it-qat-mobile` con prompt de tutoría | ❌ Pendiente |
| 4 | Medir RAM usada durante inferencia | `htop` / Monitor de sistema durante generación | ❌ Pendiente |
| 5 | Evaluar calidad de respuestas educativas | 5 prompts de tutoría de matemáticas. Evaluar: ¿entiende el tema? ¿explica con claridad? ¿usa lenguaje adecuado para adolescentes? | ❌ Pendiente |
| 6 | Crear proyecto Android mínimo con el modelo | Probar carga del modelo GGUF en Android usando `llama.cpp` para Android o `mediapipe` | ❌ Pendiente |
| 7 | Medir latencia en dispositivo 2GB RAM | Benchmark: prompt "Explica fracciones equivalentes con un ejemplo sencillo", medir tiempo hasta primer token y tokens/segundo | ❌ Pendiente |

**⚠️ RIESGO MODERADO:** Gemma 4 es nuevo (paper julio 2026). La integración Android puede tener rough edges. El rendimiento en 2GB RAM con modelo GGUF Q4_0 (~1GB) es tight pero viable con el esquema wNa8o8 optimizado para mobile. Si la latencia es inaceptable (>30s para respuesta), usar Gemini API para la demo y documentar que la arquitectura on-device es para fase 2.

### A.3 Restricciones de Diseño

| ID | Restricción | Origen | Impacto en Diseño |
|---|---|---|---|
| **RES-D01** | Offline-first: 100% funcionalidad core sin internet | NR-02 | Toda inferencia IA es local. Sin llamadas API. Sync es diferido. |
| **RES-D02** | Dispositivos Android 6+, 2GB RAM, quad-core 1.2GHz | RNF-04 | Carga lazy de componentes. Gemma 4 con QAT mobile (wNa8o8, GGUF Q4_0) para minimizar RAM. Animaciones mínimas. |
| **RES-D03** | Gemma 4 E2B obligatorio | NR-01 | Define componente MethodChannel + carga de modelo GGUF Q4_0 en assets. Inferencia CPU-only. |
| **RES-D04** | APK funcional, peso optimizado no bloqueante | P-08 (6.2.1) | Comprimir assets. Usar WebP para imágenes. Modelo Gemma quantizado. |
| **RES-D05** | Sin ranking ni evaluación docente | RES-02 (6.4.3) | Panel docente: no almacenar identificadores de docente. Datos agregados por grupo. |
| **RES-D06** | 5-7 horas de desarrollo | DG-01 (6.2.1) | Diseño enfocado en componentes core. Componentes diferidos solo con interfaz definida. |
| **RES-D07** | Stack permitido: Python, JS, Flutter, Firebase | NR-07, NR-08 | Cloud Run (Python o Node.js). Flutter (Dart) para app. |

---

## Actividad B: Establecer Características de Diseño

### B.1 Diseño Detallado del Componente: Módulo Diagnóstico Adaptativo

**Componente arquitectónico:** Módulo Diagnóstico Adaptativo (6.4.4, C.2.3)
**Requisitos que implementa:** SR-A01 a SR-A06
**Tipo:** Lógica de negocio — opera completamente offline

#### B.1.1 Especificación del Algoritmo IRT Simplificado

```
ALGORITMO: Diagnóstico Adaptativo (IRT simplificado)

ENTRADA:
  - banco_items: List<ItemDiagnostico> (≥30 lectura, ≥30 matemática)
  - max_items: int = 25
  - theta_inicial: double = 0.0
  - step_theta: double = 0.5

SALIDA:
  - nivel_estimado: int (1-5, mapeado a etiqueta "Explorador"..."Experto")
  - precision: double (error estándar)
  - items_administrados: int

PSEUDOCÓDIGO:
  theta = theta_inicial
  items_administrados = 0
  respuestas = []

  MIENTRAS items_administrados < max_items Y error_estandar > 0.3:
    // Seleccionar ítem cuya dificultad esté más cerca de theta
    item = seleccionar_item_proximo(banco_items, theta, items_ya_usados)
    
    // Administrar ítem (mostrar en UI)
    respuesta = administrar_item(item)  // correcta (1) o incorrecta (0)
    
    // Actualizar theta (fórmula simplificada de máxima verosimilitud)
    theta = theta + step_theta * (respuesta - probabilidad_esperada(theta, item.dificultad))
    
    // Actualizar error estándar
    error_estandar = calcular_error_estandar(theta, respuestas)
    
    respuestas.append(respuesta)
    items_administrados++

  nivel_estimado = mapear_theta_a_nivel(theta)  // 1-5

FUNCIÓN mapear_theta_a_nivel(theta):
  SI theta <= -2.0: retornar 1  // "Explorador" (≈1ro-2do primaria)
  SI theta <= -1.0: retornar 2  // "Aprendiz" (≈3ro-4to primaria)
  SI theta <=  0.0: retornar 3  // "Practicante" (≈5to-6to primaria)
  SI theta <= +1.0: retornar 4  // "Aventurero" (≈1ro-2do secundaria)
  SINO:            retornar 5  // "Experto" (≈3ro+ secundaria)
```

#### B.1.2 Estructura de Datos del Banco de Ítems

```dart
// Ubicación: assets/diagnostic/items_matematica.json, items_lectura.json
// Formato: precargado en APK como assets

class ItemDiagnostico {
  final String id;              // "MATH-001", "READ-042"
  final String materia;         // "matematica" | "lectura"
  final String area;            // "aritmetica", "algebra", "geometria" | "comprension", "inferencia", "vocabulario"
  final String enunciado;       // Texto del ítem (≤200 caracteres)
  final List<String> opciones;  // 4 opciones (A, B, C, D)
  final int respuestaCorrecta;  // índice 0-3
  final double dificultad;      // parámetro b de IRT, rango [-3.0, +3.0]
  final double discriminacion;  // parámetro a de IRT, rango [0.5, 2.5]
  final int gradoEquivalente;   // 1-11 (1ro primaria a 5to secundaria)
}

// Esquema JSON:
{
  "id": "MATH-023",
  "materia": "matematica",
  "area": "fracciones",
  "enunciado": "¿Cuál de las siguientes fracciones es equivalente a 3/4?",
  "opciones": ["6/8", "2/3", "5/6", "1/2"],
  "respuestaCorrecta": 0,
  "dificultad": 0.2,
  "discriminacion": 1.1,
  "gradoEquivalente": 6
}
```

#### B.1.3 Clases Dart

```dart
// lib/modules/diagnostico/diagnostico_service.dart

class DiagnosticoService {
  final List<ItemDiagnostico> bancoMatematica;
  final List<ItemDiagnostico> bancoLectura;
  
  DiagnosticoService._(this.bancoMatematica, this.bancoLectura);
  
  static Future<DiagnosticoService> cargar() async {
    // Cargar archivos JSON desde assets
    final mathJson = await rootBundle.loadString('assets/diagnostic/items_matematica.json');
    final readJson = await rootBundle.loadString('assets/diagnostic/items_lectura.json');
    // Parsear y retornar instancia
  }
  
  DiagnosticoResult ejecutarDiagnostico({
    required String materia,  // "matematica" | "lectura"
    required void Function(ItemDiagnostico item, int progreso) onItem,
    int maxItems = 25,
  }) {
    final banco = materia == 'matematica' ? bancoMatematica : bancoLectura;
    double theta = 0.0;
    int itemsAdmin = 0;
    List<RespuestaItem> respuestas = [];
    
    while (itemsAdmin < maxItems && calcularErrorEstandar(respuestas) > 0.3) {
      // Seleccionar ítem por proximidad a theta
      final item = _seleccionarItem(bancos, theta, respuestas);
      
      // Callback a UI para mostrar ítem y obtener respuesta
      final respuesta = onItem(item, itemsAdmin);
      
      theta += 0.5 * (respuesta.esCorrecta ? 1 : 0 - 
                       _probabilidadEsperada(theta, item.dificultad));
      
      respuestas.add(RespuestaItem(item.id, respuesta.esCorrecta));
      itemsAdmin++;
    }
    
    final nivel = _mapearThetaANivel(theta);
    return DiagnosticoResult(
      nivel: nivel,
      etiqueta: _etiquetaNivel(nivel),
      theta: theta,
      itemsAdministrados: itemsAdmin,
      precision: calcularErrorEstandar(respuestas),
    );
  }
  
  // ... métodos privados
  
  static String _etiquetaNivel(int nivel) {
    return ['Explorador', 'Aprendiz', 'Practicante', 'Aventurero', 'Experto'][nivel - 1];
  }
}
```

#### B.1.4 Criterios de Diseño Específicos

| Criterio | Especificación | Verificación |
|---|---|---|
| **Precisión** | Error estándar ≤0.3 en ≤25 ítems | Test unitario con respuestas simuladas: verificar convergencia |
| **Rendimiento** | Selección de ítem + cálculo de theta ≤50ms | Medir con `Stopwatch` |
| **Robustez** | Banco vacío → error controlado, no crash | Test unitario: banco vacío |
| **Persistencia** | Resultado guardado en `student_profile` de SQLite | Verificar INSERT post-diagnóstico |

### B.2 Diseño Detallado del Componente: Módulo Aprendizaje + Motor Gemma

**Componente arquitectónico:** Módulo Aprendizaje + Motor Gemma (6.4.4, C.2.3)
**Requisitos que implementa:** SR-B01 a SR-B07
**Tipo:** Lógica de negocio + IA on-device

#### B.2.1 Estructura de Datos de Lecciones

```dart
// Ubicación: assets/lessons/lesson_M001.json (precargado en APK)
// Cantidad: 3 lecciones matemática + 2 lecciones lectura para prototipo

class Leccion {
  final String id;              // "M001", "L001"
  final String materia;         // "matematica" | "lectura"
  final String titulo;          // "Fracciones: concepto visual"
  final int nivelDificultad;    // 1-5
  final List<int> prerequisitos; // IDs de lecciones previas necesarias
  final String videoPath;       // "assets/videos/M001_explicacion.mp4" (≤3 min)
  final ExplicacionJson explicacion;
  final List<Ejercicio> ejercicios;
}

class ExplicacionJson {
  final String resumen;         // ≤500 caracteres
  final List<String> pasos;     // 3-7 pasos con texto e imágenes
  final String ejemploResuelto;
  final String imagenPath;      // "assets/images/M001_portada.webp"
}

class Ejercicio {
  final String id;
  final String tipo;            // "opcion_multiple" | "respuesta_corta" | "verdadero_falso"
  final String enunciado;       // ≤300 caracteres
  final List<String> opciones;  // null si es respuesta_corta
  final String respuestaCorrecta;
  final List<String> erroresComunes;  // "confunde denominador con numerador", etc.
  final Map<String, String> feedbackPorError;  // error → mensaje de ayuda
  final int tiempoEstimadoSeg; // 30-120
}
```

#### B.2.2 Integración con Gemma on-device (Platform Channel)

```dart
// lib/modules/gemma/gemma_service.dart

class GemmaService {
  static const _channel = MethodChannel('gemma_engine');
  bool _modeloCargado = false;
  
  /// Carga el modelo Gemma quantizado desde assets.
  /// Debe llamarse UNA vez al iniciar la app (modo diagnóstico/aprendizaje).
  Future<bool> cargarModelo() async {
    try {
      final result = await _channel.invokeMethod('loadModel', {
        'modelPath': 'assets/models/gemma-4-e2b-it-q4_0.gguf',
      });
      _modeloCargado = result == true;
      return _modeloCargado;
    } on PlatformException catch (e) {
      print('Error cargando Gemma: ${e.message}');
      _modeloCargado = false;
      return false;
    }
  }
  
  /// Genera una explicación alternativa cuando el estudiante no comprende la primera.
  Future<String> generarExplicacion({
    required String tema,
    required String explicacionOriginal,
    required String errorDelEstudiante,
    required int nivel,
  }) async {
    if (!_modeloCargado) return _fallbackExplicacion(tema);
    
    final prompt = '''
Eres un tutor de matemáticas para un estudiante de secundaria en Perú (nivel $nivel).
El estudiante cometió este error: "$errorDelEstudiante"
La explicación original que no entendió fue: "$explicacionOriginal"
Tema: "$tema"

Genera una nueva explicación ALTERNATIVA, más simple, usando un ejemplo concreto de la vida cotidiana peruana.
Máximo 150 palabras. NO uses fórmulas. Usa lenguaje coloquial peruano juvenil.
''';
    
    try {
      final result = await _channel.invokeMethod('generate', {
        'prompt': prompt,
        'maxTokens': 300,
        'temperature': 0.7,
      });
      return result as String;
    } catch (e) {
      return _fallbackExplicacion(tema);
    }
  }
  
  /// Detecta patrones de error y genera ejercicios de refuerzo.
  Future<List<EjercicioRefuerzo>> generarEjerciciosRefuerzo({
    required String tema,
    required String patronError,
    required int nivel,
    }) async {
    if (!_modeloCargado) return _fallbackEjercicios(tema);
    
    final prompt = '''
Eres un generador de ejercicios de matemáticas para secundaria en Perú.
Tema: "$tema"
Patrón de error detectado: "$patronError"
Nivel del estudiante: $nivel

Genera exactamente 5 ejercicios en formato JSON que refuercen este tema específico.
Cada ejercicio debe:
- Enunciado claro (≤300 caracteres)
- 4 opciones (A, B, C, D)
- 1 respuesta correcta
- 1 explicación breve de por qué es correcta

Formato JSON estricto: [{"enunciado": "...", "opciones": ["A","B","C","D"], "correcta": 0, "explicacion": "..."}]
''';
    
    try {
      final result = await _channel.invokeMethod('generate', {
        'prompt': prompt,
        'maxTokens': 1000,
        'temperature': 0.8,
      });
      return _parsearEjercicios(result as String);
    } catch (e) {
      return _fallbackEjercicios(tema);
    }
  }
  
  /// FALLBACK: Respuestas predefinidas si Gemma no está disponible.
  String _fallbackExplicacion(String tema) {
    return 'Vamos a ver "$tema" de otra forma. Imagina que tienes... '
           '(explicación genérica predefinida para el tema). '
           'Puedes preguntarle a tu profesor en clase para más ayuda.';
  }
  
  List<EjercicioRefuerzo> _fallbackEjercicios(String tema) {
    return [/* ejercicios precargados para los 5 temas core */];
  }
  
  void liberarModelo() {
    _channel.invokeMethod('unloadModel');
    _modeloCargado = false;
  }
}
```

```
// android/app/src/main/kotlin/.../GemmaEngine.kt
// Implementación nativa del MethodChannel
// Carga Gemma 4 E2B IT QAT Mobile (GGUF Q4_0)

class GemmaEngine : MethodChannel.MethodCallHandler {
    private var modelLoaded = false
    private var llamaContext: Long = 0  // llama.cpp context
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val modelPath = call.argument<String>("modelPath")!!
                try {
                    // Usar llama.cpp para Android o MediaPipe LLM Inference
                    // con soporte para GGUF Q4_0
                    llamaContext = LlamaAndroid.loadModel(
                        context.assets, modelPath,
                        nCtx = 2048,      // contexto de inferencia
                        nThreads = 2       // 2 hilos para CPU dual/quad-core
                    )
                    modelLoaded = true
                    result.success(true)
                } catch (e: Exception) {
                    modelLoaded = false
                    result.success(false)
                }
            }
            "generate" -> {
                if (!modelLoaded) {
                    result.error("MODEL_NOT_LOADED", "Gemma 4 no está cargado", null)
                    return
                }
                val prompt = call.argument<String>("prompt")!!
                val maxTokens = call.argument<Int>("maxTokens") ?: 300
                val temperature = call.argument<Double>("temperature") ?: 0.7
                
                val response = LlamaAndroid.generate(
                    llamaContext, prompt, maxTokens, temperature
                )
                result.success(response)
            }
            "unloadModel" -> {
                LlamaAndroid.free(llamaContext)
                modelLoaded = false
                result.success(null)
            }
        }
    }
}
```

#### B.2.3 Estructura de la Lección en UI

```
┌─────────────────────────────────────────┐
│  ◄ Volver    Fracciones    ⬤ 1/5        │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐    │
│  │                                 │    │
│  │     VIDEO / ANIMACIÓN ≤3 min    │    │
│  │     (formato MP4 comprimido)    │    │
│  │                                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  📝 Explicación paso a paso:           │
│  ┌─────────────────────────────────┐    │
│  │ Paso 1: Una fracción es...      │    │
│  │ Paso 2: El numerador es...      │    │
│  │ ...                             │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ✏️ EJERCICIO 1 de 8                   │
│  ┌─────────────────────────────────┐    │
│  │ ¿Cuál es equivalente a 3/4?     │    │
│  │                                 │    │
│  │ ○ 6/8    ○ 2/3                  │    │
│  │ ○ 5/6    ○ 1/2                  │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [¿No entiendes? Pide ayuda a Gemma]    │
│  [💡 Explicar de otra forma]            │
│                                         │
│  Progreso: ████████░░ 80%              │
└─────────────────────────────────────────┘
```

**Interacción con Gemma desde la lección:**

1. Estudiante falla ejercicio → se registra `error_type`
2. Después de 3 errores del mismo tipo → `GemmaService.detectarErrores()` analiza patrón
3. Si detecta patrón → `GemmaService.generarEjerciciosRefuerzo()` produce 5 ejercicios extra
4. Si estudiante pide "Explicar de otra forma" → `GemmaService.generarExplicacion()` genera alternativa
5. Si Gemma no está disponible → fallback precargado

### B.3 Diseño Detallado del Componente: Módulo Persistencia

**Componente arquitectónico:** Módulo Persistencia (6.4.4, C.2.3)
**Requisitos que implementa:** SR-C01, SR-C04, RNF-05, RQ-01
**Tipo:** Infraestructura de datos — completamente offline

#### B.3.1 Esquema de Base de Datos SQLite (Cifrado)

```sql
-- Archivo: aprendo_plus.db (ubicación: getDatabasesPath())
-- Cifrado: AES-256 via SQLCipher
-- Clave: generada aleatoriamente, almacenada en Android Keystore
-- Migración: version 1 (prototipo)

-- Tabla: Perfil del estudiante (1 registro por dispositivo)
CREATE TABLE student_profile (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    student_alias   TEXT    NOT NULL,            -- "Estudiante_001" (alias anónimo)
    diagnostic_date TEXT    NOT NULL,            -- ISO 8601
    math_level      INTEGER NOT NULL CHECK(math_level BETWEEN 1 AND 5),
    reading_level   INTEGER NOT NULL CHECK(reading_level BETWEEN 1 AND 5),
    current_math_lesson_id   TEXT,
    current_reading_lesson_id TEXT,
    total_time_min  INTEGER NOT NULL DEFAULT 0,  -- minutos totales de uso
    last_sync_ts    TEXT,                        -- ISO 8601, null si nunca sincronizó
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- Tabla: Registro de interacciones (crece con el uso)
CREATE TABLE interaction_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    lesson_id       TEXT    NOT NULL,            -- FK lógico a lesson_content.id
    exercise_id     TEXT    NOT NULL,
    response        TEXT    NOT NULL,            -- respuesta del estudiante
    is_correct      INTEGER NOT NULL CHECK(is_correct IN (0, 1)),
    error_type      TEXT,                        -- "confunde_denominador", null si correcta
    time_spent_sec  INTEGER NOT NULL,            -- segundos en este ejercicio
    gemma_used      INTEGER NOT NULL DEFAULT 0,  -- ¿se usó Gemma para ayuda?
    timestamp       TEXT    NOT NULL DEFAULT (datetime('now')),
    sync_status     TEXT    NOT NULL DEFAULT 'pending'  -- 'pending' | 'synced'
);

-- Índice para sync eficiente
CREATE INDEX idx_interaction_sync ON interaction_log(sync_status, timestamp);

-- Tabla: Contenido de lecciones (precargado, readonly en producción)
CREATE TABLE lesson_content (
    id              TEXT    PRIMARY KEY,         -- "M001", "L001"
    subject         TEXT    NOT NULL CHECK(subject IN ('matematica', 'lectura')),
    title           TEXT    NOT NULL,
    difficulty_level INTEGER NOT NULL CHECK(difficulty_level BETWEEN 1 AND 5),
    video_path      TEXT    NOT NULL,            -- ruta relativa en assets
    explanation_json TEXT   NOT NULL,            -- JSON con pasos, ejemplo, imágenes
    exercises_json  TEXT    NOT NULL,            -- JSON array de ejercicios
    version         INTEGER NOT NULL DEFAULT 1
);

-- Tabla: Ejercicios generados por Gemma (crece con el uso)
CREATE TABLE generated_exercises (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    lesson_id       TEXT    NOT NULL,
    error_type      TEXT    NOT NULL,
    prompt          TEXT    NOT NULL,            -- prompt enviado a Gemma
    exercises_json  TEXT    NOT NULL,            -- JSON array de ejercicios generados
    generated_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);
```

#### B.3.2 Implementación de Cifrado

```dart
// lib/core/database/database_service.dart

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class DatabaseService {
  static Database? _db;
  static String? _dbPassword;
  
  /// Genera clave aleatoria y la guarda en Android Keystore.
  static Future<String> _getOrCreatePassword() async {
    // Intentar recuperar clave del Keystore
    try {
      const channel = MethodChannel('keystore');
      final existingKey = await channel.invokeMethod('getKey', {'alias': 'aprendo_db'});
      if (existingKey != null) return existingKey;
    } catch (e) {
      // Keystore no disponible o primera ejecución
    }
    
    // Generar nueva clave aleatoria (32 bytes para AES-256)
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final newKey = base64.encode(bytes);
    
    // Guardar en Keystore
    try {
      const channel = MethodChannel('keystore');
      await channel.invokeMethod('storeKey', {
        'alias': 'aprendo_db',
        'key': newKey,
      });
    } catch (e) {
      // Fallback: clave derivada (menos seguro pero funcional)
    }
    
    return newKey;
  }
  
  static Future<Database> get database async {
    if (_db != null) return _db!;
    
    _dbPassword = await _getOrCreatePassword();
    
    final path = await getDatabasesPath();
    _db = await openDatabase(
      '$path/aprendo_plus.db',
      password: _dbPassword,
      version: 1,
      onCreate: _onCreate,
    );
    
    return _db!;
  }
  
  static Future<void> _onCreate(Database db, int version) async {
    // Ejecutar DDL de B.3.1
    await db.execute('CREATE TABLE student_profile (...);');
    await db.execute('CREATE TABLE interaction_log (...);');
    await db.execute('CREATE TABLE lesson_content (...);');
    await db.execute('CREATE TABLE generated_exercises (...);');
    await db.execute('CREATE INDEX idx_interaction_sync ON interaction_log(...);');
  }
  
  /// Precarga las lecciones desde assets JSON a la BD.
  static Future<void> precargarLecciones(Database db) async {
    final lessons = ['M001', 'M002', 'M003', 'L001', 'L002'];  // 5 lecciones prototipo
    for (final id in lessons) {
      final json = await rootBundle.loadString('assets/lessons/lesson_$id.json');
      final data = jsonDecode(json);
      await db.insert('lesson_content', {
        'id': id,
        'subject': data['materia'],
        'title': data['titulo'],
        'difficulty_level': data['nivelDificultad'],
        'video_path': data['videoPath'],
        'explanation_json': jsonEncode(data['explicacion']),
        'exercises_json': jsonEncode(data['ejercicios']),
      });
    }
  }
}
```

**ProGuard rules requeridas (android/app/proguard-rules.pro):**
```
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
```

### B.4 Diseño Detallado del Componente: Módulo Sincronización

**Componente arquitectónico:** Módulo Sincronización (6.4.4, C.2.3)
**Requisitos que implementa:** SR-C02, SR-C03, SR-C06
**Tipo:** Infraestructura de red — solo opera con conectividad

#### B.4.1 Flujo de Sincronización

```dart
// lib/modules/sync/sync_service.dart

class SyncService {
  final DatabaseService _db;
  final FirebaseFirestore _firestore;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  
  /// Inicia el listener de conectividad.
  void iniciar() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }
  
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    if (results.any((r) => r != ConnectivityResult.none) && !_isSyncing) {
      await sincronizar();
    }
  }
  
  Future<SyncResult> sincronizar() async {
    if (_isSyncing) return SyncResult(alreadyRunning: true);
    _isSyncing = true;
    
    try {
      final db = await _db.database;
      
      // 1. Obtener registros pendientes
      final pendientes = await db.query(
        'interaction_log',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
        orderBy: 'timestamp ASC',
        limit: 100,  // Sincronizar en lotes de 100
      );
      
      if (pendientes.isEmpty) {
        _isSyncing = false;
        return SyncResult(synced: 0);
      }
      
      // 2. Anonimizar y enviar a Firebase (SIN nombres, SIN IDs reales)
      final batch = _firestore.batch();
      final idsSynced = <int>[];
      
      for (final row in pendientes) {
        final doc = _firestore.collection('sync_log').doc();  // ID aleatorio
        batch.set(doc, {
          'anonymous_id': _anonymousId,  // hash unidireccional del alias
          'lesson_id': row['lesson_id'],
          'exercise_id': row['exercise_id'],
          'is_correct': row['is_correct'],
          'error_type': row['error_type'],
          'time_spent_sec': row['time_spent_sec'],
          'gemma_used': row['gemma_used'],
          'sync_timestamp': DateTime.now().toIso8601String(),
          // ⚠️ NO se envía: respuesta del estudiante, alias, IDs personales
        });
        idsSynced.add(row['id'] as int);
      }
      
      // 3. Commit a Firebase
      await batch.commit();
      
      // 4. Marcar como sincronizado en SQLite (TODO o nada)
      await db.transaction((txn) async {
        for (final id in idsSynced) {
          await txn.update(
            'interaction_log',
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      });
      
      return SyncResult(synced: idsSynced.length);
      
    } catch (e) {
      return SyncResult(error: e.toString());
    } finally {
      _isSyncing = false;
    }
  }
  
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
```

### B.5 Diseño de Componentes Diferidos (Wireframe-level)

Estos componentes no se implementan en la hackathon. El diseño se limita a la definición de interfaz para asegurar compatibilidad futura.

#### B.5.1 Módulo Panel Docente (fase 2)

**Interfaz definida:**
```dart
// lib/modules/docente/docente_panel.dart
// NO IMPLEMENTADO en fase 1 — solo interfaz

abstract class DocentePanelInterface {
  /// Retorna datos agregados del grupo (anonimizados).
  Future<GrupoStats> getGrupoStats(String grupoId);
  
  /// Genera PDF de actividad de aula para un tema con dificultad.
  Future<File> generarActividadPDF({
    required String tema,
    required String nivel,
    required double porcentajeDificultad,
  });
  
  /// ⚠️ EXPLÍCITAMENTE NO EXISTE:
  /// - getDocenteRanking() 
  /// - compararDocentes()
  /// - getEstudianteIndividual(String nombre)
}
```

#### B.5.2 API Dashboard MINEDU (fase 2)

**Endpoints definidos:**
```
GET  /api/reportes?nivel=escuela&id={escuela_id}     → Reporte por escuela
GET  /api/reportes?nivel=ugel&codigo={ugel_code}      → Reporte por UGEL
GET  /api/reportes?nivel=region&nombre={region_name}   → Reporte por región
GET  /api/reportes?nivel=nacional                       → Reporte nacional

Formato respuesta:
{
  "nivel": "region",
  "nombre": "Ayacucho",
  "periodo": "2026-08",
  "total_estudiantes": 1234,
  "distribucion_niveles": {
    "explorador": 30, "aprendiz": 35, "practicante": 20,
    "aventurero": 10, "experto": 5
  },
  "progreso_promedio_meses": 2.3,
  "tiempo_uso_promedio_min_semana": 45,
  "top_temas_avance": ["fracciones", "inferencias"],
  "top_temas_dificultad": ["ecuaciones", "textos_cientificos"]
}

⚠️ No se incluye: nombres de estudiantes, identificadores personales, 
   datos de docentes, comparativas entre escuelas/docentes.
```

---

## Actividad C: Evaluar Alternativas de Diseño

### C.1 Librerías Flutter: Evaluación y Selección

| Necesidad | Alternativas evaluadas | Selección | Justificación |
|---|---|---|---|
| **State Management** | provider vs riverpod vs bloc | **provider** v6.1.5+1 | Simplicidad para hackathon. Riverpod es más potente pero tiene curva de aprendizaje. Bloc es excesivo para 5 componentes. Provider tiene 11K likes, es el más usado, y cubre el 100% de necesidades del prototipo. |
| **Persistencia** | sqflite vs drift vs hive vs isar | **sqflite** v2.4.3 | SQLite es ubicuo, portable, con soporte nativo en Android. Drift añade type-safety pero requiere code generation (complejidad innecesaria en hackathon). Hive/Isar son NoSQL — no adecuados para datos relacionales como interaction_log. |
| **Cifrado BD** | sqflite_sqlcipher vs flutter_secure_storage + sqflite | **sqflite_sqlcipher** v3.4.0 | Cifrado a nivel de archivo (todo el .db). Más simple que cifrar campo por campo. API idéntica a sqflite. Requiere ProGuard rule. Mitigación: alternativa si hay problemas de compilación → flutter_secure_storage para campos sensibles + sqflite normal. |
| **IA on-device** | llama.cpp Android vs MediaPipe LLM vs platform channel nativo | **MethodChannel Flutter → `llama.cpp` Android con GGUF Q4_0** | El modelo Gemma 4 E2B se distribuye en formato GGUF Q4_0 (~500MB-1GB). `llama.cpp` tiene bindings para Android y soporte completo para GGUF. Alternativa: MediaPipe LLM Inference si Google lanza soporte para wNa8o8 en Android. Si la latencia on-device es inaceptable, fallback a Gemini API para la demo. |
| **PDF** | pdf vs syncfusion_flutter_pdf vs open_file | **pdf** (dart) v3.13.0 | Nativo Dart, sin dependencias nativas. Licencia Apache 2.0 (gratuito). API estilo Flutter widgets. Syncfusion requiere licencia comercial. |
| **Conectividad** | connectivity_plus vs connectivity vs network_info_plus | **connectivity_plus** v7.3.1 | Plugin oficial de fluttercommunity. Más mantenido (3M downloads). API simple: check + stream. Suficiente para detectar WiFi/mobile. |
| **Navegación** | go_router vs Navigator 2.0 vs auto_route | **Navigator 1.0** (básico) | Para 5 pantallas (diagnóstico, lección, práctica, panel, sync), Navigator.push() es suficiente. Go_router añade complejidad innecesaria. |
| **Formato JSON** | dart:convert vs json_serializable vs freezed | **dart:convert** (manual) | Para ≤10 modelos de datos, el parseo manual es más rápido que configurar code generation. Sin dependencias extra. |

### C.2 Evaluación de Componentes COTS vs Desarrollo Propio

| Componente | ¿COTS? | Decisión | Justificación |
|---|---|---|---|
| **SQLite** | Sí (incluido en Android) | Usar nativo vía sqflite | No tiene sentido reinventar una BD relacional |
| **Gemma** | Sí (modelo open-source Google) | Usar como COTS | Es obligatorio por bases de hackathon (NR-01) |
| **Firebase** | Sí (Google Cloud) | Usar como COTS | BaaS elimina necesidad de backend propio |
| **Algoritmo IRT** | No (no existe COTS para Android) | Desarrollar (simple, ~100 líneas) | Algoritmo de 25 ítems con fórmula simplificada. Más rápido codificar que integrar. |
| **Contenido educativo** | No | Desarrollar (3-5 lecciones en JSON) | Es el core del prototipo. Debe ser original. |
| **Generador de PDF** | Sí (pdf package) | Usar COTS | No tiene sentido escribir un generador PDF from scratch |

---

## Actividad D: Gestionar el Diseño

### D.1 Design Decision Records (DDR)

#### DDR-001: Estrategia de Integración de Gemma 4

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | NR-01 obliga a usar Gemma. El modelo seleccionado es `google/gemma-4-E2B-it-qat-mobile-transformers` (2.3B params efectivos, QAT mobile wNa8o8, licencia Apache 2.0). No existe plugin Flutter dedicado. |
| **Decisión** | Usar **MethodChannel Flutter → Android nativo** con `llama.cpp` para Android o MediaPipe LLM Inference para cargar el modelo GGUF Q4_0 (~500MB-1GB). Crear wrapper Dart (`GemmaService`) con interfaz: `cargarModelo()`, `generarExplicacion()`, `generarEjerciciosRefuerzo()`. Incluir fallback a respuestas predefinidas si el modelo no carga o la latencia es inaceptable. Si el modelo on-device no es viable en 2GB RAM, usar Gemini API para la demo de hackathon y documentar la arquitectura on-device para fase 2. |
| **Consecuencias** | (+) Gemma 4 está diseñado explícitamente para mobile (QAT nativo, 2-bit decoding, KV cache optimizado). (+) Licencia Apache 2.0 sin restricciones. (+) 128K contexto, thinking mode, system prompt nativo. (+) Rendimiento superior a Gemma 2 en benchmarks (MMLU Pro: 60% vs ~51%). (-) Modelo nuevo (julio 2026) — integración Android puede tener rough edges. (-) ~500MB-1GB en disco, ~1-1.5GB en RAM durante inferencia. (-) Código Kotlin adicional (~150 líneas). |
| **Alternativas** | Gemma 2 (descartado: no diseñado para mobile, licencia restrictiva). Gemini API (descartado para producción: requiere internet, viola NR-02. Aceptable solo como fallback para demo). |

#### DDR-002: Estrategia de Cifrado de Datos

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | RNF-05 exige AES-256 para datos de menores. SQLite nativo no cifra. |
| **Decisión** | Usar **sqflite_sqlcipher** para cifrado AES-256 a nivel de archivo. Clave generada aleatoriamente, almacenada en Android Keystore. Si hay problemas de compilación con SQLCipher, fallback: flutter_secure_storage para campos sensibles + sqflite normal para el resto. |
| **Consecuencias** | (+) Cifrado transparente — mismo API que sqflite. (+) SQLCipher es estándar industrial (usado en Signal, WhatsApp). (-) ~4MB adicionales en APK. (-) Requiere ProGuard rules. |
| **Alternativas** | Cifrado manual campo por campo (descartado: complejo, propenso a errores). flutter_secure_storage (descartado como solución única: es key-value, no soporta queries SQL). |

#### DDR-003: Arquitectura de State Management

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | La app tiene 5 pantallas, estado compartido (perfil del estudiante, progreso actual, configuración). Se requiere state management ligero. |
| **Decisión** | Usar **provider** con ChangeNotifier para estado global (perfil, progreso). Estado local de pantalla con StatefulWidget. Sin dependencias de code generation. |
| **Consecuencias** | (+) Simple, bien documentado, 11K likes. (+) Sin code generation → iteración rápida en hackathon. (+) Compatible con refactorización futura a Riverpod/Bloc si el proyecto crece. (-) Menos type-safe que Riverpod. (-) Reconstrucción manual de listeners. |
| **Alternativas** | Riverpod (descartado: curva de aprendizaje para hackathon). Bloc (descartado: excesivo para este alcance). |

#### DDR-004: Alcance del Prototipo (componentes implementados vs diferidos)

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Contexto** | 5-7 horas de desarrollo. La arquitectura define 5 módulos pero no todos pueden implementarse. |
| **Decisión** | **Implementar en fase 1:** Módulo Diagnóstico, Módulo Aprendizaje (solo 3 lecciones matemática + 2 lectura), Módulo Persistencia (SQLite + cifrado), Motor Gemma (MethodChannel, si es viable). **Diferir a fase 2:** Módulo Panel Docente (solo interfaz definida), Módulo Sincronización Firebase, API Cloud Run, Dashboard MINEDU. |
| **Consecuencias** | (+) Demo funcional con las capacidades core. (+) Tiempo suficiente para diagnóstico + lecciones + Gemma. (-) No se demuestra sync ni panel docente. (-) La demo es offline 100% (no muestra cloud). |
| **Alternativas** | Implementar todos los módulos superficialmente (descartado: demo sin profundidad en nada). |

### D.2 Trazabilidad de Diseño

| SyRS (6.4.3) | Componente (6.4.4) | Unidad de Diseño (6.4.5) | Archivo(s) |
|---|---|---|---|
| SR-A01 a A06 | Módulo Diagnóstico | `DiagnosticoService` + `ItemDiagnostico` | `lib/modules/diagnostico/` |
| SR-B01 a B06 | Módulo Aprendizaje | `Leccion` + `Ejercicio` + UI de lección | `lib/modules/aprendizaje/` |
| SR-B02, B07 | Motor Gemma | `GemmaService` (Dart) + `GemmaEngine.kt` (Android) | `lib/modules/gemma/`, `android/.../GemmaEngine.kt` |
| SR-C01, C04 | Módulo Persistencia | `DatabaseService` + esquema SQL | `lib/core/database/` |
| SR-C02, C03, C06 | Módulo Sincronización | `SyncService` (interfaz en fase 1) | `lib/modules/sync/` |
| SR-D01 a D06 | Módulo Panel Docente | `DocentePanelInterface` (solo definición) | `lib/modules/docente/` |
| SR-E01 a E05 | API Cloud Run | Endpoints documentados | `cloud_run/` (fase 2) |
| RNF-05, RQ-01 | Cifrado | `sqflite_sqlcipher` + Keystore | `lib/core/database/` |

### D.3 Baseline de Diseño para Implementación

**Componentes CORE (se implementan en hackathon):**

| Archivo | Responsabilidad | Estimación |
|---|---|---|
| `lib/main.dart` | Entry point, inicialización de Provider, carga de BD, precarga de lecciones | 30 min |
| `lib/core/database/database_service.dart` | Apertura de BD cifrada, migraciones, precarga de contenido | 45 min |
| `lib/modules/diagnostico/diagnostico_service.dart` | Algoritmo IRT, selección de ítems, cálculo de theta | 60 min |
| `lib/modules/diagnostico/diagnostico_screen.dart` | UI del diagnóstico: mostrar ítem, opciones, progreso | 45 min |
| `lib/modules/aprendizaje/leccion_screen.dart` | UI de lección: video, explicación, ejercicios | 60 min |
| `lib/modules/aprendizaje/ruta_screen.dart` | UI de ruta de aprendizaje post-diagnóstico | 30 min |
| `lib/modules/gemma/gemma_service.dart` | Wrapper Dart para MethodChannel | 30 min |
| `android/.../GemmaEngine.kt` | Implementación nativa AI Edge SDK | 60 min (si el SDK funciona) |
| `assets/` | 3 lecciones JSON + ítems diagnóstico + videos/imágenes | 90 min (creación de contenido) |
| **TOTAL estimado** | | **7.5 horas** (ajustable) |

---

## Alineación con ISO/IEC 12207

### NTP-ISO/IEC 12207:2006 — 5.3.5 Diseño de la Arquitectura del Software

| Tarea | Aplicación en Aprendo+ |
|---|---|
| **5.3.5.1** Transformar requisitos en arquitectura de componentes | B.1-B.5: cada componente tiene requisitos asignados y estructura definida |
| **5.3.5.2** Diseño de interfaces externas e internas | B.5.1 (Panel Docente), B.5.2 (Dashboard MINEDU): interfaces diferidas definidas |
| **5.3.5.3** Diseño de base de datos | B.3.1: esquema SQLite completo (4 tablas, 1 índice) |
| **5.3.5.4** Documentación de usuario preliminar | Diferido a fase 2. Solo wireframes de UI en B.2.3 |
| **5.3.5.5** Requerimientos preliminares de pruebas | D.3: cada componente tiene plan de test en 6.4.9 |
| **5.3.5.6** Evaluación: trazabilidad, consistencia, viabilidad | D.2 (trazabilidad completa SR→componente→archivo) |
| **5.3.5.7** Revisiones conjuntas (6.6) | Diferido a fase 2 (requiere stakeholders externos) |

### NTP-ISO/IEC 12207:2006 — 5.3.6 Diseño Detallado del Software

| Tarea | Aplicación en Aprendo+ |
|---|---|
| **5.3.6.1** Diseño detallado de cada componente hasta unidades compilables | B.1-B.4: cada componente con clases Dart, estructuras de datos, algoritmos |
| **5.3.6.2** Diseño detallado de interfaces que permita codificar sin más información | A.1: principio rector "suficiente para codificar sin preguntar". IFACE-01 a IFACE-08 de 6.4.4 detalladas en B.1-B.5 |
| **5.3.6.3** Diseño detallado de la base de datos | B.3.1: DDL completo con constraints, índices, tipos de datos |
| **5.3.6.4** Actualizar documentación de usuario | Wireframe de UI en B.2.3 |
| **5.3.6.5** Definir requerimientos de prueba unitaria | Cada componente en B.1-B.4 tiene criterios de verificación |
| **5.3.6.6** Actualizar plan de integración | D.3: baseline de implementación con orden de archivos |
| **5.3.6.7** Evaluar diseño: trazabilidad, consistencia, viabilidad | C.1 (librerías), C.2 (COTS vs propio), D.2 (trazabilidad) |
| **5.3.6.8** Revisiones conjuntas (6.6) | Diferido |

### ISO/IEC 24748-3 — Aplicación al Contexto Hackathon

| Directriz 24748-3 | Aplicación |
|---|---|
| **No es necesario diseño detallado de cada unidad antes de codificar** | Solo componentes core tienen diseño detallado (B.1-B.4). Componentes diferidos tienen solo interfaz (B.5). |
| **Diseño concurrente con implementación** | El diseño de este documento se usa como guía durante las 5-7h, no como especificación rígida previa. |
| **System Analysis para seleccionar algoritmos** | C.1 evalúa 8 librerías con criterios objetivos. C.2 evalúa COTS vs build. |
| **Verificación concurrente con diseño** | Cada componente en B.1-B.4 incluye criterios de verificación. |

---

## Outcomes del Proceso 6.4.5 (ISO/IEC/IEEE 15288:2015 — 6.4.5.2)

| # | Outcome | Estado | Evidencia |
|---|---|---|---|
| **a)** | Las características detalladas de diseño de cada elemento del sistema son definidas | ✅ | B.1 (Diagnóstico: algoritmo IRT + clases Dart + criterios), B.2 (Aprendizaje + Gemma: lecciones JSON + MethodChannel + UI), B.3 (Persistencia: DDL + cifrado), B.4 (Sync: algoritmo + clases) |
| **b)** | Se evalúan las tecnologías y alternativas de diseño, seleccionando la mejor opción | ✅ | C.1 (8 librerías evaluadas con justificación), C.2 (COTS vs build), DDR-001 a DDR-004 |
| **c)** | Las interfaces físicas y lógicas son completamente diseñadas | ✅ | B.1.3 (clases Dart con firmas), B.2.2 (MethodChannel API), B.5.1-B.5.2 (interfaces diferidas), A.2.2 (arquitectura de inferencia) |
| **d)** | Los sistemas habilitadores necesarios están disponibles | ✅ | A.2.1 (stack tecnológico confirmado con versiones reales), A.2.2 (plan de verificación Gemma pre-hackathon) |
| **e)** | Se establece la trazabilidad bidireccional entre diseño detallado, arquitectura y requisitos | ✅ | D.2 (matriz SyRS → Componente → Unidad → Archivo), mapeo con 12207 (5.3.5 y 5.3.6) |

---

**Documento generado según:** ISO/IEC/IEEE 15288:2015 — 6.4.5 Design Definition
**Input:** 6.4.4 (Arquitectura: ADR-001 a ADR-006, componentes, interfaces)
**Output hacia:** 6.4.7 Implementation
**Documentación 15289:** Design Definition Strategy, System Design Description (SDD), System Design Rationale (DDRs), Interface Definition, Design Traceability Matrix
**Alineación 12207:** 12207:2017 6.4.5 (idéntico), 12207:2006 5.3.5 (7 tareas) + 5.3.6 (8 tareas), 24748-3 (diseño concurrente con implementación)
**Fecha:** 29 de julio de 2026
