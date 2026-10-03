/// 숫자에 천 단위 콤마를 추가합니다. (예: 12345 -> "12,345")
String formatNumber(int number) {
  return number.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

/// 초를 "시:분:초" 형태로 바꿉니다. (예: 3725 -> "01:02:05")
String formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// 날짜·시각을 "2026.10.04 15:30" 형태로 바꿉니다.
String formatDateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}.${two(t.month)}.${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
