import 'package:flutter/material.dart';

/// 화면 하단에 공통으로 쓰이는 광고 영역 위젯.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) {
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
