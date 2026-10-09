import 'package:flutter_test/flutter_test.dart';
import 'package:qr_expense_tracker/services/qr_receipt_parser.dart';

void main() {
  test('parses VietQR amount, recipient, and reference', () {
    const payload =
        '0002010102125406100.005802VN5909CA PHE 0162110507INV12346304ABCD';
    final expense = QrReceiptParser.parseVietQr(payload);

    expect(expense.totalAmount, 100);
    expect(expense.merchant, 'CA PHE 01');
    expect(expense.transactionCode, 'INV1234');
    expect(expense.qrContent, payload);
  });

  test('extracts bill details from Vietnamese OCR text', () {
    final expense = QrReceiptParser.parseBankBillText(
      'NGUOI NHAN: Nguyen Van A\n'
      'So tien: 1.250.000 VND\n'
      'Ma giao dich: ABC123\n'
      'Ngay giao dich: 07/10/2026',
    );

    expect(expense.merchant, 'Nguyen Van A');
    expect(expense.totalAmount, 1250000);
    expect(expense.transactionCode, 'ABC123');
    expect(expense.date, DateTime(2026, 10, 7));
  });

  test('extracts amount and transaction content from a bank payment image', () {
    final expense = QrReceiptParser.parseBankBillText(
      'VietinBank\n'
      'Chuyển tiền thành công\n'
      '57,000 VND\n'
      '02/10/2026 14:42 • 906K26A025W3FL4B\n'
      'LE THI HA VY\n'
      '5660568371 • BIDV\n'
      'Nội dung\n'
      'TRAN THI THU TRANG\n'
      'Chuyen tien',
    );

    expect(expense.totalAmount, 57000);
    expect(expense.merchant, 'TRAN THI THU TRANG Chuyen tien');
    expect(expense.date, DateTime(2026, 10, 2));
  });
}
