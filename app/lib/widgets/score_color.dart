import 'package:flutter/material.dart';

/// Maps a landmark score onto a red (low) -> yellow -> green (high) scale.
/// Scores are assumed to roughly fall in 0..100; values outside that range
/// are simply clamped so the app never crashes on unexpected server data.
Color colorForScore(double score, {double maxScore = 100}) {
  final t = (score / maxScore).clamp(0.0, 1.0);
  if (t < 0.5) {
    return Color.lerp(Colors.red, Colors.amber, t * 2)!;
  }
  return Color.lerp(Colors.amber, Colors.green, (t - 0.5) * 2)!;
}
