import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/formatters.dart';
import '../widgets/ad_banner.dart';

class RideCompletePage extends StatefulWidget {
  final String region;
  final double distance;
  final int fare;
  final Duration duration;

  const RideCompletePage({
    super.key,
    required this.region,
    required this.distance,
    required this.fare,
    required this.duration,
  });

  @override
  State<RideCompletePage> createState() => _RideCompletePageState();
}

class _RideCompletePageState extends State<RideCompletePage> {
  // 캡처할 영수증 위젯을 가리키는 키
  final GlobalKey _receiptKey = GlobalKey();

  // 영수증을 열 때마다 시각이 바뀌지 않도록 화면이 만들어질 때 한 번만 고정
  // (이 화면이 열린 시각 = 주행 종료 시각, 시작 시각 = 종료 시각 - 주행 시간)
  late final DateTime _endTime;
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _endTime = DateTime.now();
    _startTime = _endTime.subtract(widget.duration);
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
  String _dateTime(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)} ${_hm(t)}';

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // 영수증 위젯을 PNG 파일로 캡처
  // 주의: 영수증 시트가 화면에 떠 있는 동안에만 캡처할 수 있습니다.
  Future<File?> _captureReceipt() async {
    try {
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } catch (e) {
      debugPrint('영수증 캡처 실패: $e');
      return null;
    }
  }

  // 이미 캡처된 파일을 갤러리에 저장
  Future<void> _saveToGallery(File? file) async {
    if (file == null) {
      _showMessage('영수증 이미지 생성에 실패했습니다.');
      return;
    }

    try {
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          _showMessage('사진 저장 권한이 필요합니다. 설정에서 허용해주세요.');
          return;
        }
      }

      await Gal.putImage(file.path);
      _showMessage('영수증이 갤러리에 저장되었습니다.');
    } catch (e) {
      debugPrint('영수증 저장 실패: $e');
      _showMessage('이미지 저장 중 오류가 발생했습니다.');
    }
  }

  // 이미 캡처된 파일을 공유
  Future<void> _shareFile(File? file) async {
    if (file == null) {
      _showMessage('영수증 이미지 생성에 실패했습니다.');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '주행 영수증 - ₩${formatNumber(widget.fare)}',
        ),
      );
    } catch (e) {
      debugPrint('영수증 공유 실패: $e');
      _showMessage('공유 중 오류가 발생했습니다.');
    }
  }

  // 영수증 시트
  void _showReceiptSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 시트 닫기 버튼 (우측 상단 X) - 캡처 대상 밖이라 이미지에 포함되지 않음
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ),

                  // 캡처 대상
                  RepaintBoundary(key: _receiptKey, child: _buildReceipt()),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              // 1) 시트가 열려 있는 동안 먼저 캡처
                              final file = await _captureReceipt();
                              // 2) 그 다음 시트를 닫고
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              // 3) 저장
                              await _saveToGallery(file);
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('이미지 저장'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final file = await _captureReceipt();
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              await _shareFile(file);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                            ),
                            icon: const Icon(Icons.share),
                            label: const Text('전달'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 실제 택시 영수증(감열지)처럼 보이는 영수증
  Widget _buildReceipt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      color: const Color(0xFFFAFAF5),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 14,
          height: 1.5,
          fontFamily: 'monospace',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                '영 수 증 (예상요금)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const _DashedLine(),
            const SizedBox(height: 10),
            _receiptRow('운행 지역', widget.region),
            _receiptRow('거래 일시', _dateTime(_endTime)),
            _receiptRow('승하차시간', '${_hm(_startTime)} - ${_hm(_endTime)}'),
            _receiptRow('주행 거리', '${widget.distance.toStringAsFixed(2)} Km'),
            _receiptRow('주행 시간', formatDuration(widget.duration.inSeconds)),
            const SizedBox(height: 10),
            const _DashedLine(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '결제요금',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${formatNumber(widget.fare)}원',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _DashedLine(),
            const SizedBox(height: 14),
            const Center(child: Text('이용해 주셔서 감사합니다.')),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                '※ 앱에서 계산한 참고용이며 공식 영수증이 아닙니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF777777)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 영수증의 한 줄: 왼쪽 항목명(고정 폭) + 값
  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('주행 완료'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 요금 박스 + 버튼 2개를 한 묶음으로 가운데에 배치합니다.
              // 박스/버튼 사이 간격은 아래 SizedBox 숫자로만 정해집니다.
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _fareDisplay(),

                        // ▼ 요금 박스 ↔ 영수증 버튼 간격
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _showReceiptSheet,
                            icon: const Icon(Icons.receipt_long),
                            label: const Text(
                              '영수증 확인 및 발급',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),

                        // ▼ 영수증 버튼 ↔ 홈 버튼 간격
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                            ),
                            child: const Text(
                              '홈으로',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const AdBanner(),
            ],
          ),
        ),
      ),
    );
  }

  // 미터 화면의 '현재 요금' 박스와 같은 모양 + 아래 한 줄 요약
  Widget _fareDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 내용 크기만큼만 차지 (화면 전체로 늘어나지 않게)
        children: [
          const Text(
            '최종 요금',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            '₩${formatNumber(widget.fare)}',
            style: const TextStyle(
              fontSize: 36,
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade800),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryItem('지역', widget.region),
              _summaryItem('거리', '${widget.distance.toStringAsFixed(2)} km'),
              _summaryItem('시간', formatDuration(widget.duration.inSeconds)),
            ],
          ),
        ],
      ),
    );
  }
}

// 요금 박스 아래 기본정보 한 칸 (위: 항목명, 아래: 값)
Widget _summaryItem(String label, String value) {
  return Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

// 영수증의 점선 구분선
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double dash = 4;
        const double gap = 3;
        final int count = (constraints.maxWidth / (dash + gap)).floor();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => const SizedBox(
              width: dash,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF999999)),
              ),
            ),
          ),
        );
      },
    );
  }
}
