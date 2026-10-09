import 'dart:html' as html;

import 'expense_cache_platform.dart';

class WebExpenseCachePlatform implements ExpenseCachePlatform {
  String _key(String userId) =>
      'qr_expense_tracker.expenses.${Uri.encodeComponent(userId)}';

  @override
  Future<String?> read(String userId) async =>
      html.window.localStorage[_key(userId)];

  @override
  Future<void> write(String userId, String value) async {
    html.window.localStorage[_key(userId)] = value;
  }
}

ExpenseCachePlatform createExpenseCachePlatform() =>
    WebExpenseCachePlatform();
