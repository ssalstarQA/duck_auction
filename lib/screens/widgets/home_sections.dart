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
      borderRadius: BorderRadius.circular(16),
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: Icon(icon, color: accentColor, size: 30),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.category.copyWith(fontSize: 12.5),
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
        result.sort((a, b) {
          final aScore = DuckAuctionStore.parseCount(a.bids) * 10 + DuckAuctionStore.parseCount(a.likes) * 3;
          final bScore = DuckAuctionStore.parseCount(b.bids) * 10 + DuckAuctionStore.parseCount(b.likes) * 3;
          return bScore.compareTo(aScore);
        });
        return result;
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
    if (mode == ProductCollectionMode.favorites) {
      unawaited(DuckAuctionStore.loadFavoriteProductIds());
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

              if (filteredProducts.isEmpty) {
                final message = mode == ProductCollectionMode.favorites
                    ? '아직 찜한 상품이 없어요.'
                    : '표시할 상품이 없어요.';
                return Center(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  return ProductListTile(product: filteredProducts[index]);
                },
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
        _AllMenuEntry('section:categories', Icons.category_rounded, '전체 카테고리', '캐릭터와 브랜드별 경매를 둘러보세요.', () => setState(() => _selected = _AllMenuCategory.categories)),
        _AllMenuEntry('section:auctions', Icons.gavel_rounded, '경매', '인기·신규·마감 임박 경매를 확인하세요.', () => setState(() => _selected = _AllMenuCategory.auctions)),
        _AllMenuEntry('section:activity', Icons.manage_accounts_rounded, '나의 활동', '내 경매와 후기, 최근 활동을 모아보세요.', () => setState(() => _selected = _AllMenuCategory.activity)),
        _AllMenuEntry('section:communication', Icons.forum_rounded, '소통', '채팅방과 거래 후기를 확인하세요.', () => setState(() => _selected = _AllMenuCategory.communication)),
        _AllMenuEntry('section:support', Icons.support_agent_rounded, '고객 지원', '문의, 신고 이력, 공지사항을 확인하세요.', () => setState(() => _selected = _AllMenuCategory.support)),
        _AllMenuEntry('section:settings', Icons.settings_rounded, '설정', '알림과 앱 정보를 관리하세요.', () => setState(() => _selected = _AllMenuCategory.settings)),
      ];

  List<_AllMenuEntry> get _auctionItems => [
        _AllMenuEntry('auction:popular', Icons.emoji_events_rounded, '인기 경매', '입찰과 관심이 많은 경매를 모아봤어요.', () => _push(const ProductCollectionScreen(mode: ProductCollectionMode.popular))),
        _AllMenuEntry('auction:newest', Icons.new_releases_rounded, '신규 등록 경매', '최근 새롭게 등록된 진행 중 경매예요.', () => _push(const ProductCollectionScreen(mode: ProductCollectionMode.newest))),
        _AllMenuEntry('auction:ending', Icons.bolt_rounded, '마감 임박 경매', '곧 마감되는 경매를 놓치지 마세요.', () => _push(const EndingSoonAuctionsScreen())),
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
        return [
          _AllMenuEntry('activity:reviews', Icons.rate_review_outlined, '내가 남긴 후기', '작성한 후기와 받은 후기를 확인하세요.', () => _requireLogin(
                title: '후기는 로그인 후 이용할 수 있어요',
                action: () => _push(const MyReviewsScreen()),
              )),
          _AllMenuEntry('activity:auctions', Icons.gavel_rounded, '내 경매 관리', '판매·입찰·낙찰·유찰 경매를 관리하세요.', () => _requireLogin(
                title: '내 경매 관리는 로그인 후 이용할 수 있어요',
                action: () => _push(const MyAuctionManageScreen()),
              )),
          _AllMenuEntry('activity:liked', Icons.favorite_rounded, '찜한 경매', '관심 표시한 경매를 다시 확인하세요.', () => _requireLogin(
                title: '찜한 경매는 로그인 후 볼 수 있어요',
                action: () => _push(const ProductCollectionScreen(mode: ProductCollectionMode.favorites)),
              )),
          _AllMenuEntry('activity:recent', Icons.history_rounded, '최근 본 경매', '최근 확인한 경매를 이어서 둘러보세요.', () => _push(const RecentViewedProductsScreen())),
        ];
      case _AllMenuCategory.communication:
        return [
          _AllMenuEntry('communication:chat', Icons.chat_bubble_rounded, '채팅방 목록', '판매자와 구매자 간 대화를 확인하세요.', () => _requireLogin(
                title: '채팅은 로그인 후 이용할 수 있어요',
                action: () => _push(const ChatRoomListScreen()),
              )),
          _AllMenuEntry('communication:reviews', Icons.rate_review_rounded, '거래 후기', '받은 후기와 작성한 후기를 확인하세요.', () => _requireLogin(
                title: '후기는 로그인 후 이용할 수 있어요',
                action: () => _push(const MyReviewsScreen()),
              )),
        ];
      case _AllMenuCategory.support:
        return [
          _AllMenuEntry('support:email', Icons.mail_outline_rounded, '문의 메일 보내기', '문의 내용을 메일로 전달하세요.', _openSupportEmail),
          _AllMenuEntry('support:reports', Icons.report_rounded, '신고 이력', '내가 접수한 신고와 처리 상태를 확인하세요.', () => _requireLogin(
                title: '신고 이력은 로그인 후 이용할 수 있어요',
                action: () => _push(const MyReportHistoryScreen()),
              )),
          _AllMenuEntry('support:notices', Icons.campaign_rounded, '공지사항', '서비스 안내와 업데이트 소식을 확인하세요.', () => _push(const EventListScreen())),
        ];
      case _AllMenuCategory.settings:
        return [
          _AllMenuEntry('settings:app', Icons.settings_rounded, '앱 설정', '앱 사용 환경을 설정하세요.', () => _push(MySettingsScreen(onLogout: _logout))),
          _AllMenuEntry('settings:notifications', Icons.notifications_outlined, '알림 설정', '입찰·채팅·거래 알림을 관리하세요.', () => _push(MySettingsScreen(onLogout: _logout))),
          _AllMenuEntry('settings:version', Icons.info_outline_rounded, '버전·업데이트 확인', '현재 버전과 업데이트 여부를 확인하세요.', () => _push(MySettingsScreen(onLogout: _logout))),
          _AllMenuEntry('settings:logout', Icons.logout_rounded, '로그아웃', '현재 계정에서 로그아웃합니다.', _logout),
        ];
    }
  }

  List<_AllMenuEntry> get _allFavoriteCandidates {
    final categoryEntries = HomeTab.categories
        .where((item) => item.name != '전체보기')
        .map((category) => _AllMenuEntry(
              'category:${category.name}',
              Icons.sell_outlined,
              category.name,
              '${category.name} 카테고리 경매를 확인하세요.',
              () => _push(CategoryAuctionListScreen(category: category.name)),
            ));
    return <_AllMenuEntry>[
      ..._auctionItems,
      ..._detailEntriesFor(_AllMenuCategory.activity),
      ..._detailEntriesFor(_AllMenuCategory.communication),
      ..._detailEntriesFor(_AllMenuCategory.support),
      ..._detailEntriesFor(_AllMenuCategory.settings),
      ...categoryEntries,
      _AllMenuEntry(
        'favorite:products',
        Icons.favorite_rounded,
        '찜한 경매 보기',
        '관심 표시한 경매를 한곳에서 확인하세요.',
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
      selected: _selected == category,
      onTap: () => setState(() => _selected = category),
    );
  }

  Widget _menuRow(_AllMenuEntry entry) {
    final favorite = _favoriteMenus.contains(entry.id);
    return InkWell(
      onTap: entry.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 34, child: Icon(entry.icon, size: 20, color: const Color(0xFF475569))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                  const SizedBox(height: 3),
                  Text(entry.description, style: const TextStyle(fontSize: 12.5, height: 1.3, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              tooltip: favorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
              onPressed: () => _toggleFavoriteMenu(entry.id),
              icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded, color: favorite ? kGoldAccent : const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRows(List<_AllMenuEntry> entries) {
    return Column(children: entries.map(_menuRow).toList());
  }

  Widget _buildCategoryMenus() {
    final entries = HomeTab.categories
        .where((item) => item.name != '전체보기')
        .map((category) => _AllMenuEntry(
              'category:${category.name}',
              Icons.sell_outlined,
              category.name,
              '${category.name} 관련 경매를 확인하세요.',
              () => _push(CategoryAuctionListScreen(category: category.name)),
            ))
        .toList();
    return _buildRows(entries);
  }

  Widget _buildFavorites() {
    final menuEntries = _allFavoriteCandidates.where((entry) => _favoriteMenus.contains(entry.id)).toList();
    if (menuEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text(
          '즐겨찾기한 메뉴가 없어요. 각 세부 메뉴의 별을 눌러 추가해보세요.',
          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, height: 1.4),
        ),
      );
    }
    return _buildRows(menuEntries);
  }

  Widget _buildAllMenus() {
    final categories = HomeTab.categories
        .where((item) => item.name != '전체보기')
        .map((category) => _AllMenuEntry(
              'category:${category.name}',
              Icons.sell_outlined,
              category.name,
              '${category.name} 관련 경매를 확인하세요.',
              () => _push(CategoryAuctionListScreen(category: category.name)),
            ))
        .toList();

    Widget section(String title, List<_AllMenuEntry> entries) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            _buildRows(entries),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section('전체 카테고리', categories),
        section('경매', _auctionItems),
        section('나의 활동', _detailEntriesFor(_AllMenuCategory.activity)),
        section('소통', _detailEntriesFor(_AllMenuCategory.communication)),
        section('고객 지원', _detailEntriesFor(_AllMenuCategory.support)),
        section('설정', _detailEntriesFor(_AllMenuCategory.settings)),
      ],
    );
  }

  Widget _buildDetailContent() {
    if (_selected == _AllMenuCategory.all) return _buildAllMenus();
    if (_selected == _AllMenuCategory.favorites) return _buildFavorites();
    if (_selected == _AllMenuCategory.categories) return _buildCategoryMenus();
    return _buildRows(_detailItems);
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
      body: Row(
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
                padding: const EdgeInsets.symmetric(vertical: 6),
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
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  Text(_detailTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  _buildDetailContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllMenuCategoryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AllMenuCategoryButton({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          border: Border(left: BorderSide(color: selected ? kAiAccent : Colors.transparent, width: 4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: selected ? kAiAccent : const Color(0xFF64748B)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 11.5, height: 1.15, fontWeight: selected ? FontWeight.w900 : FontWeight.w700, color: selected ? const Color(0xFF111827) : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

class _AllMenuEntry {
  final String id;
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  const _AllMenuEntry(this.id, this.icon, this.label, this.description, this.onTap);
}

class CategoryAuctionListScreen extends StatelessWidget {
  final String category;

  const CategoryAuctionListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(category, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.registeredAuctions,
        builder: (context, products, _) {
          final filtered = products.where((product) {
            return product.isAuctionActive && product.category.trim() == category.trim();
          }).toList()
            ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                '$category 카테고리에 진행 중인 경매가 없어요.',
                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: filtered.length,
            itemBuilder: (context, index) => ProductListTile(product: filtered[index]),
          );
        },
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
          Icon(icon, size: 23, color: _iconColor),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: AppTextStyles.sectionTitle,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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
      height: 278,
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
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) => ProductCard(product: widget.products[index]),
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
              top: 104,
              child: _HorizontalScrollButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _scrollBy(-192),
              ),
            ),
          if (_canScrollRight)
            Positioned(
              right: 0,
              top: 104,
              child: _HorizontalScrollButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _scrollBy(192),
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
          width: 34,
          height: 34,
          child: Icon(icon, size: 24, color: kDuckPrimary),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final ProductItem product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 178,
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
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
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
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFFF4F5F8),
                        child: ProductPhoto(product: product, fontSize: 58),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _TimeBadge(text: product.isAuctionActive ? product.time : product.statusLabel),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _StatusBadge(product: product),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '현재가 ${product.price}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '입찰 ${product.bids}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(Icons.favorite_border, size: 16, color: kAiAccent),
                        const SizedBox(width: 3),
                        Text(
                          product.likes,
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
            ],
          ),
        ),
      ),
    );
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

class ProductListTile extends StatelessWidget {
  final ProductItem product;

  const ProductListTile({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        onTap: () {
          unawaited(DuckAuctionStore.addRecentViewedProduct(product));
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minVerticalPadding: 10,
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F8),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: ProductPhoto(product: product, fontSize: 28),
        ),
        title: Text(
          product.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${product.category} · 현재가 ${product.price} · 입찰 ${product.bids}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 5,
                runSpacing: 4,
                children: [
                  Text(
                    product.sellerName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SellerBadge(salesCount: product.sellerSalesCount),
                ],
              ),
            ],
          ),
        ),
        trailing: Column(
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
