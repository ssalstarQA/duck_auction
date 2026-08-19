import 'package:flutter/material.dart';

/// Duck Auction Design System v2 — Navy Premium
/// 브랜드는 네이비 하나로 통일하고, 마감 임박·남은 시간처럼 재촉이 필요한
/// 요소만 강조색(레드)으로 씁니다. 상태색(판매중/유찰/낙찰 등)은 기능색이라
/// 각 화면에서 그대로 유지합니다.
class AppColors {
  const AppColors._();

  // 브랜드 (네이비)
  static const primary = Color(0xFF16305C); // 메인: 앱바·주요 버튼·로고·활성 상태
  static const navyDeep = Color(0xFF0C1B38); // 딥네이비: 스플래시·온보딩·마케팅 배경
  static const navySoft = Color(0xFFEAF0F9); // 연한 틴트: 선택/채움 배경

  // 뉴트럴
  static const text = Color(0xFF111827);
  static const subText = Color(0xFF64748B);
  static const background = Color(0xFFF4F7FC);
  static const card = Colors.white;
  static const border = Color(0xFFE5E7EB);

  // 강조(긴급): 마감 임박·남은 시간·긴급 CTA. 화면에서 정말 급한 곳에만.
  static const urgent = Color(0xFFFF2D55);
  static const urgentSoft = Color(0xFFFFECF0);

  // 호환용 별칭(기존 코드가 참조하는 이름) — 브랜드 표면은 전부 네이비로 통일.
  static const aiAccent = urgent; // 기존 aiAccent → 강조 레드로 흡수
  static const aiDark = Color(0xFFE11D48);
  static const aiLight = Color(0xFFFFF1F5);
  static const bannerBlue = primary; // 배너 강조 파랑 → 네이비
  static const bannerOrange = primary; // 배너 주황 제거 → 네이비 (당근/번개 회피)
  static const gold = Color(0xFFC99A3B); // (선택) 프리미엄/낙찰 하이라이트 골드
}
