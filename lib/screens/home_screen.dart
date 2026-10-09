import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart';
import '../services/database_helper.dart';
import '../widgets/charts/bar_chart_painter.dart';
import '../widgets/charts/donut_chart_painter.dart';
import 'review_screen.dart';
import 'scan_qr_screen.dart';

const _chartColors = [
  Color(0xFF197B63),
  Color(0xFFFFB547),
  Color(0xFF6587D8),
  Color(0xFFE57963),
  Color(0xFF9A74C8),
  Color(0xFF55A9A0),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );
  List<Expense> _expenses = const [];
  Map<String, double> _categoryTotals = const {};
  List<double> _weeklyTotals = List<double>.filled(7, 0);
  double _total = 0;
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final expenses = await DatabaseHelper.instance.getExpenses();
      final categoryTotals = <String, double>{};
      for (final expense in expenses) {
        categoryTotals.update(
          expense.category,
          (total) => total + expense.totalAmount,
          ifAbsent: () => expense.totalAmount,
        );
      }
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _categoryTotals = Map.fromEntries(
          categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
        );
        _weeklyTotals = DatabaseHelper.calculateWeeklySpendingList(expenses);
        _total = expenses.fold<double>(
          0,
          (total, expense) => total + expense.totalAmount,
        );
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _openScanner() async {
    final expense = await Navigator.of(context)
        .push<Expense>(MaterialPageRoute(builder: (_) => const ScanQrScreen()));
    if (expense == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReviewScreen(expense: expense)),
    );
    if (saved == true) await _loadDashboard();
  }

  Future<void> _editExpense(Expense expense) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReviewScreen(expense: expense)),
    );
    if (saved == true) await _loadDashboard();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: Text(
          'Giao dịch "${expense.merchant}" sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || expense.id == null) return;
    try {
      await DatabaseHelper.instance.deleteExpense(expense.id!);
      await _loadDashboard();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa giao dịch: $error')),
      );
    }
  }

  List<String> get _weekLabels {
    final today = DateTime.now();
    final firstDay = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6));
    return List<String>.generate(7, (index) {
      final day = firstDay.add(Duration(days: index));
      return DateFormat('dd/MM/yyyy').format(day);
    }).reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chi tiêu của tôi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Chụp hoặc chọn ảnh giao dịch',
            onPressed: _openScanner,
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            onSelected: (value) async {
              if (value == 'sign_out') {
                await Supabase.instance.client.auth.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  Supabase.instance.client.auth.currentUser?.email ??
                      'Tài khoản',
                ),
              ),
              const PopupMenuItem(value: 'sign_out', child: Text('Đăng xuất')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        icon: const Icon(Icons.add),
        label: const Text('Thêm chi tiêu'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _ErrorState(error: _loadError!, onRetry: _loadDashboard)
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  if (DatabaseHelper.instance.isOffline) ...[
                    _buildOfflineNotice(),
                    const SizedBox(height: 12),
                  ],
                  _buildTotalCard(),
                  const SizedBox(height: 22),
                  _sectionHeader('Tổng quan', 'Phân bổ theo danh mục'),
                  const SizedBox(height: 12),
                  _buildCategoryCard(),
                  const SizedBox(height: 18),
                  _sectionHeader(
                    '7 ngày gần đây (có hôm nay)',
                    'Ngày/tháng/năm',
                  ),
                  const SizedBox(height: 12),
                  _buildWeeklyCard(),
                  const SizedBox(height: 22),
                  _sectionHeader('Giao dịch', '${_expenses.length} khoản'),
                  const SizedBox(height: 10),
                  if (_expenses.isEmpty)
                    _buildEmptyHistory()
                  else
                    ..._expenses.map(_buildExpenseTile),
                ],
              ),
            ),
    );
  }

  Widget _buildOfflineNotice() {
    return Card(
      color: const Color(0xFFFFF4DA),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: Color(0xFF805A00)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Đang ngoại tuyến. Giao dịch được lưu trên thiết bị và sẽ '
                'đồng bộ khi có kết nối.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Thử đồng bộ lại',
              onPressed: _loadDashboard,
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF197B63), Color(0xFF125D4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'TỔNG CHI ĐÃ GHI NHẬN',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currency.format(_total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Colors.white70,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                'Dữ liệu được lưu an toàn trên Supabase',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
        ),
      ],
    );
  }

  Widget _buildCategoryCard() {
    final entries = _categoryTotals.entries.toList(growable: false);
    final values = entries.map((entry) => entry.value).toList(growable: false);
    final colors = List<Color>.generate(
      entries.length,
      (index) => _chartColors[index % _chartColors.length],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) => CustomPaint(
                  painter: DonutChartPainter(
                    values: values,
                    colors: colors.isEmpty ? _chartColors : colors,
                    progress: progress,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Text(
                        entries.isEmpty
                            ? 'Chưa có\ndữ liệu'
                            : '${entries.length}\ndanh mục',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF52615B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: entries.isEmpty
                  ? Text(
                      'Thêm giao dịch để xem phân bổ chi tiêu.',
                      style: TextStyle(color: Colors.blueGrey.shade500),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var index = 0; index < entries.length; index++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: colors[index],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entries[index].key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _currency.format(entries[index].value),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyCard() {
    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 64,
      _weeklyTotals.length * 82.0,
    ).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Text(
                _currency.format(
                  _weeklyTotals.fold<double>(0, (a, b) => a + b),
                ),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: 142,
                width: chartWidth,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => CustomPaint(
                    painter: BarChartPainter(
                      values: _weeklyTotals.reversed.toList(),
                      labels: _weekLabels,
                      progress: progress,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: Colors.blueGrey.shade300,
            ),
            const SizedBox(height: 10),
            const Text(
              'Chưa có giao dịch nào',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Chụp ảnh bill hoặc chọn ảnh giao dịch để bắt đầu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        onTap: () => _editExpense(expense),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8F3EF),
          child: Icon(
            _iconForCategory(expense.category),
            color: const Color(0xFF197B63),
            size: 20,
          ),
        ),
        title: Text(
          expense.merchant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${expense.category} · ${DateFormat('dd/MM/yyyy', 'vi').format(expense.date)}',
          style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 11),
        ),
        trailing: SizedBox(
          width: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  _currency.format(expense.totalAmount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF197B63),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 20,
                onSelected: (value) {
                  if (value == 'edit') _editExpense(expense);
                  if (value == 'delete') _deleteExpense(expense);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    return switch (category) {
      'Ăn uống' => Icons.restaurant_outlined,
      'Di chuyển' => Icons.directions_car_outlined,
      'Mua sắm' => Icons.shopping_bag_outlined,
      'Hóa đơn' => Icons.receipt_outlined,
      'Sức khỏe' => Icons.health_and_safety_outlined,
      'Giáo dục' => Icons.school_outlined,
      'Giải trí' => Icons.movie_outlined,
      'Chuyển tiền' => Icons.swap_horiz_rounded,
      _ => Icons.payments_outlined,
    };
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Không thể tải dữ liệu chi tiêu'),
            const SizedBox(height: 5),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
