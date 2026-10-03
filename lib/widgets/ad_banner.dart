import 'package:flutter/material.dart';

/// 광고 영역 표시 스위치.
/// 실제 광고(AdMob 등)를 연결하기 전까지는 false로 두어 '광고 영역' 자리표시가 보이지 않게 합니다.
const bool kShowAds = false;

/// 화면 하단에 공통으로 쓰이는 광고 영역 위젯.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kShowAds) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.all(10),
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('광고 영역', style: TextStyle(color: Colors.grey)),
    );
  }
}
