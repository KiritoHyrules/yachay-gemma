import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Seam for on-device Gemma inference through the flutter_gemma plugin.
///
/// Decouples the orchestration layer from the native (LiteRT/FFI) plugin
/// surface so the whole dispatch and streaming logic is testable with an
/// in-memory fake (see
/// `test/modules/gemma/fakes/gemma_inference_adapter_fake.dart`).
///
/// The real implementation maps 1:1 onto the flutter_gemma 1.4.2 API:
/// - [loadModel] → `FlutterGemma.getActiveModel(preferredBackend: cpu)`
/// - [createChat] → `InferenceModel.createChat(..., toolChoice: auto)`
/// - [streamResponse] → `InferenceModelSession.getResponseAsync()`
///   (`Stream<String>` of raw tokens)
/// - [streamChatResponse] → `InferenceChat.generateChatResponseAsync()`
///   (`Stream<ModelResponse>`; tool calls are parsed from the session's
///   `lastRawResponse`, not emitted as stream items)
abstract class GemmaInferenceAdapter {
  /// Loads the active inference model on the CPU backend.
  ///
  /// Returns `false` when no model is installed/active.
  Future<bool> loadModel({int maxTokens = 8192});

  /// Creates the chat session with the system prompt and registered tools
  /// (tool choice: auto).
  Future<void> createChat({
    required String systemInstruction,
    required int maxOutputTokens,
    required List<Tool> tools,
  });

  /// Feeds a message into the active chat session.
  ///
  /// Used both for the student prompt (`Message.text(..., isUser: true)`)
  /// and for tool results (`Message.toolResponse(...)`) in the native
  /// dispatch loop. Must be called before listening to [streamResponse] /
  /// [streamChatResponse] so the session history is complete.
  Future<void> addQuery(Message message);

  /// Raw token stream of the model session (`Stream<String>`).
  Stream<String> streamResponse();

  /// Chat-level response stream, including function-call events
  /// (`Stream<ModelResponse>`).
  Stream<ModelResponse> streamChatResponse();

  /// Backend the loaded model runs on; null until [loadModel] succeeds.
  PreferredBackend? get activeBackend;

  /// Releases native resources. Never deletes the model file.
  Future<void> close();
}

/// Real [GemmaInferenceAdapter] backed by the flutter_gemma 1.4.2 plugin.
class FlutterGemmaInferenceAdapter implements GemmaInferenceAdapter {
  InferenceModel? _model;
  InferenceChat? _chat;
  PreferredBackend? _backend;

  @override
  PreferredBackend? get activeBackend => _backend;

  @override
  Future<bool> loadModel({int maxTokens = 8192}) async {
    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: PreferredBackend.cpu,
      );
      _backend = PreferredBackend.cpu;
      return true;
    } catch (e) {
      // No active model (bootstrap/install pending) or native load failure:
      // degrade to fallback instead of crashing the caller.
      debugPrint('FlutterGemmaInferenceAdapter: loadModel failed — $e');
      _model = null;
      _backend = null;
      return false;
    }
  }

  @override
  Future<void> createChat({
    required String systemInstruction,
    required int maxOutputTokens,
    required List<Tool> tools,
  }) async {
    final model = _model;
    if (model == null) {
      throw StateError(
        'GemmaInferenceAdapter: loadModel() must succeed before createChat().',
      );
    }
    _chat = await model.createChat(
      systemInstruction: systemInstruction,
      maxOutputTokens: maxOutputTokens,
      tools: tools,
      toolChoice: tools.isEmpty ? ToolChoice.none : ToolChoice.auto,
    );
  }

  @override
  Future<void> addQuery(Message message) async {
    final chat = _chat;
    if (chat == null) {
      throw StateError(
        'GemmaInferenceAdapter: no chat session; call createChat() first.',
      );
    }
    await chat.addQuery(message);
  }

  @override
  Stream<String> streamResponse() {
    final chat = _chat;
    if (chat == null) {
      throw StateError(
        'GemmaInferenceAdapter: no chat session; call createChat() first.',
      );
    }
    // The chat's session is the model's single active session (createChat
    // overwrites `InferenceModel.session`); reading from it guarantees the
    // query added via [addQuery] is the one being generated.
    return chat.session.getResponseAsync();
  }

  @override
  Stream<ModelResponse> streamChatResponse() {
    final chat = _chat;
    if (chat == null) {
      throw StateError(
        'GemmaInferenceAdapter: no chat session; call createChat() first.',
      );
    }
    return chat.generateChatResponseAsync();
  }

  @override
  Future<void> close() async {
    final chat = _chat;
    _chat = null;
    if (chat != null) {
      try {
        await chat.close();
      } catch (e) {
        debugPrint('GemmaInferenceAdapter: chat close failed — $e');
      }
    }
    final model = _model;
    _model = null;
    if (model != null) {
      try {
        await model.close();
      } catch (e) {
        debugPrint('GemmaInferenceAdapter: model close failed — $e');
      }
    }
    _backend = null;
  }
}
