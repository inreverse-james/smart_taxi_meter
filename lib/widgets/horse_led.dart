import 'dart:async';

import 'package:flutter/material.dart';

/// 구형 택시미터에 있던 막대형 LED 주행 표시등을 흉내낸 위젯.
/// LED 여러 개가 좌 -> 우로 순차 점등되며 꼬리(잔상)를 남기고,
/// 실제 주행 속도(speed, km/h)가 빠를수록 LED가 더 빠르게 흐릅니다.
class HorseLed extends StatefulWidget {
  final bool running;
  final int speed; // km/h, 애니메이션 속도 계산에 사용

  const HorseLed({super.key, required this.running, this.speed = 0});

  @override
  State<HorseLed> createState() => _HorseLedState();
}

class _HorseLedState extends State<HorseLed> {
  Timer? _timer;
  int _activeIndex = 0;

  // ===== LED 개수 조정 =====
  // 값이 클수록 LED 막대가 더 촘촘/길게 표시됩니다.
  static const int ledCount = 16;

  @override
  void initState() {
    super.initState();
    _updateTimer();
  }

  @override
  void didUpdateWidget(covariant HorseLed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running ||
        oldWidget.speed != widget.speed) {
      _updateTimer();
    }
  }

  void _updateTimer() {
    _timer?.cancel();

    if (!widget.running) {
      setState(() => _activeIndex = 0);
      return;
    }

    // ============================================================
    // ▼▼▼ LED 이동(깜빡임) 속도 조정 지점 ▼▼▼
    // 실제 속도(km/h)에 비례해서 LED가 흐르는 빠르기를 정합니다.
    //
    // ledPerSecPerKmh : 속도 1km/h 당 1초에 LED가 몇 칸 움직일지
    //                   - 키우면 전체가 빨라지고, 줄이면 전체가 느려집니다.
    //                   - 예) 0.2 이면 60km/h 에서 초당 12칸 이동
    // idleInterval    : 정차 중이거나 아주 느릴 때 LED가 한 칸 이동하는 시간(ms)
    //                   - 클수록 정차 중 LED가 더 느리게 움직입니다.
    // minInterval     : 아무리 빨라도 이보다 짧아지지 않는 최소 이동 시간(ms)
    //                   - 너무 작게 하면 깜빡임처럼 보일 수 있습니다.
    const double ledPerSecPerKmh = 0.2;
    const int idleInterval = 400;
    const int minInterval = 30;
    // ▲▲▲ 여기 세 값만 바꾸면 전체 체감 속도가 바뀝니다 ▲▲▲
    // ============================================================
    final int interval = widget.speed <= 0
        ? idleInterval
        : (1000 / (widget.speed * ledPerSecPerKmh)).round().clamp(
            minInterval,
            idleInterval,
          );

    _timer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (!mounted) return;
      setState(() {
        _activeIndex = (_activeIndex + 1) % ledCount;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.greenAccent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          ledCount,
          (index) => _led(widget.running && _isLit(index)),
        ),
      ),
    );
  }

  // ===== 꼬리(잔상) 길이 조정 =====
  // tailLength 값을 바꾸면 한 번에 켜지는 LED 개수(잔상 길이)가 변합니다.
  bool _isLit(int index) {
    const int tailLength = 3;
    for (int i = 0; i < tailLength; i++) {
      if (index == (_activeIndex - i + ledCount) % ledCount) return true;
    }
    return false;
  }

  Widget _led(bool lit) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: 10,
      height: 22,
      decoration: BoxDecoration(
        color: lit ? Colors.greenAccent : Colors.green.shade900,
        borderRadius: BorderRadius.circular(2),
        boxShadow: lit
            ? [
                const BoxShadow(
                  color: Colors.greenAccent,
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
