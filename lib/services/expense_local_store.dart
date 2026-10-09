import 'dart:convert';

import '../models/expense.dart';
import 'expense_cache_platform.dart' as cache_base;
import 'expense_cache_platform.dart'
    if (dart.library.io) 'expense_cache_platform_io.dart'
    if (dart.library.html) 'expense_cache_platform_web.dart'
    as cache_impl;

class ExpenseLocalStore {
  final cache_base.ExpenseCachePlatform _platform = cache_impl
      .createExpenseCachePlatform();

  Future<Map<String, dynamic>> _read(String userId) async {
    final content = await _platform.read(userId);
    if (content == null) {
      return {'expenses': <Object?>[], 'pending': <Object?>[]};
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> ||
        decoded['expenses'] is! List ||
        decoded['pending'] is! List) {
      throw const FormatException('Dữ liệu chi tiêu cục bộ không hợp lệ.');
    }
    return decoded;
  }

  Future<void> _write(String userId, Map<String, dynamic> data) =>
      _platform.write(userId, jsonEncode(data));

  List<Map<String, dynamic>> _maps(List rows) =>
      rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();

  Future<List<Expense>> getExpenses(String userId) async {
    final data = await _read(userId);
    return (data['expenses'] as List)
        .map((row) => Expense.fromMap(Map<String, Object?>.from(row as Map)))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getPending(String userId) async =>
      _maps((await _read(userId))['pending'] as List);

  Future<void> cacheRemote(String userId, List<Expense> expenses) async {
    final data = await _read(userId);
    final pending = _maps(data['pending'] as List);
    final pendingIds = pending.map((operation) => operation['id']).toSet();
    final localPending = _maps(data['expenses'] as List)
        .where((expense) => pendingIds.contains(expense['id']));
    await _write(userId, {
      'expenses': [
        ...expenses.map((expense) => expense.toMap()),
        ...localPending,
      ],
      'pending': pending,
    });
  }

  Future<int> insert(String userId, Expense expense) async {
    final data = await _read(userId);
    final expenses = _maps(data['expenses'] as List);
    final pending = _maps(data['pending'] as List);
    var id = -DateTime.now().microsecondsSinceEpoch;
    while (expenses.any((row) => row['id'] == id)) {
      id--;
    }
    final localExpense = expense.copyWith(id: id);
    expenses.add(localExpense.toMap());
    pending.add({
      'operation': 'insert',
      'id': id,
      'expense': localExpense.toMap(),
    });
    await _write(userId, {'expenses': expenses, 'pending': pending});
    return id;
  }

  Future<void> update(String userId, Expense expense) async {
    final id = expense.id;
    if (id == null) {
      throw ArgumentError.value(id, 'expense.id', 'Must not be null');
    }
    final data = await _read(userId);
    final expenses = _maps(data['expenses'] as List);
    final pending = _maps(data['pending'] as List);
    final expenseIndex = expenses.indexWhere((row) => row['id'] == id);
    if (expenseIndex < 0) {
      throw StateError('Không tìm thấy giao dịch trong bộ nhớ cục bộ.');
    }
    expenses[expenseIndex] = expense.toMap();
    final pendingIndex = pending.indexWhere((row) => row['id'] == id);
    if (pendingIndex >= 0 && pending[pendingIndex]['operation'] == 'insert') {
      pending[pendingIndex]['expense'] = expense.toMap();
    } else {
      final operation = {
        'operation': 'update',
        'id': id,
        'expense': expense.toMap(),
      };
      if (pendingIndex >= 0) {
        pending[pendingIndex] = operation;
      } else {
        pending.add(operation);
      }
    }
    await _write(userId, {'expenses': expenses, 'pending': pending});
  }

  Future<void> delete(String userId, int id) async {
    final data = await _read(userId);
    final expenses = _maps(data['expenses'] as List)
      ..removeWhere((row) => row['id'] == id);
    final pending = _maps(data['pending'] as List);
    final pendingIndex = pending.indexWhere((row) => row['id'] == id);
    if (pendingIndex >= 0 && pending[pendingIndex]['operation'] == 'insert') {
      pending.removeAt(pendingIndex);
    } else if (pendingIndex >= 0) {
      pending[pendingIndex] = {'operation': 'delete', 'id': id};
    } else {
      pending.add({'operation': 'delete', 'id': id});
    }
    await _write(userId, {'expenses': expenses, 'pending': pending});
  }

  Future<void> markSynced(String userId, int id, {int? serverId}) async {
    final data = await _read(userId);
    final expenses = _maps(data['expenses'] as List);
    final pending = _maps(data['pending'] as List)
      ..removeWhere((operation) => operation['id'] == id);
    if (serverId != null) {
      final index = expenses.indexWhere((row) => row['id'] == id);
      if (index >= 0) expenses[index]['id'] = serverId;
    }
    await _write(userId, {'expenses': expenses, 'pending': pending});
  }
}
