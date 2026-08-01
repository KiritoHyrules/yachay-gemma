import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'package:aprendo_plus/modules/gemma/gemma_inference_adapter.dart';
import 'fakes/gemma_inference_adapter_fake.dart';

/// Compile-contract of the [GemmaInferenceAdapter] seam (design L175-183).
///
/// Verifies the seam exposes the flutter_gemma 1.4.2 surface and that the
/// fake emits `Stream<String>` / `Stream<ModelResponse>` without touching
/// the native plugin. The real adapter (`FlutterGemmaInferenceAdapter`,
/// `implements GemmaInferenceAdapter`) is compiled together with this test
/// via the import above — any signature drift fails analysis, not just tests.
void main() {
  group('GemmaInferenceAdapter seam contract', () {
    test(
        'GIVEN the seam '
        'WHEN method tear-offs are typed against the 1.4.2 API '
        'THEN every signature matches the design', () {
      final GemmaInferenceAdapter adapter = GemmaInferenceAdapterFake();

      // loadModel({int maxTokens = 8192}) → Future<bool>
      final Future<bool> Function({int maxTokens}) loadModelRef =
          adapter.loadModel;
      expect(loadModelRef, isNotNull);

      // createChat({systemInstruction, maxOutputTokens, tools}) → Future<void>
      final Future<void> Function({
        required String systemInstruction,
        required int maxOutputTokens,
        required List<Tool> tools,
      }) createChatRef = adapter.createChat;
      expect(createChatRef, isNotNull);

      // streamResponse() → Stream<String>
      final Stream<String> Function() streamRef = adapter.streamResponse;
      expect(streamRef, isNotNull);

      // streamChatResponse() → Stream<ModelResponse>
      final Stream<ModelResponse> Function() chatStreamRef =
          adapter.streamChatResponse;
      expect(chatStreamRef, isNotNull);

      // activeBackend → PreferredBackend?
      expect(adapter.activeBackend, isA<PreferredBackend?>());

      // close() → Future<void>
      final Future<void> Function() closeRef = adapter.close;
      expect(closeRef, isNotNull);
    });

    test(
        'GIVEN a fresh fake '
        'WHEN loadModel(maxTokens: 8192) is called '
        'THEN it returns true and reports the CPU backend', () async {
      final adapter = GemmaInferenceAdapterFake();

      final ok = await adapter.loadModel(maxTokens: 8192);

      expect(ok, isTrue);
      expect(adapter.loadModelMaxTokens, 8192);
      expect(adapter.loadModelCalls, 1);
      expect(adapter.activeBackend, PreferredBackend.cpu);
    });

    test(
        'GIVEN loadModel failed '
        'WHEN activeBackend is queried '
        'THEN it reports null', () async {
      final adapter = GemmaInferenceAdapterFake(loadModelResult: false);

      final ok = await adapter.loadModel();

      expect(ok, isFalse);
      expect(adapter.activeBackend, isNull);
    });

    test(
        'GIVEN a fake '
        'WHEN createChat(systemInstruction, maxOutputTokens, tools) is called '
        'THEN the configuration is recorded', () async {
      final adapter = GemmaInferenceAdapterFake();
      const tools = [
        Tool(name: 'obtener_leccion', description: 'Lección del tema', parameters: {}),
      ];

      await adapter.createChat(
        systemInstruction: 'Eres un tutor de matemáticas en Perú.',
        maxOutputTokens: 2048,
        tools: tools,
      );

      expect(adapter.createChatCalls, 1);
      expect(adapter.systemInstruction, 'Eres un tutor de matemáticas en Perú.');
      expect(adapter.maxOutputTokens, 2048);
      expect(adapter.tools, tools);
    });

    test(
        'GIVEN a fake with a token stream '
        'WHEN streamResponse() is consumed '
        'THEN it emits Stream<String> tokens in order', () async {
      final adapter = GemmaInferenceAdapterFake(
        tokens: Stream.fromIterable(['Hola', ', ', 'mundo']),
      );

      final tokens = await adapter.streamResponse().toList();

      expect(tokens, ['Hola', ', ', 'mundo']);
    });

    test(
        'GIVEN a fake with a chat response stream '
        'WHEN streamChatResponse() is consumed '
        'THEN it emits Stream<ModelResponse> events in order', () async {
      final adapter = GemmaInferenceAdapterFake(
        chatResponses: Stream.fromIterable(const [
          TextResponse('Hola'),
          FunctionCallResponse(
            name: 'obtener_leccion',
            args: {'tema': 'fracciones'},
          ),
        ]),
      );

      final events = await adapter.streamChatResponse().toList();

      expect(events, hasLength(2));
      expect(events[0], isA<TextResponse>());
      expect((events[0] as TextResponse).token, 'Hola');
      expect(events[1], isA<FunctionCallResponse>());
      expect((events[1] as FunctionCallResponse).name, 'obtener_leccion');
    });

    test(
        'GIVEN a fake '
        'WHEN close() is called '
        'THEN it marks the adapter closed', () async {
      final adapter = GemmaInferenceAdapterFake();

      await adapter.close();

      expect(adapter.closed, isTrue);
    });
  });
}
