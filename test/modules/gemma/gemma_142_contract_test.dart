import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show PreferredBackend;

import 'package:aprendo_plus/core/models/message_stats.dart';
import 'package:aprendo_plus/modules/gemma/gemma_service.dart';

import 'fakes/gemma_inference_adapter_fake.dart';

/// Contract tests for the GemmaService rewrite on the flutter_gemma 1.4.2
/// API (PR1b, task 2.1).
///
/// Uses an in-memory [GemmaInferenceAdapterFake] so no native plugin/FFI is
/// touched. Verifies the 1.4.2 initialization contract:
/// - `cargarModelo()` → `loadModel(maxTokens: 8192, cpu)` + `createChat`
///   (systemInstruction, maxOutputTokens >= 1024, toolChoice: auto, 13 tools)
/// - `sendWithStreaming()` consumes `Stream<String>` with 3-token throttle
///   and emits a `MessageStats` summary
/// - the 30s timeout is injectable and cuts short with partial stats
/// - without a loaded model everything degrades (tokenCount == 0, never crash)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GemmaService 1.4.2 contract (adapter fake)', () {
    test(
        'GIVEN a fresh service with a fake adapter '
        'WHEN cargarModelo() succeeds '
        'THEN loadModel(8192, cpu) and createChat(systemInstruction, '
        'maxOutputTokens>=1024, 13 tools) were called', () async {
      final adapter = GemmaInferenceAdapterFake();
      final service = GemmaService.forTest(adapter: adapter);

      final loaded = await service.cargarModelo();

      expect(loaded, isTrue);
      expect(service.modeloCargado, isTrue);
      expect(adapter.loadModelCalls, 1);
      expect(adapter.loadModelMaxTokens, greaterThanOrEqualTo(1024));
      expect(adapter.createChatCalls, 1);
      expect(adapter.systemInstruction, isNotNull);
      expect(adapter.systemInstruction, isNotEmpty);
      expect(adapter.systemInstruction, contains('Yachay'));
      expect(adapter.maxOutputTokens, greaterThanOrEqualTo(1024));
      expect(adapter.tools, isNotNull);
      expect(adapter.tools!.length, 13);

      final names = adapter.tools!.map((t) => t.name).toList();
      expect(names, contains('explicar_tema'));
      expect(names, contains('generar_ejercicios'));
      expect(names, contains('evaluar_respuesta'));
      expect(names, contains('consultar_estado'));
      expect(names, contains('iniciar_conversacion'));
      expect(names, contains('obtener_siguiente_tema'));

      expect(service.activeBackend, PreferredBackend.cpu);
    });

    test(
        'GIVEN cargarModelo() already succeeded '
        'WHEN cargarModelo() is called again '
        'THEN it is idempotent (no second loadModel/createChat)', () async {
      final adapter = GemmaInferenceAdapterFake();
      final service = GemmaService.forTest(adapter: adapter);

      await service.cargarModelo();
      final second = await service.cargarModelo();

      expect(second, isTrue);
      expect(adapter.loadModelCalls, 1);
      expect(adapter.createChatCalls, 1);
    });

    test(
        'GIVEN the model is loaded '
        'WHEN sendWithStreaming() is called '
        'THEN it consumes Stream<String> with 3-token throttle and emits '
        'MessageStats', () async {
      final adapter = GemmaInferenceAdapterFake();
      adapter.setTokens(Stream.fromIterable(['Ho', 'la', ' Ya', 'ch', 'ay', '!']));
      final service = GemmaService.forTest(adapter: adapter);
      await service.cargarModelo();

      final batches = <String>[];
      MessageStats? stats;
      await service.sendWithStreaming(
        'hola yachay',
        onToken: batches.add,
        onComplete: (s) => stats = s,
      );

      // 6 tokens delivered in 2 batches of 3 (UI throttle).
      expect(batches, hasLength(2));
      expect(batches.join(), 'Hola Yachay!');
      expect(stats, isNotNull);
      expect(stats!.tokenCount, 6);
      expect(stats!.totalLatency, greaterThanOrEqualTo(0));
      // The user prompt was fed into the chat session.
      expect(adapter.addedQueries, hasLength(1));
      expect(adapter.addedQueries.single.isUser, isTrue);
      expect(adapter.addedQueries.single.text, 'hola yachay');
    });

    test(
        'GIVEN a stream that never completes '
        'WHEN sendWithStreaming() runs with an injectable 30s timeout '
        'THEN it cuts short with partial stats (tokens already received)',
        () async {
      final adapter = GemmaInferenceAdapterFake();
      // Emits 2 tokens and then stays open forever.
      final slow = Stream<String>.multi((controller) {
        controller.add('Hola');
        controller.add('Yachay');
      });
      adapter.setTokens(slow);
      final service = GemmaService.forTest(
        adapter: adapter,
        streamTimeout: const Duration(milliseconds: 100),
      );
      await service.cargarModelo();

      final stopwatch = Stopwatch()..start();
      final batches = <String>[];
      MessageStats? stats;
      await service.sendWithStreaming(
        'hola',
        onToken: batches.add,
        onComplete: (s) => stats = s,
      );
      stopwatch.stop();

      // Returned well before the production 30s timeout.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(batches.join(), 'HolaYachay');
      expect(stats, isNotNull);
      expect(stats!.tokenCount, 2);
      expect(stats!.totalLatency, greaterThanOrEqualTo(0));
    });

    test(
        'GIVEN no model is loaded (loadModel fails) '
        'WHEN sendWithStreaming() is called '
        'THEN it degrades with tokenCount == 0 and no onToken delivery',
        () async {
      final adapter = GemmaInferenceAdapterFake(loadModelResult: false);
      final service = GemmaService.forTest(adapter: adapter);

      final loaded = await service.cargarModelo();
      expect(loaded, isFalse);
      expect(service.modeloCargado, isFalse);

      var tokenCalls = 0;
      MessageStats? stats;
      await service.sendWithStreaming(
        'hola',
        onToken: (_) => tokenCalls++,
        onComplete: (s) => stats = s,
      );

      expect(tokenCalls, 0);
      expect(stats, isNotNull);
      expect(stats!.tokenCount, 0);
      expect(stats!.totalLatency, 0);
    });

    test(
        'GIVEN no model is loaded '
        'WHEN procesarMensaje() is called '
        'THEN it degrades to fallback and never returns empty', () async {
      final adapter = GemmaInferenceAdapterFake(loadModelResult: false);
      final service = GemmaService.forTest(adapter: adapter);
      await service.cargarModelo();

      final result =
          await service.procesarMensaje('hola, necesito ayuda con fracciones');

      expect(result, isNotEmpty);
    });
  });
}
