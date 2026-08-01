# Tareas — MVP 4to Primaria

> **Importante:** Cada persona trabaja en su propia rama. No modifiques archivos de otra persona.

---

## Tarea 2: Jesús — Contenido curricular base

**Rama:** `feat/content-4to` (desde `tracker/mvp-4to-primaria`)
**Archivo:** `lib/core/data/learning_data.dart` (CREAR NUEVO)

### Qué tenés que hacer

Crear un archivo Dart con la lista de temas para niños de 4to de primaria (MINEDU Perú). Cada tema tiene: id, área, título, explicación (máximo 90 palabras, lenguaje para 9-10 años), chips de respuesta rápida (3-4 opciones), y prioridad.

### Estructura

```dart
class TemaPrimaria {
  final String id;
  final String area;        // 'comunicacion', 'matematica', 'ciencia'
  final String titulo;
  final String explicacion; // ≤90 palabras
  final List<String> chips; // 3-4 opciones
  final String prioridad;   // 'alta', 'media', 'baja'

  const TemaPrimaria({...});
}

class Curricula4toPrimaria {
  static const List<TemaPrimaria> temas = [...];
  static const Map<String, String> respuestasDefault = {...};
}
```

### Plantilla de ejemplo (copiá este formato)

```dart
TemaPrimaria(
  id: 'com_01',
  area: 'comunicacion',
  titulo: 'La idea principal',
  explicacion: 'La idea principal es de qué trata un texto. Es lo más importante que el autor quiere decir. Para encontrarla, preguntate: ¿de qué habla todo el texto? No te fijes en los detalles pequeños, solo en el mensaje más grande.',
  chips: ['Quiero un ejemplo', 'Seguir practicando', 'Otro tema'],
  prioridad: 'alta',
),
```

### Áreas que necesitás cubrir

**Comunicación (6 temas, prioridad alta):**
1. La idea principal
2. La inferencia simple (leer entre líneas)
3. El afiche (partes y propósito)
4. El cuento (estructura: inicio, nudo, desenlace)
5. La noticia (qué, quién, cuándo, dónde)
6. Sinónimos y antónimos

**Matemática (6 temas, prioridad alta):**
1. Fracciones simples (1/2, 1/4, 1/3)
2. Multiplicación por una cifra
3. Patrones numéricos (secuencias)
4. División simple (repartir en partes iguales)
5. Unidades de medida (metro, litro, kilogramo)
6. Gráficos de barras (leer e interpretar)

**Ciencia y Tecnología (6 temas, prioridad media):**
1. Ecosistemas del Perú (costa, sierra, selva)
2. Animales protegidos del Perú
3. El sistema digestivo (órganos principales)
4. La cadena alimenticia (productores y consumidores)
5. Las plantas (partes y fotosíntesis simple)
6. El agua (estados y ciclo del agua)

### Validación

```bash
flutter analyze
```
No debe tirar errores.

---

## Tarea 3: Jesús — Ampliar contenido

**Rama:** `feat/content-expand` (desde `feat/content-4to`)
**Archivo:** `lib/core/data/learning_data.dart` (MODIFICAR, mismo archivo)

### Qué tenés que hacer

Agregar más temas a las 3 áreas para llegar a por lo menos 8 por área (24+ temas totales). Los nuevos temas pueden ser prioridad media o baja.

### Temas adicionales sugeridos

**Comunicación (+2):**
- El texto instructivo (recetas, manuales)
- El adjetivo calificativo

**Matemática (+2):**
- Área y perímetro de figuras simples
- Monedas y billetes peruanos (problemas de compra/venta)

**Ciencia y Tecnología (+2):**
- Los huesos y músculos (sistema locomotor)
- Los sentidos (vista, oído, tacto, gusto, olfato)

### Validación

Todas las explicaciones deben ser ≤90 palabras y usar lenguaje para 9-10 años.

```bash
flutter analyze
```

---

## Tarea 6: Freddy — Mejoras de UI

**Rama:** `feat/ui-chat` (desde `feat/content-expand`)
**Archivos:**
- `lib/modules/yachay/screens/chat_screen.dart` (MODIFICAR)
- `lib/modules/yachay/screens/yachay_scaffold.dart` (MODIFICAR)

### Qué tenés que hacer

#### A. Manejo de overflow en burbujas de chat

En `_MessageBubble`, agregar:
```dart
maxLines: 6,
overflow: TextOverflow.ellipsis,
```
Esto evita que mensajes largos desborden la pantalla en dispositivos chicos.

#### B. Chips dinámicos

Actualmente `_ContextChipRow` tiene 4 chips fijos. Cambialos para que se carguen desde `Curricula4toPrimaria.temas`. Por cada tema, mostrá sus chips como opciones rápidas.

#### C. Estado de error con botón Reintentar

Cuando `_sendMessage` falle (catch del try/catch), mostrá un widget de error:
- Mensaje: "Hubo un problema. ¿Querés intentar de nuevo?"
- Botón: "Reintentar" que vuelve a llamar `_sendMessage` con el mismo texto

#### D. Indicador de carga

Mientras `_isThinking` sea true, mostrar el `_ThinkingIndicator` actual pero con un texto más claro:
"Yachay está pensando..."

### Validación

```bash
flutter analyze
flutter test test/modules/yachay/
```
Los tests existentes de yachay deben seguir pasando.

---

## 📋 Criterios de aceptación generales

| Tarea | Cómo verificar |
|---|---|
| Datos curriculares | `flutter analyze` sin errores. Archivo `learning_data.dart` existe con ≥24 temas. |
| UI mejorada | La app no crashea. Mensajes largos no desbordan. Botón Reintentar funciona. |
| Todo | `flutter test` pasa. `flutter build apk --debug` compila. |
