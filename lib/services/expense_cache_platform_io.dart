import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'expense_cache_platform.dart';

class IoExpenseCachePlatform implements ExpenseCachePlatform {
  Future<File> _file(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File(
      p.join(
        directory.path,
        'expenses_${Uri.encodeComponent(userId)}.json',
      ),
    );
  }

  @override
  Future<String?> read(String userId) async {
    final file = await _file(userId);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String userId, String value) async {
    await (await _file(userId)).writeAsString(value, flush: true);
  }
}

ExpenseCachePlatform createExpenseCachePlatform() =>
    IoExpenseCachePlatform();
