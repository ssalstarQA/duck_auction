part of '../home_screen.dart';

class AuctionTab extends StatelessWidget {
  const AuctionTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('전체 경매', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.registeredAuctions,
        builder: (context, registeredAuctions, _) {
          final products = [
            ...registeredAuctions,
            ...HomeTab.popularProducts,
            ...HomeTab.recentProducts,
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            children: [
              const _SectionHeader(title: '등록된 경매', trailing: '최신순'),
              const SizedBox(height: 10),
              ...products.map((product) => ProductListTile(product: product)),
            ],
          );
        },
      ),
    );
  }
}

class FavoriteTab extends StatelessWidget {
  const FavoriteTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (_isGuestUser()) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: const _LoginRequiredContent(
          icon: Icons.favorite_border,
          title: '관심상품은 로그인 후 이용할 수 있어요',
          description: '찜한 상품을 저장하고 다시 보려면 로그인/회원가입이 필요해요.',
        ),
      );
    }

    return const _PlaceholderTab(
      icon: Icons.favorite,
      title: '관심상품',
      description: '하트로 찜한 상품을 모아보는 화면이에요. 다음 단계에서 관심상품 저장을 연결할 예정이에요.',
    );
  }
}

class CartTab extends StatelessWidget {
  const CartTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CartScreen(showAppBar: false);
  }
}

class CartScreen extends StatelessWidget {
  final bool showAppBar;

  const CartScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text(
                '장바구니',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text(
                '장바구니',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
      body: _isGuestUser()
          ? _LoginRequiredContent(
              icon: Icons.shopping_bag_outlined,
              title: '장바구니는 로그인 후 이용할 수 있어요',
              description: '관심 있는 경매를 담아두려면 로그인/회원가입이 필요해요.',
            )
          : ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.cartItems,
        builder: (context, cartItems, _) {
          if (cartItems.isEmpty) {
            return const _PlaceholderContent(
              icon: Icons.shopping_bag_outlined,
              title: '장바구니가 비어있어요',
              description: '경매 상세에서 장바구니 버튼을 눌러 관심 있는 경매를 모아볼 수 있어요.',
            );
          }

          final total = _sumPrices(cartItems);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.shopping_bag, color: Color(0xFF334155)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '담은 상품 ${cartItems.length}개',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  '입찰 전 관심 있는 상품을 모아둘 수 있어요.',
                                  style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionHeader(title: '장바구니 상품'),
                    const SizedBox(height: 10),
                    ...cartItems.map((product) => CartProductTile(product: product)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '현재가 합계',
                              style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${_formatNumber(total)}원',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(140, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('선택 입찰/결제 플로우는 다음 단계에서 연결할 예정이에요.')),
                          );
                        },
                        child: const Text('선택 진행'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static int _sumPrices(List<ProductItem> items) {
    return items.fold<int>(0, (sum, item) => sum + _parsePrice(item.price));
  }

  static int _parsePrice(String price) {
    return int.tryParse(price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  static String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }
}

class CartProductTile extends StatelessWidget {
  final ProductItem product;

  const CartProductTile({
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                );
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: ProductPhoto(product: product, fontSize: 34),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.category} · ${product.sellerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  SellerBadge(salesCount: product.sellerSalesCount),
                  const SizedBox(height: 6),
                  Text(
                    '현재가 ${product.price} · 입찰 ${product.bids}',
                    style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  tooltip: '삭제',
                  onPressed: () {
                    DuckAuctionStore.toggleCart(product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('장바구니에서 삭제했어요.')),
                    );
                  },
                  icon: const Icon(Icons.close),
                ),
                IconButton.filledTonal(
                  tooltip: '채팅',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF334155),
                  ),
                  onPressed: () {
                    if (_isGuestUser()) {
                      _showLoginRequiredSheet(
                        context,
                        title: '채팅은 로그인 후 가능해요',
                        description: '판매자에게 문의하려면 로그인/회원가입이 필요해요.',
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SellerChatScreen(product: product)),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MyPageTab extends StatefulWidget {
  final VoidCallback onLogout;

  const MyPageTab({super.key, required this.onLogout});

  @override
  State<MyPageTab> createState() => _MyPageTabState();
}

class _MyPageTabState extends State<MyPageTab> {
  final ImagePicker _picker = ImagePicker();
  List<String>? _savedBadgesOverride;

  Future<void> _changePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 900);
    if (image == null) return;
    try {
      final bytes = await image.readAsBytes();
      final ref = FirebaseStorage.instance.ref('profile_images/${user.uid}/profile.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profileImageUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('프로필 사진 저장에 실패했어요: $error')));
    }
  }


  Future<void> _changeCoverPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (image == null) return;
    try {
      final bytes = await image.readAsBytes();
      final ref = FirebaseStorage.instance.ref('profile_images/${user.uid}/cover.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profileCoverImageUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('배경 사진 저장에 실패했어요: $error')));
    }
  }

  Future<void> _shareMyProfile(String nickname) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final text = '덕옥션 판매자 프로필 · $nickname\nhttps://duckauction.com/profile/${user.uid}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('내 프로필 링크를 복사했어요.')));
  }

  Future<void> _editTextProfile(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final nickname = TextEditingController(text: ((data['nickname'] as String?) ?? user.displayName ?? '덕친').trim());
    final intro = TextEditingController(text: (data['sellerIntro'] as String?) ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('프로필 정보 수정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          TextField(controller: nickname, maxLength: 20, decoration: const InputDecoration(labelText: '닉네임', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: intro, maxLength: 120, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '판매자 소개', hintText: '미작성 시 기본 소개 문구가 표시돼요.', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final name = nickname.text.trim();
              if (name.isEmpty) return;
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'uid': user.uid,
                'email': user.email,
                'nickname': name,
                'sellerIntro': intro.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              await user.updateDisplayName(name);
              if (sheetContext.mounted) Navigator.pop(sheetContext, true);
            },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: const Color(0xFFE91E63)),
            child: const Text('저장하기'),
          ),
        ]),
      ),
    );
    nickname.dispose();
    intro.dispose();
    if (saved == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 정보를 저장했어요.')));
  }

  Future<void> _editBadges(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sourceBadges = _savedBadgesOverride ??
        (data['sellerBadges'] as List?)?.whereType<String>().take(3).toList() ??
        <String>[];
    final selected = <String>{...sourceBadges};
    bool saving = false;
    bool showMaxSelectionNotice = false;

    final savedBadges = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '표시할 판매자 배지',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        '${selected.length}/3',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '보유한 배지 중 프로필에 표시할 배지를 최대 3개 선택하세요.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: showMaxSelectionNotice
                        ? Container(
                            key: const ValueKey('badge-limit-notice'),
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDA4AF)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '배지는 최대 3개까지 표시할 수 있어요. 선택된 배지 하나를 먼저 해제한 뒤 다시 선택해 주세요.',
                                    style: TextStyle(
                                      color: Color(0xFFBE123C),
                                      fontWeight: FontWeight.w800,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('badge-limit-empty')),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kSellerBadgeOptions.map((badge) {
                      final id = badge['id']!;
                      final isSelected = selected.contains(id);
                      return FilterChip(
                        selected: isSelected,
                        avatar: Text(badge['emoji']!),
                        label: Text(badge['label']!),
                        onSelected: saving
                            ? null
                            : (_) {
                                setSheetState(() {
                                  if (isSelected) {
                                    selected.remove(id);
                                    showMaxSelectionNotice = false;
                                    return;
                                  }

                                  if (selected.length >= 3) {
                                    showMaxSelectionNotice = true;
                                    return;
                                  }

                                  selected.add(id);
                                  showMaxSelectionNotice = false;
                                });
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            try {
                              final values = selected.take(3).toList(growable: false);
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .set({
                                'uid': user.uid,
                                'email': user.email,
                                'sellerBadges': values,
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, values);
                              }
                            } catch (error) {
                              if (sheetContext.mounted) {
                                setSheetState(() => saving = false);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text('배지 저장에 실패했어요: $error')),
                                );
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFFE91E63),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('저장하기'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (savedBadges != null && mounted) {
      setState(() => _savedBadgesOverride = savedBadges);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('판매자 배지를 저장했어요.')),
      );
    }
  }

  Widget _avatar(String? url) {
    if ((url ?? '').trim().isNotEmpty) {
      return Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🐥', style: TextStyle(fontSize: 44))));
    }
    return const Center(child: Text('🐥', style: TextStyle(fontSize: 44)));
  }

  String _dateText(dynamic value) {
    if (value is! Timestamp) return '-';
    final d = value.toDate();
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(backgroundColor: Colors.white, appBar: AppBar(title: const Text('마이페이지')), body: const _LoginRequiredContent(icon: Icons.person_outline, title: '마이페이지는 로그인 후 이용할 수 있어요', description: '내 경매 관리와 프로필 기능을 사용하려면 로그인/회원가입이 필요해요.'));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final nickname = ((data['nickname'] as String?) ?? user.displayName ?? '덕친').trim();
          final intro = ((data['sellerIntro'] as String?) ?? '').trim();
          final imageUrl = data['profileImageUrl'] as String?;
          final coverImageUrl = data['profileCoverImageUrl'] as String?;
          final badges = _savedBadgesOverride ??
              (data['sellerBadges'] as List?)?.whereType<String>().take(3).toList() ??
              <String>[];
          final joinedText = _dateText(data['createdAt']);
          final followerCount = (data['followerCount'] as num?)?.toInt() ?? 0;
          final followingCount = (data['followingCount'] as num?)?.toInt() ?? 0;
          final completedCount = (data['completedTradeCount'] as num?)?.toInt() ?? 0;
          final reviewCount = (data['reviewCount'] as num?)?.toInt() ?? (DuckAuctionStore.isMasterAdmin ? 5 : 0);
          final rating = (data['rating'] as num?)?.toDouble() ?? (DuckAuctionStore.isMasterAdmin ? 4.8 : 0.0);

          return ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 96), children: [
            Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
              SizedBox(
                height: 185,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  if ((coverImageUrl ?? '').trim().isNotEmpty)
                    Image.network(coverImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE4EC), Color(0xFFFFF6F8)])), child: const Center(child: Text('🐥', style: TextStyle(fontSize: 78)))))
                  else
                    Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE4EC), Color(0xFFFFF6F8)])), child: const Center(child: Text('🐥', style: TextStyle(fontSize: 78)))),
                  Positioned(
                    right: 62,
                    top: 14,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => _shareMyProfile(nickname.isEmpty ? '덕친' : nickname),
                        icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
                        tooltip: '내 프로필 공유',
                      ),
                    ),
                  ),
                  Positioned(right: 14, top: 14, child: Material(color: Colors.black54, shape: const CircleBorder(), child: IconButton(onPressed: _changeCoverPhoto, icon: const Icon(Icons.camera_alt_rounded, color: Colors.white), tooltip: '배경 사진 수정'))),
                ]),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(0, 138, 0, 0),
                padding: const EdgeInsets.fromLTRB(20, 66, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: Text(nickname.isEmpty ? '덕친' : nickname, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => _editTextProfile(data), icon: const Icon(Icons.edit_outlined, size: 20), tooltip: '닉네임과 소개 수정'),
                  ]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.star_rounded, color: rating > 0 ? const Color(0xFFFFA726) : const Color(0xFFCBD5E1), size: 22),
                    const SizedBox(width: 4),
                    Text(rating > 0 ? rating.toStringAsFixed(1) : '신규', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 12),
                    Text('판매완료 $completedCount건', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      Expanded(child: _MyProfileStat(icon: Icons.calendar_month_outlined, label: '가입일', value: joinedText)),
                      const _MyProfileDivider(),
                      const Expanded(child: _MyProfileStat(icon: Icons.schedule_rounded, label: '최근 접속', value: '방금 전')),
                      const _MyProfileDivider(),
                      Expanded(child: _MyProfileStat(icon: Icons.people_outline_rounded, label: '팔로워', value: '$followerCount', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FollowListScreen(userId: user.uid, mode: FollowListMode.followers, title: '내 팔로워'))))),
                      const _MyProfileDivider(),
                      Expanded(child: _MyProfileStat(icon: Icons.person_add_alt_1_outlined, label: '팔로잉', value: '$followingCount', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FollowListScreen(userId: user.uid, mode: FollowListMode.following, title: '내 팔로잉'))))),
                    ]),
                  ),
                ]),
              ),
              Positioned(
                top: 88,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(width: 104, height: 104, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF1F5F9), border: Border.all(color: Colors.white, width: 5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 18, offset: const Offset(0, 5))]), child: _avatar(imageUrl)),
                  Positioned(right: -3, bottom: 0, child: Material(color: const Color(0xFF334155), shape: const CircleBorder(), child: IconButton(onPressed: _changePhoto, icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 19), tooltip: '프로필 사진 수정'))),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _EditableProfileCard(title: '판매자 소개', onEdit: () => _editTextProfile(data), child: Text(intro.isEmpty ? '안녕하세요! 좋은 거래 약속드릴게요 😊\n꼼꼼한 포장과 빠른 답변으로 거래할게요.' : intro, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, height: 1.5)))),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _EditableProfileCard(title: '판매자 배지', onEdit: () => _editBadges(data), child: badges.isEmpty ? const Text('표시할 배지를 선택해 주세요.', style: TextStyle(color: Color(0xFF94A3B8))) : SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: badges.map((id) => Padding(padding: const EdgeInsets.only(right: 6), child: _CompactSellerBadge(label: sellerBadgeLabel(id)))).toList())))),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: [
              _MyMenuTile(icon: Icons.receipt_long_outlined, title: '내 경매 관리', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyAuctionManageScreen()))),
              _MyMenuTile(icon: Icons.favorite_border, title: '찜한 경매', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductCollectionScreen(mode: ProductCollectionMode.favorites)))),
              _MyMenuTile(icon: Icons.remove_red_eye_outlined, title: '최근 본 경매', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecentViewedProductsScreen()))),
              _MyMenuTile(icon: Icons.chat_bubble_outline_rounded, title: '채팅', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatRoomListScreen()))),
              _MyMenuTile(icon: Icons.star_outline_rounded, title: '후기', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyReviewsScreen()))),
              _MyMenuTile(icon: Icons.report_gmailerrorred_outlined, title: '신고내역', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyReportHistoryScreen()))),
              _MyMenuTile(icon: Icons.settings_outlined, title: '설정', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MySettingsScreen(onLogout: widget.onLogout)))),
              if (DuckAuctionStore.isMasterAdmin) ...[const SizedBox(height: 10), const _DeveloperModePanel()],
            ])),
          ]);
        },
      ),
    );
  }
}

