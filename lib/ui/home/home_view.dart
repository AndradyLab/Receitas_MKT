import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/cash_log_model.dart';
import '../../logic/cash_logic_provider.dart';
import '../widgets/shared_widgets.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late final DateFormat _dateFormatter;
  late final NumberFormat _currencyFormatter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dateFormatter = DateFormat('dd/MM/yyyy');
    _currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final initialBalanceAsync = ref.watch(initialBalanceProvider);
    final cashLogsAsync = ref.watch(cashLogsProvider(true));

    return initialBalanceAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Erro: $err'))),
      data: (initialBalance) => cashLogsAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Scaffold(body: Center(child: Text('Erro: $err'))),
        data: (cashLogsState) {
          final currentBalance = (initialBalance ?? 0.0) + cashLogsState.currentBalance;

          return WillPopScope(
            onWillPop: () async => false,
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: AppBar(
                centerTitle: true,
                title: SvgPicture.asset("assets/images/logo-viana-moura.svg"),
              ),
              body: _buildBody(currentBalance, cashLogsState),
              bottomNavigationBar: const BottomBar(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(double currentBalance, CashLogsState cashLogsState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildDashboardCards(currentBalance, cashLogsState),
          const SizedBox(height: 24),
          _buildButtons(),
          const SizedBox(height: 24),
          _buildRecentTransactions(cashLogsState.logs),
        ],
      ),
    );
  }

  Widget _buildDashboardCards(double currentBalance, CashLogsState cashLogsState) {
    final ingressTotal = cashLogsState.ingressLogs.fold<double>(0, (sum, l) => sum + l.amount);
    final egressTotal = cashLogsState.egressLogs.fold<double>(0, (sum, l) => sum + l.amount);

    return Column(
      children: [
        Center(
          child:
            InkWell(
              onTap: () => _showEditBalanceDialog(currentBalance),
              borderRadius: BorderRadius.circular(8),

              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Saldo Atual',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12),
                    ),
                    Text(
                      _currencyFormatter.format(currentBalance),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: currentBalance >= 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _DashboardCard(
              label: 'Receita',
              value: _currencyFormatter.format(ingressTotal),
              icon: Icons.arrow_upward,
              iconColor: Colors.green,
            ),
            const SizedBox(width: 12),
            _DashboardCard(
              label: 'Despesa',
              value: _currencyFormatter.format(egressTotal),
              icon: Icons.arrow_downward,
              iconColor: Colors.red,
            ),
            const SizedBox(width: 12),
            _DashboardCard(
              label: 'Pendente',
              value: cashLogsState.pendingCount.toString(),
              icon: Icons.sync_problem,
              iconColor: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return _ActionButton(
      onPressed: _navigateToForm,
      icon: Icons.add_circle_outline,
      title: 'Novo Registro',
      subtitle: 'Adicionar nova receita ou despesa',
    );
  }

  Widget _buildRecentTransactions(List<CashLog> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text('Nenhum registro recente'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Últimos Registros', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...logs.map((log) => Card(
              child: ListTile(
                leading: CashTypeBadge(type: log.type),
                title: Text(log.employeeName),
                subtitle: Text(_dateFormatter.format(log.date)),
                trailing: Text(
                  _currencyFormatter.format(log.amount),
                  style: TextStyle(
                    color: log.type == CashType.ingress ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => _showTransactionDetails(log),
              ),
            )),
      ],
    );
  }

  void _navigateToForm() async {
    context.go('/form');
  }

  Future<void> _showEditBalanceDialog(double currentBalance) async {
    final controller = TextEditingController(text: currentBalance.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Saldo Inicial'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: 'R\$ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null) {
                await ref.read(initialBalanceProvider.notifier).updateInitialBalance(val);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
  //TODO
  // void _showSyncStatus() {
  //   final syncController = ref.read(syncControllerProvider);
  //   syncController.getPendingCount().then((count) {
  //     if (count > 0 && mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           behavior: SnackBarBehavior.floating,
  //           content: Text('$count registro(s) pendentes'),
  //           action: SnackBarAction(label: 'Sincronizar', onPressed: _runSync),
  //         ),
  //       );
  //     }
  //   });
  // }

  // Future<void> _runSync() async {
  //   try {
  //     final synced = await ref.read(syncControllerProvider).syncPendingLogs();
  //     ref.read(cashLogsProvider(false).notifier).loadAllLogs();
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$synced sincronizados')));
  //     }
  //   } catch (e) {
  //     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
  //   }
  // }

  Future<void> _showTransactionDetails(CashLog log) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(child: Text(log.type.displayName)),
        content: Text('Valor: ${_currencyFormatter.format(log.amount)}\nFuncionário: ${log.employeeName}'),
        actions: [
          if (log.photoPath != null)
            TextButton(
                onPressed: () => showPhoto(context, log.photoPath!),
                child: const Text("Nota Fiscal")
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))
        ],
      ),
    );
  }
}

  class _DashboardCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _DashboardCard({required this.label, required this.value, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String title;
  final String subtitle;

  const _ActionButton({required this.onPressed, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}