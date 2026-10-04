import 'package:flutter/material.dart';
import 'pages/location_page.dart';
import 'pages/meter_page.dart';
import 'services/drive_store.dart';
import 'services/ride_store.dart';

void main() async {
  // 비동기 초기화를 위한 바인딩 등록
  WidgetsFlutterBinding.ensureInitialized();

  // 진행 중이던 주행이 저장돼 있으면 불러오기
  await DriveStore.load();

  // 저장된 최근 주행 기록 불러오기
  await RideStore.load();

  runApp(const SmartTaxiMeterApp());
}

class SmartTaxiMeterApp extends StatelessWidget {
  const SmartTaxiMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = DriveStore.active;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'smart taxi meter',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      // 진행 중인 주행이 있으면 지역 선택 없이 바로 미터 화면으로 이동
      home: session != null
          ? MeterPage(region: session.region)
          : const LocationPage(),
    );
  }
}