class _EditableProfileCard extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onEdit;
  const _EditableProfileCard({required this.title, required this.child, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Stack(children: [
        Padding(padding: const EdgeInsets.only(right: 40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 12), child])),
        Positioned(right: 0, top: 0, child: IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: '$title 수정')),
      ]),
    );
  }
}

class _MyProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _MyProfileStat({required this.icon, required this.label, required this.value, this.onTap});
  @override
  Widget build(BuildContext context) {
    final child = Column(children: [Icon(icon, size: 20, color: const Color(0xFF64748B)), const SizedBox(height: 5), Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700))]);
    if (onTap == null) return child;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: child));
  }
}

class _CompactSellerBadge extends StatelessWidget {
  final String label;
  const _CompactSellerBadge({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFDDE3EA))),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
  );
}

class _MyProfileDivider extends StatelessWidget {
  const _MyProfileDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 38, color: const Color(0xFFE5E7EB));
}

class _MyMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MyMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _DeveloperModePanel extends StatefulWidget {
  const _DeveloperModePanel();

  @override
  State<_DeveloperModePanel> createState() => _DeveloperModePanelState();
}

class _DeveloperModePanelState extends State<_DeveloperModePanel> {
  bool _enabled = false;
  bool _working = false;

  Future<void> _run(Future<DevActionResult> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.developer_mode, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '개발자 모드',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'master@duckauction.com 전용 메뉴',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _enabled,
                activeColor: kAiAccent,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          if (_enabled) ...[
            const SizedBox(height: 14),
            _DevActionButton(
              icon: Icons.admin_panel_settings_outlined,
              label: '관리자 대시보드',
              working: _working,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                );
              },
            ),
            _DevActionButton(
              icon: Icons.refresh,
              label: 'Firestore 상품 새로고침',
              working: _working,
              onTap: () => _run(DuckAuctionStore.refreshProductsNow),
            ),
            _DevActionButton(
              icon: Icons.add_box_outlined,
              label: '샘플 상품 3개 생성',
              working: _working,
              onTap: () => _run(DuckAuctionStore.createSampleProducts),
            ),
            _DevActionButton(
              icon: Icons.tune_outlined,
              label: '상품 상태 테스트 변경',
              working: _working,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminProductStatusScreen()),
                );
              },
            ),
            _DevActionButton(
              icon: Icons.schedule_outlined,
              label: '시스템 시간 이동 테스트',
              working: _working,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminSystemTimeScreen()),
                );
              },
            ),
            _DevActionButton(
              icon: Icons.payments_outlined,
              label: '결제/낙찰 시나리오 테스트',
              working: _working,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminPaymentScenarioScreen()),
                );
              },
            ),
            _DevActionButton(
              icon: Icons.report_gmailerrorred_outlined,
              label: '신고 관리',
              working: _working,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminReportManagementScreen()),
                );
              },
            ),
            _DevActionButton(
              icon: Icons.cleaning_services_outlined,
              label: '로컬 테스트 캐시 삭제',
              working: _working,
              onTap: () => _run(DuckAuctionStore.clearLocalDevelopmentData),
            ),
            _DevActionButton(
              icon: Icons.image_search_outlined,
              label: '이미지 데이터 마이그레이션',
              working: _working,
              onTap: () => _run(DuckAuctionStore.migrateProductImageSchema),
            ),
            _DevActionButton(
              icon: Icons.delete_forever_outlined,
              label: '테스트 상품 전체 삭제',
              danger: true,
              working: _working,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('테스트 상품을 모두 삭제할까요?'),
                    content: const Text('Firestore products 컬렉션의 상품 문서가 삭제됩니다. 이 작업은 되돌릴 수 없어요.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _run(DuckAuctionStore.deleteAllTestProducts);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DevActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool working;

  const _DevActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.working = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFCA5A5) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: working ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              if (working)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                Icon(Icons.chevron_right, color: color.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}





class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<Map<String, int>> _loadCounts() async {
    Future<int> count(String collection) async {
      final snapshot = await FirebaseFirestore.instance.collection(collection).get();
      return snapshot.docs.length;
    }

    final values = await Future.wait<int>([
      count('users'),
      count('products'),
      count('chatRooms'),
      count('reports'),
      count('reviewReports'),
      count('reviews'),
    ]);
    return {
      '회원': values[0],
      '경매': values[1],
      '채팅': values[2],
      '상품 신고': values[3],
      '후기 신고': values[4],
      '후기': values[5],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!DuckAuctionStore.isMasterAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('관리자')),
        body: const Center(child: Text('마스터 계정에서만 사용할 수 있어요.')),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('관리자 대시보드', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          FutureBuilder<Map<String, int>>(
            future: _loadCounts(),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const <String, int>{};
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ['회원', '경매', '채팅', '상품 신고', '후기 신고', '후기'].map((label) {
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 42) / 2,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(snapshot.connectionState == ConnectionState.waiting ? '…' : '${counts[label] ?? 0}', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('운영 관리', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _AdminMenuTile(icon: Icons.people_outline, title: '회원 관리', subtitle: '검색 · 정지 · 정지 해제', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMemberManagementScreen()))),
          _AdminMenuTile(icon: Icons.campaign_outlined, title: '공지 관리', subtitle: '작성 · 수정 · 삭제 · 상단 고정', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNoticeManagementScreen()))),
          _AdminMenuTile(icon: Icons.report_gmailerrorred_outlined, title: '통합 신고 관리', subtitle: '경매 · 후기 · 채팅 신고', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportHubScreen()))),
          _AdminMenuTile(icon: Icons.rate_review_outlined, title: '후기 관리', subtitle: '숨김 · 복구 · 삭제', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReviewManagementScreen()))),
          _AdminMenuTile(icon: Icons.edit_note_rounded, title: '테스트 후기 남기기', subtitle: '판매자·구매자 후기 직접 작성', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReviewWriteHubScreen()))),
          _AdminMenuTile(icon: Icons.tune_outlined, title: '경매 상태 관리', subtitle: '진행 · 낙찰 · 유찰 상태 테스트', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductStatusScreen()))),
          _AdminMenuTile(icon: Icons.receipt_long_outlined, title: '운영 로그', subtitle: '관리자 처리 이력 확인', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOperationLogScreen()))),
        ],
      ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AdminMenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: const Color(0xFF334155))),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

