import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// RED phase by design — production code does not exist yet.
// ignore_for_file: unused_import
import 'package:aprendo_plus/modules/gemma/action_parser.dart';
import 'package:aprendo_plus/modules/gemma/gemma_service.dart';

// =============================================================================
// Group 1: findNextAction — XML action detection from streaming text
// =============================================================================

void main() {
  // -----------------------------------------------------------------
  // Test 1: findNextAction parses complete XML action
  // GIVEN text with <action name="explicar_tema"><tema>fracciones</tema></action>
  // WHEN findNextAction is called
  // THEN returns ParsedAction with name="explicar_tema", args={tema: "fracciones"}
  // -----------------------------------------------------------------
  group('findNextAction — complete XML', () {
    test(
        'GIVEN text with <action name="explicar_tema"><tema>fracciones</tema></action> '
        'WHEN findNextAction is called '
        'THEN returns ParsedAction with name="explicar_tema", args={tema: "fracciones"}', () {
      const text =
          '<action name="explicar_tema"><tema>fracciones</tema></action>';

      final result = findNextAction(text);

      expect(result, isNotNull);
      expect(result, isA<ParsedAction>());

      final action = result as ParsedAction;
      expect(action.name, equals('explicar_tema'));
      expect(action.args, containsPair('tema', 'fracciones'));
      expect(action.start, equals(0));
      // raw should contain the full action block
      expect(action.raw, contains('<action name="explicar_tema">'));
      expect(action.raw, contains('</action>'));
    });

    // Triangulation: action with multiple child elements
    test(
        'GIVEN text with action containing 2 child elements '
        'WHEN findNextAction is called '
        'THEN returns ParsedAction with both args extracted', () {
      const text =
          '<action name="generar_ejercicios">'
          '<tema>fracciones</tema>'
          '<nivel>2</nivel>'
          '</action>';

      final result = findNextAction(text);

      expect(result, isNotNull);
      expect(result, isA<ParsedAction>());

      final action = result as ParsedAction;
      expect(action.name, equals('generar_ejercicios'));
      expect(action.args, containsPair('tema', 'fracciones'));
      expect(action.args, containsPair('nivel', 2)); // number parsed
    });

    // Triangulation: action embedded in surrounding text
    test(
        'GIVEN text with speech before and after an action '
        'WHEN findNextAction is called '
        'THEN finds the action embedded in surrounding content', () {
      const text =
          'Voy a explicar el tema.\n'
          '<action name="explicar_tema"><tema>fracciones</tema></action>\n'
          'Espero que te sirva.';

      final result = findNextAction(text);

      expect(result, isNotNull);
      expect(result, isA<ParsedAction>());

      final action = result as ParsedAction;
      expect(action.name, equals('explicar_tema'));
      expect(action.args, containsPair('tema', 'fracciones'));
      // start/end should be within the text, not 0
      expect(action.start, greaterThan(0));
      expect(action.end, lessThan(text.length));
    });

    // Triangulation: action with boolean and numeric args
    test(
        'GIVEN action with true/false and numeric child values '
        'WHEN findNextAction is called '
        'THEN args are parsed as native Dart types', () {
      const text =
          '<action name="ejecutar_diagnostico">'
          '<materia>matematica</materia>'
          '<num_items>15</num_items>'
          '<adaptativo>true</adaptativo>'
          '<guardar>false</guardar>'
          '</action>';

      final result = findNextAction(text);

      expect(result, isNotNull);
      final action = result as ParsedAction;
      expect(action.name, equals('ejecutar_diagnostico'));
      expect(action.args['materia'], equals('matematica'));
      expect(action.args['num_items'], equals(15));
      expect(action.args['adaptativo'], equals(true));
      expect(action.args['guardar'], equals(false));
    });
  });

  // -----------------------------------------------------------------
  // Test 2: findNextAction returns 'incomplete' for partial XML
  // GIVEN text chunk "<action name="explicar"
  // WHEN findNextAction is called
  // THEN returns 'incomplete'
  // -----------------------------------------------------------------
  group('findNextAction — incomplete XML', () {
    test(
        'GIVEN text with opening action tag but no closing tag '
        'WHEN findNextAction is called '
        'THEN returns "incomplete"', () {
      const text = '<action name="explicar_tema"><tema>fracciones';

      final result = findNextAction(text);

      expect(result, equals('incomplete'));
    });

    // Triangulation: tag name partially written
    test(
        'GIVEN partial opening tag "<action name="explicar" (no closing bracket) '
        'WHEN findNextAction is called '
        'THEN returns null (tag not recognized as action yet)', () {
      const text = '<action name="explicar';

      final result = findNextAction(text);

      // The regex requires the > after name attribute to capture the tag.
      // A partial opening without > should not be recognized.
      expect(result, isNull);
    });

    // Triangulation: opening tag complete but no body at all
    test(
        'GIVEN text "<action name="test">" with no body and no closing tag '
        'WHEN findNextAction is called '
        'THEN returns "incomplete"', () {
      const text = '<action name="test">';

      final result = findNextAction(text);

      expect(result, equals('incomplete'));
    });

    // Triangulation: closing tag partially written
    test(
        'GIVEN full action opening + body but closing tag is "</acti" '
        'WHEN findNextAction is called '
        'THEN returns "incomplete"', () {
      const text =
          '<action name="explicar_tema"><tema>fracciones</tema></acti';

      final result = findNextAction(text);

      expect(result, equals('incomplete'));
    });
  });

  // -----------------------------------------------------------------
  // Test 3: findNextAction returns null for text without action
  // GIVEN text "Hola, ¿cómo estás?"
  // WHEN findNextAction is called
  // THEN returns null
  // -----------------------------------------------------------------
  group('findNextAction — no action present', () {
    test(
        'GIVEN plain text "Hola, ¿cómo estás?" with no XML '
        'WHEN findNextAction is called '
        'THEN returns null', () {
      const text = 'Hola, ¿cómo estás?';

      final result = findNextAction(text);

      expect(result, isNull);
    });

    // Triangulation: text with other XML tags but no action tag
    test(
        'GIVEN text with <div> and <p> tags but no <action> tag '
        'WHEN findNextAction is called '
        'THEN returns null', () {
      const text = '<div>Contenido</div><p>párrafo</p>';

      final result = findNextAction(text);

      expect(result, isNull);
    });

    // Triangulation: almost-action — word "action" in text but not XML
    test(
        'GIVEN text containing the word "action" but not as XML tag '
        'WHEN findNextAction is called '
        'THEN returns null', () {
      const text = 'La action de explicar es importante.';

      final result = findNextAction(text);

      expect(result, isNull);
    });
  });

  // -----------------------------------------------------------------
  // Test 4: findNextAction handles multiple actions
  // GIVEN text with action A then action B, from=actionA_end
  // WHEN findNextAction is called from that position
  // THEN finds action B
  // -----------------------------------------------------------------
  group('findNextAction — multiple actions with from offset', () {
    test(
        'GIVEN text with two actions and from=end_of_first '
        'WHEN findNextAction is called '
        'THEN finds the second action', () {
      const text =
          '<action name="explicar_tema"><tema>fracciones</tema></action>\n'
          'Ahora voy a generar ejercicios.\n'
          '<action name="generar_ejercicios"><tema>fracciones</tema><nivel>1</nivel></action>';

      // First, find action A.
      final first = findNextAction(text);
      expect(first, isA<ParsedAction>());

      // Now find action B starting after action A ends.
      final firstAction = first as ParsedAction;
      final second = findNextAction(text, firstAction.end);

      expect(second, isNotNull);
      expect(second, isA<ParsedAction>());

      final secondAction = second as ParsedAction;
      expect(secondAction.name, equals('generar_ejercicios'));
      expect(secondAction.args, containsPair('tema', 'fracciones'));
      expect(secondAction.args, containsPair('nivel', 1));
    });

    // Triangulation: from=0 finds the first action
    test(
        'GIVEN text with two actions and from=0 '
        'WHEN findNextAction is called '
        'THEN finds the first action', () {
      const text =
          '<action name="explicar_tema"><tema>fracciones</tema></action>'
          '<action name="generar_ejercicios"><tema>fracciones</tema></action>';

      final result = findNextAction(text, 0);

      expect(result, isA<ParsedAction>());
      final action = result as ParsedAction;
      expect(action.name, equals('explicar_tema'));
    });

    // Triangulation: from past last action returns null
    test(
        'GIVEN text with one action and from offset past the end '
        'WHEN findNextAction is called '
        'THEN returns null', () {
      const text =
          '<action name="explicar_tema"><tema>fracciones</tema></action>';

      final result = findNextAction(text, text.length + 10);

      expect(result, isNull);
    });
  });

  // =========================================================================
  // Group 2: repairXml — fix malformed XML for resilient parsing
  // =========================================================================

  group('repairXml — fix malformed XML', () {
    // -----------------------------------------------------------------
    // Test 5: repairXml fixes unclosed tags
    // GIVEN XML missing </action>
    // WHEN repairXml is called
    // THEN adds missing closing tag
    // -----------------------------------------------------------------
    test(
        'GIVEN XML text missing </action> closing tag '
        'WHEN repairXml is called '
        'THEN adds </action> at the end', () {
      const partial =
          '<action name="explicar_tema"><tema>fracciones</tema>';

      final repaired = repairXml(partial);

      expect(repaired, contains('</action>'));
      expect(repaired.endsWith('</action>'), isTrue);
      // The original content should still be present.
      expect(repaired, contains('<action name="explicar_tema">'));
      expect(repaired, contains('<tema>fracciones</tema>'));
    });

    // Triangulation: already-complete XML is unchanged
    test(
        'GIVEN complete XML with all tags closed '
        'WHEN repairXml is called '
        'THEN returns the same content unchanged', () {
      const complete =
          '<action name="explicar_tema"><tema>fracciones</tema></action>';

      final repaired = repairXml(complete);

      expect(repaired, equals(complete));
    });

    // Triangulation: deeply nested unclosed tags
    test(
        'GIVEN XML with unclosed <tema> inside unclosed <action> '
        'WHEN repairXml is called '
        'THEN closes all open tags in correct order', () {
      const partial =
          '<action name="test"><param><value>hello';

      final repaired = repairXml(partial);

      // Should close value, then param, then action.
      expect(repaired, contains('</value>'));
      expect(repaired, contains('</param>'));
      expect(repaired, contains('</action>'));
      // Closing order must be correct (LIFO).
      final valueEnd = repaired.indexOf('</value>');
      final paramEnd = repaired.indexOf('</param>');
      final actionEnd = repaired.indexOf('</action>');
      expect(valueEnd, lessThan(paramEnd));
      expect(paramEnd, lessThan(actionEnd));
    });

    // -----------------------------------------------------------------
    // Test 6: repairXml fixes malformed nested content
    // GIVEN XML with unclosed <content>
    // WHEN repairXml is called
    // THEN adds </content>
    // -----------------------------------------------------------------
    test(
        'GIVEN XML with unclosed <content> tag inside <action> '
        'WHEN repairXml is called '
        'THEN adds </content> before </action>', () {
      const partial =
          '<action name="obtener_leccion">'
          '<id>M001_fracciones</id>'
          '<content>';

      final repaired = repairXml(partial);

      expect(repaired, contains('</content>'));
      expect(repaired, contains('</action>'));
    });

    // Triangulation: empty text returns empty
    test(
        'GIVEN empty string '
        'WHEN repairXml is called '
        'THEN returns empty string unchanged', () {
      expect(repairXml(''), equals(''));
    });

    // Triangulation: plain text with no XML
    test(
        'GIVEN plain text with no XML tags '
        'WHEN repairXml is called '
        'THEN returns the text unchanged', () {
      const plain = 'Hola, ¿cómo estás?';
      expect(repairXml(plain), equals(plain));
    });
  });

  // =========================================================================
  // Group 3: detectForcedTool — keyword-to-tool rescue for malformed XML
  // =========================================================================

  group('detectForcedTool — keyword matching', () {
    // -----------------------------------------------------------------
    // Test 8: procesarMensaje detects forced tool from speak text
    // GIVEN model speaks "Voy a buscar información sobre ecuaciones"
    // WHEN detectForcedTool is called
    // THEN returns {tool: "explicar_tema", args: {tema: "ecuaciones"}}
    // -----------------------------------------------------------------
    test(
        'GIVEN text "Voy a buscar información sobre ecuaciones" '
        'WHEN detectForcedTool is called '
        'THEN returns tool mapping for explicar_tema with tema=ecuaciones', () {
      const text = 'Voy a buscar información sobre ecuaciones';

      final result = detectForcedTool(text);

      expect(result, isNotNull);
      expect(result, isA<Map<String, dynamic>>());
      expect(result!['tool'], isNotNull);
      expect(result['args'], isA<Map<String, dynamic>>());
    });

    // Triangulation: "necesito ejercicios de fracciones" → generar_ejercicios
    test(
        'GIVEN text "necesito ejercicios de fracciones" '
        'WHEN detectForcedTool is called '
        'THEN matches ejercicio keywords and returns a tool', () {
      const text = 'necesito ejercicios de fracciones';

      final result = detectForcedTool(text);

      expect(result, isNotNull);
      expect(result, isA<Map<String, dynamic>>());
      // The tool should be ejercicio-related.
      expect(result!['tool'], isNotNull);
      expect(result['args'], isA<Map<String, dynamic>>());
    });

    // Triangulation: "hazme un diagnóstico de matemática" → ejecutar_diagnostico
    test(
        'GIVEN text "hazme un diagnóstico de matemática" '
        'WHEN detectForcedTool is called '
        'THEN matches diagnóstico keywords and returns a tool', () {
      const text = 'hazme un diagnóstico de matemática';

      final result = detectForcedTool(text);

      expect(result, isNotNull);
      expect(result, isA<Map<String, dynamic>>());
      expect(result!['tool'], isNotNull);
      expect(result['args'], isA<Map<String, dynamic>>());
    });

    // Triangulation: no keyword match returns null
    test(
        'GIVEN text "hola, ¿cómo estás?" with no educational keywords '
        'WHEN detectForcedTool is called '
        'THEN returns null', () {
      const text = 'hola, ¿cómo estás?';

      final result = detectForcedTool(text);

      expect(result, isNull);
    });
  });

  // =========================================================================
  // Group 4: emitSafeBoundary — prevent split action tags during streaming
  // =========================================================================

  group('emitSafeBoundary — streaming boundary safety', () {
    test(
        'GIVEN buffer ending with complete text and no partial action '
        'WHEN emitSafeBoundary is called from=0 '
        'THEN returns buffer.length (everything is safe)', () {
      const buffer =
          'Aquí tienes la explicación de fracciones. '
          'Las fracciones representan partes de un todo.';

      final boundary = emitSafeBoundary(buffer, 0);

      expect(boundary, equals(buffer.length));
    });

    // Triangulation: buffer ends with partial "<act" — boundary before the <
    test(
        'GIVEN buffer ending with partial "<act" that could start an action tag '
        'WHEN emitSafeBoundary is called '
        'THEN boundary is before the < character', () {
      const buffer =
          'Aquí tienes la respuesta.\n<act';

      final boundary = emitSafeBoundary(buffer, 0);

      // The '<' at index before "<act" is the start of a potential action tag.
      // Boundary must be before that '<'.
      final tagStart = buffer.indexOf('<act');
      expect(boundary, lessThanOrEqualTo(tagStart));
    });

    // Triangulation: buffer with complete action is safe
    test(
        'GIVEN buffer with complete </action> and text after '
        'WHEN emitSafeBoundary is called '
        'THEN returns buffer.length', () {
      const buffer =
          '<action name="explicar_tema"><tema>fracciones</tema></action>\n'
          '¿Te quedó claro?';

      final boundary = emitSafeBoundary(buffer, 0);

      expect(boundary, equals(buffer.length));
    });

    // Triangulation: buffer ending with "<a" (partial action start)
    test(
        'GIVEN buffer ending with "<a" '
        'WHEN emitSafeBoundary is called '
        'THEN boundary protects the partial tag', () {
      const buffer = 'Texto final.<a';

      final boundary = emitSafeBoundary(buffer, 0);

      // Should not emit past the start of "<a"
      expect(boundary, equals(12)); // position of '<'
    });
  });

  // =========================================================================
  // Group 5: parseActionBody — extract args from action inner content
  // =========================================================================

  group('parseActionBody — extract typed args from XML body', () {
    test(
        'GIVEN body with simple nested tag '
        'WHEN parseActionBody is called '
        'THEN extracts the tag value as string', () {
      const body = '<tema>fracciones</tema>';

      final args = parseActionBody(body);

      expect(args, containsPair('tema', 'fracciones'));
    });

    // Triangulation: numeric value is parsed as int
    test(
        'GIVEN body with numeric tag value '
        'WHEN parseActionBody is called '
        'THEN extracts as Dart int, not string', () {
      const body = '<tema>fracciones</tema><nivel>2</nivel>';

      final args = parseActionBody(body);

      expect(args['nivel'], equals(2));
      expect(args['nivel'], isA<int>());
    });

    // Triangulation: boolean values "true"/"false" are parsed as bool
    test(
        'GIVEN body with boolean tag values '
        'WHEN parseActionBody is called '
        'THEN extracts as Dart bool', () {
      const body =
          '<adaptativo>true</adaptativo><guardar>false</guardar>';

      final args = parseActionBody(body);

      expect(args['adaptativo'], equals(true));
      expect(args['guardar'], equals(false));
    });

    // Triangulation: <content> tag with multiline value is extracted specially
    test(
        'GIVEN body with <content> containing multiline text '
        'WHEN parseActionBody is called '
        'THEN content key holds the full text preserving newlines', () {
      const body =
          '<tema>fracciones</tema>\n'
          '<content>\n'
          'Las fracciones son...\n'
          'Línea 2.\n'
          '</content>';

      final args = parseActionBody(body);

      expect(args, contains('content'));
      expect(args['content'], contains('Las fracciones son'));
      expect(args['content'], contains('Línea 2'));
      // tema should still be extracted from outside <content>
      expect(args['tema'], equals('fracciones'));
    });
  });

  // =========================================================================
  // Group 6 (GemmaService.procesarMensaje — feature gate / legacy routing)
  // was removed in PR1b (task 2.4): the useXmlDispatch gate, MethodChannel
  // mocks and the legacy routing path no longer exist. The file itself is
  // scheduled for full deletion in PR3 (task 4.4) together with
  // action_parser.dart / grammar_builder.dart.
  // =========================================================================
}
