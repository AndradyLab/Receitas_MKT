import 'package:gsheets/gsheets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'cash_log_model.dart';

/// Serviço de integração com Google Sheets
/// Responsável por sincronizar dados offline com a planilha online
class SheetsService {
  static final Logger _logger = Logger('SheetsService');

  static const String _configKey = 'sheets_link';
  static const String _credentialsKey = 'gsheets_credentials';

  static const String _spreadsheetIdKey = 'spreadsheet_id';

  // Nome da aba para logs de caixa
  static const String _logsSheetName = 'Logs';

  // Colunas dos logs (na ordem do Headers das planilhas)
  static const List<String> _logHeaders = [
    'ID',
    'Tipo',
    'Tipo (Exibição)',
    'Valor',
    'Produtos',
    'Funcionário',
    'Data',
    'Sincronizado',
    'Path da Foto',
  ];

  // ==================== CREDENTIALS & CONFIGURATION ====================

  // Cache em memória para evitar múltiplas chamadas
  String? _sheetsLink;
  String? _credentialsJson;
  String? _spreadsheetId;

  void saveSheetsLink(String link) {
    _sheetsLink = link;
  }

  Future<String?> getSheetsLink() async {
    if (_sheetsLink != null) return _sheetsLink;
    final prefs = await SharedPreferences.getInstance();
    _sheetsLink = prefs.getString(_configKey);
    return _sheetsLink;
  }

  void saveCredentials(String json) {
    _credentialsJson = json;
  }

  Future<String?> getCredentials() async {
    if (_credentialsJson != null) return _credentialsJson;
    final prefs = await SharedPreferences.getInstance();
    _credentialsJson = prefs.getString(_credentialsKey);
    return _credentialsJson;
  }

  void saveSpreadsheetId(String id) {
    _spreadsheetId = id;
  }

  Future<String?> getSpreadsheetId() async {
    if (_spreadsheetId != null) return _spreadsheetId;
    final prefs = await SharedPreferences.getInstance();
    _spreadsheetId = prefs.getString(_spreadsheetIdKey);
    return _spreadsheetId;
  }

  Future<void> clearCredentials() async {
    _sheetsLink = null;
    _credentialsJson = null;
    _spreadsheetId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    await prefs.remove(_credentialsKey);
    await prefs.remove(_spreadsheetIdKey);
  }

  // ==================== EXTRACTION ====================

  static String? extractSpreadsheetId(String link) {
    final regex = RegExp(
      r'(?:/d/|/file/d/)([a-zA-Z0-9_-]+)',
    );
    final match = regex.firstMatch(link);
    return match?.group(1);
  }

  // ==================== GSHEETS API ====================

  Future<GSheets> _authenticate() async {
    final credentialsJson = await getCredentials();
    if (credentialsJson == null) {
      throw Exception('Credenciais do Google Sheets não configuradas');
    }
    return GSheets(credentialsJson);
  }

  /// Método auxiliar para abrir a planilha já autenticada e com await
  Future<Spreadsheet> _openSpreadsheet(String spreadsheetId) async {
    final gsheets = await _authenticate();
    return await gsheets.spreadsheet(spreadsheetId);
  }

  // ==================== INITIAL BALANCE OPERATIONS ====================

  Future<double?> loadInitialBalance() async {
    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) {
      _logger.warning('Spreadsheet ID não configurado');
      return null;
    }

