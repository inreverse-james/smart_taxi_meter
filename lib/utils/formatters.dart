/// 숫자에 천 단위 콤마를 추가합니다. (예: 12345 -> "12,345")
String formatNumber(int number) {
  return number.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}
