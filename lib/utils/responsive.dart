import 'package:flutter/material.dart';

/// Duck Auction 반응형 디자인 시스템 (v1)
///
/// 폰과 태블릿 화면에서 모두 자연스럽게 보이도록 하기 위한 공통 브레이크포인트와
/// 헬퍼 위젯을 모아둔 파일입니다. 화면 폭(width)을 기준으로 값을 고르며,
/// 특정 화면에 종속되지 않는 순수 유틸이라 어디서든 import해서 쓸 수 있습니다.
class AppBreakpoints {
  const AppBreakpoints._();

  /// 이 값 미만이면 폰으로 취급합니다.
  static const double tablet = 600;

  /// 이 값 이상이면 큰 태블릿(가로 모드 포함)으로 취급합니다.
  static const double tabletLarge = 900;

  /// 이 값 이상이면 데스크톱/와이드 웹 화면으로 취급합니다.
  static const double desktop = 1200;
}

enum DeviceType { phone, tablet, tabletLarge, desktop }

DeviceType deviceTypeOf(double width) {
  if (width >= AppBreakpoints.desktop) return DeviceType.desktop;
  if (width >= AppBreakpoints.tabletLarge) return DeviceType.tabletLarge;
  if (width >= AppBreakpoints.tablet) return DeviceType.tablet;
  return DeviceType.phone;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  DeviceType get deviceType => deviceTypeOf(screenWidth);

  bool get isPhone => deviceType == DeviceType.phone;

  /// 600dp 이상이면 태블릿(이상)으로 봅니다.
  bool get isTablet => deviceType != DeviceType.phone;

  /// 900dp 이상 (큰 태블릿/데스크톱)
  bool get isTabletLarge =>
      deviceType == DeviceType.tabletLarge || deviceType == DeviceType.desktop;

  /// 화면 크기 구간별로 서로 다른 값을 고를 때 사용합니다.
  /// 더 큰 구간의 값이 없으면 한 단계 작은 구간의 값으로 자연스럽게 대체됩니다.
  T responsive<T>({required T phone, T? tablet, T? tabletLarge, T? desktop}) {
    switch (deviceType) {
      case DeviceType.desktop:
        return desktop ?? tabletLarge ?? tablet ?? phone;
      case DeviceType.tabletLarge:
        return tabletLarge ?? tablet ?? phone;
      case DeviceType.tablet:
        return tablet ?? phone;
      case DeviceType.phone:
        return phone;
    }
  }

  /// 화면 좌우 기본 여백. 태블릿에서는 콘텐츠가 화면 끝에 붙지 않도록 더 넓게 줍니다.
  double get pagePadding =>
      responsive(phone: 14.0, tablet: 28.0, tabletLarge: 40.0);

  /// 본문 콘텐츠의 최대 너비. 태블릿/와이드 화면에서 카드·텍스트가
  /// 과도하게 늘어지지 않도록 제한합니다. 폰에서는 제한이 없습니다.
  double get maxContentWidth => responsive(
        phone: double.infinity,
        tablet: 720.0,
        tabletLarge: 960.0,
        desktop: 1080.0,
      );

  /// 카드/리스트를 몇 열로 배치할지 고릅니다.
  int gridColumns({int phone = 1, int tablet = 2, int tabletLarge = 3}) {
    return responsive(phone: phone, tablet: tablet, tabletLarge: tabletLarge);
  }
}

/// 화면 폭이 넓어져도 콘텐츠가 가운데에 적당한 너비로 배치되도록 감싸는 래퍼.
/// 폰에서는 아무 영향 없이 그대로 렌더링됩니다.
class ResponsiveContentBounds extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContentBounds({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedMaxWidth = maxWidth ?? context.maxContentWidth;
    final content = padding == null ? child : Padding(padding: padding!, child: child);
    // 최대 너비 제한이 없으면(폰) 화면 폭을 그대로 꽉 채워요.
    // Align은 자식에게 loose 제약을 주기 때문에, 그대로 두면 1열 카드 목록이
    // 내용 너비만큼 줄어들어 가운데로 몰려 보여요. 폰에서는 전체 폭으로 좌측 정렬합니다.
    if (!resolvedMaxWidth.isFinite) {
      return SizedBox(width: double.infinity, child: content);
    }
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
        child: content,
      ),
    );
  }
}

/// 세로로 하나씩 쌓이던 카드 목록을, 태블릿 이상의 화면에서는
/// 여러 열로 흘려보내는 래퍼입니다. 각 카드의 높이가 서로 달라도(가변 높이)
/// [Wrap] 기반이라 자연스럽게 배치됩니다.
///
/// 카드 자체에 이미 하단 여백(margin)이 있는 리스트(예: ProductListTile)를
/// 감쌀 때는 [spacing]/[runSpacing]을 0으로 두면 됩니다(기본값).
class ResponsiveCardFlow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int phoneColumns;
  final int tabletColumns;
  final int tabletLargeColumns;

  const ResponsiveCardFlow({
    super.key,
    required this.children,
    this.spacing = 0,
    this.runSpacing = 0,
    this.phoneColumns = 1,
    this.tabletColumns = 2,
    this.tabletLargeColumns = 3,
  });

  @override
  Widget build(BuildContext context) {
    final columns = context.gridColumns(
      phone: phoneColumns,
      tablet: tabletColumns,
      tabletLarge: tabletLargeColumns,
    );

    if (columns <= 1) {
      // 1열일 때 카드가 가운데로 몰리지 않고 폭을 꽉 채우도록(좌측 정렬) 해요.
      // Column의 stretch 동작(부모 제약에 따라 결과가 달라짐)에 의존하지 않고,
      // LayoutBuilder로 실제 가용 폭을 구해 각 카드에 그 폭을 '명시적으로' 지정합니다.
      // 이렇게 하면 어떤 부모 제약에서도 카드가 항상 화면 폭을 꽉 채워 좌측 정렬돼요.
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final child in children) SizedBox(width: width, child: child),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