    try {
      final spreadsheet = await _openSpreadsheet(spreadsheetId);
      final configSheet = spreadsheet.worksheetByTitle('Config');
      
      if (configSheet != null) {
        final value = await configSheet.values.value(column: 2, row: 1);
        if (value.isNotEmpty) {
          return double.tryParse(value.replaceAll(',', '.'));
        }
      }

      _logger.info('Saldo inicial não configurado na planilha');
      return null;
    } catch (e) {
      _logger.severe('Erro ao carregar saldo inicial: $e');
      rethrow;
    }
  }

  Future<void> saveInitialBalance(double balance) async {
    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) {
      throw Exception('Spreadsheet ID não configurado');
    }

    try {
      final spreadsheet = await _openSpreadsheet(spreadsheetId);

      Worksheet? configSheet;
      try {
        configSheet = spreadsheet.worksheetByTitle('Config');
      } catch (e) {
        _logger.warning('Configurando aba Config: $e');
      }

      configSheet ??= await spreadsheet.addWorksheet('Config');

      await configSheet.values.insertValue(balance, column: 2, row: 1);
    } catch (e) {
      _logger.severe('Erro ao salvar saldo inicial: $e');
      rethrow;
    }
  }

  // ==================== LOGS OPERATIONS ====================

  Future<List<CashLog>> loadLogsFromSheets() async {
    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) {
      throw Exception('Spreadsheet ID não configurado');
    }

    try {
      final spreadsheet = await _openSpreadsheet(spreadsheetId);
      final sheet = spreadsheet.worksheetByTitle(_logsSheetName);

      if (sheet == null) {
        _logger.info('Aba Logs não encontrada, retornando lista vazia');
        return [];
      }

      final rows = await sheet.values.allRows(fromRow: 2);

      if (rows.isEmpty) return [];

      final List<CashLog> logs = [];
      for (final row in rows) {
        try {
          final log = _parseSheetRow(row);
          if (log != null) {
            logs.add(log);
          }
        } catch (e) {
          _logger.warning('Erro ao processar linha: $e');
        }
      }

      return logs;
    } catch (e) {
      _logger.severe('Erro ao carregar logs: $e');
      rethrow;
    }
  }

  Future<void> batchUpsertLogs(List<CashLog> logs) async {
    if (logs.isEmpty) return;

    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) {
      throw Exception('Spreadsheet ID não configurado');
    }

    // ✅ CORRIGIDO: Usando o método que já faz o await adequadamente
    final spreadsheet = await _openSpreadsheet(spreadsheetId);

    Worksheet? sheet;
    try {
      sheet = spreadsheet.worksheetByTitle(_logsSheetName);
    } catch (e) {
      _logger.info('Criando aba Logs: $e');
    }
    sheet ??= await spreadsheet.addWorksheet(_logsSheetName);

    final existingIds = await sheet.values.column(1, fromRow: 2);

    final List<String> newIds = [];
    final List<String> updateIds = [];

    for (final log in logs) {
      if (existingIds.contains(log.id)) {
        updateIds.add(log.id);
      } else {
        newIds.add(log.id);
      }
    }

    if (newIds.isNotEmpty) {
      final newLogs = logs.where((l) => newIds.contains(l.id)).toList();
      final newRows = newLogs.map(_toSheetRow).toList();
      await sheet.values.appendRows(newRows);
    }

    if (updateIds.isNotEmpty) {
      final updatedLogs = logs.where((l) => updateIds.contains(l.id)).toList();
      for (final log in updatedLogs) {
        final rowIndex = existingIds.indexOf(log.id) + 2; 
        await sheet.values.insertRow(rowIndex, _toSheetRow(log));
      }
    }

    _logger.info('Sincronizados ${logs.length} logs com a planilha');
  }

  Future<void> appendLog(CashLog log) async {
    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) {
      throw Exception('Spreadsheet ID não configurado');
    }

    // ✅ CORRIGIDO: Usando o método que já faz o await adequadamente
    final spreadsheet = await _openSpreadsheet(spreadsheetId);

    Worksheet? sheet;
    try {
      sheet = spreadsheet.worksheetByTitle(_logsSheetName);
    } catch (e) {
      // ignore
    }
    sheet ??= await spreadsheet.addWorksheet(_logsSheetName);

    await sheet.values.appendRow(_toSheetRow(log));
    _logger.info('Log ${log.id} adicionado à planilha');
  }

  Future<void> updateLogSyncStatus(String logId, bool isSynced) async {
    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) {
      throw Exception('Spreadsheet ID não configurado');
    }

    // ✅ CORRIGIDO: Usando o método que já faz o await adequadamente
    final spreadsheet = await _openSpreadsheet(spreadsheetId);

    Worksheet? sheet;
    try {
      sheet = spreadsheet.worksheetByTitle(_logsSheetName);
    } catch (e) {
      _logger.warning('Aba Logs não encontrada: $e');
      return;
    }

    if (sheet == null) return;

    final existingIds = await sheet.values.column(1, fromRow: 2);
    final index = existingIds.indexOf(logId);

    if (index != -1) {
      final rowIndex = index + 2;
      await sheet.values.insertValue(isSynced ? 'Sim' : 'Não', column: 8, row: rowIndex);
    }
  }

  // ==================== HELPER METHODS ====================

  CashLog? _parseSheetRow(List<String> row) {
    try {
      String safeGet(int index) => index < row.length ? row[index] : '';

      final id = safeGet(0);
      if (id.isEmpty) return null;

      final typeIndex = int.tryParse(safeGet(1)) ?? 0;
      final amountStr = safeGet(3).replaceAll(',', '.');
      final amount = double.tryParse(amountStr) ?? 0.0;
      
      final observation = safeGet(4);
      final employeeName = safeGet(5);
      final dateString = safeGet(6);
      final date = DateTime.tryParse(dateString) ?? DateTime.now();
      
      final isSyncedValue = safeGet(7).toLowerCase();
      final isSynced = isSyncedValue == 'sim' || isSyncedValue == 'true' || isSyncedValue == '1';
      
      final photoPath = safeGet(8);

      return CashLog(
        id: id,
        type: CashType.values[typeIndex],
        photoPath: photoPath.isEmpty ? null : photoPath,
        amount: amount,
        observation: observation,
        employeeName: employeeName,
        date: date,
        isSynced: isSynced,
      );
    } catch (e) {
      _logger.warning('Erro ao processar linha: $e');
      return null;
    }
  }

  List<dynamic> _toSheetRow(CashLog log) {
    return [
      log.id,
      log.type.index,
      log.type.displayName,
      log.amount,
      log.observation,
      log.employeeName,
      log.date.toIso8601String(),
      log.isSynced ? 'Sim' : 'Não',
      log.photoPath ?? '',
    ];
  }
}