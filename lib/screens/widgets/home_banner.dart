part of '../home_screen.dart';

class _HeroBanner extends StatefulWidget {
  final String nickname;

  const _HeroBanner({required this.nickname});

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;
  int _lastBannerCount = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final bannerCount = _lastBannerCount <= 0 ? 1 : _lastBannerCount;
      if (bannerCount <= 1) return;
      _pageController.animateToPage(
        _pageController.page!.round() + 1,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<_BannerData> get _fallbackBanners => [
        _BannerData(
          eyebrow: '덕옥션에서만 만날 수 있는 특별한 굿즈',
          title: '귀여운 굿즈를\n경매로 만나보세요!',
          description: '좋아하는 굿즈를 발견하고\n경매에 참여해보세요!',
          actionText: '마감 임박 경매 보기',
          imagePath: 'assets/image/image/main_duck.png',
          backgroundColor: const Color(0xFFF4F7FC),
          borderColor: const Color(0xFFE5E7EB),
          accentColor: kAiAccent,
        ),
        const _BannerData(
          eyebrow: '덕옥션 파트너',
          title: '광고주 모집',
          description: '홈 상단 메인 배너에 상점·상품을 노출해요.',
          actionText: '광고 문의하기',
          icon: Icons.campaign_rounded,
          backgroundColor: Color(0xFFF4F7FC),
          borderColor: Color(0xFFE5E7EB),
          accentColor: kBannerBlue,
        ),
        const _BannerData(
          eyebrow: '덕옥션 파트너',
          title: '카테고리 추천 광고',
          description: '추천 굿즈의 카테고리를\n별도 메뉴로 독립해 노출해요.',
          actionText: '광고 문의하기',
          icon: Icons.grid_view_rounded,
          backgroundColor: Color(0xFFF4F7FC),
          borderColor: Color(0xFFE5E7EB),
          accentColor: kBannerBlue,
        ),
        const _BannerData(
          eyebrow: '출시 기념 이벤트',
          title: '2주간 판매 수수료 무료',
          description: '이벤트 기간에 등록한 경매는\n판매 수수료가 0원이에요.',
          actionText: '이벤트 확인하기',
          icon: Icons.card_giftcard_rounded,
          backgroundColor: Color(0xFFF4F7FC),
          borderColor: Color(0xFFE5E7EB),
          accentColor: kBannerOrange,
        ),
        const _BannerData(
          eyebrow: '5주 한정 이벤트',
          title: '최저가 경매 이벤트',
          description: '5주 동안 진행되는\n최저가 경매에 참여해보세요!',
          actionText: '이벤트 확인하기',
          icon: Icons.trending_down_rounded,
          backgroundColor: Color(0xFFF4F7FC),
          borderColor: Color(0xFFE5E7EB),
          accentColor: Color(0xFF14B8A6),
        ),
      ];

  void _moveBanner(int direction) {
    if (!_pageController.hasClients) return;

    final bannerCount = _lastBannerCount <= 0 ? 1 : _lastBannerCount;
    if (bannerCount <= 1) return;
    _pageController.animateToPage(
      _pageController.page!.round() + direction,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('homeBanners')
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        final remoteBanners = snapshot.hasData
            ? snapshot.data!.docs.map(_BannerData.fromFirestore).toList()
            : const <_BannerData>[];
        final banners = remoteBanners.isNotEmpty ? remoteBanners : _fallbackBanners;
        _lastBannerCount = banners.length;
        if (_currentIndex >= banners.length) _currentIndex = 0;
        final bannerHeight = context.responsive(phone: 204.0, tablet: 240.0, tabletLarge: 264.0);

        return SizedBox(
          height: bannerHeight,
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: const _BannerScrollBehavior(),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: banners.length <= 1 ? 1 : banners.length + 2,
                  onPageChanged: (pageIndex) {
                    if (banners.length <= 1) {
                      if (_currentIndex != 0) setState(() => _currentIndex = 0);
                      return;
                    }

                    final realIndex = pageIndex == 0
                        ? banners.length - 1
                        : pageIndex == banners.length + 1
                            ? 0
                            : pageIndex - 1;

                    if (_currentIndex != realIndex) {
                      setState(() => _currentIndex = realIndex);
                    }

                    if (pageIndex == 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _pageController.hasClients) {
                          _pageController.jumpToPage(banners.length);
                        }
                      });
                    } else if (pageIndex == banners.length + 1) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _pageController.hasClients) {
                          _pageController.jumpToPage(1);
                        }
                      });
                    }
                  },
                  itemBuilder: (context, pageIndex) {
                    final realIndex = banners.length <= 1
                        ? 0
                        : pageIndex == 0
                            ? banners.length - 1
                            : pageIndex == banners.length + 1
                                ? 0
                                : pageIndex - 1;
                    return _BannerCard(data: banners[realIndex]);
                  },
                ),
              ),
          Positioned(
            left: 18,
            bottom: 13,
            child: Row(
              children: List.generate(
                banners.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.only(right: 6),
                  width: _currentIndex == index ? 16 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? banners[_currentIndex].accentColor
                        : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 11,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: Container(
                key: ValueKey(_currentIndex),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_currentIndex + 1}/${banners.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        );
      },
    );
  }
}

