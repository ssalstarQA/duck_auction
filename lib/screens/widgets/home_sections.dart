part of '../home_screen.dart';

class _QuickMenuRow extends StatelessWidget {
  final VoidCallback onRegisterTap;

  const _QuickMenuRow({required this.onRegisterTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickMenuItem(icon: Icons.bolt_rounded, label: '마감임박', accentColor: kAiAccent, onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EndingSoonAuctionsScreen()));
      }),
      _QuickMenuItem(icon: Icons.emoji_events_rounded, label: '인기경매', accentColor: kGoldAccent, onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductCollectionScreen(mode: ProductCollectionMode.popular)));
      }),
      _QuickMenuItem(icon: Icons.new_releases_rounded, label: '신규등록', accentColor: const Color(0xFFEF4444), onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductCollectionScreen(mode: ProductCollectionMode.newest)));
      }),
      _QuickMenuItem(icon: Icons.favorite_rounded, label: '찜한경매', accentColor: Color(0xFFFF5A8A), onTap: () {
        if (_isGuestUser()) {
          _showLoginRequiredSheet(context, title: '찜한 상품은 로그인 후 볼 수 있어요');
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductCollectionScreen(mode: ProductCollectionMode.favorites)));
      }),
      _QuickMenuItem(icon: Icons.grid_view_rounded, label: '전체보기', accentColor: kDuckPrimary, onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllMenuScreen()));
      }),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items.map((item) => Expanded(child: item)).toList(),
    );
  }
}

