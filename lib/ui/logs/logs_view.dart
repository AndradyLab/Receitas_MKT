import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:receitas_mkt/data/cash_log_model.dart';
import 'package:receitas_mkt/logic/cash_logic_provider.dart';
import 'package:receitas_mkt/ui/widgets/shared_widgets.dart';

class LogsView extends ConsumerWidget {
  const LogsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashLogsAsync = ref.watch(cashLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Registros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context, ref),
          ),
        ],
      ),
      body: cashLogsAsync.when(
        loading: () => _buildLoading(),
        error: (e, stack) => _buildError(e.toString()),
        data: (state) {
          if (state.logs.isEmpty) {
            return _buildEmpty(context);
          }
          return _buildLogsList(context, ref, state.logs);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(context),
        backgroundColor: Colors.green,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: Colors.green.shade200,
        hoverElevation: 12.0,
        splashColor: Colors.green.shade700,
        icon: const Icon(Icons.add),
        label: const Text('Novo Registro'),
      ),
      bottomNavigationBar: const BottomBar(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Carregando registros...'),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Text('Erro ao carregar logs: $message'),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 64, color: Color(0xFF9E9E9E)),
          const SizedBox(height: 16),
          const Text('Nenhum registro encontrado'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/form'),
            child: const Text('Adicionar primeiro registro'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(BuildContext context, WidgetRef ref, List<CashLog> logs) {
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CashTypeBadge(type: log.type),
                Text(
                  _formatDate(log.date),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            title: Text(
              log.employeeName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (log.observation == null || log.observation!.isEmpty)
                  ? 'Sem observação' : log.observation!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                if (log.photoPath == null)
                  Text(
                    "Não possui nota fiscal",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  )
                else
                  Text(
                    "Possui nota fiscal",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
            trailing: Text(
              formatter.format(log.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: log.type == CashType.ingress ? Colors.green : Colors.red,
              ),
            ),
            onTap: () => _showLogDetails(context, ref, log),
          ),
        );
      },
    );
  }

  Future<void> _showSearchDialog(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController();
    List<CashLog> filteredLogs = [];
    SearchFilter currentFilter = SearchFilter.employee;
    return showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (BuildContext ctx, setState) => AlertDialog(
          title: const Text('Buscar Registros'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: currentFilter == SearchFilter.employee
                        ? 'Nome do funcionário...'
                        : 'Buscar por data: dia/mês/ano',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: PopupMenuButton<SearchFilter>(
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Filtrar por',
                      initialValue: currentFilter,
                      onSelected: (SearchFilter result) {
                        setState(() {
                          currentFilter = result;
                          controller.clear();
                          filteredLogs = [];
                        });
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<SearchFilter>>[
                        const PopupMenuItem<SearchFilter>(
                          value: SearchFilter.employee,
                          child: Text('Funcionário'),
                        ),
                        const PopupMenuItem<SearchFilter>(
                          value: SearchFilter.date,
                          child: Text('Data'),
                        ),
                      ],
                    ),
                  ),
                  autofocus: true,
                  onChanged: (value) {
                    final currentState = ref.read(cashLogsProvider).value;
                    if (value.isNotEmpty && currentState != null) {
                      final results = currentState.logs.where((log) => switch (currentFilter) {
                        SearchFilter.employee => log.employeeName.toLowerCase().contains(value.toLowerCase()),
                        SearchFilter.date     => DateFormat('dd/MM/yyyy').format(log.date).contains(value),                      }).toList();
                      setState(() => filteredLogs = results);
                    } else {
                      setState(() => filteredLogs = []);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: controller.text.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Faça uma busca para filtrar os seus dados.'),
                  ) : filteredLogs.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            return ListTile(
                              leading: CashTypeBadge(type: log.type),
                              title: Text(log.employeeName),
                              subtitle: Text(
                                log.observation ?? 'Sem observação',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(NumberFormat.currency(
                                      locale: 'pt_BR', symbol: 'R\$')
                                  .format(log.amount)),
                              onTap: () {
                                Navigator.pop(context);
                                _showLogDetails(context, ref, log);
                              },
                            );
                          },
                        )
                      : const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Nenhum resultado encontrado'),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogDetails(BuildContext context, WidgetRef ref, CashLog log) async {
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(log.type == CashType.ingress ? Icons.arrow_upward : Icons.arrow_downward),
            const SizedBox(width: 8),
            Text(log.type.displayName),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(context, 'Valor', formatter.format(log.amount)),
              _buildDetailRow(context, 'Funcionário', log.employeeName),
              _buildDetailRow(context, 'Data', _formatDate(log.date)),
              if (log.observation != null)
                _buildDetailRow(context, 'Observação', log.observation!),
              if (log.photoPath != null)
                _buildDetailRow(context, 'Nota Fiscal', log.photoPath!.split('/').last),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _confirmDelete(context, ref, log),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
          TextButton(
            onPressed: () => _editLog(context, ref, log),
            child: const Text('Editar'),
          ),
          if (log.photoPath != null)
            TextButton(
              onPressed: () => showPhoto(context, log.photoPath!),
              child: const Text('Ver Nota'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editLog(BuildContext context, WidgetRef ref, CashLog log) async {
    final TextEditingController amountController = TextEditingController(text: log.amount.toString());
    final TextEditingController employeeController = TextEditingController(text: log.employeeName);
    final TextEditingController observationController = TextEditingController(text: log.observation);

    final ImagePicker picker = ImagePicker();

    CashType selectedType = log.type;
    DateTime selectedDate = log.date;
    String? selectedPhotoPath = log.photoPath;
    String? valueError;
    String? employeeError;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Editar Registro',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          selectedType == CashType.ingress ? Icons.arrow_upward : Icons.arrow_downward,
                          color: selectedType == CashType.ingress ? Colors.green : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: DropdownButtonFormField<CashType>(
                                initialValue: selectedType,
                                decoration: const InputDecoration(
                                    labelText: "Tipo de transação",
                                    border: OutlineInputBorder()
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: CashType.ingress,
                                    child: Text('Receita'),
                                  ),
                                  DropdownMenuItem(
                                    value: CashType.egress,
                                    child: Text('Despesa'),
                                  ),
                                ],
                                onChanged: (CashType? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      selectedType = newValue;
                                    });
                                  }
                                }
                            )
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        if (valueError != null) {
                          setState(() => valueError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Valor (R\$)',
                        prefixText: 'R\$ ',
                        errorText: valueError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: employeeController,
                      onChanged: (value) {
                        if (employeeError != null) {
                          setState(() => employeeError = null) ;
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Funcionário',
                        errorText: employeeError
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: observationController,
                      decoration: const InputDecoration(
                        labelText: 'Observação',
                        hintText: 'Digite sua observação',
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Data: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      ),
                      onPressed: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate != null) {
                          setState(() => selectedDate = pickedDate);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text('Nota Fiscal:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (selectedPhotoPath != null)
                      Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.visibility),
                            label: const Text('Visualizar'),
                            onPressed: () => showPhoto(context, selectedPhotoPath!),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Trocar'),
                            onPressed: () async {
                              final file = await picker.pickImage(source: ImageSource.gallery);
                              if (file != null) {
                                setState(() => selectedPhotoPath = file.path);
                              }
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Nova foto'),
                            onPressed: () async {
                              final file = await picker.pickImage(source: ImageSource.camera);
                              if (file != null) {
                                setState(() => selectedPhotoPath = file.path);
                              }
                            }
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Câmera'),
                            onPressed: () async {
                              final file = await picker.pickImage(source: ImageSource.camera);
                              if (file != null) {
                                setState(() => selectedPhotoPath = file.path);
                              }
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.image),
                            label: const Text('Galeria'),
                            onPressed: () async {
                              final file = await picker.pickImage(source: ImageSource.gallery);
                              if (file != null) {
                                setState(() => selectedPhotoPath = file.path);
                              }
                            },
                          ),
                        ],
                      ),

                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar')
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final cleanAmountText = amountController.text.replaceAll(',', '.');
                            final newAmount = double.tryParse(cleanAmountText);
                            final newEmployee = employeeController.text.trim();
                            final obsText = observationController.text.trim();
                            final finalObservation = obsText.isEmpty ? null : obsText;

                            if (newAmount == null || newAmount <= 0) {
                              setState(() {
                                valueError = 'Digite um número válido';
                              });
                              return;
                            }

                            if (newEmployee.isEmpty) {
                              setState(() {
                                employeeError = 'Digite o nome do funcionário';
                              });
                              return;
                            }

                            if (newEmployee.isNotEmpty) {
                              final updatedLog = log.copyWith(
                                amount: newAmount,
                                employeeName: newEmployee,
                                type: selectedType,
                                date: selectedDate,
                                observation: finalObservation,
                                photoPath: selectedPhotoPath,
                              );

                              await ref.read(cashLogsProvider.notifier).updateLog(updatedLog);

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Registro atualizado com sucesso'),
                                    backgroundColor: Colors.white,
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Preencha um valor válido e o nome do funcionário.')
                                ),
                              );
                            }
                          },
                          child: const Text('Salvar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, CashLog log) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Deseja remover permanentemente este registro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(cashLogsProvider.notifier).deleteLog(log.id);
              if (!context.mounted) return;
              Navigator.of(context)..pop()..pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Excluído com sucesso')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _navigateToForm(BuildContext context) async {
    context.go('/form');
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      ),
    );
  }
}

enum SearchFilter { employee, date }