import 'package:flutter/material.dart';

import '../yachay/screens/yachay_scaffold.dart';
import 'gemma_service.dart';
import 'model_download_service.dart';
import 'model_installer.dart';
import 'model_status.dart';
import 'token_store.dart';

/// Full-screen onboarding for the on-device AI model (gemma4-runtime).
///
/// Mirrors the reference app (yachayprueba1-fc02) download UX — first screen
/// shows the model state and starts a direct download without OAuth, because
/// the `litert-community/gemma-4-E2B-it-litert-lm` repo is public (no gating).
/// The page listens to [ModelStatusController] like the status chip and never
/// crashes: every failure degrades to an actionable on-screen error.
class ModelDownloadPage extends StatefulWidget {
  const ModelDownloadPage({
    super.key,
    this.gemmaService,
    this.installer,
    this.verifier,
    this.tokenStore,
    this.onModelReady,
  });

  /// Injectable for widget tests; production uses [GemmaService.instance].
  final GemmaService? gemmaService;

  /// Injectable [ModelInstaller] seam for widget tests; production uses
  /// [FlutterGemmaModelInstaller].
  final ModelInstaller? installer;

  /// Injectable [ModelIntegrityVerifier] seam for widget tests; production
  /// uses [GemmaModelIntegrityVerifier].
  final ModelIntegrityVerifier? verifier;

  /// Injectable [TokenStore] seam for the optional manual-token dialog;
  /// production uses [SharedPrefsTokenStore]. Kept as a fallback in case the
  /// repo becomes gated in the future.
  final TokenStore? tokenStore;

  /// Called once the model is ready and the user taps "Continuar". Defaults to
  /// replacing this route with the [YachayScaffold]; widget tests inject a
  /// recorder.
  final VoidCallback? onModelReady;

  @override
  State<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends State<ModelDownloadPage> {
  late final GemmaService _gemmaService =
      widget.gemmaService ?? GemmaService.instance;
  late final ModelStatusController _statusController =
      _gemmaService.statusController;
  late final TokenStore _tokenStore =
      widget.tokenStore ?? const SharedPrefsTokenStore();

  ModelDownloadService? _downloadService;

  /// True while a download/verify run is in flight, so the action cannot be
  /// double-triggered.
  bool _busy = false;

  /// Lazily built so widget tests that only render the page never touch the
  /// plugin-backed seams (no filesystem, no network).
  ///
  /// The download runs without an OAuth token because the model repo
  /// (`litert-community/gemma-4-E2B-it-litert-lm`) is public. If a manual
  /// token was previously saved, it is used; otherwise the download proceeds
  /// token-free.
  ModelDownloadService get _service {
    return _downloadService ??= ModelDownloadService(
      installer: widget.installer ?? FlutterGemmaModelInstaller(),
      verifier: widget.verifier ?? const GemmaModelIntegrityVerifier(),
      tokens: _OptionalTokenProvider(_tokenStore),
      status: _statusController,
    );
  }

  Future<void> _descargarModelo() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _service.ensureModelReady();
      if (!mounted) return;
      if (!result.success) return; // statusController already carries the error
      final loaded = await _gemmaService.cargarModelo();
      if (!mounted) return;
      if (!loaded) {
        _mostrarError('El modelo está instalado, pero no se pudo iniciar la '
            'sesión de IA. Cierra y abre la app para reintentar.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continuar() {
    final callback = widget.onModelReady;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const YachayScaffold()),
    );
  }

