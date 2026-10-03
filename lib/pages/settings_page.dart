import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_store.dart';
import '../services/drive_store.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final String googleId = AuthStore.currentEmail;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('로그아웃'),
          content: Text(
            DriveStore.active != null
                ? '정말 로그아웃 하시겠습니까?\n진행 중인 주행은 종료되며 저장되지 않습니다.'
                : '정말 로그아웃 하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      // 구글 계정도 실제로 로그아웃
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('구글 로그아웃 오류: $e');
      }

      // 진행 중이던 주행 정보 삭제 (다음 사용자에게 이어지지 않도록)
      await DriveStore.clear();

      if (!mounted) return;
      AuthStore.currentEmail = '게스트';

      // 로그인 페이지까지 스택을 전부 비우고 이동 (뒤로가기로 미터 화면 복귀 방지)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionLabel('계정'),

            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.account_circle,
                      color: Colors.greenAccent,
                    ),
                    title: const Text('구글 아이디'),
                    subtitle: Text(
                      googleId,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text(
                      '로그아웃',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
