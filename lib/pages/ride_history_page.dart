import 'package:flutter/material.dart';
import '../services/ride_store.dart';
import '../utils/formatters.dart';
import '../widgets/ad_banner.dart';
import 'ride_detail_page.dart';

class RideHistoryPage extends StatelessWidget {
  const RideHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final records = RideStore.records;

    return Scaffold(
      appBar: AppBar(title: const Text('주행 기록'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text(
                      '아직 완료된 주행 기록이 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.local_taxi,
                            color: Colors.greenAccent,
                          ),
                          title: Text(record.region),
                          subtitle: Text(
                            '${record.date}  ·  '
                            '${record.distance.toStringAsFixed(2)} km',
                          ),
                          trailing: Text(
                            '₩${formatNumber(record.fare)}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RideDetailPage(record: record),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }
}
