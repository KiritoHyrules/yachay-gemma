/// A single parameter definition for a tool, mirroring gemma-chat's
/// `ToolSpec.params` interface.
///
/// flutter_gemma Tool integration: see [ToolRegistry.toFlutterGemmaTools].
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_gemma/flutter_gemma.dart' show Tool;

class ToolParam {
  final String name;
  final String description;
  final bool required;

  const ToolParam({
    required this.name,
    required this.description,
    this.required = false,
  });
}

/// The result returned by every tool handler execution.
///
/// [summary] is a human-readable one-line description of what happened
/// (e.g., "Explicando fracciones (nivel 2)").
/// [payload] is the structured data — a [DiagnosticResult], a list of
/// exercises, a [StudentProfile], etc. Callers should inspect [payload]
/// for domain-specific content.
class ToolResult {
  final String summary;
  final dynamic payload;

  const ToolResult({required this.summary, this.payload});
}

/// Context passed to every tool handler.
///
/// Carries references to the services a handler may need. Handlers MUST
/// check for `null` before using any service — the context may be empty
/// when the app is not fully initialized or during testing.
class ToolContext {
  final dynamic studentState;
  final dynamic dbService;
  final dynamic diagnosticoService;
  final dynamic curriculum;
  final Map<String, dynamic>? fallbackData;

  const ToolContext({
    this.studentState,
    this.dbService,
    this.diagnosticoService,
    this.curriculum,
    this.fallbackData,
  });
}

/// Immutable descriptor for a registered tool.
///
/// Mirrors gemma-chat's `ToolSpec` interface: name, description,
/// typed parameter list, and an async handler function.
class ToolSpec {
  final String name;
  final String description;
  final List<ToolParam> params;
  final Future<ToolResult> Function(
    Map<String, dynamic> args,
    ToolContext ctx,
  ) handler;

  const ToolSpec({
    required this.name,
    required this.description,
    this.params = const [],
    required this.handler,
  });
}

/// Converts ToolSpec parameters to flutter_gemma's Tool parameter format.
///
/// Mirrors the JSON Schema subset expected by FlutterGemmaPlugin's
/// native function-calling parser.
Map<String, dynamic> _toGemmaParams(List<ToolParam> params) {
  final properties = <String, dynamic>{};
  final required = <String>[];

  for (final param in params) {
    properties[param.name] = {
      'type': 'string',
      'description': param.description,
    };
    if (param.required) {
      required.add(param.name);
    }
  }

  return {
    'type': 'object',
    'properties': properties,
    if (required.isNotEmpty) 'required': required,
  };
}

/// Registry of all available tool handlers.
///
/// Tools are registered by name and looked up by name. The registry
/// supports overwrite (re-registering replaces the previous entry).
/// [run] executes a tool's handler and returns its [ToolResult], or
/// returns an error result when the tool is unknown.
class ToolRegistry {
  final Map<String, ToolSpec> _tools = {};

  /// Clears all registered tools. Only for testing.
  @visibleForTesting
  void clearForTest() {
    _tools.clear();
  }

  /// Registers [tool]. If a tool with the same name already exists,
  /// it is silently replaced.
  void register(ToolSpec tool) {
    _tools[tool.name] = tool;
  }

  /// Looks up a [ToolSpec] by [name]. Returns `null` if not found.
  ToolSpec? lookup(String name) {
    return _tools[name];
  }

  /// Returns every registered tool as an unmodifiable list.
  List<ToolSpec> listTools() {
    return _tools.values.toList(growable: false);
  }

  /// Converts all registered tools to flutter_gemma [Tool] objects for
  /// native function calling via FlutterGemmaPlugin.
  ///
  /// Each ToolSpec's name, description, and parameter schema are mapped
  /// to the format expected by flutter_gemma's inference engine.
  List<Tool> toFlutterGemmaTools() {
    return _tools.values.map((spec) {
      return Tool(
        name: spec.name,
        description: spec.description,
        parameters: _toGemmaParams(spec.params),
      );
    }).toList(growable: false);
  }

  /// Executes the tool identified by [name] with the given [args] and
  /// [ctx], returning its [ToolResult].
  ///
  /// When [name] is unknown, returns an error-level [ToolResult] with
  /// the unknown tool name in the summary — the caller never receives
  /// `null`.
  Future<ToolResult> run(
    String name,
    Map<String, dynamic> args,
    ToolContext ctx,
  ) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolResult(
        summary:
            'Error: herramienta desconocida "$name". '
            'Herramientas disponibles: ${_tools.keys.join(", ")}.',
        payload: {'error': 'unknown_tool', 'requested': name},
      );
    }

    try {
      return await tool.handler(args, ctx);
    } catch (e) {
      return ToolResult(
        summary: 'Error al ejecutar "$name": $e',
        payload: {'error': 'execution_error', 'tool': name, 'detail': '$e'},
      );
    }
  }
}