Future<void> _writeAdminLog(String action, {String? targetId, String? detail}) async {
  final user = FirebaseAuth.instance.currentUser;
  await FirebaseFirestore.instance.collection('adminLogs').add({
    'action': action,
    'targetId': targetId,
    'detail': detail,
    'adminUid': user?.uid,
    'adminEmail': user?.email,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

class AdminMemberManagementScreen extends StatefulWidget {
  const AdminMemberManagementScreen({super.key});
  @override
  State<AdminMemberManagementScreen> createState() => _AdminMemberManagementScreenState();
}

class _AdminMemberManagementScreenState extends State<AdminMemberManagementScreen> {
  String _query = '';
  Future<void> _toggleSuspended(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final suspended = data['isSuspended'] == true;
    await doc.reference.set({'isSuspended': !suspended, 'suspendedAt': !suspended ? FieldValue.serverTimestamp() : null, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await _writeAdminLog(!suspended ? '회원 정지' : '회원 정지 해제', targetId: doc.id, detail: (data['email'] as String?) ?? (data['nickname'] as String?));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!suspended ? '회원을 정지했어요.' : '정지를 해제했어요.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('회원 관리')),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(onChanged: (v) => setState(() => _query = v.trim().toLowerCase()), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: '닉네임 또는 이메일 검색', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
      ),
      Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').limit(200).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]).where((doc) {
            final data = doc.data();
            final haystack = '${data['nickname'] ?? ''} ${data['email'] ?? ''} ${doc.id}'.toLowerCase();
            return _query.isEmpty || haystack.contains(_query);
          }).toList();
          if (docs.isEmpty) return const Center(child: Text('검색 결과가 없어요.'));
          return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), itemCount: docs.length, itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final suspended = data['isSuspended'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: suspended ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB))),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFFFFF3C4), child: const Text('🐥')),
                title: Text((data['nickname'] as String?)?.trim().isNotEmpty == true ? (data['nickname'] as String) : '닉네임 없음', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${data['email'] ?? '이메일 없음'}${suspended ? ' · 이용 정지' : ''}'),
                trailing: OutlinedButton(onPressed: () => _toggleSuspended(doc), style: OutlinedButton.styleFrom(foregroundColor: suspended ? const Color(0xFF16A34A) : const Color(0xFFDC2626)), child: Text(suspended ? '해제' : '정지')),
              ),
            );
          });
        },
      )),
    ]),
  );
}

class AdminNoticeManagementScreen extends StatefulWidget {
  const AdminNoticeManagementScreen({super.key});
  @override
  State<AdminNoticeManagementScreen> createState() => _AdminNoticeManagementScreenState();
}

class _AdminNoticeManagementScreenState extends State<AdminNoticeManagementScreen> {
  Future<void> _edit({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final old = doc?.data() ?? {};
    final title = TextEditingController(text: old['title'] as String? ?? '');
    final body = TextEditingController(text: old['body'] as String? ?? '');
    bool pinned = old['pinned'] == true;
    bool enabled = old['enabled'] != false;
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(doc == null ? '공지 작성' : '공지 수정'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, maxLength: 50, decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: body, minLines: 4, maxLines: 8, maxLength: 1000, decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder())),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('상단 고정'), value: pinned, onChanged: (v) => setDialogState(() => pinned = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('노출'), value: enabled, onChanged: (v) => setDialogState(() => enabled = v)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('취소')), FilledButton(onPressed: () { if (title.text.trim().isEmpty) { ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('제목을 입력해 주세요.'))); return; } Navigator.pop(dialogContext, true); }, child: const Text('저장'))],
    )));
    if (saved == true) {
      final data = {'title': title.text.trim(), 'body': body.text.trim(), 'pinned': pinned, 'enabled': enabled, 'updatedAt': FieldValue.serverTimestamp(), if (doc == null) 'createdAt': FieldValue.serverTimestamp()};
      if (doc == null) await FirebaseFirestore.instance.collection('notices').add(data); else await doc.reference.set(data, SetOptions(merge: true));
      await _writeAdminLog(doc == null ? '공지 작성' : '공지 수정', targetId: doc?.id, detail: title.text.trim());
    }
    title.dispose(); body.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('공지 관리'), actions: [IconButton(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), tooltip: '공지 작성')]),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('notices').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) return const Center(child: Text('등록된 공지가 없어요.'));
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length, itemBuilder: (context, index) {
          final doc = docs[index]; final data = doc.data();
          return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: ListTile(
            title: Row(children: [if (data['pinned'] == true) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin_rounded, size: 17)), Expanded(child: Text(data['title'] as String? ?? '제목 없음', style: const TextStyle(fontWeight: FontWeight.w900)))]),
            subtitle: Text('${data['enabled'] == false ? '숨김 · ' : ''}${data['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => _edit(doc: doc),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)), onPressed: () async { await doc.reference.delete(); await _writeAdminLog('공지 삭제', targetId: doc.id, detail: data['title'] as String?); }),
          ));
        });
      },
    ),
  );
}

class AdminReportHubScreen extends StatelessWidget {
  const AdminReportHubScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('통합 신고 관리')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _AdminMenuTile(icon: Icons.gavel_outlined, title: '경매 신고', subtitle: '허위 매물 · 불법 상품 · 사기 의심', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportManagementScreen()))),
      _AdminMenuTile(icon: Icons.rate_review_outlined, title: '후기 신고', subtitle: '허위 후기 · 비방 · 개인정보 노출', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReviewReportScreen()))),
      _AdminMenuTile(icon: Icons.chat_bubble_outline, title: '채팅 신고', subtitle: '욕설 · 사기 의심 · 개인정보 요구', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSimpleReportListScreen(collection: 'chatReports', title: '채팅 신고')))),
    ]),
  );
}

class AdminSimpleReportListScreen extends StatelessWidget {
  final String collection;
  final String title;
  const AdminSimpleReportListScreen({super.key, required this.collection, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: Text(title)),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(collection).orderBy('createdAt', descending: true).limit(200).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) return const Center(child: Text('접수된 신고가 없어요.'));
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length, itemBuilder: (context, index) {
          final doc = docs[index]; final data = doc.data(); final status = data['status'] as String? ?? 'waiting';
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(data['reason'] as String? ?? '신고', style: const TextStyle(fontWeight: FontWeight.w900))), Text(status, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800))]),
            const SizedBox(height: 6),
            Text(data['detail'] as String? ?? '상세 내용 없음', style: const TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: () => doc.reference.set({'status': 'reviewing', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)), child: const Text('검토중')),
              OutlinedButton(onPressed: () => doc.reference.set({'status': 'rejected', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)), child: const Text('기각')),
              FilledButton(onPressed: () async { await doc.reference.set({'status': 'complete', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); await _writeAdminLog('$title 처리완료', targetId: doc.id); }, child: const Text('처리완료')),
            ]),
          ]));
        });
      },
    ),
  );
}

class AdminReviewReportScreen extends StatelessWidget {
  const AdminReviewReportScreen({super.key});
  @override
  Widget build(BuildContext context) => const AdminSimpleReportListScreen(collection: 'reviewReports', title: '후기 신고');
}

class AdminReviewManagementScreen extends StatelessWidget {
  const AdminReviewManagementScreen({super.key});
  Future<void> _action(DocumentSnapshot<Map<String, dynamic>> doc, String action) async {
    if (action == 'delete') {
      await doc.reference.delete();
    } else {
      await doc.reference.set({'hidden': action == 'hide', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    await _writeAdminLog(action == 'delete' ? '후기 삭제' : action == 'hide' ? '후기 숨김' : '후기 복구', targetId: doc.id);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('후기 관리')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('reviews').orderBy('createdAt', descending: true).limit(200).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) return const Center(child: Text('등록된 후기가 없어요.'));
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length, itemBuilder: (context, index) {
          final doc = docs[index]; final data = doc.data(); final hidden = data['hidden'] == true; final rating = (data['rating'] as num?)?.toInt() ?? 0;
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: hidden ? const Color(0xFFF8FAFC) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${List.filled(rating.clamp(0, 5).toInt(), '🐥').join()}  ${data['writerName'] ?? data['writerUid'] ?? '작성자'}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6), Text(data['content'] as String? ?? '', style: const TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 10), Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: () => _action(doc, hidden ? 'restore' : 'hide'), child: Text(hidden ? '복구' : '숨김')),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)), onPressed: () => _action(doc, 'delete'), child: const Text('삭제')),
            ]),
          ]));
        });
      },
    ),
  );
}

class AdminOperationLogScreen extends StatelessWidget {
  const AdminOperationLogScreen({super.key});
  String _time(dynamic raw) {
    if (raw is! Timestamp) return '-'; final d = raw.toDate();
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('운영 로그')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('adminLogs').orderBy('createdAt', descending: true).limit(300).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) return const Center(child: Text('운영 로그가 없어요.'));
        return ListView.separated(padding: const EdgeInsets.all(16), itemCount: docs.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, index) {
          final data = docs[index].data();
          return ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 4), leading: const Icon(Icons.history_rounded), title: Text(data['action'] as String? ?? '관리 작업', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${data['adminEmail'] ?? '관리자'} · ${data['detail'] ?? data['targetId'] ?? ''}\n${_time(data['createdAt'])}'));
        });
      },
    ),
  );
}

class AdminSystemTimeScreen extends StatefulWidget {
  const AdminSystemTimeScreen({super.key});

  @override
  State<AdminSystemTimeScreen> createState() => _AdminSystemTimeScreenState();
}

class _AdminSystemTimeScreenState extends State<AdminSystemTimeScreen> {
  bool _working = false;

  Future<void> _move(Duration offset) async {
    if (_working) return;
    setState(() => _working = true);
    final result = await DuckAuctionStore.moveDevSystemTime(offset);
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _reset() async {
    if (_working) return;
    setState(() => _working = true);
    final result = await DuckAuctionStore.resetDevSystemTime();
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!DuckAuctionStore.isMasterAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('시스템 시간 이동')),
        body: const Center(child: Text('master 계정에서만 사용할 수 있어요.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('시스템 시간 이동')),
      body: ValueListenableBuilder<int>(
        valueListenable: DuckAuctionStore.devTimeOffsetMinutes,
        builder: (context, minutes, _) {
          final now = DuckAuctionStore.devNow();
          final offsetLabel = DuckAuctionStore.devTimeOffsetLabel;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('현재 테스트 시간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} '
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 6),
                    Text('이동값: $offsetLabel', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Text(
                      '앱 안에서만 사용하는 테스트 시간이에요. Firestore 서버 시간 자체를 바꾸지는 않지만, 경매 마감/24시간 후 숨김/남은 시간 표시를 빠르게 확인할 수 있어요.',
                      style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _TimeMoveButton(label: '+1시간', working: _working, onTap: () => _move(const Duration(hours: 1))),
              _TimeMoveButton(label: '+12시간', working: _working, onTap: () => _move(const Duration(hours: 12))),
              _TimeMoveButton(label: '+24시간', working: _working, onTap: () => _move(const Duration(hours: 24))),
              _TimeMoveButton(label: '+3일', working: _working, onTap: () => _move(const Duration(days: 3))),
              _TimeMoveButton(label: '+7일', working: _working, onTap: () => _move(const Duration(days: 7))),
              const SizedBox(height: 8),
              _TimeMoveButton(label: '-1시간', working: _working, onTap: () => _move(const Duration(hours: -1))),
              _TimeMoveButton(label: '-24시간', working: _working, onTap: () => _move(const Duration(hours: -24))),
              const SizedBox(height: 8),
              _TimeMoveButton(label: '실제 시간으로 초기화', danger: true, working: _working, onTap: _reset),
            ],
          );
        },
      ),
    );
  }
}

class _TimeMoveButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool working;

  const _TimeMoveButton({
    required this.label,
    required this.onTap,
    this.danger = false,
    this.working = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : const Color(0xFF111827);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: working ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Icon(danger ? Icons.restart_alt : Icons.schedule, size: 19, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900))),
              if (working)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right, color: color.withOpacity(0.65)),
            ],
          ),
        ),
      ),
    );
  }
}


