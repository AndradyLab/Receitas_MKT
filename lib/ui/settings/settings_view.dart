import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:receitas_mkt/logic/pdf_service.dart';
import 'package:receitas_mkt/logic/excel_service.dart';
import 'package:receitas_mkt/logic/update_android_service.dart';
import 'package:receitas_mkt/ui/widgets/shared_widgets.dart';
import 'package:receitas_mkt/ui/widgets/update_widget.dart';

import 'package:receitas_mkt/logic/cash_logic_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  late final TextEditingController _initialDateController;
  late final TextEditingController _finalDateController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGeneratingPdf = false;
  String? pdfErrorMessage;
  bool _isGeneratingExcel = false;
  String? excelErrorMessage;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _initialDateController = TextEditingController();
    _finalDateController = TextEditingController();
  }

  @override
  void dispose() {
    _initialDateController.dispose();
    _finalDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(context, 'Sistema'),
          _buildSystemSection(context, ref),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Exportação'),
          _buildPDFSystem(context, ref),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Atualizações'),
          _buildUpdateSection(context),
          const SizedBox(height: 24), 
          _buildSectionTitle(context, 'Sobre'),
          _buildAboutSection(context),
        ],
      ),
      bottomNavigationBar: const BottomBar(),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSystemSection(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Apagar Histórico de transações'),
            subtitle: const Text('Toda a base de dados será destruída e nenhum dado ficará salvo no sistema'),
            leading: const Icon(Icons.delete_forever),
            onTap: () => _showResetDatabase(context, ref),
          ),

        ],
      ),
    );
  }

  Future<void> _showResetDatabase(BuildContext context, WidgetRef ref) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir base de dados'),
        content: const Text("Deseja exluir toda sua base de dados?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(cashLogsProvider(false).notifier).resetFullDBApplication();

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seus dados foram excluídos com sucesso.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Apagar Tudo'),
          ),
        ],
      ),
    );
  }

  Widget _buildPDFSystem(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Exportação em PDF'),
            subtitle: const Text('Gerar arquivo PDF das transações.'),
            leading: const Icon(Icons.file_download),
            onTap: () => _showPDFGenerate(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Exportar para Excel'),
            subtitle: const Text('Copiar transações para colar em uma planilha.'),
            leading: const Icon(Icons.table_chart_outlined),
            onTap: () => _showExcelExport(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre o App'),
            subtitle: const Text('Gerenciador de Fluxo de Caixa'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text('Suporte'),
            subtitle: const Text('Ajuda e dúvidas frequentes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSupportDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = pickedDate;
          _initialDateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
        } else {
          _endDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 23, 59, 59);
          _finalDateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
        }
      });
    }
  }

  Future<void> _showPDFGenerate(BuildContext context, WidgetRef ref) async {
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) =>
              AlertDialog(
                title: const Text('Gerar PDF'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              await _selectDate(isStart: true);
                              setDialogState(() => pdfErrorMessage = null);
                            },
                            child: IgnorePointer(
                              child: TextField(
                                controller: _initialDateController,
                                decoration: const InputDecoration(
                                  labelText: 'Início',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              await _selectDate(isStart: false);
                              setDialogState(() => pdfErrorMessage = null);
                            },
                            child: IgnorePointer(
                              child: TextField(
                                controller: _finalDateController,
                                decoration: const InputDecoration(
                                  labelText: 'Fim',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (pdfErrorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        pdfErrorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: _isGeneratingPdf ? null : () =>
                        Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: _isGeneratingPdf
                        ? null
                        : () async {
                      if (_startDate == null || _endDate == null) {
                        setDialogState(() {
                          pdfErrorMessage =
                          'Selecione as duas datas.';
                        });
                        return;
                      }

                      setDialogState(() => _isGeneratingPdf = true);
                      setState(() {});

                      final cashState = ref
                          .read(cashLogsProvider(false))
                          .value;

                      if (cashState == null) {
                        setDialogState(() => _isGeneratingPdf = false);
                        setState(() {});
                        if (!mounted) return;
                        setDialogState(() {
                          pdfErrorMessage =
                          'Dados ainda carregando, tente novamente.';
                        });
                        return;
                      }

                      final logsInRange = cashState.getByDateRange(
                          _startDate!, _endDate!);

                      final initialBalance = ref
                          .read(initialBalanceProvider)
                          .value ?? 0.0;
                      final savedBalance = initialBalance +
                          cashState.currentBalance;

                      final pdfService = ref.read(pdfServiceProvider);
                      final result = await pdfService.generateAndSharePDF(
                        logs: logsInRange,
                        currentBalance: savedBalance,
                        startDate: _startDate!,
                        endDate: _endDate!,
                      );

                      setDialogState(() => _isGeneratingPdf = false);
                      setState(() {});

                      if (!mounted) return;
                      Navigator.pop(dialogContext);

                      final messages = {
                        PdfExportStatus
                            .empty: 'Não há lançamentos nesse período.',
                        PdfExportStatus.error: 'Erro ao gerar PDF.',
                        PdfExportStatus.success: 'PDF exportado com sucesso!',
                      };

                      if (result.status != PdfExportStatus.cancelled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(messages[result.status]!)),
                        );
                      }
                    },
                    child: _isGeneratingPdf
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Gerar PDF'),
                  ),
                ],
              ),
        );
      },
    );
  }

  Future<void> _showExcelExport(BuildContext context, WidgetRef ref) async {
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Exportar para Excel'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          await _selectDate(isStart: true);
                          setDialogState(() => excelErrorMessage = null);
                        },
                        child: IgnorePointer(
                          child: TextField(
                            controller: _initialDateController,
                            decoration: const InputDecoration(
                              labelText: 'Início',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          await _selectDate(isStart: false);
                          setDialogState(() => excelErrorMessage = null);
                        },
                        child: IgnorePointer(
                          child: TextField(
                            controller: _finalDateController,
                            decoration: const InputDecoration(
                              labelText: 'Fim',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (excelErrorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    excelErrorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isGeneratingExcel ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: _isGeneratingExcel
                    ? null
                    : () async {
                        if (_startDate == null || _endDate == null) {
                          setDialogState(() {
                            excelErrorMessage = 'Selecione as duas datas.';
                          });
                          return;
                        }

                        setDialogState(() => _isGeneratingExcel = true);
                        setState(() {});

                        final cashState = ref.read(cashLogsProvider(false)).value;

                        if (cashState == null) {
                          setDialogState(() => _isGeneratingExcel = false);
                          setState(() {});
                          if (!mounted) return;
                          setDialogState(() {
                            excelErrorMessage = 'Dados ainda carregando, tente novamente.';
                          });
                          return;
                        }

                        final logsInRange = cashState.getByDateRange(_startDate!, _endDate!);

                        final excelService = ref.read(excelServiceProvider);
                        final result = await excelService.exportToClipboard(logsInRange);

                        setDialogState(() => _isGeneratingExcel = false);
                        setState(() {});

                        if (!mounted) return;
                        Navigator.pop(dialogContext);

                        final messages = {
                          ExcelExportStatus.empty: 'Não há lançamentos nesse período.',
                          ExcelExportStatus.error: 'Erro ao exportar.',
                          ExcelExportStatus.success: 'Copiado! Cole no Excel com Ctrl+V.',
                        };

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(messages[result.status]!)),
                        );
                      },
                child: _isGeneratingExcel
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Copiar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sobre'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receitas Marketing'),
            SizedBox(height: 8),
            Text('Versão: 1.0.0'),
            SizedBox(height: 8),
            Text('Gerenciador de fluxo de caixa para área de marketing'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupportDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suporte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined, color: Colors.blue),
              title: const Text('Email'),
              subtitle: const Text('viniciusandradeprog@gmail.com'),
              onTap: () => _openLink(context, 'mailto:viniciusandradeprog@gmail.com'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_outlined, color: Colors.green),
              title: const Text('WhatsApp'),
              subtitle: const Text('(85) 99278-4784'),
              onTap: () => _openLink(context, 'https://wa.me/5585992784784'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum aplicativo encontrado para abrir este link.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro inesperado ao tentar abrir o link.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Widget _buildUpdateSection(BuildContext context) {
  return Card(
    child: ListTile(
      leading: _checkingUpdate
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.system_update),
      title: const Text('Verificar atualizações'),
      subtitle: const Text('Checar se há uma nova versão disponível'),
      onTap: _checkingUpdate ? null : _checkForUpdateManually,
    ),
  );
}

Future<void> _checkForUpdateManually() async {
  setState(() => _checkingUpdate = true);

  try {
    final update = await UpdateService().checkForUpdate();

    if (!mounted) return;

    if (update != null) {
      showUpdateToast(context, update);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você já está na versão mais recente.')),
      );
    }
  } catch (_) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível verificar atualizações.')),
      );
    }
  } finally {
    if (mounted) setState(() => _checkingUpdate = false);
  }
}
}

