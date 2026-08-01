import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'package:aprendo_plus/modules/gemma/gemma_inference_adapter.dart';

/// In-memory [GemmaInferenceAdapter] for tests.
///
/// Records every call (`loadModel` args, `createChat` configuration,
/// `close`) so contract tests can assert that the orchestration calls the
/// seam correctly — without touching the native plugin. Emission streams are
/// injectable so streaming tests can simulate token and tool-call delivery.
class GemmaInferenceAdapterFake implements GemmaInferenceAdapter {
  GemmaInferenceAdapterFake({
    Stream<String>? tokens,
    Stream<ModelResponse>? chatResponses,
    this.loadModelResult = true,
  })  : _tokens = tokens ?? const Stream<String>.empty(),
        _chatResponses = chatResponses ?? const Stream<ModelResponse>.empty();

  Stream<String> _tokens;
  Stream<ModelResponse> _chatResponses;

  /// Result returned by [loadModel] (default: success).
  final bool loadModelResult;

  // ---- recorded calls ----

  int loadModelCalls = 0;
  int? loadModelMaxTokens;
  int createChatCalls = 0;
  String? systemInstruction;
  int? maxOutputTokens;
  List<Tool>? tools;
  bool closed = false;

  /// Replaces the token stream emitted by the next [streamResponse] call.
  void setTokens(Stream<String> tokens) => _tokens = tokens;

  /// Replaces the response stream emitted by the next [streamChatResponse]
  /// call.
  void setChatResponses(Stream<ModelResponse> responses) =>
      _chatResponses = responses;

  @override
  PreferredBackend? get activeBackend =>
      loadModelResult ? PreferredBackend.cpu : null;

  @override
  Future<bool> loadModel({int maxTokens = 8192}) async {
    loadModelCalls++;
    loadModelMaxTokens = maxTokens;
    return loadModelResult;
  }

  @override
  Future<void> createChat({
    required String systemInstruction,
    required int maxOutputTokens,
    required List<Tool> tools,
  }) async {
    createChatCalls++;
    this.systemInstruction = systemInstruction;
    this.maxOutputTokens = maxOutputTokens;
    this.tools = tools;
  }

  @override
  Stream<String> streamResponse() => _tokens;

  @override
  Stream<ModelResponse> streamChatResponse() => _chatResponses;

  @override
  Future<void> close() async {
    closed = true;
  }
}