class AdminProductStatusScreen extends StatelessWidget {
  const AdminProductStatusScreen({super.key});

  static const _statuses = <String, String>{
    'active': '판매중',
    'ended': '마감',
    'sold': '낙찰',
    'failed': '유찰',
    'hidden': '숨김',
    'deleted': '삭제됨',
  };

  Future<void> _changeStatus(BuildContext context, ProductItem product, String status) async {
    final result = await DuckAuctionStore.updateProductStatus(product, status);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!DuckAuctionStore.isMasterAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('상품 상태 변경')),
        body: const Center(child: Text('master 계정에서만 사용할 수 있어요.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('상품 상태 변경'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: () async {
              final result = await DuckAuctionStore.refreshProductsNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.registeredAuctions,
        builder: (context, products, _) {
          if (products.isEmpty) {
            return const Center(child: Text('변경할 상품이 없어요. 먼저 상품을 새로고침하거나 샘플을 생성해 주세요.'));
          }

          final sorted = [...products]
            ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final product = sorted[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(width: 52, height: 52, child: ProductPhoto(product: product, fontSize: 28)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text('현재 ${product.statusLabel} · ${product.price} · 입찰 ${product.bids}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statuses.entries.map((entry) {
                        final selected = product.effectiveStatus == entry.key;
                        return ChoiceChip(
                          label: Text(entry.value),
                          selected: selected,
                          onSelected: selected ? null : (_) => _changeStatus(context, product, entry.key),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class AdminReportManagementScreen extends StatelessWidget {
  const AdminReportManagementScreen({super.key});

  Future<void> _runAction(BuildContext context, Map<String, dynamic> report, String action) async {
    final reportId = (report['id'] as String?) ?? '';
    final productId = (report['productId'] as String?) ?? '';
    if (reportId.isEmpty || productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고 또는 상품 정보를 확인할 수 없어요.')),
      );
      return;
    }

    final result = await DuckAuctionStore.handleReportAdminAction(
      reportId: reportId,
      productId: productId,
      action: action,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  String _formatTime(Object? raw) {
    DateTime? value;
    if (raw is Timestamp) value = raw.toDate();
    if (raw is String) value = DateTime.tryParse(raw);
    if (value == null) return '시간 정보 없음';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month.$day $hour:$minute';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'waiting':
        return const Color(0xFFF97316);
      case 'reviewing':
        return const Color(0xFF2563EB);
      case 'complete':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF334155);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting':
        return '접수';
      case 'reviewing':
        return '검토중';
      case 'complete':
        return '처리완료';
      case 'rejected':
        return '기각';
      default:
        return '확인필요';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DuckAuctionStore.isMasterAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('신고 관리')),
        body: const Center(child: Text('master 계정에서만 사용할 수 있어요.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('신고 관리')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('신고 목록을 불러오지 못했어요.'));
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('접수된 신고가 없어요.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return const _ReportGuideCard();
              final doc = docs[index - 1];
              final data = <String, dynamic>{...doc.data(), 'id': doc.id};
              final status = (data['status'] as String?) ?? 'waiting';
              final productTitle = (data['productTitle'] as String?) ?? '상품명 없음';
              final reason = (data['reason'] as String?) ?? '사유 없음';
              final detail = (data['detail'] as String?) ?? '';
              final reporter = (data['reporterEmail'] as String?) ?? (data['reporterUid'] as String?) ?? '신고자 정보 없음';
              final seller = (data['sellerName'] as String?) ?? (data['sellerUid'] as String?) ?? '판매자 정보 없음';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(productTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('사유: $reason', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (detail.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('상세: $detail', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 6),
                    Text('판매자: $seller', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                    Text('신고자: $reporter', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                    Text('접수: ${_formatTime(data['createdAt'])}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(onPressed: () => _runAction(context, data, 'reviewing'), child: const Text('검토중')),
                        OutlinedButton(onPressed: () => _runAction(context, data, 'rejected'), child: const Text('기각')),
                        FilledButton(onPressed: () => _runAction(context, data, 'hidden'), child: const Text('상품 숨김')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                          onPressed: () => _runAction(context, data, 'deleted'),
                          child: const Text('경매 삭제'),
                        ),
                        OutlinedButton(onPressed: () => _runAction(context, data, 'seller_warning'), child: const Text('판매자 경고')),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportGuideCard extends StatelessWidget {
  const _ReportGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Text(
        '신고는 Firestore reports 컬렉션에 저장돼요.\n'
        '메일 발송은 나중에 Firebase Functions로 연결하면 안전합니다.\n'
        '3건 이상은 주의, 5건 이상은 검토 필요, 10건 이상은 자동 숨김 후보 기준으로 운영하면 좋아요.',
        style: TextStyle(color: Color(0xFF92400E), height: 1.45, fontWeight: FontWeight.w700),
      ),
    );
  }
}


class AdminReviewWriteHubScreen extends StatelessWidget {
  const AdminReviewWriteHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!DuckAuctionStore.isMasterAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('테스트 후기 남기기')),
        body: const Center(child: Text('master 계정에서만 사용할 수 있어요.')),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('테스트 후기 남기기')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('경매를 불러오지 못했어요.\n${snapshot.error}', textAlign: TextAlign.center));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final products = snapshot.data!.docs.map(ProductItem.fromFirestore).toList();
          if (products.isEmpty) return const Center(child: Text('등록된 경매가 없어요.'));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final sellerUid = (product.sellerId ?? '').trim();
              final buyerUid = (product.lastBidUserId ?? '').trim();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 54, height: 54, child: ProductPhoto(product: product, fontSize: 28))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('${product.statusLabel} · ${product.price}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: sellerUid.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminDirectReviewWriteScreen(product: product, recipientUid: sellerUid, recipientName: product.sellerName, type: 'sale'))),
                      child: const Text('판매자에게 후기'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(
                      onPressed: buyerUid.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminDirectReviewWriteScreen(product: product, recipientUid: buyerUid, recipientName: '구매자', type: 'purchase'))),
                      child: const Text('구매자에게 후기'),
                    )),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminDirectReviewWriteScreen extends StatefulWidget {
  final ProductItem product;
  final String recipientUid;
  final String recipientName;
  final String type;

  const AdminDirectReviewWriteScreen({
    super.key,
    required this.product,
    required this.recipientUid,
    required this.recipientName,
    required this.type,
  });

  @override
  State<AdminDirectReviewWriteScreen> createState() => _AdminDirectReviewWriteScreenState();
}

class _AdminDirectReviewWriteScreenState extends State<AdminDirectReviewWriteScreen> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ReviewService.createAdminReview(
        product: widget.product,
        recipientUid: widget.recipientUid,
        recipientName: widget.recipientName,
        type: widget.type,
        rating: _rating,
        content: _controller.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('테스트 후기를 등록했어요.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('테스트 후기 작성')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.product.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('${widget.recipientName}님에게 ${widget.type == 'sale' ? '판매 후기' : '구매 후기'}를 남겨요.', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 22),
        const Text('오리 평점', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) {
          final value = index + 1;
          return InkWell(
            onTap: () => setState(() => _rating = value),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Opacity(opacity: value <= _rating ? 1 : 0.25, child: const Text('🐥', style: TextStyle(fontSize: 30))),
            ),
          );
        })),
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          maxLength: 500,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(labelText: '후기 내용', hintText: '테스트용 후기 내용을 입력하세요.', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: const Color(0xFFE91E63)),
          child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('후기 등록'),
        ),
      ]),
    );
  }
}

class AdminPaymentScenarioScreen extends StatefulWidget {
  const AdminPaymentScenarioScreen({super.key});

  @override
  State<AdminPaymentScenarioScreen> createState() => _AdminPaymentScenarioScreenState();
}

class _AdminPaymentScenarioScreenState extends State<AdminPaymentScenarioScreen> {
  int _reloadVersion = 0;

  Future<List<ProductItem>> _loadScenarioProducts() async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid == null || userUid.isEmpty) return const <ProductItem>[];

    final productSnapshot = await FirebaseFirestore.instance.collection('products').get();
    final products = productSnapshot.docs.map(ProductItem.fromFirestore).toList();
    final bidProductIds = <String>{};

    await Future.wait(productSnapshot.docs.map((productDoc) async {
      final product = ProductItem.fromFirestore(productDoc);
      if (product.sellerId == userUid || product.lastBidUserId == userUid) return;
      try {
        final bidSnapshot = await productDoc.reference
            .collection('bids')
            .where('userId', isEqualTo: userUid)
            .limit(1)
            .get();
        if (bidSnapshot.docs.isNotEmpty) bidProductIds.add(productDoc.id);
      } catch (_) {
        // 해당 경매의 입찰 이력 권한이 없으면 판매자/최고 입찰자 기준으로만 표시해요.
      }
    }));

    final result = <ProductItem>[];
    for (final product in products) {
      final id = (product.id ?? '').trim();
      final hasBidHistory = id.isNotEmpty && bidProductIds.contains(id);
      final isMine = product.sellerId == userUid || product.lastBidUserId == userUid || hasBidHistory;
      if (!isMine) continue;

      if (hasBidHistory && product.lastBidUserId != userUid) {
        result.add(product.copyWith(lastBidUserId: userUid));
      } else {
        result.add(product);
      }
    }

    result.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return result;
  }

  Future<void> _runScenario(BuildContext context, ProductItem product, String scenario) async {
    final result = await DuckAuctionStore.runPaymentTestScenario(product, scenario);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success && mounted) setState(() => _reloadVersion++);
  }

  Future<void> _refresh() async {
    final result = await DuckAuctionStore.refreshProductsNow();
    if (!mounted) return;
    setState(() => _reloadVersion++);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!DuckAuctionStore.isMasterAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('결제/낙찰 시나리오')),
        body: const Center(child: Text('master 계정에서만 사용할 수 있어요.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('결제/낙찰 시나리오'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<ProductItem>>(
        key: ValueKey(_reloadVersion),
        future: _loadScenarioProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('테스트할 경매를 불러오지 못했어요.\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final products = snapshot.data!;
          if (products.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '내가 등록했거나 입찰한 경매가 없어요.\n경매에 입찰한 뒤 새로고침해 주세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: products.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return const _PaymentScenarioGuideCard();
              final product = products[index - 1];
              return _PaymentScenarioProductCard(
                product: product,
                onRun: (scenario) => _runScenario(context, product, scenario),
              );
            },
          );
        },
      ),
    );
  }
}

class _PaymentScenarioGuideCard extends StatelessWidget {
  const _PaymentScenarioGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Text(
        '실제 결제 API 전 단계에서 쓰는 관리자 테스트 메뉴예요.\n'
        '1순위 24시간 결제대기, 미결제 시 2/3순위 승계, 전원 미결제 유찰, 배송/거래완료 상태를 버튼으로 바로 재현할 수 있어요.',
        style: TextStyle(color: Color(0xFF92400E), height: 1.45, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PaymentScenarioProductCard extends StatelessWidget {
  final ProductItem product;
  final ValueChanged<String> onRun;

  const _PaymentScenarioProductCard({
    required this.product,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final bidCount = DuckAuctionStore.parseCount(product.bids);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 52, height: 52, child: ProductPhoto(product: product, fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${product.statusLabel} · ${product.price} · 입찰 $bidCount명', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ScenarioGroup(
            title: '낙찰/결제대기',
            children: [
              _ScenarioChip(label: '1순위 결제대기 24시간', onTap: () => onRun('winner_pending')),
              _ScenarioChip(label: '1순위 결제완료', onTap: () => onRun('winner_paid')),
              _ScenarioChip(label: '1순위 포기→2순위/유찰', onTap: () => onRun('winner_abandoned_to_second')),
              _ScenarioChip(label: '1순위 24시간 경과', onTap: () => onRun('winner_timeout')),
            ],
          ),
          _ScenarioGroup(
            title: '차순위 승계',
            children: [
              _ScenarioChip(label: '2순위 결제완료', onTap: () => onRun('second_paid')),
              _ScenarioChip(label: '2순위 포기→3순위/유찰', onTap: () => onRun('second_abandoned_to_third')),
              _ScenarioChip(label: '2순위 12시간 경과', onTap: () => onRun('second_timeout')),
              _ScenarioChip(label: '3순위 결제완료', onTap: () => onRun('third_paid')),
              _ScenarioChip(label: '3순위 12시간 경과→유찰', onTap: () => onRun('third_timeout')),
            ],
          ),
          _ScenarioGroup(
            title: '유찰/판매자 처리',
            children: [
              _ScenarioChip(label: '입찰자 없는 유찰', onTap: () => onRun('no_bid_failed')),
              _ScenarioChip(label: '전원 미결제→유찰', onTap: () => onRun('all_failed')),
              _ScenarioChip(label: '판매자 연장 테스트', onTap: () => onRun('seller_extend')),
            ],
          ),
          _ScenarioGroup(
            title: '거래 진행',
            children: [
              _ScenarioChip(label: '결제완료', onTap: () => onRun('paid')),
              _ScenarioChip(label: '배송중', onTap: () => onRun('shipped')),
              _ScenarioChip(label: '거래완료', onTap: () => onRun('completed')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ScenarioGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _ScenarioChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ScenarioChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      backgroundColor: Colors.white,
    );
  }
}

class ChatRoomListScreen extends StatelessWidget {
  const ChatRoomListScreen({super.key});

  String _timeText(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate();
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      return '${date.hour >= 12 ? '오후' : '오전'} $hour:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}.${date.day}';
  }

  ProductItem _productFromRoom(Map<String, dynamic> data) {
    final price = (data['productPrice'] as String?) ?? '가격 정보 없음';
    return ProductItem(
      id: data['productId'] as String?,
      title: (data['productTitle'] as String?) ?? '삭제된 경매',
      category: (data['productCategory'] as String?) ?? '기타',
      price: price,
      bids: (data['productBids'] as String?) ?? '0명',
      time: (data['productTime'] as String?) ?? '',
      imageEmoji: '🐥',
      imageUrl: data['productImageUrl'] as String?,
      coverImageUrl: data['productImageUrl'] as String?,
      likes: '0',
      sellerId: data['sellerUid'] as String?,
      sellerName: (data['sellerName'] as String?) ?? '판매자',
      sellerSalesCount: 0,
      status: (data['productStatus'] as String?) ?? 'active',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: _LoginRequiredContent(
          icon: Icons.chat_bubble_outline,
          title: '채팅은 로그인 후 이용할 수 있어요',
          description: '로그인하면 판매자와 실시간으로 대화할 수 있어요.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('채팅', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chatRooms')
            .where('participants', arrayContains: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _PlaceholderContent(
              icon: Icons.error_outline,
              title: '채팅 목록을 불러오지 못했어요',
              description: '잠시 후 다시 시도해 주세요.',
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final at = a.data()['updatedAt'];
              final bt = b.data()['updatedAt'];
              final ad = at is Timestamp ? at.millisecondsSinceEpoch : 0;
              final bd = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
              return bd.compareTo(ad);
            });
          if (docs.isEmpty) {
            return const _PlaceholderContent(
              icon: Icons.forum_outlined,
              title: '아직 채팅이 없어요',
              description: '경매 상세에서 판매자에게 문의하면 이곳에 채팅방이 표시돼요.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final sellerUid = data['sellerUid'] as String?;
              final isSeller = sellerUid == user.uid;
              final otherName = isSeller
                  ? ((data['buyerName'] as String?) ?? '구매자')
                  : ((data['sellerName'] as String?) ?? '판매자');
              final unreadMap = Map<String, dynamic>.from((data['unreadCounts'] as Map?) ?? const {});
              final unread = (unreadMap[user.uid] as num?)?.toInt() ?? 0;
              final imageUrl = data['productImageUrl'] as String?;
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SellerChatScreen(
                        product: _productFromRoom(data),
                        roomIdOverride: doc.id,
                        otherUserName: otherName,
                      ),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 58,
                        height: 58,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: const Color(0xFFF4F5F8), borderRadius: BorderRadius.circular(15)),
                        child: (imageUrl ?? '').isNotEmpty
                            ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🐥', style: TextStyle(fontSize: 28))))
                            : const Center(child: Text('🐥', style: TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                          Text(_timeText(data['updatedAt']), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ]),
                        const SizedBox(height: 3),
                        Text((data['productTitle'] as String?) ?? '경매', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Row(children: [
                          Expanded(child: Text((data['lastMessage'] as String?) ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF475569)))),
                          if (unread > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: const BoxDecoration(color: Color(0xFFE91E63), borderRadius: BorderRadius.all(Radius.circular(999))),
                              child: Text(unread > 99 ? '99+' : '$unread', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ]),
                      ])),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SellerChatScreen extends StatefulWidget {
  final ProductItem product;
  final String? roomIdOverride;
  final String? otherUserName;

  const SellerChatScreen({
    super.key,
    required this.product,
    this.roomIdOverride,
    this.otherUserName,
  });

  @override
  State<SellerChatScreen> createState() => _SellerChatScreenState();
}

class _SellerChatScreenState extends State<SellerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _sending = false;
  bool _uploadingImage = false;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get _sellerUid => widget.product.sellerId;

  String? get _roomId {
    if ((widget.roomIdOverride ?? '').isNotEmpty) return widget.roomIdOverride;
    final productId = widget.product.id;
    final buyerUid = _currentUid;
    final sellerUid = _sellerUid;
    if (productId == null || productId.isEmpty || buyerUid == null || sellerUid == null || sellerUid.isEmpty) return null;
    final users = [buyerUid, sellerUid]..sort();
    return '${productId}_${users.join('_')}';
  }

  CollectionReference<Map<String, dynamic>>? get _messagesRef {
    final roomId = _roomId;
    if (roomId == null) return null;
    return FirebaseFirestore.instance.collection('chatRooms').doc(roomId).collection('messages');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRoomRead());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markRoomRead() async {
    final roomId = _roomId;
    final uid = _currentUid;
    if (roomId == null || uid == null) return;
    final roomRef = FirebaseFirestore.instance.collection('chatRooms').doc(roomId);
    try {
      final roomSnapshot = await roomRef.get();
      final roomData = roomSnapshot.data() ?? const <String, dynamic>{};
      final unreadCounts = Map<String, dynamic>.from((roomData['unreadCounts'] as Map?) ?? const {});
      unreadCounts[uid] = 0;
      final lastReadAt = Map<String, dynamic>.from((roomData['lastReadAt'] as Map?) ?? const {});
      lastReadAt[uid] = FieldValue.serverTimestamp();
      await roomRef.set({'unreadCounts': unreadCounts, 'lastReadAt': lastReadAt}, SetOptions(merge: true));
      final recent = await roomRef.collection('messages').limit(100).get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in recent.docs) {
        if (doc.data()['senderUid'] == uid) continue;
        final readBy = (doc.data()['readBy'] as List?)?.whereType<String>().toList() ?? <String>[];
        if (!readBy.contains(uid)) batch.update(doc.reference, {'readBy': FieldValue.arrayUnion([uid])});
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _currentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const {};
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.data() ?? const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _ensureRoom({required String preview, required String type}) async {
    final roomId = _roomId;
    final senderUid = _currentUid;
    final sellerUid = _sellerUid;
    if (roomId == null || senderUid == null || sellerUid == null) return;
    final profile = await _currentUserProfile();
    final currentName = ((profile['nickname'] as String?) ?? FirebaseAuth.instance.currentUser?.displayName ?? '덕친').trim();
    final isSeller = senderUid == sellerUid;
    final roomRef = FirebaseFirestore.instance.collection('chatRooms').doc(roomId);
    final roomSnapshot = await roomRef.get();
    final existing = roomSnapshot.data() ?? const <String, dynamic>{};
    final participants = <String>{senderUid, sellerUid, ...((existing['participants'] as List?)?.whereType<String>() ?? const <String>[])}.toList();
    final otherUid = participants.firstWhere((id) => id != senderUid, orElse: () => sellerUid);
    final unread = Map<String, dynamic>.from((existing['unreadCounts'] as Map?) ?? const {});
    unread[senderUid] = 0;
    unread[otherUid] = ((unread[otherUid] as num?)?.toInt() ?? 0) + 1;
    await roomRef.set({
      'productId': widget.product.id,
      'productTitle': widget.product.title,
      'productImageUrl': widget.product.resolvedCoverImageUrl,
      'productPrice': widget.product.price,
      'productBids': widget.product.bids,
      'productTime': widget.product.time,
      'productCategory': widget.product.category,
      'productStatus': widget.product.status,
      'sellerUid': sellerUid,
      'sellerName': isSeller ? currentName : widget.product.sellerName,
      if (!isSeller) 'buyerUid': senderUid,
      if (!isSeller) 'buyerName': currentName,
      'participants': participants,
      'lastMessage': preview,
      'lastMessageType': type,
      'lastSenderUid': senderUid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!roomSnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      'unreadCounts': unread,
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    final messagesRef = _messagesRef;
    final senderUid = _currentUid;
    if (message.isEmpty || messagesRef == null || senderUid == null) return;
    setState(() => _sending = true);
    try {
      await _ensureRoom(preview: message, type: 'text');
      await messagesRef.add({'text': message, 'senderUid': senderUid, 'createdAt': FieldValue.serverTimestamp(), 'readBy': [senderUid], 'type': 'text'});
      _messageController.clear();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) _scrollController.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('메시지를 보내지 못했어요: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final roomId = _roomId;
    final senderUid = _currentUid;
    final messagesRef = _messagesRef;
    if (roomId == null || senderUid == null || messagesRef == null || _uploadingImage) return;
    final image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1600);
    if (image == null) return;
    setState(() => _uploadingImage = true);
    try {
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref('chat_images/$roomId/$fileName');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await _ensureRoom(preview: '사진을 보냈어요.', type: 'image');
      await messagesRef.add({'text': '', 'imageUrl': url, 'senderUid': senderUid, 'createdAt': FieldValue.serverTimestamp(), 'readBy': [senderUid], 'type': 'image'});
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사진을 보내지 못했어요: $error')));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _reportChat() async {
    final roomId = _roomId;
    final uid = _currentUid;
    if (roomId == null || uid == null) return;
    String reason = '욕설/비방';
    final detail = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('채팅 신고', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: reason,
            decoration: const InputDecoration(labelText: '신고 사유', border: OutlineInputBorder()),
            items: const ['욕설/비방', '사기 의심', '개인정보 요구', '불법 거래', '스팸/광고', '기타'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setSheetState(() => reason = value ?? reason),
          ),
          const SizedBox(height: 12),
          TextField(controller: detail, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '상세 내용', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(sheetContext, true), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: const Color(0xFFEF4444)), child: const Text('신고 접수')),
        ]),
      )),
    );
    if (result == true) {
      await FirebaseFirestore.instance.collection('reports').add({
        'type': 'chat', 'chatRoomId': roomId, 'reporterUid': uid, 'reason': reason, 'detail': detail.text.trim(), 'status': 'received', 'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('채팅 신고가 접수됐어요.')));
    }
    detail.dispose();
  }

  String _messageTime(dynamic value) {
    if (value is! Timestamp) return '';
    final d = value.toDate();
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    return '${d.hour >= 12 ? '오후' : '오전'} $hour:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final currentUid = _currentUid;
    final sellerUid = _sellerUid;
    final messagesRef = _messagesRef;
    if (currentUid == null) return const Scaffold(body: _LoginRequiredContent(icon: Icons.chat_bubble_outline, title: '채팅은 로그인 후 이용할 수 있어요', description: '로그인하면 판매자에게 경매 문의를 보낼 수 있어요.'));
    if (sellerUid == null || sellerUid.isEmpty || product.id == null || messagesRef == null) return const Scaffold(body: _PlaceholderContent(icon: Icons.chat_bubble_outline, title: '채팅을 시작할 수 없어요', description: '테스트 경매이거나 판매자 정보가 없는 경매예요.'));
    final isSeller = currentUid == sellerUid;
    if (isSeller && widget.roomIdOverride == null) return const Scaffold(body: _PlaceholderContent(icon: Icons.info_outline, title: '내 경매에는 문의할 수 없어요', description: '다른 사용자가 보낸 문의는 마이페이지의 채팅에서 확인할 수 있어요.'));

    final titleName = widget.otherUserName ?? (isSeller ? '구매자' : product.sellerName);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titleName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          Text(product.title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ]),
        actions: [IconButton(onPressed: _reportChat, icon: const Icon(Icons.flag_outlined), tooltip: '채팅 신고')],
      ),
      body: Column(children: [
        InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF4F5F8), borderRadius: BorderRadius.circular(14)), clipBehavior: Clip.antiAlias, child: ProductPhoto(product: product, fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('현재가 ${product.price} · ${product.time}', style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w700)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ]),
          ),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: messagesRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData) WidgetsBinding.instance.addPostFrameCallback((_) => _markRoomRead());
            if (snapshot.hasError) return const Center(child: Text('채팅을 불러오지 못했어요.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const _PlaceholderContent(icon: Icons.waving_hand_outlined, title: '첫 메시지를 보내보세요', description: '경매 상태나 배송 방법처럼 궁금한 내용을 물어볼 수 있어요.');
            return ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final isMe = data['senderUid'] == currentUid;
                final type = (data['type'] as String?) ?? 'text';
                final readBy = (data['readBy'] as List?)?.whereType<String>().toList() ?? <String>[];
                final isRead = readBy.any((id) => id != currentUid);
                Widget content;
                if (type == 'image' && ((data['imageUrl'] as String?) ?? '').isNotEmpty) {
                  content = ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(data['imageUrl'] as String, width: 210, height: 210, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 180, height: 80, child: Center(child: Text('사진을 불러오지 못했어요.')))),
                  );
                } else if (type == 'system') {
                  return Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)), child: Text((data['text'] as String?) ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700))));
                } else {
                  content = Text((data['text'] as String?) ?? '', style: const TextStyle(height: 1.35, fontWeight: FontWeight.w600));
                }
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (isMe) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [if (!isRead) const Text('1', style: TextStyle(fontSize: 10, color: Color(0xFFE91E63), fontWeight: FontWeight.w900)), Text(_messageTime(data['createdAt']), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))]),
                      if (isMe) const SizedBox(width: 5),
                      Container(
                        padding: type == 'image' ? const EdgeInsets.all(3) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(color: isMe ? const Color(0xFFFFF1F5) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: isMe ? const Color(0xFFFFC2D0) : const Color(0xFFE5E7EB))),
                        child: content,
                      ),
                      if (!isMe) const SizedBox(width: 5),
                      if (!isMe) Text(_messageTime(data['createdAt']), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ]),
                  ),
                );
              },
            );
          },
        )),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 14),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
          child: SafeArea(top: false, child: Row(children: [
            IconButton(onPressed: _uploadingImage ? null : _sendImage, icon: _uploadingImage ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_photo_alternate_outlined), tooltip: '사진 보내기'),
            Expanded(child: TextField(controller: _messageController, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendMessage(), decoration: InputDecoration(hintText: '메시지를 입력하세요', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16))),),
            const SizedBox(width: 8),
            IconButton.filled(style: IconButton.styleFrom(backgroundColor: const Color(0xFF334155), foregroundColor: Colors.white), onPressed: _sending ? null : _sendMessage, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded)),
          ])),
        ),
      ]),
    );
  }
}

