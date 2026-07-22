import 'package:receitas_mkt/data/cash_log_model.dart';

class Utils {
  double calculateExpenses(List<CashLog> logs) {
    return logs.fold<double>(0, (sum, l) => sum + l.amount);
  }
}