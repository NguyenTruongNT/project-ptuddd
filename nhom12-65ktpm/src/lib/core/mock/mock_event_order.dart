// Thứ tự sự kiện append-only của mock.
//
// Sắp xếp tăng dần theo thời điểm server. Khi trùng thời điểm, giữ thứ tự GHI
// thực tế của store (vị trí trong danh sách append-only), KHÔNG so sánh ID dạng
// chuỗi: 'evt-mock-10' < 'evt-mock-2' theo từ điển nên sự kiện 10, 11, 12 sẽ
// nhảy lên trước 2–9. Dùng chỉ số làm khóa phụ cũng tránh phụ thuộc vào việc
// List.sort của Dart không đảm bảo ổn định.
List<T> sortedByServerOrder<T>(
  Iterable<T> events,
  DateTime Function(T event) serverAt,
) {
  final indexed = events.toList(growable: false).asMap().entries.toList();
  indexed.sort((a, b) {
    final byTime = serverAt(a.value).compareTo(serverAt(b.value));
    return byTime != 0 ? byTime : a.key.compareTo(b.key);
  });
  return [for (final entry in indexed) entry.value];
}
