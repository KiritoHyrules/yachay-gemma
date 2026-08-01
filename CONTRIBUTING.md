# Cómo Contribuir — Aprendo+

## 🚀 Primeros pasos (hacelo una sola vez)

### 1. Instalar Flutter
Necesitás Flutter 3.24 o superior en tu máquina. Seguí la guía oficial:
https://docs.flutter.dev/get-started/install/windows

### 2. Clonar el proyecto
Abrí una terminal (PowerShell, CMD, o Git Bash) y ejecutá:

```bash
git clone https://github.com/KiritoHyrules/yachay-gemma.git
cd yachay-gemma
```

### 3. Verificar que todo funciona

```bash
flutter pub get
flutter analyze
```

Si `flutter` no se reconoce, asegurate de que esté en el PATH o usá la ruta completa.

---

## 🌿 Flujo de trabajo (cada vez que hagas un cambio)

### 1. Siempre empezá desde la rama correcta

```bash
git checkout tracker/mvp-4to-primaria
git pull origin tracker/mvp-4to-primaria
```

### 2. Creá tu rama de trabajo

```bash
git checkout -b feat/tu-tarea
```

Ejemplos:
- `feat/content-4to` (Jesús)
- `fix/inference-256` (Alexander)
- `feat/ui-chat` (Freddy)

### 3. Hacé tus cambios
Editá los archivos que te tocan. Ejecutá `flutter analyze` para verificar que no haya errores.

### 4. Commiteá tus cambios

```bash
git add .
git commit -m "feat: descripcion corta de lo que hiciste"
```

Usá estos prefijos para los commits:
- `feat:` — nueva funcionalidad
- `fix:` — arreglo de bug
- `refactor:` — reorganización de código
- `chore:` — configuración, build, etc.

### 5. Subí tu rama

```bash
git push -u origin feat/tu-tarea
```

### 6. Abrí un Pull Request
Andá a https://github.com/KiritoHyrules/yachay-gemma/pulls y hacé clic en "New Pull Request".

- **Base:** la rama de la que saliste (ej. `tracker/mvp-4to-primaria` o la rama del PR anterior)
- **Compare:** tu rama `feat/tu-tarea`

### 7. Esperá la revisión de Luis
Luis revisa y mergea. No mergees tus propios PRs.

---

## 📁 Estructura del proyecto

```
lib/
├── main.dart              # Punto de entrada de la app
├── core/
│   ├── data/              # Datos estáticos (currícula, aprendizaje)
│   ├── models/            # Modelos de datos
│   ├── state/             # Estado de la app (Provider)
│   └── utils/             # Utilidades (truncamiento, etc.)
└── modules/
    ├── gemma/             # Motor de IA (Gemma on-device)
    ├── yachay/            # Chat, reglas, pantallas
    ├── diagnostico/       # Diagnóstico adaptativo
    └── aprendizaje/       # Lecciones y ejercicios
```

---

## 🧪 Tests

```bash
flutter test
```

Escribí tests para cualquier lógica nueva que agregues. Los tests existentes deben seguir pasando.

---

## ⚠️ Reglas

1. **Nunca commitees directo a `main` o `tracker/mvp-4to-primaria`.** Solo mediante PR.
2. **No modifiques archivos que no te tocaron.** Cada persona tiene archivos asignados — ver `TAREAS.md`.
3. **Antes de pushear, ejecutá `flutter analyze`.** No debe haber errores.
4. **Si algo no funciona, preguntá en el grupo.** No te quedes trabado.

---

## 🆘 ¿Tuviste un problema?

1. **No puedo clonar:** Verificá que tengas acceso al repo (Luis te tiene que agregar como colaborador).
2. **Flutter no se instala:** Seguí la guía paso a paso, lleva ~20 minutos.
3. **No entiendo git:** Pedile a Luis que te muestre — es más fácil verlo en vivo que leerlo.
