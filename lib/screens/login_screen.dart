import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/local_auth_service.dart';
import '../widgets/kicksafe_ui.dart';

/// Figma 디자인(LoginScreen.tsx): 헤더 + 흰색 카드 로그인 폼.
/// 가입한 계정(아이디/비밀번호)과 일치하면 홈으로 이동한다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty || _busy) return;

    setState(() => _busy = true);
    final ok = await LocalAuthService.login(username, password);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디 또는 비밀번호가 올바르지 않습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: KsColors.lightBackground),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  gradient: KsColors.brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.white, size: 40),
                    SizedBox(width: 12),
                    Text(
                      'kicksafe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 448),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '로그인',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: KsColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 32),
                          KsLabeledField(
                            label: '아이디',
                            icon: Icons.person_outline,
                            controller: _usernameController,
                            hint: '아이디를 입력하세요',
                          ),
                          const SizedBox(height: 24),
                          KsLabeledField(
                            label: '비밀번호',
                            icon: Icons.lock_outline,
                            controller: _passwordController,
                            hint: '비밀번호를 입력하세요',
                            obscure: true,
                          ),
                          const SizedBox(height: 24),
                          KsGradientButton(
                            label: '로그인',
                            onPressed: _busy ? null : _handleLogin,
                            trailing: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
                            child: const Text(
                              '계정이 없으신가요? 회원가입',
                              style: TextStyle(color: KsColors.purple600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
