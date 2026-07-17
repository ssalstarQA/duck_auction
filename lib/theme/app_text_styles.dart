import 'package:flutter/material.dart';

/// Duck Auction Design System v1
/// Cafe24 Ohsquare Air는 브랜드/섹션/카테고리처럼 짧은 제목에만 사용합니다.
class AppTextStyles {
  const AppTextStyles._();

  static const String brandFont = 'Cafe24OhsquareAir';

  static const logo = TextStyle(
    fontFamily: brandFont,
    color: Color(0xFF111827),
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );

  static const bannerEyebrow = TextStyle(
    fontFamily: brandFont,
    fontSize: 16,
    color: Color(0xFF334155),
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const bannerTitle = TextStyle(
    fontFamily: brandFont,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.45,
    color: Color(0xFF111827),
  );

  static const bannerButton = TextStyle(
    fontFamily: brandFont,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.15,
  );

  static const category = TextStyle(
    fontFamily: brandFont,
    fontSize: 13.5,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: Color(0xFF111827),
  );

  static const sectionTitle = TextStyle(
    fontFamily: brandFont,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    color: Color(0xFF111827),
    letterSpacing: -0.35,
  );

  static const aiTitle = TextStyle(
    fontFamily: brandFont,
    fontWeight: FontWeight.w700,
    color: Color(0xFF111827),
    letterSpacing: -0.2,
  );

  static const aiAppliedTitle = TextStyle(
    fontFamily: brandFont,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Color(0xFFE11D48),
    letterSpacing: -0.2,
  );
}
