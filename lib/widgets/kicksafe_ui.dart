import 'package:flutter/material.dart';

/// 스플래시/온보딩/로그인/회원가입 화면이 공유하는 Figma(Tailwind) 팔레트와 공용 위젯.
class KsColors {
  KsColors._();

  static const purple50 = Color(0xFFFAF5FF);
  static const purple100 = Color(0xFFF3E8FF);
  static const purple200 = Color(0xFFE9D5FF);
  static const purple500 = Color(0xFFA855F7);
  static const purple600 = Color(0xFF9333EA);
  static const purple700 = Color(0xFF7E22CE);
  static const purple800 = Color(0xFF6B21A8);
  static const indigo50 = Color(0xFFEEF2FF);
  static const indigo700 = Color(0xFF4338CA);
  static const indigo800 = Color(0xFF3730A3);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const green300 = Color(0xFF86EFAC);
  static const green600 = Color(0xFF16A34A);
  static const red600 = Color(0xFFDC2626);
  static const yellow300 = Color(0xFFFCD34D);
  static const inputBackground = Color(0xFFF3F3F5);

  /// bg-gradient-to-br from-purple-50 to-indigo-50
  static const lightBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple50, indigo50],
  );

  /// bg-gradient-to-r from-purple-600 to-indigo-700
  static const brandGradient = LinearGradient(colors: [purple600, indigo700]);
}

/// 퍼플→인디고 그라데이션 헤더 (뒤로가기 포함 여부 선택)
class KsHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? leading;

  const KsHeader({super.key, required this.title, this.onBack, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
      child: Row(
        children: [
          if (onBack != null) ...[
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 그라데이션 풀폭 버튼 (h-14, rounded-xl)
class KsGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? trailing;
  final double height;

  const KsGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailing,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [KsColors.purple600, KsColors.indigo700],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: KsColors.purple600.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 아이콘+라벨이 붙은 입력 필드 (h-14, rounded-xl, border-2)
class KsLabeledField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;

  const KsLabeledField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: KsColors.purple600),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: KsColors.gray700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  readOnly: readOnly,
                  onTap: onTap,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: KsColors.gray500),
                    filled: true,
                    fillColor: KsColors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: KsColors.gray200, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: KsColors.purple500, width: 2),
                    ),
                  ),
                ),
              ),
            ),
            if (suffix != null) ...[const SizedBox(width: 8), suffix!],
          ],
        ),
      ],
    );
  }
}

/// 은은하게 숨쉬는 흰색 글로우 + 방패 아이콘 (스플래시/온보딩 공통)
class KsGlowShield extends StatefulWidget {
  final double size;
  const KsGlowShield({super.key, this.size = 128});

  @override
  State<KsGlowShield> createState() => _KsGlowShieldState();
}

class _KsGlowShieldState extends State<KsGlowShield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.12 + 0.12 * _c.value),
                blurRadius: 60,
                spreadRadius: 20,
              ),
            ],
          ),
          child: Icon(Icons.shield_outlined, color: Colors.white, size: widget.size),
        );
      },
    );
  }
}
