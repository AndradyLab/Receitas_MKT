import 'dart:io';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/cash_log_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pdfServiceProvider = Provider<PdfService>((ref) {
  return PdfService();
});

enum PdfExportStatus { success, cancelled, empty, error }

class PdfExportResult {
  final PdfExportStatus status;
  final String? message;
  const PdfExportResult(this.status, [this.message]);
}

class _PdfBuildParams {
  final List<CashLog> logs;
  final double currentBalance;
  final DateTime startDate;
  final DateTime endDate;

  _PdfBuildParams({
    required this.logs,
    required this.currentBalance,
    required this.startDate,
    required this.endDate,
  });
}

class PdfService {
  Future<PdfExportResult> generateAndSharePDF({
    required List<CashLog> logs,
    required double currentBalance,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (logs.isEmpty) {
      return const PdfExportResult(PdfExportStatus.empty);
    }

    try {
      final params = _PdfBuildParams(
        logs: logs,
        currentBalance: currentBalance,
        startDate: startDate,
        endDate: endDate,
      );

    final Uint8List bytes = await Isolate.run(() => _buildPdfBytes(params));

    final String fileName = "Relatorio_Caixa_${DateTime.now().toString()}.pdf".replaceAll(".", "_");

    if (Platform.isWindows || Platform.isLinux) {
      return _saveOnDesktop(bytes, fileName);
    }

    return _shareOnMobile(bytes, fileName);
    } catch (e) {
      return PdfExportResult(PdfExportStatus.error, e.toString());
    }
}
  Future<PdfExportResult> _saveOnDesktop(Uint8List bytes, String fileName) async {
    final String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Salvar relatório PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );

    if (savePath == null) {
      return const PdfExportResult(PdfExportStatus.cancelled);
    }

    final file = File(savePath);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }

    return PdfExportResult(PdfExportStatus.success, savePath);
  }

  Future<PdfExportResult> _shareOnMobile(Uint8List bytes, String fileName) async {
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(bytes);

    final result = await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Relatorio Fluxo de Caixa',
    );

    if (result.status == ShareResultStatus.dismissed) {
      return const PdfExportResult(PdfExportStatus.cancelled);
    }

    return const PdfExportResult(PdfExportStatus.success);
  }
}

Future<Uint8List> _buildPdfBytes(_PdfBuildParams params) async {
  final pdf = pw.Document();

  final List<pw.TableRow> tableRows = [];
  final List<_PhotoEntry> photoEntries = [];

  tableRows.add(
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        _buildHeaderCell('Data'),
        _buildHeaderCell('Tipo'),
        _buildHeaderCell('Funcionario'),
        _buildHeaderCell('Observacao'),
        _buildHeaderCell('Valor'),
        _buildHeaderCell('Nota fiscal'),
      ],
    ),
  );

  for (int i = 0; i < params.logs.length; i++) {
    final log = params.logs[i];
    final anchorName = 'foto_$i';

    pw.Widget photoCell = pw.Text('-', textAlign: pw.TextAlign.center);

    if (log.photoPath != null && log.photoPath!.isNotEmpty) {
      final file = File(log.photoPath!);
      if (await file.exists()) {
        final imageBytes = await file.readAsBytes();

        photoEntries.add(_PhotoEntry(
          anchorName: anchorName,
          imageBytes: imageBytes,
          date: log.date,
          employeeName: log.employeeName,
          observation: log.observation ?? '',
        ));

        photoCell = pw.Link(
          destination: anchorName,
          child: pw.Text(
            'Ver Nota',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blue,
              decoration: pw.TextDecoration.underline,
            ),
            textAlign: pw.TextAlign.center,
          ),
        );
      }
    }

    tableRows.add(
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          _buildDataCell(DateFormat('dd/MM/yyyy').format(log.date)),
          _buildDataCell(log.type.displayName),
          _buildDataCell(log.employeeName),
          _buildDataCell(log.observation ?? ''),
          _buildDataCell('R\$ ${log.amount.toStringAsFixed(2)}'),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Center(child: photoCell),
          ),
        ],
      ),
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Text('Relatorio de fluxo de caixa',
                style:
                pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text(
              'Periodo: ${DateFormat('dd/MM/yyyy').format(params.startDate)} ate ${DateFormat('dd/MM/yyyy').format(params.endDate)}'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Center(
              child: pw.Text(
                'Saldo em caixa: R\$ ${params.currentBalance.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2.0),
              3: const pw.FlexColumnWidth(2.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(1.5),
            },
            children: tableRows,
          ),
          if (photoEntries.isNotEmpty) ...[
          pw.NewPage(),
            pw.Header(
              level: 0,
              child: pw.Text('Anexo de fotos',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            for (final entry in photoEntries)
              pw.Anchor(
                name: entry.anchorName,
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${entry.employeeName} - ${DateFormat('dd/MM/yyyy').format(entry.date)}\n${entry.observation}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Image(
                        pw.MemoryImage(entry.imageBytes),
                        width: 300,
                        fit: pw.BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ];
      },
    ),
  );

  return pdf.save();
}

class _PhotoEntry {
  final String anchorName;
  final Uint8List imageBytes;
  final DateTime date;
  final String employeeName;
  final String observation;

  _PhotoEntry({
    required this.anchorName,
    required this.imageBytes,
    required this.date,
    required this.employeeName,
    required this.observation
  });
}

pw.Widget _buildHeaderCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _buildDataCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 10),
      textAlign: pw.TextAlign.left,
    ),
  );
}