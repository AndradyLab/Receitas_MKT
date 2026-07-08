import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Importe o seu modelo de log
// import 'package:receitas_mkt/models/cash_log.dart'; 

final excelServiceProvider = Provider<ExcelService>((ref) {
  return ExcelService();
});

class ExcelService {
  Future<bool> exportToClipboard(List<dynamic> logs) async {
    if (logs.isEmpty) return false;

    final buffer = StringBuffer();

    for (var log in logs) {
      final date = DateFormat('dd/MM/yyyy').format(log.date);
      
      const mktString = "MKT";
      
      final amount = log.amount.toStringAsFixed(2).replaceAll('.', ',');
      
      final description = log.description ?? '';

      buffer.write("$date\t$mktString\t\t$amount\t$description\n");
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    return true;
  }
}