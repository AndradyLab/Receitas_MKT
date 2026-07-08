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
        final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: '');
        final amount = formatter.format(log.amount).trim();  
        final observation = (log.observation ?? '')
            .toString()
            .replaceAll('\t', ' ')
            .replaceAll('\n', ' ')
            .replaceAll('\r', ' ')
            .trim();

        buffer.write("\t$date\t$mktString\t\t\t\t\t\t$amount\t\t\t$observation\n");
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      return ExcelExportResult(ExcelExportStatus.success);
    } catch (e) {
      return ExcelExportResult(ExcelExportStatus.error, message: e.toString());
    }
  }
}