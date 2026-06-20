import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receitas_mkt/ui/widgets/shared_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:receitas_mkt/logic/cash_logic_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
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
}
