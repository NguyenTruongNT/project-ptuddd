import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/material_qr.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/widgets/feature_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../transactions/domain/idempotency_key.dart';
import '../providers/material_providers.dart';

class MaterialQrPage extends StatelessWidget {
  const MaterialQrPage({super.key, required this.materialId});
  final String materialId;
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: AppLocalizations.of(context)!.qrTitle,
    fallbackLocation: AppRoutes.materialDetails(materialId),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: MaterialQrPanel(
        materialId: materialId,
        autoLoad: true,
        large: true,
      ),
    ),
  );
}

class MaterialQrPanel extends ConsumerStatefulWidget {
  const MaterialQrPanel({
    super.key,
    required this.materialId,
    this.enabled = true,
    this.autoLoad = false,
    this.large = false,
  });
  final String materialId;
  final bool enabled, autoLoad, large;
  @override
  ConsumerState<MaterialQrPanel> createState() => _MaterialQrPanelState();
}

class _MaterialQrPanelState extends ConsumerState<MaterialQrPanel> {
  MaterialQr? _qr;
  DomainErrorCode? _error;
  bool _busy = false;
  int _generation = 0;
  String _key = newIdempotencyKey();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Không lưu QR vào SQLite/preferences. Ra nền phải xin lại quyền server
    // khi mở mã lần sau; token vật lý vẫn giữ nguyên, chỉ xóa bản hiển thị.
    _lifecycle = AppLifecycleListener(
      onInactive: _clear,
      onPause: _clear,
      onHide: _clear,
    );
    if (widget.autoLoad) Future.microtask(_load);
  }

  void _clear() {
    _generation++;
    if (mounted) {
      setState(() {
        _qr = null;
        _busy = false;
        _error = null;
      });
    }
  }

  @override
  void didUpdateWidget(covariant MaterialQrPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.materialId != widget.materialId || !widget.enabled) {
      _generation++;
      _qr = null;
      _busy = false;
      _error = null;
      _key = newIdempotencyKey();
    }
  }

  Future<void> _load() async {
    if (!mounted || !widget.enabled || _busy) return;
    final generation = ++_generation;
    final boundary = ref.read(sessionBoundaryProvider);
    setState(() {
      _busy = true;
      _qr = null;
      _error = null;
    });
    CommandResult<MaterialQr> result;
    try {
      result = await ref
          .read(materialQrRepositoryProvider)
          .ensureQr(widget.materialId, idempotencyKey: _key);
    } catch (error) {
      result = CommandError(
        error is AppError ? error.code : DomainErrorCode.unexpectedError,
        '',
      );
    }
    // HTTP cũ có thể về sau logout hoặc sau khi đổi Material; bỏ kết quả đó.
    if (!mounted ||
        generation != _generation ||
        boundary != ref.read(sessionBoundaryProvider)) {
      return;
    }
    setState(() {
      _busy = false;
      switch (result) {
        case CommandOk(:final data):
          _qr = data;
        case CommandError(:final code):
          _error = code;
      }
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionBoundaryProvider, (previous, next) {
      if (previous != next) {
        _key = newIdempotencyKey();
        _clear();
      }
    });
    final t = AppLocalizations.of(context)!;
    final qr = _qr;
    final message = switch (_error) {
      DomainErrorCode.authRequired ||
      DomainErrorCode.forbidden => t.qrUnavailable,
      DomainErrorCode.backendUnavailable => t.qrBackendUnavailable,
      DomainErrorCode.timeoutUnknown => t.qrUnknown,
      DomainErrorCode.networkUnavailable => t.qrOffline,
      null => null,
      _ => t.qrFailed,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.qrTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (qr != null) ...[
              Text(qr.title, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.large ? 420 : 280,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Semantics(
                      label: t.qrTitle,
                      excludeSemantics: true,
                      child: QrImageView(
                        data: qr.payload,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(20),
                        eyeStyle: const QrEyeStyle(color: Colors.black),
                        dataModuleStyle: const QrDataModuleStyle(
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(qr.isDemo ? t.qrDemoNotice : t.qrNotice),
              const SizedBox(height: 8),
              SelectableText(qr.materialId, textAlign: TextAlign.center),
              if (!widget.large)
                TextButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.materialQr(widget.materialId)),
                  icon: const Icon(Icons.fullscreen),
                  label: Text(t.qrEnlarge),
                ),
            ],
            if (!widget.enabled) Text(t.qrOffline),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(message),
              ),
            if (_busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              OutlinedButton.icon(
                key: const ValueKey('material-qr-load'),
                onPressed: widget.enabled ? _load : null,
                icon: const Icon(Icons.qr_code),
                label: Text(
                  qr != null || _error != null ? t.qrRetry : t.qrShow,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
