import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';

/// Figma 디자인(Kicksafe Android UI_UX / HomeScreen.tsx)을 그대로 옮긴 홈 화면.
///
/// - 상단: 인사 헤더 + "오늘도 safe하게 주행 시작하기" 배너
/// - 통계 카드 3개(주행시간/안전점수/배지) — 안전점수·배지는 각각 히스토리/배지맵으로 이동
/// - 최근 주행 목록, 안전 운전 팁
/// - 하단 네비게이션(계정 / 헬멧 인증 / 기록)
///
/// 주행시간·안전점수·최근 주행 목록은 아직 실제 주행 기록 기능이 없어 원본 디자인의
/// 데모 값을 그대로 쓰고, username/배지 개수는 SharedPreferences에서 읽어온다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _usernameKey = 'username';
  static const _badgeCountKey = 'badge_count';

  // ---- Figma 디자인 색상 (Tailwind 팔레트) ----
  static const _purple50 = Color(0xFFFAF5FF);
  static const _purple100 = Color(0xFFF3E8FF);
  static const _purple600 = Color(0xFF9333EA);
  static const _indigo50 = Color(0xFFEEF2FF);
  static const _indigo600 = Color(0xFF4F46E5);
  static const _indigo700 = Color(0xFF4338CA);
  static const _yellow50 = Color(0xFFFFFBEB);
  static const _yellow200 = Color(0xFFFDE68A);
  static const _yellow300 = Color(0xFFFCD34D);
  static const _orange50 = Color(0xFFFFF7ED);
  static const _orange600 = Color(0xFFEA580C);
  static const _gray50 = Color(0xFFF9FAFB);
  static const _gray200 = Color(0xFFE5E7EB);
  static const _gray400 = Color(0xFF9CA3AF);
  static const _gray500 = Color(0xFF6B7280);
  static const _gray800 = Color(0xFF1F2937);

  String _username = '사용자';
  int _badgeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _username = prefs.getString(_usernameKey) ?? '사용자';
      _badgeCount = prefs.getInt(_badgeCountKey) ?? 0;
    });
  }

  void _goTo(String route) {
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_purple50, _indigo50],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopSection(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildRecentActivity(),
                      const SizedBox(height: 24),
                      _buildTipsSection(),
                    ],
                  ),
                ),
              ),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 상단 헤더 ----------------

  Widget _buildTopSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_purple600, _indigo700]),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'kicksafe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_username님, 환영합니다',
                      style: const TextStyle(color: _purple100, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _goTo(AppRoutes.account),
                icon: const Icon(Icons.settings, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: _yellow300, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '오늘도 safe하게 주행 시작하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '안전한 하루를 위해 준비되었습니다',
                  style: TextStyle(color: _purple100, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 통계 카드 3개 ----------------

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.access_time,
            iconColor: _purple600,
            value: '24',
            label: '주행시간',
            onTap: null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.insights,
            iconColor: _indigo600,
            value: '95%',
            label: '안전점수',
            onTap: () => _goTo(AppRoutes.history),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.emoji_events,
            iconColor: _purple600,
            value: '$_badgeCount',
            label: '배지',
            onTap: () => _goTo(AppRoutes.badgeMap),
          ),
        ),
      ],
    );
  }

  // ---------------- 최근 주행 ----------------

  Widget _buildRecentActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 주행',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _gray800),
              ),
              TextButton(
                onPressed: () => _goTo(AppRoutes.history),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '전체보기',
                  style: TextStyle(color: _purple600, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TripTile(
            color: _purple600,
            background: _purple50,
            route: '서울 → 인천',
            detail: '2시간 15분 · 45.2km',
            score: '98점',
            scoreColor: _purple600,
          ),
          const SizedBox(height: 10),
          _TripTile(
            color: _indigo600,
            background: _gray50,
            route: '분당 → 강남',
            detail: '45분 · 18.5km',
            score: '92점',
            scoreColor: _indigo600,
          ),
        ],
      ),
    );
  }

  // ---------------- 안전 운전 팁 ----------------

  Widget _buildTipsSection() {
    final remaining = (5 - _badgeCount).clamp(0, 5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_yellow50, _orange50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _yellow200, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.trending_up, color: _orange600, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '안전 운전 팁',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _gray800),
                ),
                const SizedBox(height: 6),
                Text(
                  '급제동과 급가속을 줄이면 안전점수가 향상됩니다. '
                  '배지 $remaining개만 더 모으면 혜택을 받을 수 있어요!',
                  style: const TextStyle(color: _gray500, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 하단 네비게이션 ----------------

  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _gray200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIconButton(
            icon: Icons.person_outline,
            label: '계정',
            onTap: () => _goTo(AppRoutes.account),
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: GestureDetector(
              onTap: () => _goTo(AppRoutes.helmetVerification),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_purple600, _indigo700]),
                  boxShadow: [
                    BoxShadow(
                      color: _purple600.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
            ),
          ),
          _NavIconButton(
            icon: Icons.insights,
            label: '기록',
            onTap: () => _goTo(AppRoutes.history),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _HomeScreenState._gray800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: _HomeScreenState._gray500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final Color color;
  final Color background;
  final String route;
  final String detail;
  final String score;
  final Color scoreColor;

  const _TripTile({
    required this.color,
    required this.background,
    required this.route,
    required this.detail,
    required this.score,
    required this.scoreColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.location_on, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _HomeScreenState._gray800,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 12, color: _HomeScreenState._gray500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: scoreColor),
              ),
              const Text('안전', style: TextStyle(fontSize: 11, color: _HomeScreenState._gray500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavIconButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _HomeScreenState._gray400, size: 24),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: _HomeScreenState._gray400)),
          ],
        ),
      ),
    );
  }
}
