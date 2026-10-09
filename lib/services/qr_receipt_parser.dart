import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/expense.dart';

class QrReceiptParser {
  QrReceiptParser._();

  static const defaultCategory = 'Khác';

  /// Parses the EMVCo TLV payload commonly used by VietQR.
  static Expense parseVietQr(String content) {
    final tags = _parseTlv(content.trim());
    final amount =
        double.tryParse((tags['54'] ?? '').replaceAll(',', '.')) ?? 0;
    final recipient = tags['59']?.trim();
    final additionalData = _parseTlv(tags['62'] ?? '');
    final reference = additionalData['05']?.trim();
    final account = _parseTlv(tags['38'] ?? '');
    final bankAccount = account['01']?.trim();

    return Expense(
      merchant: recipient?.isNotEmpty == true
          ? recipient!
          : (bankAccount?.isNotEmpty == true ? bankAccount! : 'Người nhận'),
      totalAmount: amount,
      date: DateTime.now(),
      category: defaultCategory,
      transactionCode: reference?.isNotEmpty == true ? reference : null,
      qrContent: content,
    );
  }

  /// Reads text locally using on-device ML Kit; no image or OCR data is uploaded.
  static Future<Expense> recognizeBankBill(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return parseBankBillText(result.text, imagePath: imagePath);
    } finally {
      await recognizer.close();
    }
  }

  static Expense parseBankBillText(String text, {String? imagePath}) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final amount = _extractAmount(text);
    final merchant = _extractTransactionContent(lines) ??
        _extractLabelValue(
          lines,
          RegExp(
            r'(?:người\s*nhận|nguoi\s*nhan|đến|den|to|merchant|đơn\s*vị|don\s*vi)\s*[:：-]\s*(.+)',
            caseSensitive: false,
          ),
        ) ??
        'Giao dịch ngân hàng';

    final transactionCode = _extractLabelValue(
      lines,
      RegExp(
        r'(?:mã\s*giao\s*dịch|ma\s*giao\s*dich|transaction\s*id|reference|mã\s*tham\s*chiếu)\s*[:：-]\s*([A-Z0-9-]+)',
        caseSensitive: false,
      ),
    );
    final date = _extractDate(text) ?? DateTime.now();

    return Expense(
      merchant: merchant,
      totalAmount: amount,
      date: date,
      category: defaultCategory,
      imagePath: imagePath,
      transactionCode: transactionCode,
    );
  }

  static Future<String> copyImageToAppDocuments(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Không tìm thấy ảnh bill', sourcePath);
    }

    final documents = await getApplicationDocumentsDirectory();
    final receiptsDirectory = Directory(p.join(documents.path, 'receipts'));
    await receiptsDirectory.create(recursive: true);

    final extension = p.extension(sourcePath);
    final fileName =
        'receipt_${DateTime.now().microsecondsSinceEpoch}$extension';
    final cachedFile = await source.copy(
      p.join(receiptsDirectory.path, fileName),
    );
    return cachedFile.path;
  }

  static double _extractAmount(String text) {
    final labeled = RegExp(
      r'(?:tổng\s*tiền|tong\s*tien|số\s*tiền|so\s*tien|thành\s*tiền|thanh\s*tien|amount|total|debit)\s*[:：]?\s*((?:VND|₫)\s*)?([0-9][0-9., ]*)\s*(?:VND|VNĐ|₫)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null) {
      final amount = _normalizeAmount(labeled.group(2) ?? '');
      if (amount != null) return amount;
    }

    final currencyAmount = RegExp(
      r'([0-9][0-9., ]*)\s*(?:VND|VNĐ|₫)',
      caseSensitive: false,
    ).allMatches(text).lastOrNull;
    return _normalizeAmount(currencyAmount?.group(1) ?? '') ?? 0;
  }

  static double? _normalizeAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (cleaned.isEmpty) return null;

    final comma = cleaned.lastIndexOf(',');
    final dot = cleaned.lastIndexOf('.');
    final decimalSeparator = comma > dot ? ',' : (dot > comma ? '.' : '');
    final hasDecimal =
        decimalSeparator.isNotEmpty &&
        cleaned.length - cleaned.lastIndexOf(decimalSeparator) - 1 <= 2;
    final normalized = hasDecimal
        ? cleaned
              .replaceAll(decimalSeparator == ',' ? '.' : ',', '')
              .replaceFirst(decimalSeparator, '.')
        : cleaned.replaceAll(RegExp(r'[.,]'), '');
    return double.tryParse(normalized);
  }

  static DateTime? _extractDate(String text) {
    final match = RegExp(r'\b([0-3]?\d)[/-]([01]?\d)[/-]((?:20)?\d{2})\b')
        .firstMatch(text);
    if (match == null) return null;

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    try {
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }
      return date;
    } on ArgumentError {
      return null;
    }
  }

  static String? _extractLabelValue(List<String> lines, RegExp expression) {
    for (final line in lines) {
      final value = expression.firstMatch(line)?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _extractTransactionContent(List<String> lines) {
    final contentLabel = RegExp(
      r'^(?:nội\s*dung|noi\s*dung|diễn\s*giải|dien\s*giai|transaction\s*content|description)\s*[:：-]?\s*(.*)$',
      caseSensitive: false,
    );
    final nextSection = RegExp(
      r'^(?:mã\s*giao\s*dịch|ma\s*giao\s*dich|ngày\s*giao\s*dịch|ngay\s*giao\s*dich|người\s*nhận|nguoi\s*nhan|số\s*tiền|so\s*tien|xem\s*thêm|giao\s*dịch\s*mới)',
      caseSensitive: false,
    );
    final nonContent = RegExp(
      r'^(?:chuyển\s*tiền\s*thành\s*công|chuyen\s*tien\s*thanh\s*cong|[0-9][0-9., ]*\s*(?:VND|VNĐ|₫)|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
      caseSensitive: false,
    );

    for (var index = 0; index < lines.length; index++) {
      final match = contentLabel.firstMatch(lines[index]);
      if (match == null) continue;

      final values = <String>[];
      final inlineValue = match.group(1)?.trim() ?? '';
      if (inlineValue.isNotEmpty) values.add(inlineValue);
      for (var nextIndex = index + 1; nextIndex < lines.length; nextIndex++) {
        final line = lines[nextIndex].trim();
        if (line.isEmpty || nextSection.hasMatch(line)) break;
        if (nonContent.hasMatch(line)) continue;
        values.add(line);
        if (values.length == 2) break;
      }
      if (values.isNotEmpty) return values.join(' ');
    }
    return null;
  }

  static Map<String, String> _parseTlv(String value) {
    final tags = <String, String>{};
    var offset = 0;
    while (offset + 4 <= value.length) {
      final tag = value.substring(offset, offset + 2);
      final lengthText = value.substring(offset + 2, offset + 4);
      final length = int.tryParse(lengthText);
      if (length == null || length < 0 || offset + 4 + length > value.length) {
        break;
      }
      tags[tag] = value.substring(offset + 4, offset + 4 + length);
      offset += 4 + length;
    }
    return tags;
  }
}
