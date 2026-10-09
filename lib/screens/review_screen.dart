import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../services/database_helper.dart';

const expenseCategories = [
  'Ăn uống',
  'Di chuyển',
  'Mua sắm',
  'Hóa đơn',
  'Sức khỏe',
  'Giáo dục',
  'Giải trí',
  'Chuyển tiền',
  'Khác',
];

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.expense});

  final Expense expense;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _transactionController;
  late DateTime _date;
  late String _category;
  bool _saving = false;

  bool get _isEditing => widget.expense.id != null;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.expense.merchant);
    _amountController = TextEditingController(
      text: widget.expense.totalAmount == 0
          ? ''
          : widget.expense.totalAmount.toStringAsFixed(
              widget.expense.totalAmount % 1 == 0 ? 0 : 2,
            ),
    );
    _transactionController = TextEditingController(
      text: widget.expense.transactionCode ?? '',
    );
    _date = widget.expense.date;
    _category = expenseCategories.contains(widget.expense.category)
        ? widget.expense.category
        : 'Khác';
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _transactionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('vi', 'VN'),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = double.parse(
        _amountController.text.trim().replaceAll(',', '.'),
      );
      final updated = widget.expense.copyWith(
        merchant: _merchantController.text.trim(),
        totalAmount: amount,
        date: _date,
        category: _category,
        transactionCode: _transactionController.text.trim().isEmpty
            ? null
            : _transactionController.text.trim(),
        clearTransactionCode: _transactionController.text.trim().isEmpty,
      );
      if (_isEditing) {
        await DatabaseHelper.instance.updateExpense(updated);
      } else {
        await DatabaseHelper.instance.insertExpense(updated);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu giao dịch: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.expense.imagePath;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa giao dịch' : 'Xác nhận giao dịch'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    File(imagePath),
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      alignment: Alignment.center,
                      color: Colors.white,
                      child: const Text('Không thể hiển thị ảnh bill'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Kiểm tra thông tin',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Hãy chỉnh lại các trường được nhận diện chưa chính xác.',
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _merchantController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nội dung giao dịch',
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập tên giao dịch'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VND)',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    (value ?? '').trim().replaceAll(',', '.'),
                  );
                  if (amount == null || amount <= 0) {
                    return 'Nhập số tiền hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Loại chi tiêu',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: expenseCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(DateFormat('dd/MM/yyyy', 'vi').format(_date)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 17,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _transactionController,
                decoration: const InputDecoration(
                  labelText: 'Mã giao dịch (không bắt buộc)',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.expense.qrContent != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Nguồn: VietQR · Nội dung QR được lưu offline',
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu giao dịch'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
