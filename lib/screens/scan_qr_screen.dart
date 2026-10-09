import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/qr_receipt_parser.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _handlingScan = false;
  bool _handlingImage = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handlingScan) return;
    final content = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (content == null || content.isEmpty) return;

    _handlingScan = true;
    await _scannerController.stop();
    if (!mounted) return;
    Navigator.of(context).pop(QrReceiptParser.parseVietQr(content));
  }

  Future<void> _pickBillImage() async {
    if (_handlingImage) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nhận diện ảnh giao dịch hiện cần chạy trên Android hoặc iPhone. '
            'Trên Chrome, bạn vẫn có thể quét mã VietQR.',
          ),
        ),
      );
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;

      setState(() => _handlingImage = true);
      final cachedPath = await QrReceiptParser.copyImageToAppDocuments(
        picked.path,
      );
      final expense = await QrReceiptParser.recognizeBankBill(cachedPath);
      if (!mounted) return;
      Navigator.of(context).pop(expense);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể đọc ảnh giao dịch: $error')),
      );
    } finally {
      if (mounted) setState(() => _handlingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét giao dịch thanh toán')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Không thể mở camera. Hãy kiểm tra quyền camera '
                              'hoặc chọn ảnh giao dịch từ thư viện.\n\n$error',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 3),
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 22,
                        child: Text(
                          'Quét mã VietQR hoặc chọn ảnh giao dịch thanh toán',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 8),
                                ],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handlingImage ? null : _pickBillImage,
                  icon: _handlingImage
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined),
                  label: Text(
                    _handlingImage
                        ? 'Đang nhận diện giao dịch...'
                        : kIsWeb
                        ? 'Chọn ảnh giao dịch (Android/iPhone)'
                        : 'Chọn ảnh giao dịch thanh toán',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
