# Yachay Gemma

Tutor de IA offline para estudiantes de educación secundaria en Perú. Usa Gemma (Google) corriendo completamente en el dispositivo: sin conexión, sin internet, sin costo de cómputo en la nube y con los datos del estudiante siempre en su propio equipo.

## Problema

Miles de estudiantes no tienen acceso estable a internet y muchos no pueden pagar servicios de tutoría. Las apps educativas actuales dependen de la nube, lo que las hace inutilizables fuera de línea y costosas de operar.

## Solución

Yachay Gemma es una app móvil (Flutter) que ejecuta un modelo de lenguaje Gemma **on-device** para actuar como tutor personalizado de los contenidos del Currículo Nacional. El modelo se descarga una sola vez y luego todo funciona sin conexión.

- IA 100% local y privada (los datos nunca salen del dispositivo).
- Aprendizaje adaptativo según el desempeño del estudiante.
- Interfaz en español, diseñada para estudiantes de secundaria.

## Arquitectura

```
lib/
├── core/                  # Infraestructura transversal
│   ├── database/          # Persistencia local (SQLCipher)
│   ├── keystore/          # Almacenamiento seguro de secretos
│   ├── models/            # Modelos de dominio
│   └── state/             # Estado global del estudiante
└── modules/               # Feature modules
    ├── aprendizaje/       # Lecciones, ejercicios y ruta de aprendizaje
    ├── diagnostico/       # Evaluación inicial de nivel
    ├── gemma/             # Motor de IA on-device (Gemma)
    └── yachay/            # Orquestador: chat, currículo, dominio, BKT
```

| Módulo | Responsabilidad |
|---|---|
| `gemma` | Inferencia local con Gemma, descarga e instalación del modelo, registro de herramientas (tools), fallback degradado |
| `yachay` | Orquesta el tutor: currículo nacional, motor de dominio (BKT), generación de preguntas |
| `aprendizaje` | Experiencia de lecciones y ejercicios gamificados |
| `diagnostico` | Prueba de nivel inicial de lectura y matemática |

## Stack

- **Flutter** (Android / iOS / Web)
- **flutter_gemma** + LiteRT LM — inferencia on-device
- **sqflite_sqlcipher** — base de datos local cifrada
- **provider** — gestión de estado

## Estado del proyecto

La arquitectura está definida y los módulos están en desarrollo. Ver la estructura de carpetas y `test/` para el avance.

## Licencia

Apache License 2.0 — ver [LICENSE](LICENSE).