class _PlaceholderContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PlaceholderContent({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFF334155)),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4B5563), height: 1.4, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}


class _LoginRequiredContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _LoginRequiredContent({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('로그인 / 회원가입하기', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: const Color(0xFF334155)),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class MyAuctionManageScreen extends StatelessWidget {
  const MyAuctionManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('내 경매 관리'),
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.registeredAuctions,
        builder: (context, products, _) {
          final myProducts = products
              .where((product) => user != null && product.sellerId == user.uid)
              .toList()
            ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

          if (myProducts.isEmpty) {
            return _MyEmptyList(
              icon: Icons.receipt_long_outlined,
              title: '등록한 경매가 없어요',
              description: '경매를 등록하면 여기에서 수정하고 관리할 수 있어요.',
              buttonText: '경매 등록하기',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuctionRegisterScreen()),
                );
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: myProducts.length,
            itemBuilder: (context, index) {
              final product = myProducts[index];
              final hasBid = DuckAuctionStore.parseCount(product.bids) > 0;
              final isFailed = product.effectiveStatus == 'failed';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    ProductListTile(product: product),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: isFailed
                          ? Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final result = await DuckAuctionStore.extendFailedAuction(product);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(result.message)),
                                      );
                                    },
                                    icon: const Icon(Icons.update_rounded, size: 18),
                                    label: const Text('경매 연장'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF334155), foregroundColor: Colors.white),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => AuctionRegisterScreen(editProduct: product, registerAsNew: true)),
                                      );
                                    },
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                    label: const Text('새로 등록'),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: hasBid
                                        ? null
                                        : () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(builder: (_) => AuctionRegisterScreen(editProduct: product)),
                                            );
                                          },
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: Text(hasBid ? '입찰 있음 · 수정 불가' : '수정하기'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                                      );
                                    },
                                    icon: const Icon(Icons.visibility_outlined, size: 18),
                                    label: const Text('경매 상세'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


const List<Map<String, String>> kSellerBadgeOptions = [
  {'id': 'new_seller', 'label': '새싹 판매자', 'emoji': '🌱'},
  {'id': 'first_sale', 'label': '첫 판매 완료', 'emoji': '🏅'},
  {'id': 'sales_10', 'label': '판매 10회 달성', 'emoji': '📦'},
  {'id': 'sales_50', 'label': '판매 50회 달성', 'emoji': '🏆'},
  {'id': 'fast_shipping', 'label': '빠른 배송 판매자', 'emoji': '🚚'},
  {'id': 'fast_reply', 'label': '응답 우수 판매자', 'emoji': '💬'},
  {'id': 'honest_seller', 'label': '정직한 판매자', 'emoji': '🛡️'},
  {'id': 'review_star', 'label': '후기 우수 판매자', 'emoji': '⭐'},
  {'id': 'popular_seller', 'label': '인기 판매자', 'emoji': '💎'},
  {'id': 'veteran_seller', 'label': '베테랑 판매자', 'emoji': '👑'},
];

String sellerBadgeLabel(String id) {
  for (final badge in kSellerBadgeOptions) {
    if (badge['id'] == id) return '${badge['emoji']} ${badge['label']}';
  }
  return id;
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nicknameController = TextEditingController();
  final _introController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final Set<String> _selectedBadges = <String>{};
  Uint8List? _newImageBytes;
  String? _profileImageUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      _nicknameController.text = (data['nickname'] as String?)?.trim().isNotEmpty == true
          ? (data['nickname'] as String).trim()
          : (user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : '덕친');
      _introController.text = (data['sellerIntro'] as String?) ?? '';
      _profileImageUrl = data['profileImageUrl'] as String?;
      final badges = (data['sellerBadges'] as List?)?.whereType<String>().take(3) ?? const <String>[];
      _selectedBadges.addAll(badges);
    } catch (_) {
      _nicknameController.text = user.displayName ?? '덕친';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 900);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => _newImageBytes = bytes);
  }

  void _toggleBadge(String id) {
    setState(() {
      if (_selectedBadges.contains(id)) {
        _selectedBadges.remove(id);
      } else if (_selectedBadges.length < 3) {
        _selectedBadges.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('판매자 배지는 최대 3개까지 선택할 수 있어요.')));
      }
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _saving) return;
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      var imageUrl = _profileImageUrl;
      if (_newImageBytes != null) {
        final ref = FirebaseStorage.instance.ref('profile_images/${user.uid}/profile.jpg');
        await ref.putData(_newImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await ref.getDownloadURL();
      }
      final intro = _introController.text.trim();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'nickname': nickname,
        'profileImageUrl': imageUrl,
        'sellerIntro': intro,
        'sellerBadges': _selectedBadges.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.updateDisplayName(nickname);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필을 저장했어요.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('프로필 저장에 실패했어요: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _avatar() {
    if (_newImageBytes != null) return Image.memory(_newImageBytes!, fit: BoxFit.cover);
    if ((_profileImageUrl ?? '').isNotEmpty) {
      return Image.network(_profileImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🐥', style: TextStyle(fontSize: 48))));
    }
    return const Center(child: Text('🐥', style: TextStyle(fontSize: 48)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('프로필 수정')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF1F5F9), border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 16)]),
                        child: _avatar(),
                      ),
                      Positioned(
                        right: -2,
                        bottom: 2,
                        child: Material(
                          color: const Color(0xFF334155),
                          shape: const CircleBorder(),
                          child: IconButton(onPressed: _pickImage, icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(controller: _nicknameController, maxLength: 20, decoration: const InputDecoration(labelText: '닉네임', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                  controller: _introController,
                  maxLength: 120,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '판매자 소개',
                    hintText: '미작성 시 “안녕하세요! 좋은 거래 약속드릴게요 😊”가 표시돼요.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Text('판매자 배지', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                  Text('${_selectedBadges.length}/3', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                const Text('모든 계정에서 아래 배지 중 최대 3개를 선택할 수 있어요.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kSellerBadgeOptions.map((badge) {
                    final id = badge['id']!;
                    final selected = _selectedBadges.contains(id);
                    return FilterChip(
                      selected: selected,
                      onSelected: (_) => _toggleBadge(id),
                      avatar: Text(badge['emoji']!),
                      label: Text(badge['label']!),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: const Color(0xFF334155)),
                  child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('저장하기'),
                ),
              ],
            ),
    );
  }
}

class ReviewRecord {
  final String id;
  final String productId;
  final String productTitle;
  final String authorUid;
  final String authorName;
  final String recipientUid;
  final String recipientName;
  final String type;
  final int rating;
  final String content;
  final List<String> imageUrls;
  final DateTime? createdAt;
  final bool hidden;

  const ReviewRecord({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.authorUid,
    required this.authorName,
    required this.recipientUid,
    required this.recipientName,
    required this.type,
    required this.rating,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    required this.hidden,
  });

  factory ReviewRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    return ReviewRecord(
      id: doc.id,
      productId: (data['productId'] as String?) ?? '',
      productTitle: (data['productTitle'] as String?) ?? '경매',
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '덕친',
      recipientUid: (data['recipientUid'] as String?) ?? '',
      recipientName: (data['recipientName'] as String?) ?? '덕친',
      type: (data['type'] as String?) ?? 'sale',
      rating: ((data['rating'] as num?)?.toInt().clamp(1, 5) ?? 5).toInt(),
      content: (data['content'] as String?) ?? '',
      imageUrls: (data['imageUrls'] as List?)?.whereType<String>().toList() ?? const <String>[],
      createdAt: created is Timestamp ? created.toDate() : null,
      hidden: data['hidden'] == true,
    );
  }
}

