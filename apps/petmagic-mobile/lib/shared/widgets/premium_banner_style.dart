import 'package:flutter/material.dart';

class PremiumBannerStyle {
  static const border = Color(0xFFE0A91E);
  static const darkGradient = <Color>[
    Color(0xFF08121F),
    Color(0xFF0B1C33),
    Color(0xFF0A172B),
  ];
  static const lightGradient = <Color>[
    Color(0xFFF2F7FF),
    Color(0xFFE7F0FF),
    Color(0xFFF4F8FF),
  ];

  static List<Color> gradient(bool isLight) =>
      isLight ? lightGradient : darkGradient;
}
