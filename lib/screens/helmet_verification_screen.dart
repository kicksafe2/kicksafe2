import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../routes/app_routes.dart';

/// Figma 디자인(Kicksafe Android UI_UX / HelmetVerificationScreen.tsx)을 그대로 옮긴
/// 헬멧 인증 화면. 카메라로 촬영해 Teachable Machine TFLite 모델로 착용 여부를 판별한다.
///
/// 원본 디자인 로직:
/// - 실패할 때마다 시도 횟수 +1 (성공하면 0으로 초기화)
/// - 5회 실패하면 24시간 동안 잠김(잠김 화면 + 카운트다운)
class HelmetVerificationScreen extends StatefulWidget {
  const HelmetVerificationScreen({super.key});

  @override
  State<HelmetVerificationScreen> createState() =>
      _HelmetVerificationScreenState();
}

enum _VerifyResult { success, failed }

class _HelmetVerificationScreenState extends State<HelmetVerificationScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxAttempts = 5;
  static const Duration _lockDuration = Duration(hours: 24);
  static const String _attemptsKey = 'helmet_attempts';
  static const String _lockUntilKey = 'helmet_lock_until';

  static const int _inputSize = 224;
  static const String _modelAsset = 'lib/assets/model/model_unquant.tflite';
  static const String _labelsAsset = 'lib/assets/model/labels.txt';

  // ---- Figma 디자인 색상 (Tailwind 팔레트) ----
  static const _purple50 = Color(0xFFFAF5FF);
  static const _purple200 = Color(0xFFE9D5FF);
  static const _purple600 = Color(0xFF9333EA);
  static const _indigo50 = Color(0xFFEEF2FF);
  static const _indigo700 = Color(0xFF4338CA);
  static const _indigo800 = Color(0xFF3730A3);
  static const _red50 = Color(0xFFFEF2F2);
  static const _red200 = Color(0xFFFECACA);
  static const _red400 = Color(0xFFF87171);
  static const _red600 = Color(0xFFDC2626);
  static const _pink50 = Color(0xFFFDF2F8);
  static const _pink700 = Color(0xFFBE185D);
  static const _gray50 = Color(0xFFF9FAFB);
  static const _gray200 = Color(0xFFE5E7EB);
  static const _gray600 = Color(0xFF4B5563);
  static const _gray800 = Color(0xFF1F2937);
  static const _gray900 = Color(0xFF111827);
  static const _green400 = Color(0xFF4ADE80);

  CameraController? _cameraController;
  Interpreter? _interpreter;
  List<String> _labels = [];

  bool _cameraReady = false;
  String? _initError;

  bool _isVerifying = false;
  _VerifyResult? _result;

  int _attempts = 0;
  bool _isLocked = false;
  int? _lockEndMillis;
  String _remainingTime = '';
  Timer? _lockTimer;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _pulseController.dispose();
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadLockState();
    if (_isLocked) return; // 잠긴 상태면 카메라/모델 초기화할 필요 없음
    try {
      await _loadModel();
      await _initCamera();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = '초기화에 실패했습니다: $e');
    }
  }

  Future<void> _loadLockState() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntil = prefs.getInt(_lockUntilKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lockUntil != null && now < lockUntil) {
      setState(() {
        _isLocked = true;
        _lockEndMillis = lockUntil;
      });
      _startLockTimer();
    } else {
      if (lockUntil != null) {
        await prefs.remove(_lockUntilKey);
        await prefs.remove(_attemptsKey);
      }
      _attempts = prefs.getInt(_attemptsKey) ?? 0;
    }
  }

  void _startLockTimer() {
    _updateRemainingTime();
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  Future<void> _updateRemainingTime() async {
    final lockEnd = _lockEndMillis;
    if (lockEnd == null) return;
    final remaining = lockEnd - DateTime.now().millisecondsSinceEpoch;

    if (remaining <= 0) {
      _lockTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lockUntilKey);
      await prefs.remove(_attemptsKey);
      if (!mounted) return;
      setState(() {
        _isLocked = false;
        _lockEndMillis = null;
        _attempts = 0;
      });
      await _bootstrap();
      return;
    }

    final hours = remaining ~/ (1000 * 60 * 60);
    final minutes = (remaining % (1000 * 60 * 60)) ~/ (1000 * 60);
    final seconds = (remaining % (1000 * 60)) ~/ 1000;
    if (!mounted) return;
    setState(() {
      _remainingTime = '$hours시간 $minutes분 $seconds초';
    });
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset(_modelAsset);
    final raw = await rootBundle.loadString(_labelsAsset);
    _labels = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          // Teachable Machine 형식: "0 helmet" -> 인덱스 제거하고 라벨만 사용
          final parts = line.split(' ');
          return parts.length > 1 ? parts.sublist(1).join(' ') : line;
        })
        .toList();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('사용 가능한 카메라가 없습니다.');
    }
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    _cameraController = controller;
  }

  /// [-1, 1]로 정규화한 [1, 224, 224, 3] 텐서로 변환 (Teachable Machine 표준 전처리)
  List<List<List<List<double>>>> _preprocess(img.Image source) {
    final resized = img.copyResize(source, width: _inputSize, height: _inputSize);
    return [
      List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 127.5,
            (pixel.g - 127.5) / 127.5,
            (pixel.b - 127.5) / 127.5,
          ];
        }),
      ),
    ];
  }

  Future<void> _handleVerify() async {
    final controller = _cameraController;
    final interpreter = _interpreter;
    if (_isVerifying || _isLocked || controller == null || interpreter == null) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _result = null;
    });

    bool isHelmet = false;
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('촬영한 이미지를 디코딩하지 못했습니다.');

      final input = _preprocess(decoded);
      final output = [List.filled(_labels.length, 0.0)];
      interpreter.run(input, output);

      final scores = output[0];
      var bestIndex = 0;
      for (var i = 1; i < scores.length; i++) {
        if (scores[i] > scores[bestIndex]) bestIndex = i;
      }
      final label = _labels.isNotEmpty ? _labels[bestIndex] : '';
      isHelmet = label.toLowerCase().contains('no helmet') == false &&
          label.toLowerCase().contains('helmet');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _initError = '인식에 실패했습니다: $e';
      });
      return;
    }

    await _applyResult(isHelmet);
  }

  Future<void> _applyResult(bool success) async {
    final prefs = await SharedPreferences.getInstance();

    if (success) {
      await prefs.remove(_attemptsKey);
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _result = _VerifyResult.success;
        _attempts = 0;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.map);
      });
      return;
    }

    final newAttempts = _attempts + 1;
    await prefs.setInt(_attemptsKey, newAttempts);

    if (newAttempts >= _maxAttempts) {
      final lockEnd = DateTime.now().add(_lockDuration).millisecondsSinceEpoch;
      await prefs.setInt(_lockUntilKey, lockEnd);
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _attempts = newAttempts;
        _isLocked = true;
        _lockEndMillis = lockEnd;
      });
      _startLockTimer();
      return;
    }

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _result = _VerifyResult.failed;
      _attempts = newAttempts;
    });
  }

  void _goHome() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLocked ? _buildLockedView() : _buildMainView(),
    );
  }

  // ---------------- 메인(잠기지 않은) 화면 ----------------

  Widget _buildMainView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_purple50, _indigo50],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(
              title: '헬멧 인증',
              gradientColors: const [_purple600, _indigo700],
              onBack: _goHome,
            ),
            _buildAttemptCounter(),
            Expanded(
              child: _initError != null
                  ? _buildErrorPanel()
                  : !_cameraReady
                      ? const Center(child: CircularProgressIndicator(color: _purple600))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                          child: Column(
                            children: [
                              _buildCameraCard(),
                              const SizedBox(height: 24),
                              _buildInfoBox(),
                              const SizedBox(height: 24),
                              _buildActionButton(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String title,
    required List<Color> gradientColors,
    required VoidCallback onBack,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
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
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 16),
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

  Widget _buildAttemptCounter() {
    final warn = _attempts >= 4;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _gray200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('인증 시도', style: TextStyle(color: _gray600, fontSize: 14)),
              Text(
                '$_attempts / $_maxAttempts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: warn ? _red600 : _purple600,
                ),
              ),
            ],
          ),
          if (_attempts >= 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_maxAttempts - _attempts}회 더 실패하면 24시간 동안 잠금됩니다',
                style: const TextStyle(color: _red600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraCard() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 카메라 실시간 프리뷰 (실제 촬영 화면)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gray800, _gray900],
                ),
              ),
              child: _cameraController != null &&
                      _cameraController!.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize?.height ?? 1,
                        height: _cameraController!.value.previewSize?.width ?? 1,
                        child: CameraPreview(_cameraController!),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // 상태별 오버레이
            if (!_isVerifying && _result == null) ...[
              // 얼굴 가이드 원형 프레임
              Center(
                child: Container(
                  width: 220,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 4),
                    borderRadius: BorderRadius.circular(140),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '얼굴을 화면에 맞춰주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ],
            if (_isVerifying)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('헬멧 인증 중...', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            if (_result == _VerifyResult.success)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPulseGlow(icon: Icons.check_circle, color: _green400),
                      const SizedBox(height: 12),
                      const Text(
                        '인증 성공!',
                        style: TextStyle(color: _green400, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            if (_result == _VerifyResult.failed)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPulseGlow(icon: Icons.cancel, color: _red400),
                      const SizedBox(height: 12),
                      const Text(
                        '인증 실패',
                        style: TextStyle(color: _red400, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text('헬멧을 착용해주세요', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseGlow({required IconData icon, required Color color}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = _pulseController.value; // 0..1
        return Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35 + 0.25 * t),
                blurRadius: 40 + 20 * t,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 72),
        );
      },
    );
  }

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _purple50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple200),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield, color: _purple600, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안전을 위한 헬멧 착용 필수',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                ),
                SizedBox(height: 8),
                _InfoBullet('얼굴을 화면 안내선에 맞춰주세요'),
                _InfoBullet('헬멧을 정확히 착용해주세요'),
                _InfoBullet('밝은 곳에서 인증해주세요'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final disabled = _isVerifying || _result == _VerifyResult.success;
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_purple600, _indigo700]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: _purple600.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: disabled ? null : _handleVerify,
            child: Opacity(
              opacity: disabled ? 0.5 : 1,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isVerifying && _result != _VerifyResult.success) ...[
                      const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _isVerifying
                          ? '인증 중...'
                          : _result == _VerifyResult.success
                              ? '인증 완료'
                              : '헬멧 인증 시작',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _initError!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _red600),
        ),
      ),
    );
  }

  // ---------------- 잠김 화면 ----------------

  Widget _buildLockedView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_red50, _pink50],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(
              title: '헬멧 인증',
              gradientColors: const [_red600, _pink700],
              onBack: _goHome,
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
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
                        _buildPulseGlow(icon: Icons.warning_amber_rounded, color: _red600),
                        const SizedBox(height: 20),
                        const Text(
                          '계정 잠김',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '헬멧 인증을 5회 이상 실패하여\n24시간 동안 서비스 이용이 제한됩니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _gray600, fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _red50,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _red200),
                          ),
                          child: Column(
                            children: [
                              const Text('잠금 해제까지', style: TextStyle(color: _gray600, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                _remainingTime,
                                style: const TextStyle(
                                  color: _red600,
                                  fontSize: 26,
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
                            color: _gray50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '안전을 위해 헬멧 착용은 필수입니다. 잠금 해제 후 다시 시도해주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _gray600, fontSize: 13, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_purple600, _indigo800]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _goHome,
                                child: const Center(
                                  child: Text(
                                    '메인으로 돌아가기',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
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
    );
  }
}

class _InfoBullet extends StatelessWidget {
  final String text;
  const _InfoBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: Colors.black87, fontSize: 13)),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
