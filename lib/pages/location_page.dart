import 'package:flutter/material.dart';
import '../widgets/ad_banner.dart';
import 'meter_page.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  String selectedRegion = '인천';

  final List<String> regions = [
    '서울',
    '인천',
    '부산',
    '대구',
    '광주',
    '대전',
    '울산',
    '세종',
    '경기',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '제주',
  ];

  void _startMeter() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MeterPage(region: selectedRegion)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지역 설정'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  children: [
                    const SizedBox(height: 25),

                    const Icon(
                      Icons.location_on,
                      size: 65,
                      color: Colors.greenAccent,
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      '현재 지역',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      selectedRegion,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 35),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('GPS 기능은 다음 단계에서 연결합니다.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.gps_fixed),
                        label: const Text(
                          'GPS로 현재 지역 확인',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      initialValue: selectedRegion,
                      decoration: const InputDecoration(
                        labelText: '지역 직접 선택',
                        border: OutlineInputBorder(),
                      ),
                      items: regions.map((region) {
                        return DropdownMenuItem(
                          value: region,
                          child: Text(region),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedRegion = value;
                          });
                        }
                      },
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _startMeter,
                        child: const Text(
                          '확인',
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

            const AdBanner(),
          ],
        ),
      ),
    );
  }
}
