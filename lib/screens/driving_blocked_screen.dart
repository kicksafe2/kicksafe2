import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../routes/app_routes.dart';
import '../widgets/kicksafe_ui.dart';

/// Figma 디자인(DrivingBlockedScreen.tsx): 예상 주행 시간이 제한을 넘을 때 보여주는 안내 화면.
/// 지도 화면이 `arguments: {'estimatedMinutes': 분}` 으로 시간을 넘겨준다. (없으면 120분)
class DrivingBlockedScreen extends StatelessWidget {
  const DrivingBlockedScreen({super.key});

  int _estimatedMinutes(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['estimatedMinutes'] is int) {
      return args['estimatedMinutes'] as int;
    }
    return 120;
  }

  void _goMap(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed(AppRoutes.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _estimatedMinutes(context);
    final limitH = AppConfig.maxRideMinutes ~/ 60;
    final limitM = AppConfig.maxRideMinutes % 60;
    final limitText = limitM == 0 ? '$limitH시간' : '$limitH시간 $limitM분';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KsColors.red50, KsColors.pink50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              KsHeader(
                title: '주행 불가',
                onBack: () => _goMap(context),
                gradient: const LinearGradient(colors: [KsColors.red600, KsColors.pink700]),
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
                          const KsPulseIcon(icon: Icons.cancel_outlined, color: KsColors.red600),
                          const SizedBox(height: 20),
                          const Text(
                            '주행 불가',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: KsColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '예상 주행 시간이 $limitText을 초과합니다',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: KsColors.gray500, fontSize: 15),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: KsColors.red50,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: KsColors.red200),
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.access_time, color: KsColors.red600, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      '예상 주행 시간',
                                      style: TextStyle(color: KsColors.gray500, fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${minutes ~/ 60}시간 ${minutes % 60}분',
                                  style: const TextStyle(
                                    color: KsColors.red600,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: KsColors.gray50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '안전한 주행을 위해 $limitText 이내의 경로만 이용 가능합니다. 다른 도착지를 선택해주세요.',
                              style: const TextStyle(color: KsColors.gray500, fontSize: 13, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 24),
                          KsGradientButton(
                            label: '다른 경로 선택',
                            onPressed: () => _goMap(context),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context)
                                  .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: KsColors.gray300, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                '메인으로 돌아가기',
                                style: TextStyle(
                                  color: KsColors.gray700,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
