import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_store.dart';
import '../widgets/ad_banner.dart';
import 'location_page.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return; // 사용자가 로그인을 취소함

      AuthStore.currentEmail = account.email;

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('구글 로그인 실패: $e')));
      }
    }
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
