import 'package:flutter_test/flutter_test.dart';

import 'package:aprendo_plus/modules/gemma/system_prompt.dart';
import 'package:aprendo_plus/core/data/learning_data.dart';

/// Block 4 of `chat-ui-assistant` — System Prompt curriculum awareness (REQ-08).
///
/// Tests that `SystemPrompt.buildYachay()` accepts an optional `currentTopic`
/// parameter and includes area/title/grade when provided, or uses a generic
/// 4to primaria persona when null. Verifies no stale "1° de secundaria" or
/// "aritmética" references remain.
void main() {
  // ── Test fixtures ───────────────────────────────────────────────────────

  const com01 = TemaPrimaria(
    id: 'com_01',
    area: 'comunicacion',
    titulo: 'La idea principal',
    explicacion: 'Un texto corto.',
    chips: ['Quiero un ejemplo', 'Seguir practicando', 'Otro tema'],
    prioridad: 'alta',
  );

  const mat01 = TemaPrimaria(
    id: 'mat_01',
    area: 'matematica',
    titulo: 'Fracciones simples',
    explicacion: 'Partes de un todo.',
    chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
    prioridad: 'alta',
  );

  // ═════════════════════════════════════════════════════════════════════════
  // REQ-08: Curriculum-aware system prompt — topic provided
  // ═════════════════════════════════════════════════════════════════════════

  group('SystemPrompt.buildYachay — curriculum-aware (REQ-08)', () {
    test(
      'GIVEN com_01 ("La idea principal", "comunicacion") '
      'WHEN buildYachay is called with currentTopic=com_01 '
      'THEN prompt includes "comunicación", "La idea principal", '
      '"4to de primaria"',
      () {
        final prompt = SystemPrompt.buildYachay([], currentTopic: com01);
        expect(prompt, contains('comunicación'));
        expect(prompt, contains('La idea principal'));
        expect(prompt, contains('4to de primaria'));
      },
    );

    test(
      'GIVEN mat_01 ("Fracciones simples", "matematica") '
      'WHEN buildYachay is called with currentTopic=mat_01 '
      'THEN prompt includes "matemática", "Fracciones simples", '
      '"4to de primaria"',
      () {
        final prompt = SystemPrompt.buildYachay([], currentTopic: mat01);
        expect(prompt, contains('matemática'));
        expect(prompt, contains('Fracciones simples'));
        expect(prompt, contains('4to de primaria'));
      },
    );

    test(
      'GIVEN no currentTopic '
      'WHEN buildYachay is called '
      'THEN prompt uses generic "4to de primaria" persona, '
      'does NOT mention "aritmética" or "1° de secundaria"',
      () {
        final prompt = SystemPrompt.buildYachay([]);
        expect(prompt, contains('4to de primaria'));
        expect(prompt, isNot(contains('aritmética')));
        expect(prompt, isNot(contains('1° de secundaria')));
      },
    );

    test(
      'GIVEN no currentTopic '
      'WHEN buildYachay is called '
      'THEN prompt includes Yachay persona and Socratic rules',
      () {
        final prompt = SystemPrompt.buildYachay([]);
        expect(prompt, contains('Yachay'));
        expect(prompt, contains('quechua'));
        expect(prompt, contains('REGLAS'));
      },
    );
  });
}
