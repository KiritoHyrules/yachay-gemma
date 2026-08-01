import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gemma/flutter_gemma.dart'
    show FunctionCallResponse, TextResponse;

import 'package:aprendo_plus/modules/gemma/gemma_service.dart';
import 'package:aprendo_plus/modules/gemma/tool_registry.dart';

import 'fakes/gemma_inference_adapter_fake.dart';

/// Dispatch-loop tests for the GemmaService 1.4.2 native function calling
/// (PR1b, task 2.2).
///
/// The fake adapter emits one `Stream<ModelResponse>` per round via
/// [GemmaInferenceAdapterFake.setChatResponseQueue]; the service must:
/// - run a single tool round and return the final text
/// - chain multiple tools without exceeding `maxDispatchRounds` (7)
/// - force a final text with the accumulated results when round 7 is reached
/// - persist `student_mastery` when `evaluar_respuesta` runs (checkpoint)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GemmaService dispatch nativo (fake adapter)', () {
    test(
        'GIVEN one tool call followed by a text response '
        'WHEN procesarMensaje() runs '
        'THEN the tool executes and the final text is returned', () async {
      final adapter = GemmaInferenceAdapterFake();
      adapter.setChatResponseQueue([
        Stream.value(const FunctionCallResponse(
          name: 'explicar_tema',
          args: {'tema': 'fracciones', 'nivel': '2'},
        )),
        Stream.value(
            const TextResponse('Vamos a entender fracciones con ejemplos.')),
      ]);
      final service = GemmaService.forTest(adapter: adapter);
      await service.cargarModelo();

      final result = await service.procesarMensaje('explicame fracciones');

      expect(result, contains('fracciones'));
      // User message + tool result fed back into the chat.
      expect(adapter.addedQueries, hasLength(2));
      expect(adapter.addedQueries.first.isUser, isTrue);
      expect(adapter.addedQueries.last.toolName, 'explicar_tema');
      expect(adapter.addedQueries.last.type.name, 'toolResponse');
    });

    test(
        'GIVEN multiple sequential tool calls '
        'WHEN procesarMensaje() runs '
        'THEN all tools execute (<=7 rounds) and the final text is returned',
        () async {
      final adapter = GemmaInferenceAdapterFake();
      adapter.setChatResponseQueue([
        Stream.value(const FunctionCallResponse(name: 'consultar_estado', args: {})),
        Stream.value(const FunctionCallResponse(
          name: 'obtener_siguiente_tema',
          args: {'tema': 'fracciones'},
        )),
        Stream.value(
            const TextResponse('Te recomiendo repasar suma de fracciones.')),
      ]);
      final service = GemmaService.forTest(adapter: adapter);
      await service.cargarModelo();

      final result = await service.procesarMensaje('quiero repasar');

      expect(result, contains('fracciones'));
      // user message + 2 tool results.
      expect(adapter.addedQueries, hasLength(3));
    });

    test(
        'GIVEN 7 consecutive tool rounds without a final text '
        'WHEN procesarMensaje() exhausts the rounds '
        'THEN it forces a final text with the accumulated results', () async {
      final adapter = GemmaInferenceAdapterFake();
      adapter.setChatResponseQueue(
        List.generate(
          GemmaService.maxDispatchRounds,
          (_) =>
              Stream.value(const FunctionCallResponse(name: 'consultar_estado', args: {})),
        ),
      );
      final service = GemmaService.forTest(adapter: adapter);
      await service.cargarModelo();

      final result = await service.procesarMensaje('cuanto llevo');

      expect(result, isNotEmpty);
      // user message + 7 tool results.
      expect(adapter.addedQueries, hasLength(1 + GemmaService.maxDispatchRounds));
      // Every round generated a model response.
      expect(adapter.streamChatResponseCalls, GemmaService.maxDispatchRounds);
    });

    test(
        'GIVEN evaluar_respuesta is called in a round '
        'WHEN the tool runs with an injected ToolContext '
        'THEN student_mastery is persisted (checkpoint)', () async {
      final adapter = GemmaInferenceAdapterFake();
      adapter.setChatResponseQueue([
        Stream.value(const FunctionCallResponse(
          name: 'evaluar_respuesta',
          args: {'tema': 'fracciones', 'subtema': 'suma', 'correcta': true},
        )),
        Stream.value(
            const TextResponse('¡Excelente, dominaste la suma de fracciones!')),
      ]);
      final state = _FakeStudentState();
      final service = GemmaService.forTest(adapter: adapter);
      service.setToolContext(
        ToolContext(studentState: state, fallbackData: const {}),
      );
      await service.cargarModelo();

      final result = await service.procesarMensaje('resolví 1/2 + 1/2');

      expect(result, contains('dominaste'));
      expect(state.updatedTopics, contains('fracciones/suma'));
    });

    test(
        'GIVEN a greeting '
        'WHEN procesarMensaje() runs '
        'THEN it responds directly without consuming dispatch rounds',
        () async {
      final adapter = GemmaInferenceAdapterFake();
      final service = GemmaService.forTest(adapter: adapter);
      await service.cargarModelo();

      final result = await service.procesarMensaje('Hola');

      expect(result, isNotEmpty);
      expect(adapter.addedQueries, isEmpty);
      expect(adapter.streamChatResponseCalls, 0);
    });
  });
}

class _FakeMastery {
  final num pLearned;
  const _FakeMastery(this.pLearned);
}

/// Minimal duck-typed StudentState so `evaluar_respuesta`'s BKT checkpoint
/// persists through `actualizarMastery` without a real database.
class _FakeStudentState {
  final Map<String, _FakeMastery> masteryMap = {
    'student1|fracciones/suma': const _FakeMastery(0.4),
  };
  final Map<String, dynamic> profile = {'id': 'student1'};
  final List<String> updatedTopics = [];

  Future<void> actualizarMastery(
    String studentId,
    String topicId,
    bool correcta,
  ) async {
    updatedTopics.add(topicId);
  }
}
