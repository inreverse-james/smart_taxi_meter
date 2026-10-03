import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/ad_banner.dart';
import 'meter_page.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  String selectedRegion = '서울';

  final List<String> regions = [
    '서울',
    '경기도',
    '충청도',
    '경상도',
    '전라도',
    '강원도',
    '제주도',
  ];

  bool _locating = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // 시/도 이름(예: '서울특별시', '충청북도')을 앱의 7개 지역으로 변환
  String? _regionFromAdminArea(String? area) {
    if (area == null) return null;

    const Map<String, String> prefixToRegion = {
      '서울': '서울',
      '경기': '경기도',
      '인천': '경기도',
      '대전': '충청도',
      '세종': '충청도',
      '충청': '충청도',
      '부산': '경상도',
      '대구': '경상도',
      '울산': '경상도',
      '경상': '경상도',
      '광주': '전라도',
      '전라': '전라도',
      '전북': '전라도',
      '강원': '강원도',
      '제주': '제주도',
    };

    for (final entry in prefixToRegion.entries) {
      if (area.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  // GPS로 현재 지역 확인
  Future<void> _detectRegion() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('스마트폰의 위치(GPS) 기능을 켜주세요.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('위치 권한이 필요합니다. 지역을 직접 선택해주세요.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // geocoding 5.0.0 방식: Geocoding 객체를 만들어 사용하고, 한국어 주소로 받기 위해 locale을 직접 전달
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        locale: const Locale('ko', 'KR'),
      );

      final region = placemarks.isEmpty
          ? null
          : _regionFromAdminArea(placemarks.first.administrativeArea);

      if (region == null) {
        _showMessage('현재 지역을 확인할 수 없습니다. 직접 선택해주세요.');
        return;
      }

      if (!mounted) return;
      setState(() => selectedRegion = region);
    } catch (e) {
      debugPrint('지역 확인 실패: $e');
      _showMessage('현재 지역을 확인하지 못했습니다. 직접 선택해주세요.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

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
                        onPressed: _locating ? null : _detectRegion,
                        icon: const Icon(Icons.gps_fixed),
                        label: Text(
                          _locating ? '확인 중...' : 'GPS로 현재 지역 확인',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedRegion),
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