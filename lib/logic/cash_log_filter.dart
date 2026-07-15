import 'package:intl/intl.dart';

import 'package:receitas_mkt/data/cash_log_model.dart';

enum SearchFilter { date, month, observation }

List<CashLog> filterCashLogs(
  List<CashLog> logs,
  String query,
  SearchFilter filter,
) {
  if (query.isEmpty) return [];

  return logs.where((log) {
    return switch (filter) {
      SearchFilter.date =>
        DateFormat('dd/MM/yyyy').format(log.date).contains(query),
      SearchFilter.month => DateFormat('MM').format(log.date).contains(query),
      SearchFilter.observation =>
        log.observation?.toLowerCase().contains(query.toLowerCase()) ??
            false,
    };
  }).toList();
}

String searchHintFor(SearchFilter filter) {
  return switch (filter) {
    SearchFilter.month => 'Digite o número do mês (ex: 01 para Janeiro)',
    SearchFilter.observation => 'Digite o texto da observação',
    SearchFilter.date => 'Buscar por data: dia/mês/ano',
  };
}