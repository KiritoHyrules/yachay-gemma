import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'package:aprendo_plus/modules/gemma/gemma_inference_adapter.dart';

/// In-memory [GemmaInferenceAdapter] for tests.
///
/// Records every call (`loadModel` args, `createChat` configuration,
/// `addQuery` history, `close`) so contract tests can assert that the
/// orchestration calls the seam correctly — without touching the native
/// plugin. Emission streams are injectable so streaming tests can simulate
/// token and tool-call delivery.
///
/// For multi-round dispatch tests, [setChatResponseQueue] provides one
/// `Stream<ModelResponse>` per round; each [streamChatResponse] call pops the
/// next stream from the queue.
class GemmaInferenceAdapterFake implements GemmaInferenceAdapter {
  GemmaInferenceAdapterFake({
    Stream<String>? tokens,
    Stream<ModelResponse>? chatResponses,
    this.loadModelResult = true,
  })  : _tokens = tokens ?? Stream<String>.empty(),
        _chatResponses = chatResponses ?? Stream<ModelResponse>.empty();

  Stream<String> _tokens;
  Stream<ModelResponse> _chatResponses;
  final List<Stream<ModelResponse>> _chatResponseQueue = [];

  /// Result returned by [loadModel] (default: success).
  final bool loadModelResult;

  // ---- recorded calls ----

  int loadModelCalls = 0;
  int? loadModelMaxTokens;
  int createChatCalls = 0;
  String? systemInstruction;
  int? maxOutputTokens;
  List<Tool>? tools;
  int? tokenBuffer;
  int? randomSeed;
  double? temperature;
  int? topK;
  double? topP;
  double? repeatPenalty;
  bool closed = false;
  bool historyCleared = false;

  /// Every message fed into the chat session, in order.
  final List<Message> addedQueries = [];

  /// Number of [streamChatResponse] listens (one per dispatch round).
  int streamChatResponseCalls = 0;

  /// Replaces the token stream emitted by the next [streamResponse] call.
  void setTokens(Stream<String> tokens) => _tokens = tokens;

  /// Replaces the response stream emitted by the next [streamChatResponse]
  /// call.
  void setChatResponses(Stream<ModelResponse> responses) =>
      _chatResponses = responses;

  /// Provides one `Stream<ModelResponse>` per dispatch round; each
  /// [streamChatResponse] call pops the next stream.
  void setChatResponseQueue(List<Stream<ModelResponse>> responses) {
    _chatResponseQueue
      ..clear()
      ..addAll(responses);
  }

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
    double temperature = 0.4,
    int topK = 64,
    double topP = 0.85,
    double repeatPenalty = 1.1,
    int tokenBuffer = 512,
  }) async {
    createChatCalls++;
    this.systemInstruction = systemInstruction;
    this.maxOutputTokens = maxOutputTokens;
    this.tools = tools;
    this.temperature = temperature;
    this.topK = topK;
    this.topP = topP;
    this.repeatPenalty = repeatPenalty;
    this.tokenBuffer = tokenBuffer;
    this.randomSeed = randomSeed;
  }

  @override
  Future<void> addQuery(Message message) async {
    addedQueries.add(message);
  }

  @override
  Stream<String> streamResponse() => _tokens;

  @override
  Stream<ModelResponse> streamChatResponse() {
    streamChatResponseCalls++;
    if (_chatResponseQueue.isNotEmpty) {
      return _chatResponseQueue.removeAt(0);
    }
    return _chatResponses;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<void> clearHistory() async {
    historyCleared = true;
  }
}
