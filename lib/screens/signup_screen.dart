import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/local_auth_service.dart';
import '../widgets/kicksafe_ui.dart';

/// Figma 디자인(SignupScreen.tsx): 3단계 회원가입.
/// 1 기본정보(이름/생년월일/주소) → 2 계정정보(아이디 중복확인/비밀번호) → 3 연락처 + 약관 동의.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _birthdate = TextEditingController();
  final _address = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  int _step = 1;
  bool _usernameChecked = false;
  bool _usernameAvailable = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [
      _name, _birthdate, _address, _username, _password,
      _confirmPassword, _phone, _email,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _passwordMatch =>
      _password.text.isNotEmpty &&
      _confirmPassword.text.isNotEmpty &&
      _password.text == _confirmPassword.text;
  bool get _passwordMismatch =>
      _password.text.isNotEmpty &&
      _confirmPassword.text.isNotEmpty &&
      _password.text != _confirmPassword.text;

  void _goBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed(AppRoutes.login);
    }
  }

  Future<void> _pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    setState(() => _birthdate.text = '${picked.year}-$m-$d');
  }

  Future<void> _checkUsername() async {
    final taken = await LocalAuthService.isUsernameTaken(_username.text.trim());
    if (!mounted) return;
    setState(() {
      _usernameChecked = true;
      _usernameAvailable = !taken;
    });
  }

  Future<void> _showAlert(String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('확인')),
        ],
      ),
    );
  }

  Future<void> _handleSignup() async {
    if (_submitting) return;
    if (!_passwordMatch) {
      await _showAlert('비밀번호가 일치하지 않습니다');
      return;
    }
    if (!_usernameChecked || !_usernameAvailable) {
      await _showAlert('아이디 중복 확인을 해주세요');
      return;
    }

    setState(() => _submitting = true);
    await LocalAuthService.register(
      name: _name.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      birthdate: _birthdate.text,
      address: _address.text.trim(),
    );
    if (!mounted) return;
    await _showAlert('회원가입이 완료되었습니다!');
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: KsColors.lightBackground),
        child: SafeArea(
          child: Column(
            children: [
              KsHeader(title: '회원가입', onBack: _goBack),
              _buildProgress(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: switch (_step) {
                    1 => _stepBasic(),
                    2 => _stepAccount(),
                    _ => _stepContact(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    const labels = ['기본정보', '계정정보', '연락처'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: KsColors.gray200)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 3; i++)
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _step >= i + 1 ? KsColors.purple600 : KsColors.gray400,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: _step >= i + 1 ? KsColors.purple600 : KsColors.gray200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepHeader(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, size: 64, color: KsColors.purple600),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: KsColors.gray800,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: KsColors.gray500)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _outlineButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: KsColors.gray300, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: KsColors.gray700,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _status(bool ok, String okText, String badText) {
    final color = ok ? KsColors.green600 : KsColors.red600;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Text(ok ? okText : badText, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  // ---- 1단계: 기본 정보 ----
  Widget _stepBasic() {
    final canNext = _name.text.isNotEmpty &&
        _birthdate.text.isNotEmpty &&
        _address.text.trim().isNotEmpty;
    return Column(
      children: [
        _stepHeader(Icons.shield_outlined, '기본 정보', '회원님의 기본 정보를 입력해주세요'),
        KsLabeledField(
          label: '이름',
          icon: Icons.person_outline,
          controller: _name,
          hint: '이름을 입력하세요',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        KsLabeledField(
          label: '생년월일',
          icon: Icons.badge_outlined,
          controller: _birthdate,
          hint: '생년월일을 선택하세요',
          readOnly: true,
          onTap: _pickBirthdate,
        ),
        const SizedBox(height: 16),
        KsLabeledField(
          label: '주소',
          icon: Icons.badge_outlined,
          controller: _address,
          hint: '주소를 입력하세요',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        KsGradientButton(
          label: '다음',
          onPressed: canNext ? () => setState(() => _step = 2) : null,
        ),
      ],
    );
  }

  // ---- 2단계: 계정 정보 ----
  Widget _stepAccount() {
    final canNext = _username.text.isNotEmpty &&
        _password.text.isNotEmpty &&
        _confirmPassword.text.isNotEmpty &&
        _usernameChecked &&
        _usernameAvailable &&
        _passwordMatch;
    return Column(
      children: [
        _stepHeader(Icons.lock_outline, '계정 정보', '로그인에 사용할 정보를 입력해주세요'),
        KsLabeledField(
          label: '아이디',
          icon: Icons.person_outline,
          controller: _username,
          hint: '아이디를 입력하세요',
          onChanged: (_) => setState(() => _usernameChecked = false),
          suffix: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _username.text.trim().isEmpty ? null : _checkUsername,
              style: ElevatedButton.styleFrom(
                backgroundColor: KsColors.purple600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('중복확인'),
            ),
          ),
        ),
        if (_usernameChecked)
          Align(
            alignment: Alignment.centerLeft,
            child: _status(_usernameAvailable, '사용 가능한 아이디입니다', '이미 사용 중인 아이디입니다'),
          ),
        const SizedBox(height: 16),
        KsLabeledField(
          label: '비밀번호',
          icon: Icons.lock_outline,
          controller: _password,
          hint: '비밀번호를 입력하세요',
          obscure: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        KsLabeledField(
          label: '비밀번호 확인',
          icon: Icons.lock_outline,
          controller: _confirmPassword,
          hint: '비밀번호를 다시 입력하세요',
          obscure: true,
          onChanged: (_) => setState(() {}),
        ),
        if (_passwordMatch)
          Align(
            alignment: Alignment.centerLeft,
            child: _status(true, '비밀번호가 일치합니다', ''),
          ),
        if (_passwordMismatch)
          Align(
            alignment: Alignment.centerLeft,
            child: _status(false, '', '비밀번호가 일치하지 않습니다'),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _outlineButton('이전', () => setState(() => _step = 1))),
            const SizedBox(width: 12),
            Expanded(
              child: KsGradientButton(
                label: '다음',
                onPressed: canNext ? () => setState(() => _step = 3) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- 3단계: 연락처 + 약관 ----
  Widget _stepContact() {
    final canSubmit = _phone.text.trim().isNotEmpty &&
        _email.text.trim().isNotEmpty &&
        _agreeTerms &&
        _agreePrivacy;
    return Column(
      children: [
        _stepHeader(Icons.mail_outline, '연락처 정보', '연락 가능한 정보를 입력해주세요'),
        KsLabeledField(
          label: '전화번호',
          icon: Icons.phone_outlined,
          controller: _phone,
          hint: '010-0000-0000',
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        KsLabeledField(
          label: '이메일',
          icon: Icons.mail_outline,
          controller: _email,
          hint: 'example@email.com',
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KsColors.purple50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KsColors.purple200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '약관 동의',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: KsColors.gray800,
                ),
              ),
              const SizedBox(height: 8),
              _agreeRow(
                '[필수]',
                ' kicksafe 이용약관에 동의합니다',
                _agreeTerms,
                (v) => setState(() => _agreeTerms = v),
              ),
              _agreeRow(
                '[필수]',
                ' 개인정보 처리방침에 동의합니다',
                _agreePrivacy,
                (v) => setState(() => _agreePrivacy = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _outlineButton('이전', () => setState(() => _step = 2))),
            const SizedBox(width: 12),
            Expanded(
              child: KsGradientButton(
                label: '가입완료',
                onPressed: canSubmit && !_submitting ? _handleSignup : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _agreeRow(String tag, String text, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: KsColors.purple600,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: tag,
                      style: const TextStyle(
                        color: KsColors.purple600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: text),
                  ],
                ),
                style: const TextStyle(fontSize: 14, color: KsColors.gray700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
