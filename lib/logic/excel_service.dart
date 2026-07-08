import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum ExcelExportStatus { success, empty, error }

class ExcelExportResult {
  final ExcelExportStatus status;
  final String? message;

  ExcelExportResult(this.status, {this.message});
}

final excelServiceProvider = Provider<ExcelService>((ref) {
  return ExcelService();
});

class ExcelService {
  Future<ExcelExportResult> exportToClipboard(List<dynamic> logs) async {
    if (logs.isEmpty) {
      return ExcelExportResult(ExcelExportStatus.empty);
    }

    try {
      final buffer = StringBuffer();

      for (var log in logs) {
        final date = DateFormat('dd/MM/yyyy').format(log.date);

        const mktString = "MKT";

        final amount = log.amount.toStringAsFixed(2).replaceAll('.', ',');

        final description = (log.description ?? '')
            .toString()
            .replaceAll('\t', ' ')
            .replaceAll('\n', ' ')
            .replaceAll('\r', ' ')
            .trim();

        buffer.write("$date\t$mktString\t\t$amount\t$description\n");
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      return ExcelExportResult(ExcelExportStatus.success);
    } catch (e) {
      return ExcelExportResult(ExcelExportStatus.error, message: e.toString());
    }
  }
}