class _BannerScrollBehavior extends MaterialScrollBehavior {
  const _BannerScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class _BannerArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BannerArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white.withOpacity(0.86),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(icon, size: 18, color: const Color(0xFF16305C)),
          ),
        ),
      ),
    );
  }
}

class _BannerData {
  final String eyebrow;
  final String title;
  final String description;
  final String actionText;
  final String? imagePath;
  final String? imageUrl;
  final String? storagePath;
  final IconData? icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color accentColor;

  const _BannerData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionText,
    this.imagePath,
    this.imageUrl,
    this.storagePath,
    this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.accentColor,
  });

  String? get imageSource {
    final source = storagePath?.trim().isNotEmpty == true ? storagePath : imageUrl;
    return source?.trim().isEmpty == true ? null : source;
  }


  factory _BannerData.fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    Color parseColor(Object? value, Color fallback) {
      if (value is int) return Color(value);
      if (value is String) {
        final cleaned = value.replaceAll('#', '').replaceAll('0x', '');
        final parsed = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
        if (parsed != null) return Color(parsed);
      }
      return fallback;
    }

    return _BannerData(
      eyebrow: data['eyebrow'] as String? ?? '덕옥션 소식',
      title: data['title'] as String? ?? '배너',
      description: data['description'] as String? ?? '',
      actionText: data['actionText'] as String? ?? '자세히 보기',
      imageUrl: data['imageUrl'] as String?,
      storagePath: (data['storagePath'] as String?) ?? (data['imageStoragePath'] as String?),
      backgroundColor: parseColor(data['backgroundColor'], const Color(0xFFF4F7FC)),
      borderColor: parseColor(data['borderColor'], const Color(0xFFE5E7EB)),
      accentColor: parseColor(data['accentColor'], kBannerBlue),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final _BannerData data;

  const _BannerCard({required this.data});

  void _openBannerDestination(BuildContext context) {
    if (data.actionText.contains('마감')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EndingSoonAuctionsScreen()),
      );
      return;
    }
    if (data.actionText.contains('광고')) {
      final product = data.title.contains('카테고리') ? '카테고리 추천' : '메인 배너';
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdvertisementInquiryScreen(adProduct: product)),
      );
      return;
    }
    if (data.actionText.contains('이벤트')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EventListScreen()),
      );
    }
  }

  bool get _isMainDuckBanner =>
      data.imagePath == 'assets/image/image/main_duck.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: context.responsive(phone: 204.0, tablet: 240.0, tabletLarge: 264.0),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: data.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _isMainDuckBanner
          ? _buildMainDuckBanner(context)
          : _buildDefaultBanner(context),
    );
  }

  Widget _buildMainDuckBanner(BuildContext context) {
    // 배너 카드 자체의 높이는 기기 구간(폰/태블릿/태블릿라지)별로 정해져 있으므로,
    // 텍스트 크기는 여기에 맞춰 커지도록 합니다(고정된 배율 대신 실제 브레이크포인트를 따라감).
    final bannerHeight = context.responsive(phone: 204.0, tablet: 240.0, tabletLarge: 264.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 360;
        final textScale = compact ? 0.94 : context.responsive(phone: 1.0, tablet: 1.15, tabletLarge: 1.3);

        const leftPad = 26.0;
        // 오리를 배너 오른쪽 영역에 크게(아래 살짝 크롭) 배치. 타이트 크롭된
        // main_duck.png라 프레임을 꽉 채워 큼직하게 보입니다. 폭은 duckRegionRatio로 조절.
        final duckRegionRatio = compact ? 0.42 : 0.44;
        final duckRegion = width * duckRegionRatio; // 오리가 차지할 오른쪽 폭
        final textRightInset = duckRegion + 4;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: compact ? 14 : 28,
              bottom: -18,
              width: duckRegion,
              height: bannerHeight + 22,
              child: Image.asset(
                data.imagePath!,
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                gaplessPlayback: true,
              ),
            ),
            Positioned(
              left: leftPad,
              top: 16,
              right: textRightInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '굿즈를 경매로\n만나보세요',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF111827),
                      fontSize: 21 * textScale,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '원하는 굿즈를 발견하고\n간편하게 입찰해보세요.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      height: 1.35,
                      fontSize: 13 * textScale,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36 * textScale,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: data.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        textStyle: TextStyle(
                          fontSize: 12.5 * textScale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => _openBannerDestination(context),
                      child: Text(
                        data.actionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDefaultBanner(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 360;
        // 오리 배너와 같은 방식으로, 태블릿/데스크톱에서는 텍스트·아이콘도 함께 커지도록 합니다.
        final textScale = compact ? 0.94 : context.responsive(phone: 1.0, tablet: 1.15, tabletLarge: 1.3);
        final visualWidth = (compact ? 104.0 : 122.0) * textScale;
        // 왼쪽 아래 페이지네이션 점(Positioned left:18, bottom:13, 높이 7)과 버튼이
        // 겹치던 문제 수정: 기존엔 bottom:18이라 버튼 하단이 점과 2px 겹쳤습니다.
        // 점 영역(13~20) 위로 충분히 띄우도록 32로 늘렸습니다.
        const bottomInset = 32.0;

        return MediaQuery(
          // Z플립처럼 시스템 글꼴 크기가 큰 기기에서 배너 텍스트가 함께 커지면서
          // 아래 버튼과 겹치던 문제를 막아요. 배너 안에서는 글꼴 확대를 최대
          // 1.1배로만 허용해서 고정 높이 안에 안전하게 들어가게 합니다.
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
          ),
          child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 26,
              top: 16,
              right: visualWidth + 40,
              bottom: bottomInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.eyebrow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12 * textScale,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21 * textScale,
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    child: Text(
                      data.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.35,
                        fontSize: 13 * textScale,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 36 * textScale,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: data.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        textStyle: TextStyle(
                          fontSize: 12.5 * textScale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => _openBannerDestination(context),
                      child: Text(
                        data.actionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 34,
              top: 0,
              bottom: 0,
              width: visualWidth,
              child: (data.imagePath != null || data.imageSource != null)
                  ? Center(
                      child: SizedBox(
                        width: visualWidth,
                        height: visualWidth,
                        child: data.imagePath != null
                            ? Image.asset(
                                data.imagePath!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                isAntiAlias: true,
                                gaplessPlayback: true,
                              )
                            : FirebaseStorageImage(
                                source: data.imageSource!,
                                fit: BoxFit.contain,
                                fallback: const SizedBox.shrink(),
                              ),
                      ),
                    )
                  : Center(
                      child: Container(
                        width: (compact ? 88.0 : 102.0) * textScale,
                        height: (compact ? 88.0 : 102.0) * textScale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.82),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: data.accentColor.withOpacity(0.18),
                          ),
                        ),
                        child: Icon(
                          data.icon,
                          size: (compact ? 48.0 : 56.0) * textScale,
                          color: data.accentColor,
                        ),
                      ),
                    ),
            ),
          ],
          ),
        );
      },
    );
  }
}
