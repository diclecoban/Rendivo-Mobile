import 'package:flutter/material.dart';

/// Shared pastel palette so staff avatars and schedule badges feel consistent.
const List<Color> staffPastelPalette = <Color>[
  Color(0xFFFFDEE8),
  Color(0xFFFFECDD),
  Color(0xFFE6F3F2),
  Color(0xFFE1ECFF),
  Color(0xFFF0E4FF),
  Color(0xFFEAF4FF),
  Color(0xFFF9E6FF),
  Color(0xFFE6F7EA),
];

Color staffPastelColorForId(String id) {
  final safeId = id.trim();
  if (safeId.isEmpty) {
    return const Color(0xFFF7E8F3);
  }
  final hash = safeId.hashCode.abs();
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.45, 0.86).toColor();
}

Color staffPastelTextColor(Color base) {
  final hsl = HSLColor.fromColor(base);
  final darker = (hsl.lightness - 0.32).clamp(0.0, 1.0);
  return hsl.withLightness(darker).toColor();
}
