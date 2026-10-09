import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart';
import 'expense_local_store.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  final ExpenseLocalStore _localStore = ExpenseLocalStore();
  bool isOffline = false;
  Object? offlineError;

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Bạn cần đăng nhập để truy cập giao dịch.');
    }
    return userId;
  }

  Future<int> insertExpense(Expense expense) async {
    final userId = _userId;
    try {
      final row = await _client
          .from('expenses')
          .insert(
            expense.toMap()
              ..remove('id')
              ..['user_id'] = userId,
          )
          .select('id')
          .single();
      isOffline = false;
      offlineError = null;
      return (row['id'] as num).toInt();
    } catch (error) {
      if (!_isNetworkError(error)) rethrow;
      final id = await _localStore.insert(userId, expense);
      isOffline = true;
      offlineError = error;
      return id;
    }
  }

  Future<int> updateExpense(Expense expense) async {
    final userId = _userId;
    final id = expense.id;
    if (id == null) {
      throw ArgumentError.value(id, 'expense.id', 'Must not be null');
    }
    if (id < 0) {
      await _localStore.update(userId, expense);
      isOffline = true;
      return 1;
    }
    try {
      final rows = await _client
          .from('expenses')
          .update(expense.toMap()..remove('id'))
          .eq('id', id)
          .eq('user_id', userId)
          .select('id');
      isOffline = false;
      offlineError = null;
      return rows.length;
    } catch (error) {
      if (!_isNetworkError(error)) rethrow;
      await _localStore.update(userId, expense);
      isOffline = true;
      offlineError = error;
      return 1;
    }
  }

  Future<int> deleteExpense(int id) async {
    final userId = _userId;
    if (id < 0) {
      await _localStore.delete(userId, id);
      isOffline = true;
      return 1;
    }
    try {
      final rows = await _client
          .from('expenses')
          .delete()
          .eq('id', id)
          .eq('user_id', userId)
          .select('id');
      isOffline = false;
      offlineError = null;
      return rows.length;
    } catch (error) {
      if (!_isNetworkError(error)) rethrow;
      await _localStore.delete(userId, id);
      isOffline = true;
      offlineError = error;
      return 1;
    }
  }

  Future<List<Expense>> getExpenses() async {
    final userId = _userId;
    try {
      await _syncPending(userId);
      final rows = await _client
          .from('expenses')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false)
          .order('id', ascending: false);
      final expenses = rows
          .map((row) => Expense.fromMap(Map<String, Object?>.from(row)))
          .toList(growable: false);
      await _localStore.cacheRemote(userId, expenses);
      isOffline = false;
      offlineError = null;
      return expenses;
    } catch (error) {
      if (!_isNetworkError(error)) rethrow;
      final localExpenses = await _localStore.getExpenses(userId);
      isOffline = true;
      offlineError = error;
      return localExpenses;
    }
  }

  Future<void> _syncPending(String userId) async {
    for (final operation in await _localStore.getPending(userId)) {
      final id = operation['id'] as int;
      switch (operation['operation']) {
        case 'insert':
          final expense = Expense.fromMap(
            Map<String, Object?>.from(operation['expense'] as Map),
          );
          final row = await _client
              .from('expenses')
              .insert(
                expense.toMap()
                  ..remove('id')
                  ..['user_id'] = userId,
              )
              .select('id')
              .single();
          await _localStore.markSynced(
            userId,
            id,
            serverId: (row['id'] as num).toInt(),
          );
        case 'update':
          await _client
              .from('expenses')
              .update(
                Map<String, Object?>.from(operation['expense'] as Map)
                  ..remove('id'),
              )
              .eq('id', id)
              .eq('user_id', userId);
          await _localStore.markSynced(userId, id);
        case 'delete':
          await _client
              .from('expenses')
              .delete()
              .eq('id', id)
              .eq('user_id', userId);
          await _localStore.markSynced(userId, id);
        default:
          throw FormatException(
            'Thao tác đồng bộ giao dịch không hợp lệ: ${operation['operation']}',
          );
      }
    }
  }

  bool _isNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return [
      'socketexception',
      'httpexception',
      'timeoutexception',
      'clientexception',
      'failed host lookup',
      'connection refused',
      'connection reset',
      'network is unreachable',
      'network request failed',
      'failed to connect',
      'no internet',
      'xmlhttprequest error',
      'failed to fetch',
      'networkerror',
      'timed out',
    ].any(message.contains);
  }

  Future<double> getTotalSpending() async {
    final expenses = await getExpenses();
    return expenses.fold<double>(
      0.0,
      (total, expense) => total + expense.totalAmount,
    );
  }

  Future<Map<String, double>> getCategoryTotals() async {
    final totals = <String, double>{};
    for (final expense in await getExpenses()) {
      totals.update(
        expense.category,
        (total) => total + expense.totalAmount,
        ifAbsent: () => expense.totalAmount,
      );
    }
    return Map.fromEntries(
      totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Future<List<double>> getWeeklySpendingList() async {
    return calculateWeeklySpendingList(await getExpenses());
  }

  static List<double> calculateWeeklySpendingList(
    List<Expense> expenses, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final firstDay = startOfToday.subtract(const Duration(days: 6));
    final totals = <String, double>{};
    for (final expense in expenses) {
      final date = expense.date;
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(firstDay) || day.isAfter(startOfToday)) continue;
      final key = day.toIso8601String().substring(0, 10);
      totals.update(
        key,
        (total) => total + expense.totalAmount,
        ifAbsent: () => expense.totalAmount,
      );
    }
    return List<double>.generate(7, (index) {
      final day = firstDay.add(Duration(days: index));
      return totals[day.toIso8601String().substring(0, 10)] ?? 0;
    }, growable: false);
  }
}
