class Expense {
  const Expense({
    this.id,
    required this.merchant,
    required this.totalAmount,
    required this.date,
    this.category = 'Khác',
    this.imagePath,
    this.transactionCode,
    this.qrContent,
  });

  final int? id;
  final String merchant;
  final double totalAmount;
  final DateTime date;
  final String category;
  final String? imagePath;
  final String? transactionCode;
  final String? qrContent;

  factory Expense.fromMap(Map<String, Object?> map) {
    return Expense(
      id: (map['id'] as num?)?.toInt(),
      merchant: map['merchant'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      imagePath: map['image_path'] as String?,
      transactionCode: map['transaction_code'] as String?,
      qrContent: map['qr_content'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'merchant': merchant,
      'total_amount': totalAmount,
      'date': date.toIso8601String(),
      'category': category,
      'image_path': imagePath,
      'transaction_code': transactionCode,
      'qr_content': qrContent,
    };
  }

  Expense copyWith({
    int? id,
    String? merchant,
    double? totalAmount,
    DateTime? date,
    String? category,
    String? imagePath,
    String? transactionCode,
    String? qrContent,
    bool clearTransactionCode = false,
  }) {
    return Expense(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      transactionCode: clearTransactionCode
          ? null
          : transactionCode ?? this.transactionCode,
      qrContent: qrContent ?? this.qrContent,
    );
  }
}
