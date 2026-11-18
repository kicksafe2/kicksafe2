import 'package:flutter/material.dart';

/// 경로 안내 화면(지도/주행 중)이 함께 쓰는 표시용 도우미.

/// 1000m 이상은 km(소수 1자리), 미만은 10m 단위로 반올림.
String formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
  return '${(meters / 10).round() * 10}m';
}

/// 안내 문구에서 방향을 추정해 아이콘을 고른다.
IconData guideIcon(String instruction) {
  if (instruction.contains('도착') || instruction.contains('목적지')) return Icons.flag;
  if (instruction.contains('유턴') || instruction.contains('U턴')) return Icons.u_turn_left;
  if (instruction.contains('좌회전') || instruction.contains('왼쪽')) return Icons.turn_left;
  if (instruction.contains('우회전') || instruction.contains('오른쪽')) return Icons.turn_right;
  return Icons.straight;
}
