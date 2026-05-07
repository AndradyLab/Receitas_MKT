import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'cash_log_model.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._internal();

  static Future<DatabaseHelper> getInstance() async {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static const String _tableName = 'cash_logs';
  static const String _configTableName = 'app_config';

  Future<Database> _initDatabase() async {

    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'receitas_mkt.db');

    final database = await openDatabase(
      dbPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return database;
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela de logs de caixa
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL,
        photoPath TEXT,
        amount REAL NOT NULL,
        products TEXT NOT NULL,
        employeeName TEXT NOT NULL,
        date TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabela de configuração (para saldo inicial)
    await db.execute('''
      CREATE TABLE $_configTableName (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Índice para busca de logs pendentes
    await db.execute('''
      CREATE INDEX idx_cash_logs_synced ON $_tableName (isSynced)
    ''');

    // Índice para ordenação por data
    await db.execute('''
      CREATE INDEX idx_cash_logs_date ON $_tableName (date DESC)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Versão 2: adiciona coluna isSynced (já na tabela original)
    }
    if (oldVersion < 3) {
      // Versão 3: adiciona tabela de configuração
      await db.execute('''
        CREATE TABLE $_configTableName (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  // ==================== CRUD OPERATIONS ====================

  Future<void> insertCashLog(CashLog log) async {
    final db = await database;
    await db.insert(
      _tableName,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Salva múltiplos logs (para sync batch)
  Future<void> insertCashLogs(List<CashLog> logs) async {
    final db = await database;
    final batch = db.batch();
    for (final log in logs) {
      batch.insert(
        _tableName,
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  Future<List<CashLog>> getAllCashLogs() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => CashLog.fromMap(maps[i]));
  }

  Future<List<CashLog>> getRecentLogs({int limit = 5}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'date DESC',
      limit: limit,
    );

    List<CashLog> recentLogs = List.generate(
      maps.length,
          (i) => CashLog.fromMap(maps[i]),
    );

    return recentLogs.toList();
  }

  /// Leitura de logs filtrados por tipo
  Future<List<CashLog>> getCashLogsByType(CashType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'type = ?',
      whereArgs: [type.index],
    );
    return List.generate(maps.length, (i) => CashLog.fromMap(maps[i]));
  }

  /// Leitura de logs filtrados por data (intervalo)
  Future<List<CashLog>> getCashLogsByDateRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => CashLog.fromMap(maps[i]));
  }

  /// Leitura de logs pendentes de sincronização
  Future<List<CashLog>> getPendingLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'isSynced = 0',
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) => CashLog.fromMap(maps[i]));
  }

  /// Atualiza o status de sincronização
  Future<void> updateSyncStatus(String logId, bool isSynced) async {
    final db = await database;
    await db.update(
      _tableName,
      {'isSynced': isSynced ? 1 : 0},
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  /// Deleta um log pelo ID
  Future<void> deleteCashLog(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deleta múltiplos logs (por ID)
  Future<void> deleteCashLogs(List<String> ids) async {
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit();
  }

  /// Obtém um log pelo ID
  Future<CashLog?> getCashLogById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return CashLog.fromMap(maps[0]);
  }

  /// Conta o total de logs pendentes
  Future<int> countPendingLogs() async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName WHERE isSynced = 0'),
    ) ?? 0;
  }

  /// Salva o saldo inicial na tabela de configuração
  Future<void> saveInitialBalance(double balance) async {
    final db = await database;
    await db.insert(
      _configTableName,
      {'key': 'cached_initial_balance', 'value': balance.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtém o saldo inicial cacheado
  Future<double?> getCachedInitialBalance() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _configTableName,
      where: 'key = ?',
      whereArgs: ['cached_initial_balance'],
    );
    if (maps.isEmpty) return null;
    return double.tryParse(maps[0]['value'] as String);
  }

  /// Deleta todos os dados (para reset completo)
  Future<void> resetDatabase() async {
    final db = await database;
    await db.execute('DROP TABLE IF EXISTS $_tableName');
    await db.execute('DROP TABLE IF EXISTS $_configTableName');
    await _onCreate(db, 3);
  }

  /// Limpa logs sincronizados (para otimização)
  Future<void> cleanSyncedLogs() async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'isSynced = 1',
    );
  }
}