import 'package:flutter/material.dart';
import '../services/ride_store.dart';
import '../utils/formatters.dart';
import '../widgets/ad_banner.dart';

class RideDetailPage extends StatelessWidget {
  final RideRecord record;

  const RideDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주행 상세'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.local_taxi,
                    size: 70,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(height: 25),

                  _info('지역', record.region),
                  _info('거리', '${record.distance.toStringAsFixed(2)} km'),
                  _info('요금', '₩${formatNumber(record.fare)}'),
                  _info('날짜', record.date),
                ],
              ),
            ),
          ),

          const AdBanner(),
        ],
      ),
    );
  }

  Widget _info(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
