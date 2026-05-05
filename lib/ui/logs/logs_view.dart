import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:receitas_mkt/data/cash_log_model.dart';
import 'package:receitas_mkt/logic/cash_logic_provider.dart';
import 'package:receitas_mkt/ui/form/form_view.dart';
import 'package:receitas_mkt/ui/widgets/shared_widgets.dart';

class LogsView extends ConsumerWidget {
  const LogsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashLogsAsync = ref.watch(cashLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Logs'),
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
            onPressed: () => _navigateToForm(context),
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
                const SizedBox(height: 4),
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
                  log.products.isNotEmpty ? log.products.join(', ') : 'Sem produtos',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  log.isSynced ? 'Sincronizado' : 'Pendente',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: log.isSynced ? Colors.green : Colors.orange,
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
                  decoration: const InputDecoration(
                    hintText: 'Nome do funcionário...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  autofocus: true,
                  onChanged: (value) {
                    final currentState = ref.read(cashLogsProvider).value;
                    if (value.isNotEmpty && currentState != null) {
                      final results = currentState.logs
                          .where((log) => log.employeeName
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                          .toList();
                      setState(() => filteredLogs = results);
                    } else {
                      setState(() => filteredLogs = []);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: filteredLogs.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            return ListTile(
                              leading: CashTypeBadge(type: log.type),
                              title: Text(log.employeeName),
                              subtitle: Text(log.products.join(', ')),
                              trailing: Text(NumberFormat.currency(
                                      locale: 'pt_BR', symbol: 'R\$')
                                  .format(log.amount)),
                              onTap: () {
                                Navigator.pop(dialogContext);
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
              onPressed: () => Navigator.pop(dialogContext),
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
              _buildDetailRow(context, 'ID', log.id),
              _buildDetailRow(context, 'Valor', formatter.format(log.amount)),
              _buildDetailRow(context, 'Funcionário', log.employeeName),
              _buildDetailRow(context, 'Data', _formatDate(log.date)),
              if (log.products.isNotEmpty)
                _buildDetailRow(context, 'Produtos', log.products.join(', ')),
              _buildDetailRow(context, 'Status de Sync', log.isSynced ? 'Sincronizado' : 'Pendente'),
              if (log.photoPath != null)
                _buildDetailRow(context, 'Foto', log.photoPath!.split('/').last),
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
              onPressed: () => _showPhoto(context, log.photoPath!),
              child: const Text('Ver Foto'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPhoto(BuildContext context, String photoPath) async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photoPath),
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editLog(BuildContext context, WidgetRef ref, CashLog log) async {
    final TextEditingController amountController = TextEditingController(text: log.amount.toString());
    final TextEditingController employeeController = TextEditingController(text: log.employeeName);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Registro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valor (R\$)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: employeeController,
              decoration: const InputDecoration(labelText: 'Funcionário'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final newAmount = double.tryParse(amountController.text);
              final newEmployee = employeeController.text.trim();

              if (newAmount != null && newEmployee.isNotEmpty) {
                final updatedLog = log.copyWith(amount: newAmount, employeeName: newEmployee);
                await ref.read(cashLogsProvider.notifier).updateLog(updatedLog);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Registro atualizado com sucesso')),
                  );
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
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
          TextButton(onPressed: () => context.go('/form'), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(cashLogsProvider.notifier).deleteLog(log.id);
              if (context.mounted) Navigator.pop(context);
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
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
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