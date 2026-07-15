import 'package:go_router/go_router.dart';
import 'package:receitas_mkt/ui/form/form_view.dart';
import 'package:receitas_mkt/ui/home/home_view.dart';
import 'package:receitas_mkt/ui/history/logs_view.dart';
import 'package:receitas_mkt/ui/settings/settings_view.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeView()
    ),
    GoRoute(
        path: '/config',
        builder: (context, state) => const SettingsView()
    ),
    GoRoute(
        path: '/history',
        builder: (context, state) => const LogsView()
    ),
    GoRoute(
      path: '/form',
      builder: (context, state) => const FormView()
    ),
  ]
);