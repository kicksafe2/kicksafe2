import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../theme/app_colors.dart';

/// Teachable Machine에서 내보낸 model_unquant.tflite(helmet / No helmet 2-class)로
/// 카메라 프레임을 분류해 헬멧 착용 여부를 인증하는 화면.
/// 기기당 최대 [maxVerificationCount]회까지만 인증을 허용한다.
class HelmetVerificationScreen extends StatefulWidget {
  const HelmetVerificationScreen({super.key});

  @override
  State<HelmetVerificationScreen> createState() =>
      _HelmetVerificationScreenState();
}

class _HelmetVerificationScreenState extends State<HelmetVerificationScreen> {
  static const int maxVerificationCount = 5;
  static const String _prefsKey = 'helmet_verification_count';
  static const int _inputSize = 224;
  static const String _modelAsset = 'lib/assets/model/model_unquant.tflite';
  static const String _labelsAsset = 'lib/assets/model/labels.txt';

  CameraController? _cameraController;
  Interpreter? _interpreter;
  List<String> _labels = [];

  int _verificationCount = 0;
  bool _isBusy = false;
  bool _isInitialized = false;
  String? _resultLabel;
  double? _resultConfidence;
  String? _errorMessage;

  bool get _limitReached => _verificationCount >= maxVerificationCount;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _loadVerificationCount();
      await _loadModel();
      await _initCamera();
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '초기화에 실패했습니다: $e');
    }
  }

  Future<void> _loadVerificationCount() async {
    final prefs = await SharedPreferences.getInstance();
    _verificationCount = prefs.getInt(_prefsKey) ?? 0;
  }

  Future<void> _incrementVerificationCount() async {
    final prefs = await SharedPreferences.getInstance();
    _verificationCount += 1;
    await prefs.setInt(_prefsKey, _verificationCount);
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

  /// 카메라 프레임을 [-1, 1]로 정규화한 [1, 224, 224, 3] 텐서로 변환
  /// (Teachable Machine unquantized 모델 표준 전처리 방식)
  List<List<List<List<double>>>> _preprocess(img.Image source) {
    final resized = img.copyResize(
      source,
      width: _inputSize,
      height: _inputSize,
    );

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

  Future<void> _verifyHelmet() async {
    final controller = _cameraController;
    final interpreter = _interpreter;
    if (_isBusy || _limitReached || controller == null || interpreter == null) {
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('촬영한 이미지를 디코딩하지 못했습니다.');
      }

      final input = _preprocess(decoded);
      final output = [List.filled(_labels.length, 0.0)];
      interpreter.run(input, output);

      final scores = output[0];
      var bestIndex = 0;
      for (var i = 1; i < scores.length; i++) {
        if (scores[i] > scores[bestIndex]) bestIndex = i;
      }
      final label = _labels.isNotEmpty ? _labels[bestIndex] : '알 수 없음';
      final confidence = scores[bestIndex];
      final isHelmet = label.toLowerCase().contains('no helmet') == false &&
          label.toLowerCase().contains('helmet');

      await _incrementVerificationCount();

      if (!mounted) return;
      setState(() {
        _resultLabel = label;
        _resultConfidence = confidence;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isHelmet ? Colors.green : AppColors.destructive,
          content: Text(
            isHelmet
                ? '헬멧 착용 확인됨 ✅ (신뢰도 ${(confidence * 100).toStringAsFixed(1)}%)'
                : '헬멧 미착용으로 인식됨 ❌ (신뢰도 ${(confidence * 100).toStringAsFixed(1)}%)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '인식에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = maxVerificationCount - _verificationCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('헬멧 인식'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      body: SafeArea(
        child: !_isInitialized
            ? _buildLoadingOrError(context)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      '남은 인증 횟수: ${remaining < 0 ? 0 : remaining} / $maxVerificationCount',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ),
                  if (_resultLabel != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '최근 인식 결과: $_resultLabel '
                        '(${(_resultConfidence! * 100).toStringAsFixed(1)}%)',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.destructive),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.primaryForeground,
                        ),
                        onPressed: _limitReached || _isBusy ? null : _verifyHelmet,
                        child: Text(
                          _limitReached
                              ? '인증 횟수를 모두 사용했습니다'
                              : _isBusy
                                  ? '인식 중...'
                                  : '헬멧 인증하기',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadingOrError(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.destructive),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
