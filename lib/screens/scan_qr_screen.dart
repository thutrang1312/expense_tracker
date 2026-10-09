import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/qr_receipt_parser.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _handlingImage = false;

  Future<void> _captureOrPickImage(ImageSource source) async {
    if (_handlingImage) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nhận diện nội dung ảnh giao dịch hiện cần chạy trên Android '
            'hoặc iPhone.',
          ),
        ),
      );
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
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
      appBar: AppBar(title: const Text('Quét ảnh giao dịch thanh toán')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Chụp ảnh màn hình thanh toán hoặc chọn ảnh giao dịch',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ứng dụng sẽ nhận diện số tiền, ngày và nội dung trên ảnh. '
                    'Bạn có thể kiểm tra, chỉnh sửa thông tin trước khi lưu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey.shade600),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _handlingImage
                          ? null
                          : () => _captureOrPickImage(ImageSource.camera),
                      icon: _handlingImage
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _handlingImage
                            ? 'Đang nhận diện giao dịch...'
                            : 'Chụp ảnh giao dịch',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handlingImage
                          ? null
                          : () => _captureOrPickImage(ImageSource.gallery),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Chọn ảnh giao dịch'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