class _QuickMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickMenuItem({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(icon, color: accentColor, size: 23),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.category.copyWith(
                fontFamily: null,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


enum ProductCollectionMode { popular, newest, favorites, all }

class ProductCollectionScreen extends StatelessWidget {
  final ProductCollectionMode mode;

  const ProductCollectionScreen({super.key, required this.mode});

  String get _title {
    switch (mode) {
      case ProductCollectionMode.popular:
        return '인기경매';
      case ProductCollectionMode.newest:
        return '신규 등록 경매';
      case ProductCollectionMode.favorites:
        return '찜한경매';
      case ProductCollectionMode.all:
        return '전체보기';
    }
  }

  IconData get _icon {
    switch (mode) {
      case ProductCollectionMode.popular:
        return Icons.emoji_events_rounded;
      case ProductCollectionMode.newest:
        return Icons.new_releases_rounded;
      case ProductCollectionMode.favorites:
        return Icons.favorite_rounded;
      case ProductCollectionMode.all:
        return Icons.grid_view_rounded;
    }
  }

  Color get _accentColor {
    switch (mode) {
      case ProductCollectionMode.popular:
        return kGoldAccent;
      case ProductCollectionMode.newest:
        return const Color(0xFFEF4444);
      case ProductCollectionMode.favorites:
        return const Color(0xFFFF5A8A);
      case ProductCollectionMode.all:
        return kDuckPrimary;
    }
  }

  List<ProductItem> _filterProducts(List<ProductItem> products, Set<String> favorites) {
    final result = List<ProductItem>.from(products);
    switch (mode) {
      case ProductCollectionMode.popular:
        // 거래완료·유찰·낙찰 등 종료된 경매는 인기 목록에서 제외한다.
        final active = result.where((product) => product.isAuctionActive).toList();
        active.sort((a, b) {
          final aScore = DuckAuctionStore.parseCount(a.bids) * 10 + DuckAuctionStore.parseCount(a.likes) * 3;
          final bScore = DuckAuctionStore.parseCount(b.bids) * 10 + DuckAuctionStore.parseCount(b.likes) * 3;
          return bScore.compareTo(aScore);
        });
        return active;
      case ProductCollectionMode.newest:
        return result.where((product) => product.isAuctionActive).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      case ProductCollectionMode.favorites:
        return result.where((product) {
          final id = product.id;
          if (id != null && id.isNotEmpty) return favorites.contains(id);
          return favorites.contains(product.title);
        }).toList();
      case ProductCollectionMode.all:
        result.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        return result;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 찜 목록은 카테고리(+쿠지 등급) 필터 + 선택 삭제/하트 해제를 갖춘 전용 화면을 써요.
    if (mode == ProductCollectionMode.favorites) {
      return const FavoritesCollectionScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Row(
          children: [
            Icon(_icon, color: _accentColor),
            const SizedBox(width: 8),
            Text(_title, style: AppTextStyles.sectionTitle),
          ],
        ),
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.registeredAuctions,
        builder: (context, products, _) {
          return ValueListenableBuilder<Set<String>>(
            valueListenable: DuckAuctionStore.favoriteProductIds,
            builder: (context, favorites, __) {
              final filteredProducts = _filterProducts(products, favorites);
              // 마감임박 화면과 동일하게 카테고리 + 정렬 필터를 갖춘 목록으로 통일해요.
              return _FilteredAuctionListView(
                products: filteredProducts,
                initialSort: mode == ProductCollectionMode.popular
                    ? _AuctionSort.popular
                    : _AuctionSort.latest,
                emptyText: '표시할 상품이 없어요.',
              );
            },
          );
        },
      ),
    );
  }
}

enum _AllMenuCategory {
  all,
  favorites,
  categories,
  auctions,
  activity,
  communication,
  support,
  settings,
}

class AllMenuScreen extends StatefulWidget {
  const AllMenuScreen({super.key});

  @override
  State<AllMenuScreen> createState() => _AllMenuScreenState();
}

class _AllMenuScreenState extends State<AllMenuScreen> {
  static const _favoriteMenuKey = 'duck_auction_favorite_menus_v1';

  static const Map<_AllMenuCategory, Color> _categoryColors = {
    _AllMenuCategory.all: kDuckPrimary,
    _AllMenuCategory.favorites: kGoldAccent,
    _AllMenuCategory.categories: Color(0xFF3B82F6),
    _AllMenuCategory.auctions: kAiAccent,
    _AllMenuCategory.activity: Color(0xFF6366F1),
    _AllMenuCategory.communication: Color(0xFF10B981),
    _AllMenuCategory.support: Color(0xFF8B5CF6),
    _AllMenuCategory.settings: Color(0xFF64748B),
  };

  Color _colorOf(_AllMenuCategory category) => _categoryColors[category]!;

  _AllMenuCategory _selected = _AllMenuCategory.all;
  Set<String> _favoriteMenus = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFavoriteMenus();
  }

  Future<void> _loadFavoriteMenus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favoriteMenus = (prefs.getStringList(_favoriteMenuKey) ?? const <String>[]).toSet();
    });
  }

  Future<void> _toggleFavoriteMenu(String id) async {
    final next = Set<String>.from(_favoriteMenus);
    if (!next.add(id)) next.remove(id);
    setState(() => _favoriteMenus = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteMenuKey, next.toList());
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _requireLogin({required String title, required VoidCallback action}) {
    if (_isGuestUser()) {
      _showLoginRequiredSheet(context, title: title);
      return;
    }
    action();
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@duckauction.com',
      queryParameters: const {
        'subject': '[덕옥션 문의]',
        'body': '문의 내용을 작성해 주세요.\n\n계정 이메일: \n문의 유형: ',
      },
    );
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 앱을 열 수 없어요. support@duckauction.com으로 문의해 주세요.')),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String get _detailTitle {
    switch (_selected) {
      case _AllMenuCategory.all:
        return '전체 메뉴';
      case _AllMenuCategory.favorites:
        return '즐겨찾기';
      case _AllMenuCategory.categories:
        return '전체 카테고리';
      case _AllMenuCategory.auctions:
        return '경매';
      case _AllMenuCategory.activity:
        return '나의 활동';
      case _AllMenuCategory.communication:
        return '소통';
      case _AllMenuCategory.support:
        return '고객 지원';
      case _AllMenuCategory.settings:
        return '설정';
    }
  }

  List<_AllMenuEntry> get _allItems => [
        _AllMenuEntry('section:categories', Icons.category_rounded, '전체 카테고리', '캐릭터와 브랜드별 경매를 둘러보세요.', _colorOf(_AllMenuCategory.categories), () => setState(() => _selected = _AllMenuCategory.categories)),
        _AllMenuEntry('section:auctions', Icons.gavel_rounded, '경매', '인기·신규·마감 임박 경매를 확인하세요.', _colorOf(_AllMenuCategory.auctions), () => setState(() => _selected = _AllMenuCategory.auctions)),
        _AllMenuEntry('section:activity', Icons.manage_accounts_rounded, '나의 활동', '내 경매와 후기, 최근 활동을 모아보세요.', _colorOf(_AllMenuCategory.activity), () => setState(() => _selected = _AllMenuCategory.activity)),
        _AllMenuEntry('section:communication', Icons.forum_rounded, '소통', '채팅방과 거래 후기를 확인하세요.', _colorOf(_AllMenuCategory.communication), () => setState(() => _selected = _AllMenuCategory.communication)),
        _AllMenuEntry('section:support', Icons.support_agent_rounded, '고객 지원', '문의, 신고 이력, 공지사항을 확인하세요.', _colorOf(_AllMenuCategory.support), () => setState(() => _selected = _AllMenuCategory.support)),
        _AllMenuEntry('section:settings', Icons.settings_rounded, '설정', '알림과 앱 정보를 관리하세요.', _colorOf(_AllMenuCategory.settings), () => setState(() => _selected = _AllMenuCategory.settings)),
      ];

  List<_AllMenuEntry> get _auctionItems => [
        _AllMenuEntry('auction:popular', Icons.emoji_events_rounded, '인기 경매', '입찰과 관심이 많은 경매를 모아봤어요.', _colorOf(_AllMenuCategory.auctions), () => _push(const ProductCollectionScreen(mode: ProductCollectionMode.popular))),
        _AllMenuEntry('auction:newest', Icons.new_releases_rounded, '신규 등록 경매', '최근 새롭게 등록된 진행 중 경매예요.', _colorOf(_AllMenuCategory.auctions), () => _push(const ProductCollectionScreen(mode: ProductCollectionMode.newest))),
        _AllMenuEntry('auction:ending', Icons.bolt_rounded, '마감 임박 경매', '곧 마감되는 경매를 놓치지 마세요.', _colorOf(_AllMenuCategory.auctions), () => _push(const EndingSoonAuctionsScreen())),
      ];

  List<_AllMenuEntry> get _detailItems {
    switch (_selected) {
      case _AllMenuCategory.all:
        return _allItems;
      case _AllMenuCategory.favorites:
      case _AllMenuCategory.categories:
        return const <_AllMenuEntry>[];
      case _AllMenuCategory.auctions:
        return _auctionItems;
      case _AllMenuCategory.activity:
        final color = _colorOf(_AllMenuCategory.activity);
        return [
          _AllMenuEntry('activity:reviews', Icons.rate_review_outlined, '내가 남긴 후기', '작성한 후기와 받은 후기를 확인하세요.', color, () => _requireLogin(
                title: '후기는 로그인 후 이용할 수 있어요',
                action: () => _push(const MyReviewsScreen()),
              )),
          _AllMenuEntry('activity:auctions', Icons.gavel_rounded, '내 경매 관리', '판매·입찰·낙찰·유찰 경매를 관리하세요.', color, () => _requireLogin(
                title: '내 경매 관리는 로그인 후 이용할 수 있어요',
                action: () => _push(const MyAuctionManageScreen()),
              )),
          _AllMenuEntry('activity:liked', Icons.favorite_rounded, '찜한 경매', '관심 표시한 경매를 다시 확인하세요.', color, () => _requireLogin(
                title: '찜한 경매는 로그인 후 볼 수 있어요',
                action: () => _push(const ProductCollectionScreen(mode: ProductCollectionMode.favorites)),
              )),
          _AllMenuEntry('activity:recent', Icons.history_rounded, '최근 본 경매', '최근 확인한 경매를 이어서 둘러보세요.', color, () => _push(const RecentViewedProductsScreen())),
        ];
      case _AllMenuCategory.communication:
        final color = _colorOf(_AllMenuCategory.communication);
        return [
          _AllMenuEntry('communication:chat', Icons.chat_bubble_rounded, '채팅방 목록', '판매자와 구매자 간 대화를 확인하세요.', color, () => _requireLogin(
                title: '채팅은 로그인 후 이용할 수 있어요',
                action: () => _push(const ChatRoomListScreen()),
              )),
          _AllMenuEntry('communication:reviews', Icons.rate_review_rounded, '거래 후기', '받은 후기와 작성한 후기를 확인하세요.', color, () => _requireLogin(
                title: '후기는 로그인 후 이용할 수 있어요',
                action: () => _push(const MyReviewsScreen()),
              )),
        ];
      case _AllMenuCategory.support:
        final color = _colorOf(_AllMenuCategory.support);
        return [
          _AllMenuEntry('support:email', Icons.mail_outline_rounded, '문의 메일 보내기', '문의 내용을 메일로 전달하세요.', color, _openSupportEmail),
          _AllMenuEntry('support:reports', Icons.report_rounded, '신고 이력', '내가 접수한 신고와 처리 상태를 확인하세요.', color, () => _requireLogin(
                title: '신고 이력은 로그인 후 이용할 수 있어요',
                action: () => _push(const MyReportHistoryScreen()),
              )),
          _AllMenuEntry('support:notices', Icons.campaign_rounded, '공지사항', '서비스 안내와 업데이트 소식을 확인하세요.', color, () => _push(const EventListScreen())),
          _AllMenuEntry('support:ad', Icons.storefront_rounded, '광고주 모집', '홈 배너·카테고리 광고 문의를 남겨보세요.', color, () => _push(const AdvertisementInquiryScreen())),
        ];
      case _AllMenuCategory.settings:
        final color = _colorOf(_AllMenuCategory.settings);
        return [
          _AllMenuEntry('settings:app', Icons.settings_rounded, '앱 설정', '앱 사용 환경을 설정하세요.', color, () => _push(MySettingsScreen(onLogout: _logout))),
          _AllMenuEntry('settings:notifications', Icons.notifications_outlined, '알림 설정', '입찰·채팅·거래 알림을 관리하세요.', color, () => _push(MySettingsScreen(onLogout: _logout))),
          _AllMenuEntry('settings:version', Icons.info_outline_rounded, '버전·업데이트 확인', '현재 버전과 업데이트 여부를 확인하세요.', color, () => _push(MySettingsScreen(onLogout: _logout))),
          _AllMenuEntry('settings:logout', Icons.logout_rounded, '로그아웃', '현재 계정에서 로그아웃합니다.', color, _logout),
        ];
    }
  }

  List<_AllMenuEntry> _categoryEntries() {
    final color = _colorOf(_AllMenuCategory.categories);
    return HomeTab.categories
        .where((item) => item.name != '전체보기')
        .map((category) => _AllMenuEntry(
              'category:${category.name}',
              Icons.sell_outlined,
              category.name,
              AppCategories.categoryTaglines[category.name] ?? '${category.name} 관련 경매를 확인하세요.',
              color,
              () => _push(CategoryAuctionListScreen(category: category.name)),
            ))
        .toList();
  }

  List<_AllMenuEntry> get _allFavoriteCandidates {
    return <_AllMenuEntry>[
      ..._auctionItems,
      ..._detailEntriesFor(_AllMenuCategory.activity),
      ..._detailEntriesFor(_AllMenuCategory.communication),
      ..._detailEntriesFor(_AllMenuCategory.support),
      ..._detailEntriesFor(_AllMenuCategory.settings),
      ..._categoryEntries(),
      _AllMenuEntry(
        'favorite:products',
        Icons.favorite_rounded,
        '찜한 경매 보기',
        '관심 표시한 경매를 한곳에서 확인하세요.',
        _colorOf(_AllMenuCategory.activity),
        () => _requireLogin(
          title: '찜한 경매는 로그인 후 볼 수 있어요',
          action: () => _push(const ProductCollectionScreen(mode: ProductCollectionMode.favorites)),
        ),
      ),
    ];
  }

  List<_AllMenuEntry> _detailEntriesFor(_AllMenuCategory category) {
    final before = _selected;
    _selected = category;
    final result = List<_AllMenuEntry>.from(_detailItems);
    _selected = before;
    return result;
  }

  Widget _sideButton({required String label, required IconData icon, required _AllMenuCategory category}) {
    return _AllMenuCategoryButton(
      label: label,
      icon: icon,
      color: _colorOf(category),
      selected: _selected == category,
      onTap: () => setState(() => _selected = category),
    );
  }

  Widget _menuRow(_AllMenuEntry entry, {bool showDivider = true}) {
    final favorite = _favoriteMenus.contains(entry.id);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: entry.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: entry.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(entry.icon, size: 20, color: entry.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                        const SizedBox(height: 3),
                        Text(_wordSafeBreak(entry.description), style: const TextStyle(fontSize: 12.5, height: 1.3, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _toggleFavoriteMenu(entry.id),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded, size: 22, color: favorite ? kGoldAccent : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 52),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          ),
      ],
    );
  }

  Widget _buildRows(List<_AllMenuEntry> entries) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) _menuRow(entries[i], showDivider: i != entries.length - 1),
      ],
    );
  }

  Widget _buildCategoryMenus() => _buildRows(_categoryEntries());

  Widget _buildFavorites() {
    final menuEntries = _allFavoriteCandidates.where((entry) => _favoriteMenus.contains(entry.id)).toList();
    if (menuEntries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(Icons.star_border_rounded, size: 34, color: kGoldAccent.withOpacity(0.6)),
            const SizedBox(height: 10),
            const Text(
              '즐겨찾기한 메뉴가 없어요',
              style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w900, fontSize: 14.5),
            ),
            const SizedBox(height: 4),
            const Text(
              '자주 쓰는 메뉴의 별 아이콘을 눌러 여기에 모아보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.4, fontSize: 12.5),
            ),
          ],
        ),
      );
    }
    return _MenuSectionCard(child: _buildRows(menuEntries));
  }

  Widget _buildAllMenus() {
    Widget section(String title, Color color, List<_AllMenuEntry> entries) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
            _MenuSectionCard(child: _buildRows(entries)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section('전체 카테고리', _colorOf(_AllMenuCategory.categories), _categoryEntries()),
        section('경매', _colorOf(_AllMenuCategory.auctions), _auctionItems),
        section('나의 활동', _colorOf(_AllMenuCategory.activity), _detailEntriesFor(_AllMenuCategory.activity)),
        section('소통', _colorOf(_AllMenuCategory.communication), _detailEntriesFor(_AllMenuCategory.communication)),
        section('고객 지원', _colorOf(_AllMenuCategory.support), _detailEntriesFor(_AllMenuCategory.support)),
        section('설정', _colorOf(_AllMenuCategory.settings), _detailEntriesFor(_AllMenuCategory.settings)),
      ],
    );
  }

  Widget _buildDetailContent() {
    if (_selected == _AllMenuCategory.all) return _buildAllMenus();
    if (_selected == _AllMenuCategory.favorites) return _buildFavorites();
    if (_selected == _AllMenuCategory.categories) return _MenuSectionCard(child: _buildCategoryMenus());
    return _MenuSectionCard(child: _buildRows(_detailItems));
  }

  Widget _buildStatusHeader() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF334155), Color(0xFF1E293B)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), shape: BoxShape.circle),
              child: const Center(child: Text('🐥', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('로그인하고 덕옥션을 시작해보세요', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5)),
                  SizedBox(height: 3),
                  Text('찜, 채팅, 경매 관리까지 한번에 이용할 수 있어요.', style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _showLoginRequiredSheet(context, title: '로그인하고 덕옥션을 이용해보세요'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF334155),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('로그인', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final nickname = ((data['nickname'] as String?) ?? user.displayName ?? '덕친').trim();
        final imageUrl = (data['profileImageUrl'] as String?)?.trim();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _push(MyPageTab(onLogout: _logout)),
            child: Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFFFFE4EC),
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🐥', style: TextStyle(fontSize: 20))))
                        : const Center(child: Text('🐥', style: TextStyle(fontSize: 20))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$nickname님, 안녕하세요 👋', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF111827))),
                      const SizedBox(height: 3),
                      const Text('마이페이지에서 프로필과 활동을 확인해보세요.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('전체 메뉴', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          _buildStatusHeader(),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 112,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: ListView(
                      // 하단 시스템 내비게이션 바(갤럭시 등)에 마지막 '설정' 메뉴가
                      // 가려지지 않도록 안전영역 높이만큼 하단 여백을 더해요.
                      padding: EdgeInsets.fromLTRB(
                          0, 6, 0, 6 + MediaQuery.of(context).padding.bottom),
                      children: [
                        _sideButton(label: '전체 메뉴', icon: Icons.apps_rounded, category: _AllMenuCategory.all),
                        _sideButton(label: '즐겨찾기', icon: Icons.star_rounded, category: _AllMenuCategory.favorites),
                        _sideButton(label: '전체 카테고리', icon: Icons.category_rounded, category: _AllMenuCategory.categories),
                        _sideButton(label: '경매', icon: Icons.gavel_rounded, category: _AllMenuCategory.auctions),
                        _sideButton(label: '나의 활동', icon: Icons.person_rounded, category: _AllMenuCategory.activity),
                        _sideButton(label: '소통', icon: Icons.forum_rounded, category: _AllMenuCategory.communication),
                        _sideButton(label: '고객 지원', icon: Icons.support_agent_rounded, category: _AllMenuCategory.support),
                        _sideButton(label: '설정', icon: Icons.settings_rounded, category: _AllMenuCategory.settings),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: ListView(
                      key: ValueKey(_selected),
                      padding: EdgeInsets.fromLTRB(
                          16, 18, 16, 28 + MediaQuery.of(context).padding.bottom),
                      children: [
                        Text(_detailTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        _buildDetailContent(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSectionCard extends StatelessWidget {
  final Widget child;

  const _MenuSectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _AllMenuCategoryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AllMenuCategoryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? color : const Color(0xFF64748B)),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? const Color(0xFF111827) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 한글 설명이 어절(단어) 중간에서 줄바꿈되지 않도록, 각 어절 내부 글자를
/// word-joiner(U+2060)로 묶어 공백에서만 줄바꿈되게 만들어요.
/// (예: "…확률의 쿠지 상\n품" → "…확률의\n쿠지 상품")
String _wordSafeBreak(String text) {
  return text
      .split(' ')
      .map((w) => w.isEmpty ? w : w.split('').join('\u{2060}'))
      .join(' ');
}

class _AllMenuEntry {
  final String id;
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
  const _AllMenuEntry(this.id, this.icon, this.label, this.description, this.color, this.onTap);
}

class CategoryAuctionListScreen extends StatefulWidget {
  final String category;

  const CategoryAuctionListScreen({super.key, required this.category});

  @override
  State<CategoryAuctionListScreen> createState() => _CategoryAuctionListScreenState();
}

class _CategoryAuctionListScreenState extends State<CategoryAuctionListScreen> {
  // null이면 '전체'예요. 쿠지 카테고리에서만 쓰는 등급 필터입니다.
  String? _gradeFilter;
  // null이면 '전체'예요. 피규어/아크릴/가챠/인형/기타 — 모든 카테고리에서 씁니다.
  String? _itemTypeFilter;
  bool _isGridView = false;

  // build()가 새로 호출될 때마다 .snapshots()를 다시 만들면 StreamBuilder가
  // 매번 '새로운 스트림'으로 인식해서 필터 칩이나 보기 방식(목록/카드)을
  // 누를 때마다 구독을 끊고 다시 맺어요. 그래서 그때마다 로딩 상태로
  // 돌아가면서 카테고리 화면이 유독 느리고 버벅였던 거예요. initState에서
  // 딱 한 번만 만들어서 재사용하도록 고쳤어요.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream;

  @override
  void initState() {
    super.initState();
    _productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: widget.category)
        .snapshots();
  }

  bool get _isKuji => widget.category == AppCategories.kuji;

  Widget _viewModeButton(IconData icon, bool isGrid) {
    final isActive = _isGridView == isGrid;
    return InkWell(
      onTap: () => setState(() => _isGridView = isGrid),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF334155).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: isActive ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(widget.category, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          _viewModeButton(Icons.view_list_rounded, false),
          const SizedBox(width: 4),
          _viewModeButton(Icons.grid_view_rounded, true),
          const SizedBox(width: 8),
        ],
      ),
      // 예전에는 이 화면 등 상품 목록 여러 곳이 이 기기에만 있는 로컬
      // 캐시(DuckAuctionStore.registeredAuctions)를 봤어요. 그래서 다른
      // 계정/기기에서 등록한 상품은 안 보이는 문제가 있었어요. 카테고리
      // 화면은 Firestore를 직접 구독해서 누가 등록했든 실시간으로 보이게
      // 바꿨어요. orderBy까지 같이 걸면 복합 색인이 새로 필요해지니
      // 정렬은 받아온 뒤 화면에서 처리합니다.
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  '${widget.category} 상품을 불러오지 못했어요. 잠시 후 다시 시도해주세요.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProducts = (snapshot.data?.docs ?? const [])
              .map(ProductItem.fromFirestore)
              .where((product) => product.isAuctionActive)
              .toList()
            ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

          // 쿠지 카테고리는 등급(상위상/하위상)만, 나머지 카테고리는
          // 세부 카테고리(피규어/아크릴/가챠/인형/기타)만 걸 수 있어요.
          // 두 필터를 동시에 보여주지 않습니다.
          final filtered = allProducts.where((product) {
            if (_isKuji) {
              return _gradeFilter == null || product.kujiGrade == _gradeFilter;
            }
            return _itemTypeFilter == null || product.itemType == _itemTypeFilter;
          }).toList();

          return Column(
            children: [
              _ListFilterBar(
                resultCount: filtered.length,
                options: _isKuji ? AppCategories.kujiGrades : AppCategories.itemTypes,
                selected: _isKuji ? _gradeFilter : _itemTypeFilter,
                onSelected: (value) => setState(() {
                  if (_isKuji) {
                    _gradeFilter = value;
                  } else {
                    _itemTypeFilter = value;
                  }
                }),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          '${widget.category} 카테고리에 진행 중인 경매가 없어요.',
                          style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800),
                        ),
                      )
                    : _isGridView
                        ? GridView.builder(
                            padding: EdgeInsets.fromLTRB(16, 12, 16,
                                24 + MediaQuery.of(context).padding.bottom),
                            // ProductCard는 사진(128) + 글자 영역이 폭과
                            // 상관없이 항상 거의 같은 높이라, 폭 비율로
                            // 셀 높이를 정하는 childAspectRatio를 쓰면 화면이
                            // 넓을수록 셀이 카드보다 훨씬 커져서 아래쪽에
                            // 빈 공간이 크게 남았어요. 높이를 고정값으로
                            // 직접 지정해서 그 공백을 없앴어요.
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              // 판매자·태그 줄이 추가되면서 카드가 더
                              // 길어져 216 → 240으로 같이 늘렸어요.
                              // 판매자명/태그를 두 줄로 나누면서 다시
                              // 240 → 256으로 늘려 overflow를 없앴어요.
                              mainAxisExtent: 256,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                            itemCount: filtered.length,
                            // width: null이면 ProductCard가 164 고정폭 대신
                            // 그리드 셀 폭에 맞춰 늘어나요.
                            itemBuilder: (context, index) => ProductCard(product: filtered[index], width: null),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(16, 12, 16,
                                24 + MediaQuery.of(context).padding.bottom),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => ProductListTile(product: filtered[index]),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 쇼핑몰 상품 목록 화면에서 흔히 보이는, "상품 N개" + 얇은 구분선으로 나뉜
// 텍스트 탭 형태예요. 알록달록한 필터 버블보다 훨씬 차분하고 목록 화면
// 같은 느낌을 줘서 이 스타일로 바꿨어요.
class _ListFilterBar extends StatelessWidget {
  final int resultCount;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _ListFilterBar({
    required this.resultCount,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(String? option, String label) {
      final isSelected = selected == option;
      return InkWell(
        onTap: () => onSelected(option),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      );
    }

    final tabs = <Widget>[tab(null, '전체')];
    for (final option in options) {
      tabs.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(width: 1, height: 10, color: const Color(0xFFE5E7EB)),
      ));
      tabs.add(tab(option, option));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          Text(
            '상품 $resultCount개',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700),
          ),
          // Spacer랑 Flexible을 같이 쓰면 남은 공간을 절반씩 나눠 가지면서
          // 탭이 오른쪽 끝까지 안 붙고 그 사이에 빈 공간이 남았어요.
          // Expanded+Align 하나로만 오른쪽 끝에 딱 붙게 고쳤어요.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(mainAxisSize: MainAxisSize.min, children: tabs),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<CategoryItem> categories;

  const _CategoryGrid({required this.categories});

  String _displayName(String name) {
    switch (name) {
      case '진격의 거인':
        return '진격의\n거인';
      case '나의 히어로 아카데미':
        return '나의 히어로\n아카데미';
      case '전체보기':
        return '전체\n보기';
      default:
        return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final item = categories[index];
        final isAll = item.name == '전체보기';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${item.name} 카테고리는 다음 단계에서 연결할 예정이에요.')),
              );
            },
            child: Ink(
              decoration: BoxDecoration(
                color: isAll ? const Color(0xFFF1F5F9) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isAll ? const Color(0xFFCBD5E1) : const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Center(
                  child: Text(
                    _displayName(item.name),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontFamily: AppTextStyles.brandFont,
                      fontSize: 16.5,
                      height: 1.08,
                      letterSpacing: -0.2,
                      fontWeight: FontWeight.w700,
                      color: isAll ? const Color(0xFF334155) : const Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final IconData? icon;

  const _SectionHeader({
    required this.title,
    this.trailing,
    this.icon,
  });

  Color get _iconColor {
    if (title.contains('마감')) return kAiAccent;
    if (title.contains('인기')) return kGoldAccent;
    if (title.contains('신규')) return const Color(0xFFEF4444);
    if (title.contains('최근')) return const Color(0xFF64748B);
    return kDuckPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: _iconColor),
          const SizedBox(width: 5),
        ],
        Text(
          title,
          style: AppTextStyles.sectionTitle.copyWith(
            fontFamily: null,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text(
                    trailing!,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HorizontalProductList extends StatefulWidget {
  final List<ProductItem> products;

  const _HorizontalProductList({required this.products});

  @override
  State<_HorizontalProductList> createState() => _HorizontalProductListState();
}

class _HorizontalProductListState extends State<_HorizontalProductList> {
  late final ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateScrollHint);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollHint());
  }

  @override
  void didUpdateWidget(covariant _HorizontalProductList oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollHint());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollHint);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollHint() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canLeft = position.pixels > 8;
    final canRight = position.pixels < position.maxScrollExtent - 8;

    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (_scrollController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // ProductCard 하단에 판매자·태그 줄이 추가되면서 카드 높이가
      // 늘어나, 잘리지 않게 244 → 266으로 같이 늘렸어요.
      // 판매자명/태그를 두 줄로 나누면서 다시 266 → 282로 늘렸어요.
      height: 282,
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: const _HorizontalProductScrollBehavior(),
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 26),
              itemCount: widget.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              // 카드가 고정 높이를 꽉 채우며 아래에 빈 공간이 생기지 않도록,
              // 내용 높이만큼만 차지하게 상단 정렬로 감싸요.
              itemBuilder: (context, index) => Align(
                alignment: Alignment.topCenter,
                child: ProductCard(product: widget.products[index]),
              ),
            ),
          ),
          if (_canScrollLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFF8FAFC).withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_canScrollRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFF8FAFC).withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_canScrollLeft)
            Positioned(
              left: 0,
              top: 88,
              child: _HorizontalScrollButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _scrollBy(-174),
              ),
            ),
          if (_canScrollRight)
            Positioned(
              right: 0,
              top: 88,
              child: _HorizontalScrollButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _scrollBy(174),
              ),
            ),
        ],
      ),
    );
  }
}

class _HorizontalProductScrollBehavior extends MaterialScrollBehavior {
  const _HorizontalProductScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class _HorizontalScrollButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HorizontalScrollButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.12),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 21, color: kDuckPrimary),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final ProductItem product;
  // 홈 화면 가로 스크롤 캐러셀에서는 164 고정폭이 필요하지만, 그리드
  // 안에서 쓸 때는 셀 폭에 맞게 채워야 해서 null이면 폭을 고정하지 않아요.
  final double? width;

  const ProductCard({
    super.key,
    required this.product,
    this.width = 164,
  });

  @override
  Widget build(BuildContext context) {
    final card = InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          unawaited(DuckAuctionStore.addRecentViewedProduct(product));
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 128,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFFF4F5F8),
                        child: ProductPhoto(product: product, fontSize: 48),
                      ),
                    ),
                    // 마감까지 넉넉히 남은 활성 경매는 굳이 안 보여주고,
                    // 마감 임박(3시간 이하)이거나 활성 상태가 아닐 때만 보여요.
                    if (!product.isAuctionActive || product.isEndingSoon)
                      Positioned(
                        left: 7,
                        top: 7,
                        child: _TimeBadge(text: product.isAuctionActive ? product.time : product.statusLabel),
                      ),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: _StatusBadge(product: product),
                    ),
                    if (product.isLowestAuction)
                      const Positioned(
                        left: 7,
                        bottom: 7,
                        child: _AuctionTypeBadge(),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '현재가 ${product.price}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.postedAgoLabel.isEmpty
                                ? '입찰 ${product.bids}'
                                : '입찰 ${product.bids} · ${product.postedAgoLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.favorite_border, size: 16, color: kAiAccent),
                        const SizedBox(width: 3),
                        Text(
                          product.likes,
                          style: const TextStyle(
                            color: kAiAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (product.sellerName.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              product.sellerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (product.isSellerFirstListing) ...[
                            const SizedBox(width: 3),
                            const Text('🆕', style: TextStyle(fontSize: 10.5)),
                          ],
                          // 목록형과 동일하게 프로필에 설정한 배지(최대 3개)를
                          // 전부 보여줘요.
                          for (final id in product.sellerBadgeIds)
                            if (sellerBadgeEmoji(id) != null) ...[
                              const SizedBox(width: 3),
                              Text(sellerBadgeEmoji(id)!, style: const TextStyle(fontSize: 10.5)),
                            ],
                        ],
                      ),
                    ],
                    if (product.tags.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.tags.map((tag) => '#$tag').join(''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    if (width == null) return card;
    return SizedBox(width: width, child: card);
  }
}


class _StatusBadge extends StatelessWidget {
  final ProductItem product;

  const _StatusBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: product.statusColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        product.statusLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  final String text;

  const _TimeBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kAiAccent.withOpacity(0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuctionTypeBadge extends StatelessWidget {
  const _AuctionTypeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '최저가',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 홈 카드와 동일한 그리드 스타일로 경매 카드(ProductCard)를 격자로 보여줘요.
/// 여러 화면에서 재사용해요(최근 본 경매, 찜/필터 결과 등).
///  - [shrinkWrap]=true 이면 스크롤을 자체적으로 하지 않고(부모 스크롤에 얹힘)
///    내용 높이만큼만 차지해요(예: 다른 리스트/컬럼 안에 넣을 때).
class AuctionCardGrid extends StatelessWidget {
  final List<ProductItem> products;
  final bool shrinkWrap;
  final EdgeInsetsGeometry padding;

  const AuctionCardGrid({
    super.key,
    required this.products,
    this.shrinkWrap = false,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      // 홈 카드 그리드와 동일한 규격(폭 최대 200, 셀 높이 256 고정).
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 256,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: products.length,
      // width: null이면 ProductCard가 164 고정폭 대신 그리드 셀 폭에 맞춰 늘어나요.
      itemBuilder: (context, index) =>
          ProductCard(product: products[index], width: null),
    );
  }
}

/// 찜 목록 화면 — 상단에 [카테고리 필터](쿠지 선택 시 상위상/하위상 등급 필터 추가)와
/// 우측 [선택] 버튼(선택 모드에서 여러 개를 골라 한 번에 찜 해제)을 갖춘 찜 전용 화면이에요.
/// 각 카드의 하트를 눌러 바로 찜을 해제할 수도 있어요.
/// ProductCollectionScreen의 favorites 모드가 이 화면을 사용합니다.
class FavoritesCollectionScreen extends StatefulWidget {
  const FavoritesCollectionScreen({super.key});

  @override
  State<FavoritesCollectionScreen> createState() =>
      _FavoritesCollectionScreenState();
}

class _FavoritesCollectionScreenState extends State<FavoritesCollectionScreen> {
  static const String _allCategory = '전체';
  static const String _allGrade = '전체';
  String _category = _allCategory;
  String _kujiGrade = _allGrade; // 쿠지 하위 등급 필터(전체/상위상/하위상)
  bool _selectionMode = false;
  final Set<String> _selectedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(DuckAuctionStore.loadFavoriteProductIds());
  }

  List<String> get _categoryOptions =>
      <String>[_allCategory, ...AppCategories.names];
  List<String> get _gradeOptions =>
      <String>[_allGrade, ...AppCategories.kujiGrades];

  // 찜 저장 키: 상품 id(없으면 제목).
  String _keyOf(ProductItem p) =>
      (p.id != null && p.id!.isNotEmpty) ? p.id! : p.title;

  bool _isFavorited(ProductItem p, Set<String> favorites) {
    final id = p.id;
    if (id != null && id.isNotEmpty) return favorites.contains(id);
    return favorites.contains(p.title);
  }

  // 카테고리 + (쿠지일 때) 등급 필터를 적용해요.
  List<ProductItem> _applyFilters(List<ProductItem> favProducts) {
    var list = _category == _allCategory
        ? favProducts
        : favProducts.where((p) => p.category == _category).toList();
    if (_category == AppCategories.kuji && _kujiGrade != _allGrade) {
      list = list.where((p) => p.kujiGrade == _kujiGrade).toList();
    }
    return list;
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedKeys.clear();
    });
  }

  // 선택한 찜을 한 번에 해제해요(선택 후 삭제).
  Future<void> _deleteSelected(List<ProductItem> visible) async {
    final targets =
        visible.where((p) => _selectedKeys.contains(_keyOf(p))).toList();
    if (targets.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('찜 해제', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          '선택한 ${targets.length}개를 찜 목록에서 뺄까요?\n'
          '찜만 해제되고 경매·거래에는 영향이 없어요.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: Text('${targets.length}개 해제')),
        ],
      ),
    );
    if (ok != true) return;
    var removed = 0;
    for (final p in targets) {
      final r = await DuckAuctionStore.toggleFavorite(p);
      if (r.success) removed++;
    }
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$removed개를 찜 해제했어요.')),
    );
  }

  // 하트를 직접 눌러 찜 해제 — 실수 방지를 위해 확인 팝업 후 해제.
  Future<void> _unfavorite(ProductItem p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('찜 해제', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('이 경매를 찜 목록에서 뺄까요? 찜만 해제되고 경매·거래에는 영향이 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('찜 해제')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await DuckAuctionStore.toggleFavorite(p);
    if (!mounted) return;
    if (!r.success && r.message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.message!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.favorite_rounded, color: Color(0xFFFF6F91)),
            SizedBox(width: 8),
            Text('찜한 경매', style: AppTextStyles.sectionTitle),
          ],
        ),
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.registeredAuctions,
        builder: (context, products, _) {
          return ValueListenableBuilder<Set<String>>(
            valueListenable: DuckAuctionStore.favoriteProductIds,
            builder: (context, favorites, __) {
              final favProducts = products
                  .where((p) => _isFavorited(p, favorites))
                  .toList();
              final visible = _applyFilters(favProducts);

              return Column(
                children: [
                  _buildFilterBar(visible),
                  Expanded(
                    child: favProducts.isEmpty
                        ? _empty('아직 찜한 상품이 없어요.')
                        : (visible.isEmpty
                            ? _empty(_emptyFilterText())
                            : ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  ResponsiveContentBounds(
                                    maxWidth: double.infinity,
                                    padding: EdgeInsets.fromLTRB(16, 12, 16,
                                        24 + MediaQuery.of(context).padding.bottom),
                                    child: ResponsiveCardFlow(
                                      spacing: 12,
                                      runSpacing: 12,
                                      phoneColumns: 2,
                                      tabletColumns: 3,
                                      children: visible.map(_favCard).toList(),
                                    ),
                                  ),
                                ],
                              )),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _empty(String text) => Center(
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
      );

  String _emptyFilterText() =>
      (_category == AppCategories.kuji && _kujiGrade != _allGrade)
          ? "'쿠지 · $_kujiGrade'에 찜한 경매가 없어요."
          : "'$_category' 카테고리에 찜한 경매가 없어요.";

  // 찜 카드: 다른 목록과 동일한 표준 ProductCard(정보 전부 노출).
  // 평소엔 사진 우하단 하트(누르면 해제), 선택 모드엔 좌상단 체크(누르면 선택).
  Widget _favCard(ProductItem p) {
    final key = _keyOf(p);
    final selected = _selectedKeys.contains(key);

    if (_selectionMode) {
      return Stack(
        children: [
          Opacity(
            opacity: selected ? 1.0 : 0.6,
            child: IgnorePointer(child: ProductCard(product: p, width: null)),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                if (selected) {
                  _selectedKeys.remove(key);
                } else {
                  _selectedKeys.add(key);
                }
              }),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 26,
                color:
                    selected ? const Color(0xFFDB2777) : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ProductCard(product: p, width: null),
        // 사진(높이 128) 영역의 우하단에 하트를 얹어, 상태 뱃지와 겹치지 않게 해요.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 128,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 1,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _unfavorite(p),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.favorite_rounded,
                        color: Color(0xFFFF6F91), size: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 상단 바: 선택 모드가 아닐 땐 필터 드롭박스 + [선택], 선택 모드일 땐
  // [취소]·[전체 선택]·[삭제(N)] — 내 경매관리(판매)와 동일한 툴바예요.
  Widget _buildFilterBar(List<ProductItem> visible) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(context.pagePadding, 9, context.pagePadding, 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: _selectionMode ? _selectionRow(visible) : _filterRow(visible),
    );
  }

  Widget _filterRow(List<ProductItem> visible) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                PopupMenuButton<String>(
                  initialValue: _category,
                  onSelected: (v) => setState(() {
                    _category = v;
                    if (v != AppCategories.kuji) _kujiGrade = _allGrade;
                    _selectedKeys.clear();
                  }),
                  itemBuilder: (_) => _categoryOptions
                      .map((value) => PopupMenuItem<String>(
                          value: value, child: Text(value)))
                      .toList(),
                  child: _FilterPill(label: _category),
                ),
                // 쿠지 카테고리를 고르면 우측에 상위상/하위상/전체 등급 드롭박스가 생겨요.
                if (_category == AppCategories.kuji) ...[
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    initialValue: _kujiGrade,
                    onSelected: (v) => setState(() {
                      _kujiGrade = v;
                      _selectedKeys.clear();
                    }),
                    itemBuilder: (_) => _gradeOptions
                        .map((value) => PopupMenuItem<String>(
                            value: value,
                            child: Text(value == _allGrade ? '전체 등급' : value)))
                        .toList(),
                    child: _FilterPill(
                        label: _kujiGrade == _allGrade ? '전체 등급' : _kujiGrade),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: visible.isEmpty
              ? null
              : () => setState(() {
                    _selectionMode = true;
                    _selectedKeys.clear();
                  }),
          icon: const Icon(Icons.checklist_rounded, size: 18),
          label: const Text('선택'),
        ),
      ],
    );
  }

  Widget _selectionRow(List<ProductItem> visible) {
    final total = visible.length;
    final allSel = total > 0 && _selectedKeys.length >= total;
    return Row(
      children: [
        TextButton(onPressed: _exitSelection, child: const Text('취소')),
        TextButton(
          onPressed: total == 0
              ? null
              : () => setState(() {
                    if (allSel) {
                      _selectedKeys.clear();
                    } else {
                      _selectedKeys
                        ..clear()
                        ..addAll(visible.map(_keyOf));
                    }
                  }),
          child: Text(allSel ? '선택 해제' : '전체 선택'),
        ),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            disabledBackgroundColor: const Color(0xFFE7BBBB),
            foregroundColor: Colors.white,
          ),
          onPressed:
              _selectedKeys.isEmpty ? null : () => _deleteSelected(visible),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text('삭제 (${_selectedKeys.length})'),
        ),
      ],
    );
  }
}

/// 상품 목록을 정렬(최신/마감임박/가격/인기)만 바꿔가며 보여주는 리스트예요.
/// 부모가 Scaffold를 제공하므로 여기서는 정렬 바 + 그리드(본문)만 반환합니다.
/// (배너 링크 화면 — 마감 임박 경매 등 — 에서 재사용해요.)
class _FilteredAuctionListView extends StatefulWidget {
  final List<ProductItem> products;
  final _AuctionSort initialSort;
  final String emptyText;

  const _FilteredAuctionListView({
    required this.products,
    this.initialSort = _AuctionSort.latest,
    required this.emptyText,
  });

  @override
  State<_FilteredAuctionListView> createState() =>
      _FilteredAuctionListViewState();
}

class _FilteredAuctionListViewState extends State<_FilteredAuctionListView> {
  static const String _allCategory = '전체';
  static const String _allGrade = '전체';
  late _AuctionSort _sort = widget.initialSort;
  String _category = _allCategory;
  String _kujiGrade = _allGrade; // 쿠지 하위 등급(전체/상위상/하위상)

  List<String> get _categoryOptions =>
      <String>[_allCategory, ...AppCategories.names];
  List<String> get _gradeOptions =>
      <String>[_allGrade, ...AppCategories.kujiGrades];

  int _priceOf(ProductItem p) {
    if (p.currentPrice > 0) return p.currentPrice;
    return int.tryParse(p.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int _popularityOf(ProductItem p) {
    final bids = int.tryParse(p.bids.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final likes = int.tryParse(p.likes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return bids * 3 + likes;
  }

  String _sortLabel(_AuctionSort v) {
    switch (v) {
      case _AuctionSort.latest:
        return '최신순';
      case _AuctionSort.deadline:
        return '마감 임박순';
      case _AuctionSort.priceLow:
        return '낮은 가격순';
      case _AuctionSort.priceHigh:
        return '높은 가격순';
      case _AuctionSort.popular:
        return '인기순';
    }
  }

  // 카테고리(+쿠지일 때 등급) 필터를 적용해요.
  List<ProductItem> _applyCategory(List<ProductItem> list) {
    var out = _category == _allCategory
        ? list
        : list.where((p) => p.category == _category).toList();
    if (_category == AppCategories.kuji && _kujiGrade != _allGrade) {
      out = out.where((p) => p.kujiGrade == _kujiGrade).toList();
    }
    return out;
  }

  List<ProductItem> _sortList(List<ProductItem> src) {
    final result = List<ProductItem>.from(src);
    switch (_sort) {
      case _AuctionSort.latest:
        result.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        break;
      case _AuctionSort.deadline:
        result.sort((a, b) =>
            (a.endAt ?? DateTime(2999)).compareTo(b.endAt ?? DateTime(2999)));
        break;
      case _AuctionSort.priceLow:
        result.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
        break;
      case _AuctionSort.priceHigh:
        result.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
        break;
      case _AuctionSort.popular:
        result.sort((a, b) => _popularityOf(b).compareTo(_popularityOf(a)));
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortList(_applyCategory(widget.products));
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(context.pagePadding, 9, context.pagePadding, 9),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 카테고리 필터
                      PopupMenuButton<String>(
                        initialValue: _category,
                        onSelected: (v) => setState(() {
                          _category = v;
                          if (v != AppCategories.kuji) _kujiGrade = _allGrade;
                        }),
                        itemBuilder: (_) => _categoryOptions
                            .map((value) => PopupMenuItem<String>(
                                value: value, child: Text(value)))
                            .toList(),
                        child: _FilterPill(label: _category),
                      ),
                      // 쿠지를 고르면 상위상/하위상/전체 등급 필터가 생겨요.
                      if (_category == AppCategories.kuji) ...[
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          initialValue: _kujiGrade,
                          onSelected: (v) => setState(() => _kujiGrade = v),
                          itemBuilder: (_) => _gradeOptions
                              .map((value) => PopupMenuItem<String>(
                                  value: value,
                                  child: Text(
                                      value == _allGrade ? '전체 등급' : value)))
                              .toList(),
                          child: _FilterPill(
                              label:
                                  _kujiGrade == _allGrade ? '전체 등급' : _kujiGrade),
                        ),
                      ],
                      const SizedBox(width: 6),
                      // 정렬 필터
                      PopupMenuButton<_AuctionSort>(
                        initialValue: _sort,
                        onSelected: (v) => setState(() => _sort = v),
                        itemBuilder: (_) => _AuctionSort.values
                            .map((v) => PopupMenuItem<_AuctionSort>(
                                value: v, child: Text(_sortLabel(v))))
                            .toList(),
                        child: _FilterPill(label: _sortLabel(_sort)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    widget.emptyText,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontWeight: FontWeight.w800),
                  ),
                )
              : AuctionCardGrid(
                  products: items,
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
                ),
        ),
      ],
    );
  }
}

/// 사업자정보 + 이용약관·개인정보처리방침을 보여주는 화면이에요.
/// 홈 하단 '사업자정보·약관 전체보기'에서 열려요.
class BusinessInfoScreen extends StatelessWidget {
  const BusinessInfoScreen({super.key});

  void _openLegal(BuildContext context, String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _LegalTextScreen(title: title, body: body)),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(k,
                style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('사업자정보', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('덕옥션 사업자정보',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                _row('상호', '덕옥션'),
                _row('대표자', '이현선'),
                _row('사업자등록번호', '748-15-02875'),
                _row('사업장 소재지', '인천광역시 미추홀구 주안로 39, 1106호(주안동)'),
                _row('이메일', 'micket0012@gmail.com'),
                _row('연락처', '010-4553-0838'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '덕옥션은 통신판매중개자로서 통신판매의 당사자가 아니며, 개별 판매자가 등록한 '
            '상품·거래정보 및 거래에 대해 책임을 지지 않습니다. 상품·거래·배송·환불 등 '
            '거래에 관한 의무와 책임은 각 판매 회원(판매자)에게 있습니다.',
            style: TextStyle(
                fontSize: 12, height: 1.55, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: Color(0xFF16305C)),
                  title: const Text('서비스 이용약관',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8)),
                  onTap: () =>
                      _openLegal(context, '서비스 이용약관', kTermsOfServiceText),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: Color(0xFF16305C)),
                  title: const Text('개인정보처리방침',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8)),
                  onTap: () =>
                      _openLegal(context, '개인정보처리방침', kPrivacyPolicyText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 약관/개인정보처리방침 등 긴 법적 문서를 스크롤로 보여주는 단순 화면이에요.
class _LegalTextScreen extends StatelessWidget {
  final String title;
  final String body;

  const _LegalTextScreen({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: SelectableText(
          body,
          style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF334155)),
        ),
      ),
    );
  }
}

class ProductListTile extends StatelessWidget {
  final ProductItem product;

  const ProductListTile({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    // ListTile의 leading은 타일 전체 높이 계산 방식 때문에 92x92로 줘도
    // 실제로는 폭보다 낮게 눌려서 사진이 가로로 길어 보이는 문제가 있었어요.
    // 그리드 카드처럼 정확히 정사각형으로 나오도록 ListTile 대신 직접
    // Row로 레이아웃을 짜서 사진 박스 크기를 완전히 고정했어요.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          unawaited(DuckAuctionStore.addRecentViewedProduct(product));
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ProductPhoto(product: product, fontSize: 52),
                    ),
                    if (product.isLowestAuction)
                      const Positioned(
                        left: 4,
                        bottom: 4,
                        child: _AuctionTypeBadge(),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.postedAgoLabel.isEmpty
                          ? '${product.category} · 입찰 ${product.bids}'
                          : '${product.category} · 입찰 ${product.bids} · ${product.postedAgoLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '현재가 ${product.price}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (product.isSellerFirstListing) ...[
                          const SizedBox(width: 4),
                          const Text('🆕', style: TextStyle(fontSize: 13)),
                        ],
                        for (final id in product.sellerBadgeIds)
                          if (sellerBadgeEmoji(id) != null) ...[
                            const SizedBox(width: 4),
                            Text(sellerBadgeEmoji(id)!, style: const TextStyle(fontSize: 13)),
                          ],
                      ],
                    ),
                    if (product.tags.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.tags.map((tag) => '#$tag').join(''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(product: product),
                  const SizedBox(height: 6),
                  Text(
                    product.isAuctionActive ? product.time : product.statusLabel,
                    style: const TextStyle(
                      color: kAiAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAuctionSection extends StatelessWidget {
  final String message;
  final String description;

  const _EmptyAuctionSection({
    required this.message,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty_rounded, color: Color(0xFF94A3B8), size: 30),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
