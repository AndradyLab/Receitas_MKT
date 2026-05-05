import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/local_database.dart';
import '../data/cash_log_model.dart';
import '../data/sheets_service.dart';

/// Controller responsável pela sincronização offline→online
class SyncController {
  static final Logger _logger = Logger('SyncController');

  final DatabaseHelper database;
  final SheetsService sheetsService;

  /// Estado da sincronização
  bool _isSyncing = false;
  int _failedAttempts = 0;
  final List<String> _pendingIds = [];

  SyncController(this.database, this.sheetsService);

  // ==================== PUBLIC API ====================

  /// Sincroniza todos os logs pendentes com o Google Sheets
  /// Retorna o número de logs sincronizados com sucesso
  Future<int> syncPendingLogs() async {
    if (_isSyncing) {
      _logger.info('Sincronização já em andamento');
      return 0;
    }

    // Verifica conectividade antes de começar
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _logger.warning('Sem conectividade de rede');
      throw Exception('Não é possível sincronizar sem conexão com a internet');
    }

    _isSyncing = true;
    _failedAttempts = 0;

    try {
      // Carrega logs pendentes
      final pendingLogs = await database.getPendingLogs();
      final totalLogs = pendingLogs.length;

      _logger.info('Iniciando sincronização de $totalLogs logs');

      // Separa por batch para evitar timeouts
      const batchSize = 50;
      int syncedCount = 0;

      for (var i = 0; i < pendingLogs.length; i += batchSize) {
        final batch = pendingLogs.sublist(
          i,
          i + batchSize > pendingLogs.length ? pendingLogs.length : i + batchSize,
        );

        try {
          await sheetsService.batchUpsertLogs(batch);

          // Atualiza status de sincronização
          for (final log in batch) {
            await database.updateSyncStatus(log.id, true);
            _pendingIds.remove(log.id);
          }

          syncedCount += batch.length;

          _logger.info('Sincronizados ${batch.length} logs (Total: $syncedCount/$totalLogs)');
        } catch (e) {
          _failedAttempts++;
          _logger.warning('Falha no batch ${i ~/ batchSize + 1}: $e');

          if (_failedAttempts >= 3) {
            _logger.severe('3 falhas consecutivas. Parando sincronização.');
            throw Exception('Falha ao sincronizar após 3 tentativas');
          }

          // Retorna os logs que falharam para reprocessamento
          for (final log in batch) {
            await database.updateSyncStatus(log.id, false);
          }
        }
      }

      _logger.info('Sincronização concluída: $syncedCount/$totalLogs logs');

      return syncedCount;
    } finally {
      _isSyncing = false;
    }
  }

  /// Enfileira um log para sincronização
  /// O log já deve ter sido salvo no banco antes
  Future<void> queueForSync(CashLog log) async {
    // O log já nascem com isSynced: false no database
    // Este método apenas registra a intenção de sync
    _pendingIds.add(log.id);
    _logger.info('Log ${log.id} enfileirado para sincronização');
  }

  /// Sincronização em segundo plano (chamada periódica)
  Future<void> backgroundSync() async {
    if (_isSyncing) return;

    try {
      final synced = await syncPendingLogs();
      _logger.info('Sincronização em background: $synced logs');
    } catch (e) {
      _logger.warning('Sincronização em background falhou: $e');
    }
  }

  /// Tenta sincronizar logs que estavam pending
  /// Útil após recuperação de offline
  Future<void> retryPendingSync() async {
    if (_isSyncing) return;

    try {
      final synced = await syncPendingLogs();
      _logger.info('Tentativa de sync após falha: $synced logs');
    } catch (e) {
      _logger.warning('Nova tentativa de sync falhou: $e');
    }
  }

  /// Verifica estado de sincronização
  Future<bool> hasPendingLogs() async {
    final count = await database.countPendingLogs();
    return count > 0;
  }

  /// Obtém o número de logs pendentes
  Future<int> getPendingCount() async {
    return await database.countPendingLogs();
  }

  /// Limpa o estado de erro e reseta contadores
  void resetErrors() {
    _failedAttempts = 0;
    _isSyncing = false;
  }

  // ==================== STATUS METHODS ====================

  /// Texto descritivo do status atual
  Future<String> getStatusText() async {
    final pending = await database.countPendingLogs();
    if (pending > 0) {
      return '$pending pendente(s)';
    }
    return 'Sincronizado';
  }

  /// Cor baseada no status (para UI)
  Future<Color> getStatusColor() async {
    final pending = await database.countPendingLogs();
    if (pending > 0) {
      return Colors.orange;
    }
    return Colors.green;
  }

  /// Ícone baseado no status
  Future<IconData> getStatusIcon() async {
    final pending = await database.countPendingLogs();
    if (pending > 0) {
      return Icons.sync_problem;
    }
    return Icons.check_circle;
  }
}