class ReviewService {
  static CollectionReference<Map<String, dynamic>> get _reviews => FirebaseFirestore.instance.collection('reviews');

  static String reviewIdFor(String productId, String authorUid) => '${productId}_$authorUid';

  static Future<String> displayNameFor(String uid, {String fallback = '덕친'}) async {
    if (uid.isEmpty) return fallback;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = (doc.data()?['nickname'] as String?)?.trim();
    return (name == null || name.isEmpty) ? fallback : name;
  }

  static Future<void> createReview({
    required ProductItem product,
    required int rating,
    required String content,
    required List<XFile> images,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) throw StateError('로그인이 필요해요.');
    if (rating < 1 || rating > 5) throw StateError('오리 평점을 선택해 주세요.');
    final trimmedContent = content.trim();
    if (rating == 1 && trimmedContent.length < 20) {
      throw StateError('1오리 후기는 상세 내용을 20자 이상 작성해 주세요.');
    }
    if (rating == 2 && trimmedContent.length < 15) {
      throw StateError('2오리 후기는 상세 내용을 15자 이상 작성해 주세요.');
    }
    if (product.effectiveStatus != 'completed') throw StateError('거래완료된 경매만 후기를 작성할 수 있어요.');
    final productId = product.id ?? '';
    if (productId.isEmpty) throw StateError('경매 정보를 확인할 수 없어요.');

    final isSeller = product.sellerId == user.uid;
    final isBuyer = product.lastBidUserId == user.uid;
    if (!isSeller && !isBuyer) throw StateError('거래 당사자만 후기를 작성할 수 있어요.');

    final recipientUid = isSeller ? (product.lastBidUserId ?? '') : (product.sellerId ?? '');
    if (recipientUid.isEmpty || recipientUid == user.uid) throw StateError('후기 대상자를 확인할 수 없어요.');
    final reviewId = reviewIdFor(productId, user.uid);
    final existing = await _reviews.doc(reviewId).get();
    if (existing.exists) throw StateError('이미 이 거래에 대한 후기를 작성했어요.');

    final authorName = await displayNameFor(user.uid, fallback: user.displayName ?? '덕친');
    final recipientName = await displayNameFor(
      recipientUid,
      fallback: isSeller ? '구매자' : product.sellerName,
    );

    final urls = <String>[];
    for (var i = 0; i < images.length && i < 3; i++) {
      final bytes = await images[i].readAsBytes();
      final ref = FirebaseStorage.instance.ref('review_images/$reviewId/$i.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }

    await _reviews.doc(reviewId).set({
      'reviewId': reviewId,
      'productId': productId,
      'productTitle': product.title,
      'authorUid': user.uid,
      'authorName': authorName,
      'recipientUid': recipientUid,
      'recipientName': recipientName,
      // 구매자가 판매자에게 남기면 판매 후기, 판매자가 구매자에게 남기면 구매 후기
      'type': isSeller ? 'purchase' : 'sale',
      'rating': rating,
      'content': trimmedContent,
      'imageUrls': urls,
      'hidden': false,
      'reportCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await recalculateRecipient(recipientUid);
  }

  static Future<void> createAdminReview({
    required ProductItem product,
    required String recipientUid,
    required String recipientName,
    required String type,
    required int rating,
    required String content,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !DuckAuctionStore.isMasterAdmin) {
      throw StateError('master 계정에서만 테스트 후기를 작성할 수 있어요.');
    }
    if (recipientUid.trim().isEmpty) throw StateError('후기 대상자를 확인할 수 없어요.');
    if (rating < 1 || rating > 5) throw StateError('오리 평점을 선택해 주세요.');
    final trimmed = content.trim();
    if (rating == 1 && trimmed.length < 20) throw StateError('1오리 후기는 상세 내용을 20자 이상 작성해 주세요.');
    if (rating == 2 && trimmed.length < 15) throw StateError('2오리 후기는 상세 내용을 15자 이상 작성해 주세요.');

    final productId = (product.id ?? '').trim();
    if (productId.isEmpty) throw StateError('경매 정보를 확인할 수 없어요.');
    final reviewId = 'admin_${productId}_${recipientUid}_${DateTime.now().millisecondsSinceEpoch}';
    final authorName = await displayNameFor(user.uid, fallback: '관리자');

    await _reviews.doc(reviewId).set({
      'reviewId': reviewId,
      'productId': productId,
      'productTitle': product.title,
      'authorUid': user.uid,
      'authorName': authorName,
      'recipientUid': recipientUid,
      'recipientName': recipientName,
      'type': type,
      'rating': rating,
      'content': trimmed,
      'imageUrls': const <String>[],
      'hidden': false,
      'reportCount': 0,
      'isAdminTestReview': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await recalculateRecipient(recipientUid);
    await _writeAdminLog('테스트 후기 작성', targetId: reviewId);
  }

  static Future<void> recalculateRecipient(String recipientUid) async {
    final snapshot = await _reviews.where('recipientUid', isEqualTo: recipientUid).get();
    final visible = snapshot.docs.map(ReviewRecord.fromDoc).where((r) => !r.hidden).toList();
    final average = visible.isEmpty ? 0.0 : visible.fold<int>(0, (sum, r) => sum + r.rating) / visible.length;
    await FirebaseFirestore.instance.collection('users').doc(recipientUid).set({
      'rating': average,
      'reviewCount': visible.length,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> reportReview({
    required ReviewRecord review,
    required String reason,
    required String detail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) throw StateError('로그인이 필요해요.');
    if (user.uid == review.authorUid) throw StateError('내가 작성한 후기는 신고할 수 없어요.');
    final reportId = '${review.id}_${user.uid}';
    final ref = FirebaseFirestore.instance.collection('reviewReports').doc(reportId);
    if ((await ref.get()).exists) throw StateError('이미 신고한 후기예요.');
    await ref.set({
      'reviewId': review.id,
      'productId': review.productId,
      'reviewAuthorUid': review.authorUid,
      'reviewRecipientUid': review.recipientUid,
      'reporterUid': user.uid,
      'reason': reason,
      'detail': detail.trim(),
      'status': 'received',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('reviews').doc(review.id).set({
      'reportCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const Scaffold(body: _LoginRequiredContent(icon: Icons.star_outline_rounded, title: '후기는 로그인 후 이용할 수 있어요', description: '거래완료 후 상대방에게 후기를 남길 수 있어요.'));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('후기')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('작성 가능')),
              ButtonSegment(value: 1, label: Text('받은 후기')),
              ButtonSegment(value: 2, label: Text('작성한 후기')),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => setState(() => _tab = value.first),
            showSelectedIcon: false,
          ),
        ),
        Expanded(child: _tab == 0 ? _ReviewableTrades(userUid: user.uid) : _MyReviewList(userUid: user.uid, received: _tab == 1)),
      ]),
    );
  }
}

class _ReviewableTrades extends StatelessWidget {
  final String userUid;
  const _ReviewableTrades({required this.userUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('products').where('status', isEqualTo: 'completed').snapshots(),
      builder: (context, productSnapshot) {
        if (productSnapshot.hasError) return const Center(child: Text('거래완료 경매를 불러오지 못했어요.'));
        if (!productSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        final products = productSnapshot.data!.docs.map(ProductItem.fromFirestore).where((p) => p.sellerId == userUid || p.lastBidUserId == userUid).toList();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('reviews').where('authorUid', isEqualTo: userUid).snapshots(),
          builder: (context, reviewSnapshot) {
            if (!reviewSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            final writtenProductIds = reviewSnapshot.data!.docs.map((d) => (d.data()['productId'] as String?) ?? '').toSet();
            final available = products.where((p) => !writtenProductIds.contains(p.id)).toList();
            if (available.isEmpty) return const _ReviewEmptyState(icon: Icons.rate_review_outlined, title: '작성 가능한 후기가 없어요', description: '거래완료된 경매가 생기면 이곳에서 후기를 작성할 수 있어요.');
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: available.length,
              itemBuilder: (context, index) {
                final product = available[index];
                final isSeller = product.sellerId == userUid;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Row(children: [
                    SizedBox(width: 66, height: 66, child: ClipRRect(borderRadius: BorderRadius.circular(14), child: ProductPhoto(product: product, fontSize: 30))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(isSeller ? '구매자에게 구매 후기를 남겨주세요.' : '판매자에게 판매 후기를 남겨주세요.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700)),
                    ])),
                    FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewWriteScreen(product: product))), child: const Text('작성')),
                  ]),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MyReviewList extends StatelessWidget {
  final String userUid;
  final bool received;
  const _MyReviewList({required this.userUid, required this.received});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('reviews').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('후기를 불러오지 못했어요.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final reviews = snapshot.data!.docs.map(ReviewRecord.fromDoc).where((r) => !r.hidden && (received ? r.recipientUid == userUid : r.authorUid == userUid)).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
        if (reviews.isEmpty) return _ReviewEmptyState(icon: Icons.star_outline_rounded, title: received ? '받은 후기가 없어요' : '작성한 후기가 없어요', description: received ? '상대방이 남긴 후기가 이곳에 표시돼요.' : '내가 작성한 후기가 이곳에 표시돼요.');
        return ListView(padding: const EdgeInsets.all(16), children: reviews.map((r) => ReviewCard(review: r, showReport: false)).toList());
      },
    );
  }
}


class _ReviewEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ReviewEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF334155)),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewWriteScreen extends StatefulWidget {
  final ProductItem product;
  const ReviewWriteScreen({super.key, required this.product});

  @override
  State<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _ReviewWriteScreenState extends State<ReviewWriteScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  int _rating = 0;
  List<XFile> _images = const [];
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final selected = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1400);
    if (!mounted) return;
    if (selected.length > 3) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('후기 사진은 최대 3장까지 등록할 수 있어요.')));
    setState(() => _images = selected.take(3).toList());
  }

  String get _ratingLabel {
    switch (_rating) {
      case 1:
        return '아쉬웠어요';
      case 2:
        return '조금 아쉬웠어요';
      case 3:
        return '무난했어요';
      case 4:
        return '좋았어요';
      case 5:
        return '다시 거래하고 싶어요!';
      default:
        return '오리 평점을 선택해 주세요';
    }
  }

  bool get _isContentRequired => _rating == 1 || _rating == 2;
  int get _minimumContentLength => _rating == 1 ? 20 : (_rating == 2 ? 15 : 0);

  String get _contentHint {
    switch (_rating) {
      case 1:
        return '아쉬웠던 점을 자세히 남겨주세요. (20자 이상)';
      case 2:
        return '아쉬웠던 이유를 남겨주세요. (15자 이상)';
      case 3:
        return '거래 후기를 남겨주세요. (선택)';
      case 4:
        return '좋았던 점이 있다면 남겨주세요. (선택)';
      case 5:
        return '다시 거래하고 싶은 이유를 남겨주세요. (선택)';
      default:
        return '먼저 오리 평점을 선택해 주세요.';
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오리 평점을 선택해 주세요.')));
      return;
    }
    final content = _controller.text.trim();
    if (_isContentRequired && content.length < _minimumContentLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_rating오리 후기는 상세 내용을 $_minimumContentLength자 이상 작성해 주세요.')),
      );
      return;
    }
    bool agreed = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('후기를 등록할까요?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('후기는 등록 후 작성자가 수정하거나 삭제할 수 없습니다. 거래 상대방과 작성 내용을 다시 확인해 주세요.', style: TextStyle(height: 1.45)),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: agreed,
            onChanged: (value) => setDialogState(() => agreed = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('등록 후 수정·삭제가 불가능함을 확인했습니다.', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('다시 확인')),
          FilledButton(onPressed: agreed ? () => Navigator.pop(dialogContext, true) : null, child: const Text('등록하기')),
        ],
      )),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ReviewService.createReview(product: widget.product, rating: _rating, content: _controller.text, images: _images);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('후기를 등록했어요.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('후기 작성')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            SizedBox(width: 64, height: 64, child: ClipRRect(borderRadius: BorderRadius.circular(14), child: ProductPhoto(product: widget.product, fontSize: 28))),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.product.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
          ]),
        ),
        const SizedBox(height: 22),
        const Text('후기를 남겨주세요!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('이번 거래의 만족도를 오리 1마리부터 5마리까지 선택해 주세요.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final value = i + 1;
            final selected = value <= _rating;
            return Semantics(
              button: true,
              label: '$value오리',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _rating = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFF4C7) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? const Color(0xFFF6C344) : Colors.transparent),
                  ),
                  child: Opacity(
                    opacity: selected ? 1 : .25,
                    child: const Text('🐥', style: TextStyle(fontSize: 32)),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Text(
            _rating == 0 ? _ratingLabel : '$_rating오리 · $_ratingLabel',
            key: ValueKey(_rating),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _rating == 0 ? const Color(0xFF94A3B8) : const Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          minLines: 5,
          maxLines: 9,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: _isContentRequired ? '상세 후기 (필수)' : '상세 후기 (선택)',
            hintText: _contentHint,
            helperText: _isContentRequired ? '최소 $_minimumContentLength자 이상 작성해 주세요.' : null,
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text('사진 선택 (${_images.length}/3)'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(height: 82, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _images.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, index) => FutureBuilder<Uint8List>(future: _images[index].readAsBytes(), builder: (_, snap) => Container(width: 82, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)), child: snap.hasData ? Image.memory(snap.data!, fit: BoxFit.cover) : const Center(child: CircularProgressIndicator()))))),
        ],
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(14)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, color: Color(0xFFC2410C)), SizedBox(width: 9), Expanded(child: Text('후기는 등록 후 수정하거나 삭제할 수 없어요. 신고가 접수된 후기는 관리자 검토를 거쳐 숨김 또는 삭제될 수 있습니다.', style: TextStyle(color: Color(0xFF9A3412), height: 1.4, fontWeight: FontWeight.w700)))])),
        const SizedBox(height: 20),
        FilledButton(onPressed: _saving ? null : _submit, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: const Color(0xFFE91E63)), child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('후기 등록')),
      ]),
    );
  }
}

