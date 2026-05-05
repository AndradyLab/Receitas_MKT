import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:intl/date_symbol_data_local.dart';
import 'package:receitas_mkt/logic/router.dart';

// Importe as telas se for necessário inicializar algo mais aqui,
// caso contrário, o router.dart já está cuidando delas.
import 'data/local_database.dart';
import 'logic/cash_logic_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await path_provider.getApplicationDocumentsDirectory();

  await initializeDateFormatting('pt_BR', null);

  final dbHelper = await DatabaseHelper.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(dbHelper),
      ],
      child: const ReceitasMktApp(),
    ),
  );
}

class ReceitasMktApp extends StatelessWidget {
  const ReceitasMktApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Receitas Marketing',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildTheme(true),
      darkTheme: _buildTheme(false),
      routerConfig: router,
    );
  }

  ThemeData _buildTheme(bool isLight) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4CAF50),
      brightness: isLight ? Brightness.light : Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
    );
  }
}