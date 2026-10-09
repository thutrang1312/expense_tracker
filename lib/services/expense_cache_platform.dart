abstract interface class ExpenseCachePlatform {
  Future<String?> read(String userId);

  Future<void> write(String userId, String value);
}

ExpenseCachePlatform createExpenseCachePlatform() =>
    throw UnsupportedError('Nền tảng lưu dữ liệu chi tiêu chưa được hỗ trợ.');