class ReviewCard extends StatelessWidget {
  final ReviewRecord review;
  final bool showReport;
  const ReviewCard({super.key, required this.review, this.showReport = true});

  String _date() {
    final d = review.createdAt;
    if (d == null) return '';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _report(BuildContext context) async {
    const reasons = ['욕설·비방', '개인정보 노출', '거래와 무관한 내용', '허위 사실', '광고·스팸', '기타'];
    var selected = reasons.first;
    final detail = TextEditingController();
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('후기 신고', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: reasons.map((r) => ChoiceChip(label: Text(r), selected: selected == r, onSelected: (_) => setSheetState(() => selected = r))).toList()),
          const SizedBox(height: 12),
          TextField(controller: detail, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '상세 내용 (선택)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(sheetContext, true), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('신고 접수')),
        ]),
      )),
    );
    if (submitted != true) { detail.dispose(); return; }
    try {
      await ReviewService.reportReview(review: review, reason: selected, detail: detail.text);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('후기 신고를 접수했어요.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      detail.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewer = FirebaseAuth.instance.currentUser;
    final canReport = showReport && viewer != null && !viewer.isAnonymous && viewer.uid != review.authorUid;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(review.authorName, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('${review.type == 'sale' ? '판매 후기' : '구매 후기'} · ${review.productTitle}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700))])),
          Text(List.filled(review.rating.clamp(0, 5).toInt(), '🐥').join(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          if (canReport) PopupMenuButton<String>(tooltip: '후기 메뉴', onSelected: (_) => _report(context), itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, size: 18), SizedBox(width: 8), Text('신고하기')]))]),
        ]),
        if (review.content.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(review.content, style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
        ],
        if (review.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(height: 78, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: review.imageUrls.length, separatorBuilder: (_, __) => const SizedBox(width: 7), itemBuilder: (_, index) => ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(review.imageUrls[index], width: 78, height: 78, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 78, color: const Color(0xFFE2E8F0), child: const Icon(Icons.broken_image_outlined)))))),
        ],
        if (_date().isNotEmpty) ...[const SizedBox(height: 8), Text(_date(), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))],
      ]),
    );
  }
}


