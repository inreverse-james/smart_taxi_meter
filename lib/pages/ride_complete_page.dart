import 'package:flutter/material.dart';
import '../utils/formatters.dart';
import '../widgets/ad_banner.dart';
import 'ride_history_page.dart';

class RideCompletePage extends StatelessWidget {
  final String region;
  final double distance;
  final int fare;

  const RideCompletePage({
    super.key,
    required this.region,
    required this.distance,
    required this.fare,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주행 완료'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 80,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '주행 완료',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      '₩${formatNumber(fare)}',
                      style: const TextStyle(
                        fontSize: 42,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text('지역 : $region'),
                    const SizedBox(height: 8),
                    Text('거리 : ${distance.toStringAsFixed(2)} km'),
                    const SizedBox(height: 35),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RideHistoryPage(),
                            ),
                          );
                        },
                        child: const Text('주행 기록 보기'),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      child: const Text('홈으로'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }
}
