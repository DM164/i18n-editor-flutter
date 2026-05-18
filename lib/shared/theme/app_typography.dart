import 'dart:ui' as ui;

import 'package:flutter/material.dart';

@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({required this.fontSizeMedium});

  final double fontSizeMedium;

  @override
  AppTypography copyWith({double? fontSizeMedium}) {
    return AppTypography(fontSizeMedium: fontSizeMedium ?? this.fontSizeMedium);
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) {
      return this;
    }

    return AppTypography(
      fontSizeMedium: ui.lerpDouble(fontSizeMedium, other.fontSizeMedium, t)!,
    );
  }
}
