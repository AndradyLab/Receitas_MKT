import 'package:flutter/material.dart';
import 'package:receitas_mkt/data/update_info.dart';
import 'package:receitas_mkt/logic/update_android_service.dart';

void showUpdateToast(BuildContext context, UpdateInfo updateInfo) {
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 12,
      child: UpdateToast(
        updateInfo: updateInfo,
        onDismiss: () => entry.remove(),
      ),
    ),
  );

  Overlay.of(context).insert(entry);
}

class UpdateToast extends StatefulWidget {
  final UpdateInfo updateInfo;
  final VoidCallback onDismiss;

  const UpdateToast({
    super.key,
    required this.updateInfo,
    required this.onDismiss,
  });

  @override
  State<UpdateToast> createState() => _UpdateToastState();
}

class _UpdateToastState extends State<UpdateToast> {
  final _updateService = UpdateService();
  double? _progress;
  String? _errorMessage;

  bool get _isDownloading => _progress != null && _errorMessage == null;

  Future<void> _startUpdate() async {
    setState(() {
      _progress = 0;
      _errorMessage = null;
    });

    try {
      await _updateService.downloadAndInstall(
        widget.updateInfo,
        onProgress: (p) => setState(() => _progress = p),
      );
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Erro: $e e StackTrace: $stackTrace'; 
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Versão ${widget.updateInfo.version} disponível',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text('${((_progress ?? 0) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12)),
            ] else if (_errorMessage != null) ...[
              GestureDetector(
                onTap: _startUpdate,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _startUpdate,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Atualizar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}