import 'package:flutter/material.dart';

import '../services/ride_store.dart';
import '../utils/formatters.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 삭제 확인 창. 삭제를 누르면 true
  Future<bool> _confirmDelete(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _deleteOne(RideRecord record) async {
    if (!await _confirmDelete('기록 삭제', '이 주행 기록을 삭제하시겠습니까?')) return;
    await RideStore.remove(record);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteAll() async {
    if (!await _confirmDelete('전체 삭제', '저장된 주행 기록을 모두 삭제하시겠습니까?')) return;
    await RideStore.clear();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final records = RideStore.records;

    return Scaffold(
      appBar: AppBar(title: const Text('설정'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionLabel('ⓘ 요금 적용 기준 안내'),
            _fareNotice(),

            const SizedBox(height: 24),

            _sectionLabel('최근 주행 기록 (최대 ${RideStore.maxRecords}개)'),
            _recordList(records),

            if (records.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _deleteAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.red.shade700),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('전체 기록 삭제'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 요금 적용 기준 안내 (미터 화면에서 옮겨온 내용)
  Widget _fareNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '[중형택시]\n'
        '• 기본요금 4,800원(1.6km), 이후 131m마다 100원\n'
        '• 시속 약 15.7km 미만,정차 시 30초마다 100원\n'
        '• 심야 할증은 시간에 따라 자동 적용\n'
        '[모범택시]\n'
        '• 기본요금 7,000원(3.0km), 이후 151m마다 200원\n'
        '• 시속 약 15.1km 미만,정차 시 36초마다 200원\n'
        '[그외]\n'
        '• 서울시 택시요금 기준으로 계산합니다.\n'
        '• 시외는 요금의 20% 추가 계산\n'
        '• 통행료, 호출료는 포함되지 않습니다.\n'
        '• 참고용 계산이며 실제 택시 미터기 요금과 다를 수 있습니다.',
        style: TextStyle(fontSize: 13, height: 1.6, color: Colors.grey),
      ),
    );
  }

  // 주행 기록 목록: 날짜 / 거리 / 요금 순
  Widget _recordList(List<RideRecord> records) {
    if (records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('저장된 주행 기록이 없습니다.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _headerRow(),
          for (final record in records) ...[
            Divider(height: 1, color: Colors.grey.shade800),
            _recordRow(record),
          ],
        ],
      ),
    );
  }

  // 칸 폭 비율: 날짜 5 : 거리 3 : 요금 3 + 삭제 버튼 자리
  Widget _headerRow() {
    const style = TextStyle(
      color: Colors.grey,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('날짜', style: style)),
          Expanded(
            flex: 3,
            child: Text('거리', textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 3,
            child: Text('요금', textAlign: TextAlign.right, style: style),
          ),
          SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _recordRow(RideRecord record) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatDateTime(record.date),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${record.distance.toStringAsFixed(2)} km',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '₩${formatNumber(record.fare)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.grey,
            tooltip: '삭제',
            onPressed: () => _deleteOne(record),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
