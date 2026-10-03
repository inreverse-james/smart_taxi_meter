import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_store.dart';
import '../widgets/ad_banner.dart';
import 'location_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      // v7 최신 API: GoogleSignIn.instance.authenticate() 사용
      final account = await GoogleSignIn.instance.authenticate();

      AuthStore.currentEmail = account.email;

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
        );
      }
    } on GoogleSignInException catch (e) {
      // 사용자가 로그인 창을 닫은 경우에는 아무 메시지도 띄우지 않음
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      debugPrint('구글 로그인 실패: $e');
      if (context.mounted) _showLoginError(context);
    } catch (e) {
      debugPrint('구글 로그인 실패: $e');
      if (context.mounted) _showLoginError(context);
    }
  }

  // 자세한 오류는 호출하는 곳에서 개발 로그에만 남기고, 사용자에게는 짧은 안내만 보여줌
  void _showLoginError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('구글 로그인에 실패했습니다. 잠시 후 다시 시도해주세요.')),
    );
  }

  void _continueAsGuest(BuildContext context) {
    AuthStore.currentEmail = '게스트';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LocationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🚕', style: TextStyle(fontSize: 80)),
                      const SizedBox(height: 15),
                      const Text(
                        'SMART TAXI',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      const Text(
                        'METER',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.greenAccent,
                          letterSpacing: 5,
                        ),
                      ),
                      const SizedBox(height: 60),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () => _signInWithGoogle(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text(
                            'Google 로그인',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton(
                          onPressed: () => _continueAsGuest(context),
                          child: const Text(
                            '게스트로 시작',
                            style: TextStyle(fontSize: 17),
                          ),
                        ),
                      ),
                    ],
                  ),
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