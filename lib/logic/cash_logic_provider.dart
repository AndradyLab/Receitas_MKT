import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/cash_log_model.dart';
import '../data/local_database.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  throw UnimplementedError('O databaseProvider deve ser sobrescrito no main.dart');
});

final initialBalanceProvider = AsyncNotifierProvider<InitialBalanceNotifier, double?>(
  InitialBalanceNotifier.new,
);

class InitialBalanceNotifier extends AsyncNotifier<double?> {
  DatabaseHelper get _database => ref.read(databaseProvider);

  @override
  Future<double?> build() async {
    final cachedBalance = await _database.getCachedInitialBalance();
    if (cachedBalance != null) {
      return cachedBalance;
    }

    return 0.0;
  }

  Future<void> updateInitialBalance(double newBalance) async {
    state = const AsyncLoading();

    try {
      await _database.saveInitialBalance(newBalance);

      state = AsyncValue.data(newBalance);
    } catch (e, stack) {
      state = AsyncValue.error('Erro ao atualizar saldo inicial: $e', stack);
    }
  }
}

class CashLogsState extends Equatable {
  final List<CashLog> logs;

  const CashLogsState({
    this.logs = const [],
  });

  CashLogsState copyWith({
    List<CashLog>? logs,
    int? pendingCount,
  }) {
    return CashLogsState(
      logs: logs ?? this.logs,
    );
  }

  double get currentBalance {
    double ingress = 0;
    double egress = 0;

    for (final log in logs) {
      if (log.type == CashType.ingress) {
        ingress += log.amount;
      } else {
        egress += log.amount;
      }
    }

    return ingress - egress;
  }

  List<CashLog> get ingressLogs => logs.where((l) => l.type == CashType.ingress).toList();
  List<CashLog> get egressLogs => logs.where((l) => l.type == CashType.egress).toList();

  List<CashLog> getByDateRange(DateTime start, DateTime end) {
    return logs
        .where((l) {
      return l.date.isAfter(start) || l.date.isAtSameMomentAs(start);
    })
        .where((l) => l.date.isBefore(end) || l.date.isAtSameMomentAs(end))
        .toList();
  }

  @override
  List<Object?> get props => [logs];
}

final cashLogsProvider = AsyncNotifierProvider<CashLogsNotifier, CashLogsState>(
  CashLogsNotifier.new,
);

class CashLogsNotifier extends AsyncNotifier<CashLogsState> {
  DatabaseHelper get _database => ref.read(databaseProvider);

  @override
  Future<CashLogsState> build() async {
    return _fetchState();
  }

  Future<CashLogsState> _fetchState() async {
    final logs = await _database.getAllCashLogs();
    return CashLogsState(logs: logs);
  }

  Future<void> resetFullDBApplication() async {
    state = const AsyncLoading();

    try {
      await _database.deleteAllLogs();

      ref.invalidateSelf();
      ref.invalidate(initialBalanceProvider);

    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<CashLogsState> _fetchRecentState() async {
    final logs = await _database.getRecentLogs();
    return CashLogsState(logs: logs);
  }

  Future<List<CashLog>> searchByEmployee(String query) async {
    final logs = await _database.getAllCashLogs();
    return logs.where((l) => l.employeeName.toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> loadAllLogs() async {
    state = const AsyncLoading();
    try {
      state = AsyncValue.data(await _fetchRecentState());
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadRecentLogs() async {
    state = const AsyncLoading();
    try {
      state = AsyncValue.data(await _fetchState());
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addLog(CashLog log) async {
    state = const AsyncLoading();

    try {
      await _database.insertCashLog(log);

      state = AsyncValue.data(await _fetchState());
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateLog(CashLog log) async {
    state = const AsyncLoading();

    try {
      await _database.insertCashLog(log);
      state = AsyncValue.data(await _fetchState());
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteLog(String id) async {
    state = const AsyncLoading();

    try {
      await _database.deleteCashLog(id);
      state = AsyncValue.data(await _fetchState());
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  List<CashLog> filterByType(CashType type) {
    final logs = state.value?.logs ?? [];
    return logs.where((l) => l.type == type).toList();
  }

  Future<void> clearFilter() async {
    await loadAllLogs();
  }
}