class MyReportHistoryScreen extends StatelessWidget {
  const MyReportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: _LoginRequiredContent(icon: Icons.report_gmailerrorred_outlined, title: '신고내역은 로그인 후 이용할 수 있어요', description: '로그인하면 접수한 신고의 처리 상태를 확인할 수 있어요.'));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('신고내역')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('reports').where('reporterUid', isEqualTo: user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('신고내역을 불러오지 못했어요.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final at = a.data()['createdAt'];
              final bt = b.data()['createdAt'];
              final ad = at is Timestamp ? at.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              final bd = bt is Timestamp ? bt.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });
          if (docs.isEmpty) return const _PlaceholderContent(icon: Icons.report_gmailerrorred_outlined, title: '접수한 신고가 없어요', description: '경매 상세화면에서 접수한 신고의 처리 상태가 이곳에 표시돼요.');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final status = (data['status'] as String?) ?? 'received';
              final statusText = {'received':'접수','reviewing':'검토중','rejected':'기각','hidden':'처리완료','deleted':'처리완료','warned':'처리완료','complete':'처리완료'}[status] ?? '접수';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text((data['productTitle'] as String?) ?? '상품 신고', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                    Chip(label: Text(statusText)),
                  ]),
                  const SizedBox(height: 6),
                  Text((data['reason'] as String?) ?? '신고 사유 미입력', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (((data['detail'] as String?) ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text((data['detail'] as String).trim(), style: const TextStyle(color: Color(0xFF64748B), height: 1.4)),
                  ],
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class RecentViewedProductsScreen extends StatelessWidget {
  const RecentViewedProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    unawaited(DuckAuctionStore.loadRecentViewedProducts());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('최근 본 상품'),
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.recentViewedProducts,
        builder: (context, products, _) {
          if (products.isEmpty) {
            return const _MyEmptyList(
              icon: Icons.remove_red_eye_outlined,
              title: '최근 본 상품이 없어요',
              description: '경매 상세화면을 열면 최근 본 경매로 저장돼요.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: products.length,
            itemBuilder: (context, index) => ProductListTile(product: products[index]),
          );
        },
      ),
    );
  }
}

class MySettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MySettingsScreen({super.key, required this.onLogout});

  @override
  State<MySettingsScreen> createState() => _MySettingsScreenState();
}

class _MySettingsScreenState extends State<MySettingsScreen> {
  bool _pushEnabled = true;
  bool _marketingEnabled = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: '계정',
            children: [
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('이메일'),
                subtitle: Text(user?.email ?? '로그인 정보 없음'),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('닉네임'),
                subtitle: Text(user?.displayName ?? '덕친'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: '알림',
            children: [
              SwitchListTile(
                value: _pushEnabled,
                onChanged: (value) => setState(() => _pushEnabled = value),
                title: const Text('입찰/낙찰 알림'),
                subtitle: const Text('실제 푸시 연동은 알림 기능 개발 때 연결할 예정이에요.'),
              ),
              SwitchListTile(
                value: _marketingEnabled,
                onChanged: (value) => setState(() => _marketingEnabled = value),
                title: const Text('이벤트/마케팅 알림'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: '앱 정보',
            children: const [
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('버전'),
                subtitle: Text('개발중'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            onPressed: widget.onLogout,
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF334155))),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _MyEmptyList extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? buttonText;
  final VoidCallback? onPressed;

  const _MyEmptyList({
    required this.icon,
    required this.title,
    required this.description,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onPressed, child: Text(buttonText!)),
            ],
          ],
        ),
      ),
    );
  }
}
