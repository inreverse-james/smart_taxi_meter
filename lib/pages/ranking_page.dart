import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  String selectedRegion = '전체';
  final List<String> regions = [
    '전체',
    '서울',
    '경기',
    '인천',
    '부산',
    '대구',
    '광주',
    '대전',
    '울산'
  ];

  @override
  Widget build(BuildContext context) {
    // 1. 쿼리 구성
    Query query = FirebaseFirestore.instance.collection('users');

    if (selectedRegion != '전체') {
      query = query.where('region', isEqualTo: selectedRegion);
    }

    query = query.orderBy('totalDistance', descending: true).limit(20);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RACE RANKING'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // 지역 선택 Dropdown
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: DropdownButton<String>(
              value: selectedRegion,
              isExpanded: true,
              items: regions.map((String region) {
                return DropdownMenuItem<String>(
                  value: region,
                  child: Text(region),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedRegion = newValue;
                  });
                }
              },
            ),
          ),

          // 파이어베이스 실시간 데이터 수신
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('오류 발생: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('등록된 랭킹 데이터가 없습니다.'),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final int rank = index + 1;
                    final String nickname = data['nickname'] ?? '익명';
                    final num totalDistance = data['totalDistance'] ?? 0;
                    final String region = data['region'] ?? '-';

                    return ListTile(
                      leading: Text(
                        '$rank위',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rank == 1
                              ? const Color(0xFFFFD700)
                              : (rank == 2
                                  ? const Color(0xFFC0C0C0)
                                  : const Color(0xFFCD7F32)),
                        ),
                      ),
                      title: Text(nickname),
                      subtitle: Text('지역: $region'),
                      trailing: Text('${totalDistance.toStringAsFixed(1)} km'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}