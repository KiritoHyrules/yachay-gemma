import 'package:flutter_test/flutter_test.dart';
import 'package:aprendo_plus/core/utils/text_utils.dart';

void main() {
  group('truncateAtSentence', () {
    // 1. Happy path: truncate at the last complete sentence (period + space).
    test('trunca en el último ". " (punto y espacio)', () {
      const text = 'Hola. Esto es una prueba. Y esto sigue sin punto final';
      final result = truncateAtSentence(text);
      // Last ". " is between "prueba." and "Y" → truncate there.
      expect(result, 'Hola. Esto es una prueba.');
    });

    // 2. Truncate at last '.' (period only, no space).
    test('trunca en el último "." (punto sin espacio)', () {
      const text = 'Las fracciones son partes de un todo.Se representan con numerador y denominador.';
      final result = truncateAtSentence(text);
      // Should truncate at the last '.' which is after "denominador"
      expect(result, 'Las fracciones son partes de un todo.Se representan con numerador y denominador.');
    });

    // 3. No period — fall back to '!'.
    test('sin punto, trunca en "!"', () {
      const text = '¡Muy bien! ¡Seguí practicando! ¡Sos un crack!';
      final result = truncateAtSentence(text);
      expect(result, '¡Muy bien! ¡Seguí practicando! ¡Sos un crack!');
    });

    // 4. No period or exclamation — fall back to '?'.
    test('sin punto ni exclamación, trunca en "?"', () {
      const text = '¿Querés practicar? ¿O preferís otro tema? Seguimos';
      final result = truncateAtSentence(text);
      // Last '?' is after "otro tema" — no '.' in the text.
      expect(result, '¿Querés practicar? ¿O preferís otro tema?');
    });

    // 5. No punctuation at all — return full text.
    test('sin puntuación, devuelve el texto completo', () {
      const text = 'Esto es un texto sin puntuación alguna';
      final result = truncateAtSentence(text);
      expect(result, text);
    });

    // 6. Empty string.
    test('texto vacío, devuelve vacío', () {
      final result = truncateAtSentence('');
      expect(result, '');
    });

    // 7. Single sentence with period at the end.
    test('una sola oración con punto final', () {
      const text = 'Esta es una sola oración.';
      final result = truncateAtSentence(text);
      expect(result, 'Esta es una sola oración.');
    });
  });
}
