import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Bạn cần đăng nhập để truy cập giao dịch.');
    }
    return userId;
  }

  Future<int> insertExpense(Expense expense) async {
    final row = await _client
        .from('expenses')
        .insert(expense.toMap()..remove('id')..['user_id'] = _userId)
        .select('id')
        .single();
    return (row['id'] as num).toInt();
  }

  Future<int> updateExpense(Expense expense) async {
    final id = expense.id;
    if (id == null) {
      throw ArgumentError.value(id, 'expense.id', 'Must not be null');
    }
    final rows = await _client
        .from('expenses')
        .update(expense.toMap()..remove('id'))
        .eq('id', id)
        .eq('user_id', _userId)
        .select('id');
    return rows.length;
  }

  Future<int> deleteExpense(int id) async {
    final rows = await _client
        .from('expenses')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId)
        .select('id');
    return rows.length;
  }

  Future<List<Expense>> getExpenses() async {
    final rows = await _client
        .from('expenses')
        .select()
        .eq('user_id', _userId)
        .order('date', ascending: false)
        .order('id', ascending: false);
    return rows
        .map((row) => Expense.fromMap(Map<String, Object?>.from(row)))
        .toList(growable: false);
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
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final firstDay = startOfToday.subtract(const Duration(days: 6));
    final totals = <String, double>{};
    for (final expense in await getExpenses()) {
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
