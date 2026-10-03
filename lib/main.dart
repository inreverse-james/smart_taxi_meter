import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'pages/login_page.dart';
import 'pages/meter_page.dart';
import 'services/auth_store.dart';
import 'services/drive_store.dart';

void main() async {
  // 비동기 초기화를 위한 바인딩 등록
  WidgetsFlutterBinding.ensureInitialized();

  // google_sign_in v7 필수 초기화
  await GoogleSignIn.instance.initialize();

  // 진행 중이던 주행이 저장돼 있으면 불러오기
  await DriveStore.load();
  final session = DriveStore.active;
  if (session != null) {
    AuthStore.currentEmail = session.email;
  }

  runApp(const SmartTaxiMeterApp());
}

class SmartTaxiMeterApp extends StatelessWidget {
  const SmartTaxiMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = DriveStore.active;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '택시미터앱',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      // 진행 중인 주행이 있으면 로그인 화면 없이 바로 미터 화면으로 이동
      home: session != null ? MeterPage(region: session.region) : LoginPage(),
    );
  }
}