  void _mostrarError(String message) {
    _statusController.error(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<ModelStatusInfo>(
          valueListenable: _statusController,
          builder: (context, info, _) => _buildBody(info),
        ),
      ),
    );
  }

  Widget _buildBody(ModelStatusInfo info) {
    final status = info.status;
    final busy = _busy ||
        status == ModelStatus.downloading ||
        status == ModelStatus.verifying;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _buildIcon(status),
          const SizedBox(height: 24),
          _buildStatusBadge(info),
          const SizedBox(height: 16),
          Text(
            _title(status),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _subtitle(status),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          if (status == ModelStatus.downloading) ...[
            if (info.progressPercent != null) ...[
              LinearProgressIndicator(
                value: (info.progressPercent! / 100).clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${info.progressPercent}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
          if (status == ModelStatus.error && info.errorMessage != null) ...[
            _errorBanner(info.errorMessage!),
            const SizedBox(height: 24),
          ],
          _buildActions(status, busy),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIcon(ModelStatus status) {
    switch (status) {
      case ModelStatus.ready:
        return const _StatusIcon(
            icon: Icons.check_rounded, color: Colors.green);
      case ModelStatus.error:
        return const _StatusIcon(icon: Icons.error_outline, color: Colors.red);
      case ModelStatus.downloading:
      case ModelStatus.verifying:
        return const SizedBox(
          width: 88,
          height: 88,
          child: CircularProgressIndicator(strokeWidth: 5),
        );
      case ModelStatus.noModel:
        return const _StatusIcon(
          icon: Icons.download_rounded,
          color: Color(0xFF1565C0),
        );
    }
  }

  Widget _buildStatusBadge(ModelStatusInfo info) {
    final color = _statusColor(info.status);
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          info.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: scheme.onErrorContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ModelStatus status, bool busy) {
    switch (status) {
      case ModelStatus.ready:
        return _filledButton(
          onPressed: busy ? null : _continuar,
          label: 'Continuar',
          icon: Icons.arrow_forward,
        );
      case ModelStatus.downloading:
        return _filledButton(
          onPressed: null,
          label: 'Descargando...',
          icon: Icons.downloading,
        );
      case ModelStatus.verifying:
        return _filledButton(
          onPressed: null,
          label: 'Verificando...',
          icon: Icons.verified_outlined,
        );
      case ModelStatus.error:
        return Column(
          children: [
            _filledButton(
              onPressed: busy ? null : _descargarModelo,
              label: 'Reintentar',
              icon: Icons.refresh,
            ),
            const SizedBox(height: 12),
            _textButton(
              onPressed: busy ? null : _usarTokenManual,
              label: 'Usar token de HuggingFace (opcional)',
            ),
          ],
        );
      case ModelStatus.noModel:
        return Column(
          children: [
            _filledButton(
              onPressed: busy ? null : _descargarModelo,
              label: 'Descargar modelo',
              icon: Icons.download,
              spinner: _busy,
            ),
            const SizedBox(height: 12),
            _textButton(
              onPressed: busy ? null : _usarTokenManual,
              label: 'Usar token de HuggingFace (opcional)',
            ),
          ],
        );
    }
  }

  Future<void> _usarTokenManual() async {
    if (_busy) return;
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Token de HuggingFace (opcional)'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Pega tu token (empieza con hf_)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (token == null || token.isEmpty) return;
    try {
      await _tokenStore.write(token);
    } catch (_) {
      _mostrarError('No se pudo guardar el token. Inténtalo de nuevo.');
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token guardado. Ya puedes descargar el modelo.'),
      ),
    );
  }

  Widget _filledButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    bool spinner = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: spinner
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }

  Widget _textButton({
    required VoidCallback? onPressed,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  String _title(ModelStatus status) {
    switch (status) {
      case ModelStatus.noModel:
        return 'Conecta Yachay';
      case ModelStatus.downloading:
        return 'Descargando el modelo de IA';
      case ModelStatus.verifying:
        return 'Verificando el modelo';
      case ModelStatus.ready:
        return '¡Modelo listo!';
      case ModelStatus.error:
        return 'No se pudo preparar el modelo';
    }
  }

  String _subtitle(ModelStatus status) {
    switch (status) {
      case ModelStatus.noModel:
        return 'Yachay es tu tutor de matemáticas que funciona sin conexión. '
            'Para activarlo, descarga el modelo de IA (unos 2.6 GB). '
            'Solo se descarga una vez.';
      case ModelStatus.downloading:
        return 'El modelo se está descargando. No cierres la app; en '
            'conexiones lentas puede tomar varios minutos.';
      case ModelStatus.verifying:
        return 'Comprobando que el archivo descargado esté completo y en '
            'buen estado...';
      case ModelStatus.ready:
        return 'El modelo de IA está instalado y listo. Yachay puede '
            'acompañarte sin necesidad de internet.';
      case ModelStatus.error:
        return 'Revisa el mensaje a continuación e inténtalo de nuevo.';
    }
  }

  Color _statusColor(ModelStatus status) {
    switch (status) {
      case ModelStatus.ready:
        return Colors.green;
      case ModelStatus.error:
        return Colors.red;
      case ModelStatus.downloading:
      case ModelStatus.verifying:
        return Colors.orange;
      case ModelStatus.noModel:
        return const Color(0xFF1565C0);
    }
  }
}

/// Circular status icon with a soft tinted background.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
        ),
        child: Icon(icon, size: 44, color: color),
      ),
    );
  }
}

/// A [TokenProvider] that returns a previously saved manual token if present,
/// or `null` otherwise. The download proceeds without authentication when no
/// token is available (the model repo is public).
class _OptionalTokenProvider implements TokenProvider {
  const _OptionalTokenProvider(this._store);
  final TokenStore _store;

  @override
  Future<String?> getAccessToken() => _store.read();
}
