part of '../home_screen.dart';

enum _AuctionSort { latest, deadline, priceLow, priceHigh, popular }

class AuctionTab extends StatefulWidget {
  const AuctionTab({super.key});

  @override
  State<AuctionTab> createState() => _AuctionTabState();
}

class _AuctionTabState extends State<AuctionTab> {
  static const String _categoryAll = '전체';

  String _category = _categoryAll;
  _AuctionSort _sort = _AuctionSort.latest;
  // 쿠지 카테고리를 선택했을 때만 쓰는 등급 필터예요. null이면 '전체 등급'.
  String? _kujiGrade;

  List<String> get _categoryOptions => [
        _categoryAll,
        ...AppCategories.names,
        AppCategories.etc,
      ];

  void _onCategorySelected(String value) {
    setState(() {
      _category = value;
      if (value != AppCategories.kuji) _kujiGrade = null;
    });
  }

  String _sortLabel(_AuctionSort value) {
    switch (value) {
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

  int _priceOf(ProductItem product) {
    if (product.currentPrice > 0) return product.currentPrice;
    return int.tryParse(product.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int _popularityOf(ProductItem product) {
    final bids = int.tryParse(product.bids.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final likes = int.tryParse(product.likes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return bids * 3 + likes;
  }

  List<ProductItem> _filterAndSort(List<ProductItem> products) {
    var result = _category == _categoryAll
        ? List<ProductItem>.from(products)
        : products.where((product) => product.category == _category).toList();

    if (_category == AppCategories.kuji && _kujiGrade != null) {
      result = result.where((product) => product.kujiGrade == _kujiGrade).toList();
    }

    switch (_sort) {
      case _AuctionSort.latest:
        result.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        break;
      case _AuctionSort.deadline:
        result.sort((a, b) => (a.endAt ?? DateTime(2999)).compareTo(b.endAt ?? DateTime(2999)));
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
          final allProducts = [
            ...registeredAuctions,
            ...HomeTab.popularProducts,
            ...HomeTab.recentProducts,
          ];
          final products = _filterAndSort(allProducts);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuctionFilterBar(
                category: _category,
                categoryOptions: _categoryOptions,
                onCategorySelected: _onCategorySelected,
                sortLabel: _sortLabel(_sort),
                sortMenuItems: _AuctionSort.values
                    .map((value) => PopupMenuItem(value: value, child: Text(_sortLabel(value))))
                    .toList(),
                onSortSelected: (value) => setState(() => _sort = value),
                showGradeFilter: _category == AppCategories.kuji,
                gradeLabel: _kujiGrade ?? '전체 등급',
                onGradeSelected: (value) => setState(() => _kujiGrade = value),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ResponsiveContentBounds(
                      padding: EdgeInsets.fromLTRB(context.pagePadding, 12, context.pagePadding, 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _category == _categoryAll
                                ? '전체 경매 ${products.length}개'
                                : '$_category 경매 ${products.length}개',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 10),
                          if (products.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.gavel_outlined, size: 42, color: Color(0xFFB8BBC2)),
                                  SizedBox(height: 10),
                                  Text('조건에 맞는 경매가 없어요', style: TextStyle(fontWeight: FontWeight.w900)),
                                  SizedBox(height: 5),
                                  Text('카테고리나 정렬을 바꿔서 다시 확인해보세요.', style: TextStyle(color: Color(0xFF6B7280))),
                                ],
                              ),
                            )
                          else
                            AuctionCardGrid(
                              products: products,
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 경매 탭 상단의 카테고리/정렬 필터 바예요. 검색 화면의 알약 버튼보다 더
/// 옅은 채움색 + 얇은 하단 구분선으로 눌러서, 화면 위에 붕 떠 보이지 않고
/// 앱바 바로 아래에 자연스럽게 붙어있는 느낌을 주려고 했어요(번개장터류
/// 필터 바 참고).
class _AuctionFilterBar extends StatelessWidget {
  final String category;
  final List<String> categoryOptions;
  final ValueChanged<String> onCategorySelected;
  final String sortLabel;
  final List<PopupMenuEntry<_AuctionSort>> sortMenuItems;
  final ValueChanged<_AuctionSort> onSortSelected;
  final bool showGradeFilter;
  final String gradeLabel;
  final ValueChanged<String?> onGradeSelected;
  // 필터 줄 우측 끝에 붙는 액션(예: 찜한경매의 '종료 삭제' 버튼).
  final Widget? trailing;

  const _AuctionFilterBar({
    required this.category,
    required this.categoryOptions,
    required this.onCategorySelected,
    required this.sortLabel,
    required this.sortMenuItems,
    required this.onSortSelected,
    required this.showGradeFilter,
    required this.gradeLabel,
    required this.onGradeSelected,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final pills = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PopupMenuButton<String>(
            initialValue: category,
            onSelected: onCategorySelected,
            itemBuilder: (_) => categoryOptions
                .map((value) => PopupMenuItem(value: value, child: Text(value)))
                .toList(),
            child: _FilterPill(label: category),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<_AuctionSort>(
            onSelected: onSortSelected,
            itemBuilder: (_) => sortMenuItems,
            child: _FilterPill(label: sortLabel),
          ),
          if (showGradeFilter) ...[
            const SizedBox(width: 6),
            PopupMenuButton<String?>(
              onSelected: onGradeSelected,
              itemBuilder: (_) => [
                const PopupMenuItem<String?>(value: null, child: Text('전체 등급')),
                ...AppCategories.kujiGrades.map((grade) => PopupMenuItem<String?>(value: grade, child: Text(grade))),
              ],
              child: _FilterPill(label: gradeLabel),
            ),
          ],
        ],
      ),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 9, context.pagePadding, 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: trailing == null
          ? pills
          : Row(
              children: [
                Expanded(child: pills),
                const SizedBox(width: 8),
                trailing!,
              ],
            ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;

  const _FilterPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          const SizedBox(width: 3),
          const Icon(Icons.expand_more, size: 16, color: Color(0xFF6B7280)),
        ],
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
        body: _LoginRequiredContent(
          icon: Icons.favorite_border,
          title: '찜한 경매는 로그인 후 이용할 수 있어요',
          description: '찜한 상품을 저장하고 다시 보려면 로그인/회원가입이 필요해요.',
        ),
      );
    }

    return const ProductCollectionScreen(mode: ProductCollectionMode.favorites);
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

  // 프로필 통계(가입일·최근접속 등)를 눌렀을 때 상세를 보여주는 안내 팝업이에요.
  Future<void> _showStatInfo(BuildContext context, String title, String value, String description) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF16305C))),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569))),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF334155)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final source = await pickImageSourceSheet(context);
    if (source == null) return;
    final image = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 900);
    if (image == null) return;
    final bytes = await cropPickedImage(image, aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1));
    if (bytes == null) return;
    try {
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
    final source = await pickImageSourceSheet(context);
    if (source == null) return;
    final image = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (image == null) return;
    final bytes = await cropPickedImage(image);
    if (bytes == null) return;
    try {
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
              // 닉네임 중복 예약(변경 시 이전 닉네임은 반납). 이미 쓰는 닉네임이면 막아요.
              try {
                await AuthService.reserveNickname(
                  uid: user.uid,
                  nickname: name,
                  previousNickname: (data['nickname'] as String?)?.trim(),
                );
              } on NicknameTakenException {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(
                      content: Text('이미 사용 중인 닉네임이에요. 다른 닉네임을 입력해주세요.')));
                }
                return;
              }
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

    // 이 계정이 실제로 획득한 배지만 선택할 수 있어요(마스터는 전부).
    final earned = earnedSellerBadgesFromData(data);

    final sourceBadges = (_savedBadgesOverride ??
            (data['sellerBadges'] as List?)?.whereType<String>().toList() ??
            <String>[])
        .where(earned.contains)
        .take(3)
        .toList();
    final selected = <String>{...sourceBadges};
    bool saving = false;
    bool showMaxSelectionNotice = false;
    // 잠긴 배지를 눌렀을 때 시트 안에 인라인으로 보여줄 안내 문구예요.
    // (스낵바로 띄우면 모달 시트 뒤에 가려져서 안 보였어요.)
    String? lockedHint;

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
                        : (lockedHint != null
                            ? Container(
                                key: const ValueKey('badge-locked-notice'),
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF64748B)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        lockedHint!,
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w800,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('badge-limit-empty'))),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kSellerBadgeOptions.map((badge) {
                      final id = badge['id']!;
                      final locked = !earned.contains(id);
                      final isSelected = selected.contains(id) && !locked;
                      return FilterChip(
                        selected: isSelected,
                        avatar: Text(locked ? '🔒' : badge['emoji']!),
                        label: Text(badge['label']!),
                        labelStyle: locked ? const TextStyle(color: Color(0xFF94A3B8)) : null,
                        onSelected: saving
                            ? null
                            : (_) {
                                if (locked) {
                                  setSheetState(() {
                                    lockedHint = kSellerBadgeCriteria[id] ?? '아직 획득하지 못한 배지예요.';
                                    showMaxSelectionNotice = false;
                                  });
                                  return;
                                }
                                setSheetState(() {
                                  lockedHint = null;
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
                              final values = selected.where(earned.contains).take(3).toList(growable: false);
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
      // SizedBox.expand로 원형 컨테이너를 꽉 채워, 이미지가 네모로 남지 않게 해요.
      return SizedBox.expand(
        child: Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🐥', style: TextStyle(fontSize: 44)))),
      );
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
          if (snapshot.hasError) {
            return const _PlaceholderContent(
              icon: Icons.error_outline,
              title: '프로필 정보를 불러오지 못했어요',
              description: '네트워크 상태를 확인한 뒤 다시 열어봐 주세요.',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
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
          // 실제로 획득한 배지만 노출해요(기준 미달인데 예전에 저장돼 있던 배지는 숨겨요).
          final earnedBadges = computeEarnedSellerBadges(
            isMaster: DuckAuctionStore.isMasterAdmin,
            completedSales: completedCount,
            reviewCount: reviewCount,
            rating: rating,
            followerCount: followerCount,
          );
          final visibleBadges = badges.where(earnedBadges.contains).toList();

          return ListView(padding: EdgeInsets.zero, children: [
            ResponsiveContentBounds(
              maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
              padding: EdgeInsets.fromLTRB(0, 0, 0, context.responsive(phone: 96.0, tablet: 28.0)),
              child: Column(children: [
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
                    right: 72,
                    top: MediaQuery.of(context).padding.top + 24,
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
                  Positioned(right: 12, top: MediaQuery.of(context).padding.top + 24, child: Material(color: Colors.black54, shape: const CircleBorder(), child: IconButton(onPressed: _changeCoverPhoto, icon: const Icon(Icons.camera_alt_rounded, color: Colors.white), tooltip: '배경 사진 수정'))),
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
                    child: Column(children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _MyProfileStat(icon: Icons.calendar_month_outlined, label: '가입일', value: joinedText, onTap: () => _showStatInfo(context, '가입일', joinedText, '덕옥션에 처음 가입한 날짜예요.'))),
                        const _MyProfileDivider(),
                        Expanded(child: _MyProfileStat(icon: Icons.schedule_rounded, label: '최근 접속', value: '방금 전', onTap: () => _showStatInfo(context, '최근 접속', '방금 전', '가장 최근에 앱에 접속한 시점이에요.'))),
                        const _MyProfileDivider(),
                        Expanded(child: _MyProfileStat(icon: Icons.people_outline_rounded, label: '팔로워', value: '$followerCount', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FollowListScreen(userId: user.uid, mode: FollowListMode.followers, title: '내 팔로워'))))),
                        const _MyProfileDivider(),
                        Expanded(child: _MyProfileStat(icon: Icons.person_add_alt_1_outlined, label: '팔로잉', value: '$followingCount', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FollowListScreen(userId: user.uid, mode: FollowListMode.following, title: '내 팔로잉'))))),
                      ]),
                      const SizedBox(height: 10),
                      const Text(
                        '항목을 누르면 상세 정보를 볼 수 있어요',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ]),
              ),
              Positioned(
                top: 88,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(width: 104, height: 104, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF1F5F9), border: Border.all(color: Colors.white, width: 5), image: (imageUrl != null && imageUrl.trim().isNotEmpty) ? DecorationImage(image: NetworkImage(imageUrl.trim()), fit: BoxFit.cover) : null, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 18, offset: const Offset(0, 5))]), child: (imageUrl == null || imageUrl.trim().isEmpty) ? const Center(child: Text('🐥', style: TextStyle(fontSize: 44))) : null),
                  Positioned(right: -3, bottom: 0, child: Material(color: const Color(0xFF334155), shape: const CircleBorder(), child: IconButton(onPressed: _changePhoto, icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 19), tooltip: '프로필 사진 수정'))),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _EditableProfileCard(title: '판매자 소개', onEdit: () => _editTextProfile(data), child: Text(intro.isEmpty ? '안녕하세요! 꼼꼼한 포장과 빠른 답변 약속드릴게요 😊' : intro, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, height: 1.5)))),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _EditableProfileCard(title: '판매자 배지', onEdit: () => _editBadges(data), child: visibleBadges.isEmpty ? const Text('표시할 배지를 선택해 주세요.', style: TextStyle(color: Color(0xFF94A3B8))) : SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: visibleBadges.map((id) => Padding(padding: const EdgeInsets.only(right: 6), child: _CompactSellerBadge(label: sellerBadgeLabel(id)))).toList())))),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: [
              _MyMenuTile(icon: Icons.receipt_long_outlined, title: '내 경매 관리', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyAuctionManageScreen()))),
              _MyMenuTile(icon: Icons.favorite_border, title: '찜한 경매', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductCollectionScreen(mode: ProductCollectionMode.favorites)))),
              _MyMenuTile(icon: Icons.remove_red_eye_outlined, title: '최근 본 경매', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecentViewedProductsScreen()))),
              _MyMenuTile(icon: Icons.chat_bubble_outline_rounded, title: '채팅', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatRoomListScreen()))),
              _MyMenuTile(icon: Icons.star_outline_rounded, title: '후기', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyReviewsScreen()))),
              _MyMenuTile(icon: Icons.report_gmailerrorred_outlined, title: '신고내역', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyReportHistoryScreen()))),
              _MyMenuTile(icon: Icons.block_outlined, title: '차단 관리', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlockedUsersScreen()))),
              _MyMenuTile(icon: Icons.settings_outlined, title: '설정', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MySettingsScreen(onLogout: widget.onLogout)))),
              if (DuckAuctionStore.isMasterAdmin) ...[const SizedBox(height: 10), const _DeveloperModePanel()],
            ])),
          ]),
            ),
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

/// 좁은 화면(폴드 등)에서 라벨이 줄바꿈되지 않게 한 줄로 유지하고, 폭이 부족하면
/// 자동으로 살짝 축소해서 보여주는 텍스트예요.
class _OneLineFit extends StatelessWidget {
  final String label;
  final AlignmentGeometry alignment;
  final TextStyle? style;

  const _OneLineFit(this.label, {this.alignment = Alignment.center, this.style});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(label, maxLines: 1, softWrap: false, style: style),
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
    final child = Column(children: [
      Icon(icon, size: 22, color: const Color(0xFF64748B)),
      const SizedBox(height: 6),
      // 값(숫자·날짜)은 기본 화면에서 숨기고, 아이콘을 누르면 상세로 보여줘요.
      // 좁은 화면(폴드4 등)에서 '최근 접속' 같은 라벨이 줄바꿈되지 않게 한 줄로
      // 유지하고, 필요할 때만 자동 축소해요.
      _OneLineFit(label, alignment: Alignment.center, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
    ]);
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
              label: '카테고리별 샘플 경매 생성',
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
        padding: EdgeInsets.zero,
        children: [
          ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 760.0),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FutureBuilder<Map<String, int>>(
            future: _loadCounts(),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const <String, int>{};
              return ResponsiveCardFlow(
                spacing: 10,
                runSpacing: 10,
                children: ['회원', '경매', '채팅', '상품 신고', '후기 신고', '후기'].map((label) {
                  return Container(
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
                    );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: Text('운영 관리', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
          const SizedBox(height: 10),
          _AdminMenuTile(icon: Icons.people_outline, title: '회원 관리', subtitle: '검색 · 정지 · 정지 해제', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMemberManagementScreen()))),
          _AdminMenuTile(icon: Icons.campaign_outlined, title: '공지 관리', subtitle: '작성 · 수정 · 삭제 · 상단 고정', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNoticeManagementScreen()))),
          _AdminMenuTile(icon: Icons.report_gmailerrorred_outlined, title: '통합 신고 관리', subtitle: '경매 · 후기 · 채팅 신고', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportHubScreen()))),
          _AdminMenuTile(icon: Icons.rate_review_outlined, title: '후기 관리', subtitle: '숨김 · 복구 · 삭제', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReviewManagementScreen()))),
          _AdminMenuTile(icon: Icons.edit_note_rounded, title: '테스트 후기 남기기', subtitle: '판매자·구매자 후기 직접 작성', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReviewWriteHubScreen()))),
          _AdminMenuTile(icon: Icons.tune_outlined, title: '경매 상태 관리', subtitle: '진행 · 낙찰 · 유찰 상태 테스트', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductStatusScreen()))),
          _AdminMenuTile(icon: Icons.receipt_long_outlined, title: '운영 로그', subtitle: '관리자 처리 이력 확인', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOperationLogScreen()))),
            ]),
          ),
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
    body: ResponsiveContentBounds(
      maxWidth: context.responsive(phone: double.infinity, tablet: 720.0),
      padding: EdgeInsets.zero,
      child: Column(children: [
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
            final noShowCount = (data['noShowCount'] as num?)?.toInt() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: suspended ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB))),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFFFFF3C4), child: const Text('🐥')),
                title: Text((data['nickname'] as String?)?.trim().isNotEmpty == true ? (data['nickname'] as String) : '닉네임 없음', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(
                  '${data['email'] ?? '이메일 없음'}${suspended ? ' · 이용 정지' : ''}${noShowCount > 0 ? ' · 노쇼 $noShowCount회' : ''}',
                  style: noShowCount > 0 ? const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700) : null,
                ),
                trailing: OutlinedButton(onPressed: () => _toggleSuspended(doc), style: OutlinedButton.styleFrom(foregroundColor: suspended ? const Color(0xFF16A34A) : const Color(0xFFDC2626)), child: Text(suspended ? '해제' : '정지')),
              ),
            );
          });
        },
      )),
      ]),
    ),
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
        return ListView(padding: EdgeInsets.zero, children: [
          ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 720.0),
            padding: const EdgeInsets.all(16),
            child: Column(children: docs.map((doc) {
          final data = doc.data();
          return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: ListTile(
            title: Row(children: [if (data['pinned'] == true) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin_rounded, size: 17)), Expanded(child: Text(data['title'] as String? ?? '제목 없음', style: const TextStyle(fontWeight: FontWeight.w900)))]),
            subtitle: Text('${data['enabled'] == false ? '숨김 · ' : ''}${data['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => _edit(doc: doc),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)), onPressed: () async { await doc.reference.delete(); await _writeAdminLog('공지 삭제', targetId: doc.id, detail: data['title'] as String?); }),
          ));
        }).toList()),
          ),
        ]);
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
    body: ListView(padding: EdgeInsets.zero, children: [
      ResponsiveContentBounds(
        maxWidth: context.responsive(phone: double.infinity, tablet: 720.0),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _AdminMenuTile(icon: Icons.gavel_outlined, title: '경매 신고', subtitle: '허위 매물 · 불법 상품 · 사기 의심', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportManagementScreen()))),
      _AdminMenuTile(icon: Icons.rate_review_outlined, title: '후기 신고', subtitle: '허위 후기 · 비방 · 개인정보 노출', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReviewReportScreen()))),
      _AdminMenuTile(icon: Icons.chat_bubble_outline, title: '채팅 신고', subtitle: '욕설 · 사기 의심 · 개인정보 요구', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSimpleReportListScreen(collection: 'chatReports', title: '채팅 신고')))),
        ]),
      ),
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
        return ListView(padding: EdgeInsets.zero, children: [
          ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 760.0),
            padding: const EdgeInsets.all(16),
            child: ResponsiveCardFlow(spacing: 10, runSpacing: 10, children: docs.map((doc) {
          final data = doc.data(); final status = data['status'] as String? ?? 'waiting';
          return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        }).toList()),
          ),
        ]);
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
        return ListView(padding: EdgeInsets.zero, children: [
          ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 760.0),
            padding: const EdgeInsets.all(16),
            child: ResponsiveCardFlow(spacing: 10, runSpacing: 10, children: docs.map((doc) {
          final data = doc.data(); final hidden = data['hidden'] == true; final rating = (data['rating'] as num?)?.toInt() ?? 0;
          return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: hidden ? const Color(0xFFF8FAFC) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${List.filled(rating.clamp(0, 5).toInt(), '🐥').join()}  ${data['writerName'] ?? data['writerUid'] ?? '작성자'}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6), Text(data['content'] as String? ?? '', style: const TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 10), Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: () => _action(doc, hidden ? 'restore' : 'hide'), child: Text(hidden ? '복구' : '숨김')),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)), onPressed: () => _action(doc, 'delete'), child: const Text('삭제')),
            ]),
          ]));
        }).toList()),
          ),
        ]);
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
        return ListView(padding: EdgeInsets.zero, children: [
          ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 720.0),
            padding: EdgeInsets.zero,
            child: ListView.separated(padding: const EdgeInsets.all(16), shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: docs.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, index) {
          final data = docs[index].data();
          return ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 4), leading: const Icon(Icons.history_rounded), title: Text(data['action'] as String? ?? '관리 작업', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${data['adminEmail'] ?? '관리자'} · ${data['detail'] ?? data['targetId'] ?? ''}\n${_time(data['createdAt'])}'));
        }),
          ),
        ]);
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
            padding: EdgeInsets.zero,
            children: [
              ResponsiveContentBounds(
                maxWidth: context.responsive(phone: double.infinity, tablet: 480.0),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(children: [
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
                ]),
              ),
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

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              ResponsiveContentBounds(
                maxWidth: context.responsive(phone: double.infinity, tablet: 760.0),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: ResponsiveCardFlow(
                  spacing: 12,
                  runSpacing: 12,
                  children: sorted.map((product) {
              return Container(
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
            }).toList(),
                ),
              ),
            ],
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

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              ResponsiveContentBounds(
                maxWidth: context.responsive(phone: double.infinity, tablet: 800.0),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _ReportGuideCard(),
              ResponsiveCardFlow(
                spacing: 12,
                runSpacing: 12,
                children: docs.map((doc) {
              final data = <String, dynamic>{...doc.data(), 'id': doc.id};
              final status = (data['status'] as String?) ?? 'waiting';
              final productTitle = (data['productTitle'] as String?) ?? '상품명 없음';
              final reason = (data['reason'] as String?) ?? '사유 없음';
              final detail = (data['detail'] as String?) ?? '';
              final reporter = (data['reporterEmail'] as String?) ?? (data['reporterUid'] as String?) ?? '신고자 정보 없음';
              final seller = (data['sellerName'] as String?) ?? (data['sellerUid'] as String?) ?? '판매자 정보 없음';

              return Container(
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
            }).toList(),
              ),
                ]),
              ),
            ],
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
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              ResponsiveContentBounds(
                maxWidth: context.responsive(phone: double.infinity, tablet: 760.0),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: ResponsiveCardFlow(
                  spacing: 12,
                  runSpacing: 12,
                  children: products.map((product) {
              final sellerUid = (product.sellerId ?? '').trim();
              final buyerUid = (product.lastBidUserId ?? '').trim();
              return Container(
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
            }).toList(),
                ),
              ),
            ],
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
      body: ListView(padding: EdgeInsets.zero, children: [
        ResponsiveContentBounds(
          maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
          padding: const EdgeInsets.all(16),
          child: Column(children: [
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

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              ResponsiveContentBounds(
                maxWidth: context.responsive(phone: double.infinity, tablet: 720.0),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(children: [
              const _PaymentScenarioGuideCard(),
              ...products.map((product) {
              return _PaymentScenarioProductCard(
                product: product,
                onRun: (scenario) => _runScenario(context, product, scenario),
              );
              }),
                ]),
              ),
            ],
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
          return ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
            padding: EdgeInsets.zero,
            child: ListView.separated(
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
          ));
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

  // 사용자 차단 상태입니다. 내가 상대를 차단했는지, 상대가 나를 차단했는지를
  // 각각의 users/{uid}.blockedUsers 배열을 구독해서 실시간으로 반영합니다.
  String? _otherUid;
  Set<String> _iBlockedSet = {};
  Set<String> _blockedBySet = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _myBlockSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _otherBlockSub;

  // 낙찰 확정 이후 상대방 배송지를 서버(Cloud Functions)에서 받아와 보여줍니다.
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get _sellerUid => widget.product.sellerId;

  bool get _iHaveBlockedOther => _otherUid != null && _iBlockedSet.contains(_otherUid);
  bool get _isBlockedConversation {
    final other = _otherUid;
    final me = _currentUid;
    if (other == null || me == null) return false;
    return _iBlockedSet.contains(other) || _blockedBySet.contains(me);
  }

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
    _initBlockState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _myBlockSub?.cancel();
    _otherBlockSub?.cancel();
    super.dispose();
  }

  /// 상대방 UID를 알아낸 뒤(내가 판매자면 채팅방 문서의 buyerUid를 조회),
  /// 나와 상대방 각각의 차단 목록을 실시간으로 구독합니다.
  Future<void> _initBlockState() async {
    final me = _currentUid;
    if (me == null) return;
    String? other = _sellerUid != me ? _sellerUid : null;
    final roomId = _roomId;
    if (other == null && roomId != null) {
      try {
        final roomSnap = await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).get();
        other = roomSnap.data()?['buyerUid'] as String?;
      } catch (_) {}
    }
    if (!mounted || other == null) return;
    setState(() => _otherUid = other);

    _myBlockSub = FirebaseFirestore.instance.collection('users').doc(me).snapshots().listen((snap) {
      if (!mounted) return;
      final list = (snap.data()?['blockedUsers'] as List?)?.whereType<String>().toSet() ?? <String>{};
      setState(() => _iBlockedSet = list);
    });
    _otherBlockSub = FirebaseFirestore.instance.collection('users').doc(other).snapshots().listen((snap) {
      if (!mounted) return;
      final list = (snap.data()?['blockedUsers'] as List?)?.whereType<String>().toSet() ?? <String>{};
      setState(() => _blockedBySet = list);
    });
  }

  Future<void> _toggleBlockUser() async {
    final me = _currentUid;
    final other = _otherUid;
    if (me == null || other == null) return;
    final blocking = !_iHaveBlockedOther;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(blocking ? '이 사용자를 차단할까요?' : '차단을 해제할까요?'),
        content: Text(blocking
            ? '차단하면 이 사용자와 더 이상 메시지를 주고받을 수 없어요. 마이페이지의 "차단 관리"에서 언제든 해제할 수 있어요.'
            : '차단을 해제하면 다시 메시지를 주고받을 수 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: blocking ? FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)) : null,
            child: Text(blocking ? '차단' : '차단 해제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(me).set({
        'blockedUsers': blocking ? FieldValue.arrayUnion([other]) : FieldValue.arrayRemove([other]),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(blocking ? '차단했어요.' : '차단을 해제했어요.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('처리하지 못했어요: $error')));
    }
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
    if (_isBlockedConversation) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단된 사용자와는 메시지를 주고받을 수 없어요.')));
      return;
    }
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
    if (_isBlockedConversation) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단된 사용자와는 메시지를 주고받을 수 없어요.')));
      return;
    }
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

  /// 판매자가 '배송 준비 시작'을 누르면, 상품에 준비 시각을 남기고 채팅방에
  /// 시스템 안내를 자동으로 띄워요(구매자에게 푸시까지 자동 전달).
  Future<void> _startPreparing() async {
    final productId = widget.product.id;
    final senderUid = _currentUid;
    if (productId == null || senderUid == null) return;
    const msg = '판매자가 배송 준비를 시작했어요 🐥  곧 운송장을 등록할게요.';
    try {
      await FirebaseFirestore.instance.collection('products').doc(productId).set({
        'shippingPreparedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _ensureRoom(preview: msg, type: 'system');
      await _messagesRef?.add({
        'text': msg,
        'senderUid': senderUid,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [senderUid],
        'type': 'system',
      });
      await DuckAuctionStore.refreshProductsNow();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('처리에 실패했어요.\n$e')));
    }
  }

  Future<void> _openShipmentRegisterFromChat(ProductItem product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShipmentRegisterScreen(product: product)),
    );
  }

  // 낙찰자가 '배송 지연' 선택 메시지에서 버튼을 눌렀을 때 두 번 실행되지 않도록
  // 잠깐 잠급니다.
  bool _shipActionBusy = false;

  /// 낙찰자가 [결제취소]를 눌렀을 때: 확인 후 결제 취소(환불)를 요청해요.
  Future<void> _onBuyerCancelPayment() async {
    final productId = widget.product.id;
    if (productId == null || _shipActionBusy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('결제를 취소할까요?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '결제하신 금액이 환불돼요. 이 작업은 되돌릴 수 없어요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('닫기')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('결제 취소'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _shipActionBusy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('cancelTossPayment').call<Map<String, dynamic>>({
        'productId': productId,
        'reason': '구매자 요청 (배송 지연)',
      });
      await DuckAuctionStore.refreshProductsNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결제 취소(환불)를 요청했어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('결제 취소에 실패했어요. 잠시 후 다시 시도해주세요.\n$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _shipActionBusy = false);
    }
  }

  /// 낙찰자가 [배송요청 다시]를 눌렀을 때: 판매자에게 배송을 다시 요청해요.
  Future<void> _onBuyerRequestReship() async {
    final productId = widget.product.id;
    if (productId == null || _shipActionBusy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('배송을 다시 요청할까요?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '판매자에게 운송장 등록을 다시 요청해요. 판매자에게 배송 기한이 다시 부여돼요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('닫기')),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('배송 다시 요청')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _shipActionBusy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('requestShipmentAgain').call<Map<String, dynamic>>({
        'productId': productId,
      });
      await DuckAuctionStore.refreshProductsNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('판매자에게 배송 요청을 다시 보냈어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('배송 재요청에 실패했어요. 잠시 후 다시 시도해주세요.\n$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _shipActionBusy = false);
    }
  }

  /// 낙찰자가 [상품 받았어요]를 눌렀을 때: 수령표시(markDelivered)로 배송완료 처리해요.
  Future<void> _onBuyerMarkDelivered() async {
    final productId = widget.product.id;
    if (productId == null || _shipActionBusy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('상품을 받으셨나요?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('수령을 표시하면 배송완료 상태로 바뀌어요. 상품을 확인한 뒤 구매확정을 진행할 수 있어요.', style: TextStyle(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('닫기')),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('상품 받았어요')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _shipActionBusy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('markDelivered').call<Map<String, dynamic>>({'productId': productId});
      await DuckAuctionStore.refreshProductsNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수령 확인했어요. 상품을 확인하고 구매확정을 눌러주세요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수령 표시에 실패했어요. 잠시 후 다시 시도해주세요.\n$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _shipActionBusy = false);
    }
  }

  /// 낙찰자가 배송 확인 알림에서 [받지 못했어요]를 눌렀을 때: 미수령을 알려
  /// 자동 구매확정을 보류하고, 7일 뒤 재확인 알림을 예약해요(reportNotReceived).
  Future<void> _onBuyerReportNotReceived() async {
    final productId = widget.product.id;
    if (productId == null || _shipActionBusy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('아직 못 받으셨나요?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '미수령으로 표시하면 자동 구매확정이 보류되고, 7일 뒤에 다시 확인 알림을 보내드려요. '
          '배송에 문제가 있으면 판매자와 상의하고, 필요하면 결제취소(환불)를 요청할 수 있어요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('닫기')),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('아직 못 받았어요')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _shipActionBusy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('reportNotReceived').call<Map<String, dynamic>>({'productId': productId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('미수령으로 표시했어요. 7일 뒤 다시 확인할게요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리에 실패했어요. 잠시 후 다시 시도해주세요.\n$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _shipActionBusy = false);
    }
  }

  /// 낙찰자가 [구매확정]을 눌렀을 때: confirmPurchase로 거래를 완료해요.
  Future<void> _onBuyerConfirmPurchase() async {
    final productId = widget.product.id;
    if (productId == null || _shipActionBusy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('구매를 확정할까요?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('구매확정 후에는 거래가 완료돼요. 상품을 충분히 확인한 뒤 진행해주세요.', style: TextStyle(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('닫기')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('구매확정'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _shipActionBusy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('confirmPurchase').call<Map<String, dynamic>>({'productId': productId});
      await DuckAuctionStore.refreshProductsNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구매확정이 완료됐어요. 거래가 종료됐어요. 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구매확정에 실패했어요. 잠시 후 다시 시도해주세요.\n$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _shipActionBusy = false);
    }
  }

  /// 채팅방 상단의 배송 단계 안내/액션 바예요. 상품 문서를 실시간 구독해서,
  /// 배송 준비→운송장 등록으로 넘어갈 때 버튼이 자동으로 바뀌어요.
  Widget _shipmentBar(BuildContext context, bool isSeller, ProductItem fallback) {
    final productId = fallback.id;
    if (productId == null || productId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('products').doc(productId).snapshots(),
      builder: (context, snap) {
        final product = (snap.hasData && snap.data!.exists)
            ? ProductItem.fromFirestore(snap.data!)
            : fallback;
        final status = product.effectiveStatus;

        if (isSeller) {
          if (status == 'paid') {
            final prepared = product.shippingPreparedAt != null;
            return _ShipmentBanner(
              icon: prepared ? Icons.inventory_2_outlined : Icons.redeem_rounded,
              tone: prepared ? _ShipTone.point : _ShipTone.info,
              title: prepared ? '배송 준비 중이에요' : '결제가 완료됐어요 🎉',
              subtitle: prepared
                  ? '운송장을 등록하면 구매자에게 자동으로 전달돼요.'
                  : '배송 준비를 시작해 구매자에게 알려주세요.',
              buttonLabel: prepared ? '운송장 등록' : '배송 준비 시작',
              onPressed: prepared ? () => _openShipmentRegisterFromChat(product) : _startPreparing,
            );
          }
          if (status == 'shipped') {
            return _ShipmentBanner(
              icon: Icons.local_shipping_outlined,
              tone: _ShipTone.point,
              title: '배송 중이에요',
              subtitle: '${product.shippingCourier} · ${product.shippingTrackingNumber}',
              buttonLabel: '운송장 수정',
              onPressed: () => _openShipmentRegisterFromChat(product),
            );
          }
          return const SizedBox.shrink();
        }

        // 구매자: 배송이 시작되면 배송조회 + '상품 받았어요'(수령표시)를 함께 보여줘요.
        if (status == 'shipped' && product.hasShipment) {
          return _ShipmentBanner(
            icon: Icons.local_shipping_outlined,
            tone: _ShipTone.point,
            title: '상품이 배송 중이에요',
            subtitle: '${product.shippingCourier} · ${product.shippingTrackingNumber}',
            buttonLabel: '배송조회',
            onPressed: () => _showShipmentInfoSheet(context, product),
            secondaryLabel: '상품 받았어요',
            secondaryOnPressed: _onBuyerMarkDelivered,
          );
        }
        // 배송완료(수령표시 후): 구매확정으로 거래를 마무리하고, 배송조회도 유지해요.
        if (status == 'delivered') {
          return _ShipmentBanner(
            icon: Icons.verified_outlined,
            tone: _ShipTone.point,
            title: '상품을 받으셨나요?',
            subtitle: '상품을 확인한 뒤 구매확정을 누르면 거래가 완료돼요.',
            buttonLabel: '구매확정',
            onPressed: _onBuyerConfirmPurchase,
            secondaryLabel: product.hasShipment ? '배송조회' : null,
            secondaryOnPressed: product.hasShipment ? () => _showShipmentInfoSheet(context, product) : null,
          );
        }
        return const SizedBox.shrink();
      },
    );
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
        actions: [
          if (_otherUid != null)
            IconButton(
              onPressed: _toggleBlockUser,
              icon: Icon(_iHaveBlockedOther ? Icons.block : Icons.block_outlined, color: _iHaveBlockedOther ? const Color(0xFFEF4444) : null),
              tooltip: _iHaveBlockedOther ? '차단 해제' : '사용자 차단',
            ),
          IconButton(onPressed: _reportChat, icon: const Icon(Icons.flag_outlined), tooltip: '채팅 신고'),
        ],
      ),
      body: ResponsiveContentBounds(
        maxWidth: context.responsive(phone: double.infinity, tablet: 720.0),
        padding: EdgeInsets.zero,
        child: Column(children: [
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
          ),
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
        _shipmentBar(context, isSeller, product),
        // 개인정보 보호: 배송지는 채팅에 공개하지 않아요. 판매자는 '운송장 등록'
        // 화면에서만 배송지를 확인할 수 있어요(ShipmentRegisterScreen).
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
                } else if (type == 'ship_decision') {
                  return _ShipDecisionMessage(
                    productId: product.id,
                    text: (data['text'] as String?) ?? '',
                    currentUid: currentUid,
                    busy: _shipActionBusy,
                    onCancel: _onBuyerCancelPayment,
                    onReship: _onBuyerRequestReship,
                  );
                } else if (type == 'delivery_check') {
                  return _DeliveryCheckMessage(
                    productId: product.id,
                    text: (data['text'] as String?) ?? '',
                    currentUid: currentUid,
                    busy: _shipActionBusy,
                    onReceived: _onBuyerMarkDelivered,
                    onNotReceived: _onBuyerReportNotReceived,
                  );
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
        _isBlockedConversation
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
                child: SafeArea(
                  top: false,
                  child: Text(
                    _iHaveBlockedOther ? '차단한 사용자예요. 메시지를 보내려면 마이페이지의 "차단 관리"에서 차단을 해제하세요.' : '상대방이 대화를 제한해서 메시지를 보낼 수 없어요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, height: 1.4),
                  ),
                ),
              )
            : Container(
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
      ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
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
      ),
    );
  }
}

class MyAuctionManageScreen extends StatefulWidget {
  const MyAuctionManageScreen({super.key});

  @override
  State<MyAuctionManageScreen> createState() => _MyAuctionManageScreenState();
}

class _MyAuctionManageScreenState extends State<MyAuctionManageScreen> {
  int _tabIndex = 0; // 0: 판매, 1: 입찰

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('내 경매 관리'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: _MyAuctionTabSwitch(
              index: _tabIndex,
              onChanged: (index) => setState(() => _tabIndex = index),
            ),
          ),
          Expanded(
            child: _tabIndex == 0 ? const _SellingList() : _BiddingList(userId: user?.uid),
          ),
        ],
      ),
    );
  }
}

/// "판매" / "입찰" 두 목록을 오갈 수 있는 간단한 세그먼트 스위치입니다.
class _MyAuctionTabSwitch extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _MyAuctionTabSwitch({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _MyAuctionTabButton(label: '판매', selected: index == 0, onTap: () => onChanged(0))),
          Expanded(child: _MyAuctionTabButton(label: '입찰', selected: index == 1, onTap: () => onChanged(1))),
        ],
      ),
    );
  }
}

class _MyAuctionTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MyAuctionTabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

/// 내가 판매자로 등록한 경매 목록입니다(기존 로직 그대로).
/// 판매자가 운송장(택배사 + 송장번호)을 등록하는 화면이에요. 저장하면 상품을
/// '배송중(shipped)'으로 바꾸고, 낙찰자에게 같은 채팅방으로 자동 알림을 보내요.
class ShipmentRegisterScreen extends StatefulWidget {
  final ProductItem product;
  const ShipmentRegisterScreen({super.key, required this.product});

  @override
  State<ShipmentRegisterScreen> createState() => _ShipmentRegisterScreenState();
}

class _ShipmentRegisterScreenState extends State<ShipmentRegisterScreen> {
  late String _courier = widget.product.shippingCourier.isNotEmpty
      ? widget.product.shippingCourier
      : AppCouriers.names.first;
  late final TextEditingController _numberController =
      TextEditingController(text: widget.product.shippingTrackingNumber);
  bool _saving = false;

  // 낙찰자(구매자)의 배송지예요. 서버(getTradeAddress)가 거래 당사자(판매자)에게만
  // 상대방 주소를 돌려줘요. null=조회 전, {available:false}=구매자가 배송지 미등록.
  Map<String, dynamic>? _buyerAddress;
  bool _addressLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBuyerAddress();
  }

  Future<void> _loadBuyerAddress() async {
    final productId = widget.product.id;
    if (productId == null || productId.isEmpty) {
      if (mounted) setState(() => _addressLoading = false);
      return;
    }
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getTradeAddress')
          .call<Map<String, dynamic>>({'productId': productId});
      if (!mounted) return;
      setState(() {
        _buyerAddress = Map<String, dynamic>.from(result.data as Map);
        _addressLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _addressLoading = false);
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('송장번호를 입력해주세요.')));
      return;
    }
    final productId = widget.product.id;
    final sellerUid = FirebaseAuth.instance.currentUser?.uid;
    if (productId == null || productId.isEmpty || sellerUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상품 정보를 확인할 수 없어요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('products').doc(productId).set({
        'shippingCourier': _courier,
        'shippingTrackingNumber': number,
        'shippedAt': FieldValue.serverTimestamp(),
        'status': 'shipped',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final buyerUid = widget.product.winnerId ?? widget.product.lastBidUserId;
      if (buyerUid != null && buyerUid.isNotEmpty) {
        await _postShipmentChat(productId, sellerUid, buyerUid, _courier, number);
      }

      await DuckAuctionStore.refreshProductsNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운송장을 등록했어요. 낙찰자에게 알림을 보냈어요.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('운송장 등록에 실패했어요.\n$e')));
    }
  }

  /// 낙찰자에게 같은 채팅방으로 배송 시작 알림을 남겨요(판매자 명의). 채팅방
  /// id 규칙은 앱과 동일하게 '{productId}_{정렬한 두 uid}'예요.
  Future<void> _postShipmentChat(
      String productId, String sellerUid, String buyerUid, String courier, String number) async {
    final users = [buyerUid, sellerUid]..sort();
    final roomId = '${productId}_${users.join('_')}';
    final roomRef = FirebaseFirestore.instance.collection('chatRooms').doc(roomId);
    final message = '[배송 시작] 판매자가 운송장을 등록했어요. 📦\n'
        '택배사: $courier\n송장번호: $number\n'
        "배송 조회는 '내 경매 관리 > 입찰'에서 언제든 확인할 수 있어요.";

    final roomSnap = await roomRef.get();
    final existing = roomSnap.data() ?? const <String, dynamic>{};
    final participants = <String>{
      buyerUid,
      sellerUid,
      ...((existing['participants'] as List?)?.whereType<String>() ?? const <String>[]),
    }.toList();
    final unread = Map<String, dynamic>.from((existing['unreadCounts'] as Map?) ?? const {});
    unread[buyerUid] = ((unread[buyerUid] as num?)?.toInt() ?? 0) + 1;
    if (unread[sellerUid] == null) unread[sellerUid] = 0;

    await roomRef.set({
      'productId': productId,
      'productTitle': widget.product.title,
      'productImageUrl': widget.product.resolvedCoverImageUrl,
      'productPrice': widget.product.price,
      'productStatus': 'shipped',
      'sellerUid': sellerUid,
      'sellerName': widget.product.sellerName,
      'buyerUid': buyerUid,
      'participants': participants,
      'lastMessage': message,
      'lastMessageType': 'text',
      'lastSenderUid': sellerUid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!roomSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
      'unreadCounts': unread,
    }, SetOptions(merge: true));

    await roomRef.collection('messages').add({
      'text': message,
      'senderUid': sellerUid,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [sellerUid],
      'type': 'text',
    });
  }

  /// 낙찰자 배송지 카드예요. 이 화면(판매자만 접근)에서만 주소를 보여줘요.
  Widget _buildAddressCard() {
    if (_addressLoading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('배송지를 불러오는 중...', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
        ]),
      );
    }
    final addr = _buyerAddress;
    final available = addr != null && addr['available'] == true;
    if (!available) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, color: Color(0xFFEA580C), size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('낙찰자가 아직 배송지를 등록하지 않았어요. 배송지가 등록되면 여기에 표시돼요.',
              style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w700, height: 1.4))),
        ]),
      );
    }
    final postcode = (addr!['postcode'] as String?) ?? '';
    final line = [
      if (postcode.isNotEmpty) '($postcode)',
      (addr['address1'] as String?) ?? '',
      (addr['address2'] as String?) ?? '',
    ].where((s) => s.isNotEmpty).join(' ');
    final nickname = (addr['nickname'] as String?) ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.home_outlined, color: Color(0xFF16A34A), size: 20),
          SizedBox(width: 8),
          Text('받는 사람 배송지', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
        ]),
        const SizedBox(height: 8),
        if (nickname.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(nickname, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534))),
          ),
        Text(line, style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w700, height: 1.45)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF15803D),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: line));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('배송지를 복사했어요.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('주소 복사', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  [편의점택배 예약 연동 자리 — 나중에 제휴/계약 후 채우기]  ※ 지금은 미구현 ※
  // ───────────────────────────────────────────────────────────────────────
  //  번개장터·당근처럼 "편의점택배 예약번호 발급 → 편의점 키오스크에 번호만 입력 →
  //  주소 재입력 없이 접수" 흐름이에요. 붙이려면 택배사/편의점망 제휴가 전제예요:
  //    · GS25 = GS Postbox(CVSnet), CU/기타 = CJ대한통운 편의점택배 등과 직접 제휴, 또는
  //    · 굿스플로 같은 물류 API 대행사를 경유한 '예약접수 API' 계약.
  //    (GS Postbox 공식 안내: "당사와 제휴한 쇼핑몰에서만 이용 가능")
  //
  //  구현 그림(계약 후):
  //   1) 위 택배사 선택(_courier)에 '편의점택배(반값택배)' 항목 추가.
  //   2) 그 항목을 고르면 [편의점택배 예약] 버튼 노출 → _reserveConvenienceParcel() 호출.
  //   3) 예약접수는 반드시 서버(Cloud Function)에서 처리 — API 키/정산 정보가 앱에
  //      노출되면 안 돼요. 서버에 보내는사람(판매자)·받는사람(_buyerAddress, 이미 이
  //      화면이 갖고 있음)·상품/무게 정보를 넘겨 예약접수 → 예약번호를 돌려받아요.
  //   4) 예약번호를 판매자에게 보여주고(복사) → 편의점에서 접수하면 발급되는
  //      운송장번호를 웹훅/재조회로 받아 _numberController + status 'shipped'로 자동 반영.
  //   5) 이후 배송추적은 지금 만든 배송조회 / 자동 배송완료 훅에 그대로 연결돼요.
  //
  //  준비물: 제휴 계약, 서버측 예약접수 Cloud Function(reserveConvenienceParcel),
  //         편의점망 택배사 코드. — 배송완료 자동감지 훅(functions/index.js의
  //         detectCarrierDelivery)과 세트로 붙이면 배송 흐름이 완성돼요.
  // ═══════════════════════════════════════════════════════════════════════
  // ignore: unused_element
  Future<void> _reserveConvenienceParcel() async {
    // TODO(편의점택배): 제휴/서버 함수 준비 후 구현. 지금은 자리표시자예요.
    //   예)
    //   final res = await FirebaseFunctions.instance
    //       .httpsCallable('reserveConvenienceParcel')
    //       .call<Map<String, dynamic>>({'productId': widget.product.id});
    //   final reservationNo = res.data['reservationNumber'] as String?;
    //   → 판매자에게 예약번호 안내(복사) → 편의점 접수 → 운송장번호 자동 반영.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('운송장 등록', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.local_shipping_outlined, color: Color(0xFF16305C)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('"${widget.product.title}" 배송 정보를 등록해요.',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // 낙찰자 배송지 — 이 화면(판매자)에서만 확인할 수 있어요.
          _buildAddressCard(),
          const SizedBox(height: 20),
          const Text('택배사', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _courier,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            items: AppCouriers.names.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _courier = v ?? _courier),
          ),
          const SizedBox(height: 18),
          const Text('송장번호', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '숫자만 입력',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: const Color(0xFF16305C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '등록 중...' : '등록하고 낙찰자에게 알림'),
          ),
        ],
      ),
    );
  }
}

/// 배송 정보(택배사·송장번호)를 보여주고, 복사/배송조회를 할 수 있는 바텀시트예요.
/// 판매자·낙찰자 양쪽에서 재사용해요.
void _showShipmentInfoSheet(BuildContext context, ProductItem product) {
  final courier = product.shippingCourier;
  final number = product.shippingTrackingNumber;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.local_shipping_rounded, color: Color(0xFF16305C)),
                const SizedBox(width: 8),
                Text('배송 정보 · ${product.deliveryStatusLabel}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 16),
              _ShipmentInfoRow(label: '택배사', value: courier.isEmpty ? '아직 등록 전' : courier),
              const SizedBox(height: 8),
              _ShipmentInfoRow(label: '송장번호', value: number.isEmpty ? '아직 등록 전' : number),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: number.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: number));
                            ScaffoldMessenger.of(sheetContext)
                                .showSnackBar(const SnackBar(content: Text('송장번호를 복사했어요.')));
                          },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('번호 복사'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16305C)),
                    onPressed: number.isEmpty
                        ? null
                        : () async {
                            final uri = AppCouriers.trackingSearchUri(courier, number);
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (_) {}
                          },
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('배송조회'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
    },
  );
}

class _ShipmentInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _ShipmentInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    );
  }
}

enum _ShipTone { info, point }

/// 배송이 오래 지연됐을 때(배송 준비 후 7일 경과) 채팅방에 뜨는 안내 메시지예요.
/// 낙찰자에게만 [결제취소]/[배송요청 다시] 버튼을 보여주고, 이미 처리됐거나
/// 판매자가 볼 때는 안내 문구만 표시해요. 상품 문서를 실시간 구독해서 처리
/// 완료(환불/재요청/운송장 등록)되면 버튼이 자동으로 사라져요.
class _ShipDecisionMessage extends StatelessWidget {
  final String? productId;
  final String text;
  final String? currentUid;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onReship;

  const _ShipDecisionMessage({
    required this.productId,
    required this.text,
    required this.currentUid,
    required this.busy,
    required this.onCancel,
    required this.onReship,
  });

  @override
  Widget build(BuildContext context) {
    if (productId == null || productId!.isEmpty) return _card(showButtons: false);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('products').doc(productId).snapshots(),
      builder: (context, snap) {
        var showButtons = false;
        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() ?? const <String, dynamic>{};
          final status = (d['status'] as String?)?.toLowerCase().trim() ?? '';
          final buyerId = (d['winnerId'] ?? d['buyerId']) as String?;
          final tracking = (d['shippingTrackingNumber'] as String?)?.trim() ?? '';
          final requested = d['shipDecisionRequestedAt'];
          final resolved = d['shipDecisionResolvedAt'];
          showButtons = currentUid != null &&
              currentUid == buyerId &&
              status == 'paid' &&
              tracking.isEmpty &&
              requested != null &&
              resolved == null;
        }
        return _card(showButtons: showButtons);
      },
    );
  }

  Widget _card({required bool showButtons}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.schedule_rounded, size: 20, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('배송이 지연되고 있어요', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF9A3412))),
          ]),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600, color: Color(0xFF7C2D12))),
          if (showButtons) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReship,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    side: const BorderSide(color: Color(0xFFFDBA74)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('배송요청 다시', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onCancel,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('결제취소', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// 배송예정일 즈음 낙찰자에게 '상품 받으셨나요?' + [받았어요]/[받지 못했어요] 버튼을
/// 보여줘요. 상품 문서를 실시간 구독해서 배송완료/거래완료가 되면 버튼이 자동으로
/// 사라져요(배송중 상태의 낙찰자에게만 버튼 노출).
class _DeliveryCheckMessage extends StatelessWidget {
  final String? productId;
  final String text;
  final String? currentUid;
  final bool busy;
  final VoidCallback onReceived;
  final VoidCallback onNotReceived;

  const _DeliveryCheckMessage({
    required this.productId,
    required this.text,
    required this.currentUid,
    required this.busy,
    required this.onReceived,
    required this.onNotReceived,
  });

  @override
  Widget build(BuildContext context) {
    if (productId == null || productId!.isEmpty) return _card(showButtons: false);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('products').doc(productId).snapshots(),
      builder: (context, snap) {
        var showButtons = false;
        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() ?? const <String, dynamic>{};
          final status = (d['status'] as String?)?.toLowerCase().trim() ?? '';
          final buyerId = (d['winnerId'] ?? d['buyerId']) as String?;
          // 배송중(shipped)일 때, 낙찰자에게만 수령 확인 버튼을 보여줘요.
          showButtons = currentUid != null && currentUid == buyerId && status == 'shipped';
        }
        return _card(showButtons: showButtons);
      },
    );
  }

  Widget _card({required bool showButtons}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBCFE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.local_shipping_rounded, size: 20, color: Color(0xFFDB2777)),
            SizedBox(width: 8),
            Text('상품을 받으셨나요?', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF9D174D))),
          ]),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600, color: Color(0xFF831843))),
          if (showButtons) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onNotReceived,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBE185D),
                    side: const BorderSide(color: Color(0xFFF9A8D4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('받지 못했어요', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onReceived,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDB2777),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('받았어요', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// 채팅방 안에서 판매자/구매자에게 배송 단계 안내 + 액션 버튼을 보여주는
/// 카드예요. 결제완료 → 배송 준비 → 운송장 등록 흐름을 여기서 이어가요.
class _ShipmentBanner extends StatelessWidget {
  final IconData icon;
  final _ShipTone tone;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;
  // 선택적 보조 버튼(예: '배송조회'와 '상품 받았어요'를 함께 노출).
  final String? secondaryLabel;
  final VoidCallback? secondaryOnPressed;

  const _ShipmentBanner({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.secondaryLabel,
    this.secondaryOnPressed,
  });

  @override
  Widget build(BuildContext context) {
    final point = tone == _ShipTone.point;
    final bg = point ? const Color(0xFFFDF2F8) : const Color(0xFFF1F5FB);
    final border = point ? const Color(0xFFFBCFE8) : const Color(0xFFDCE5F2);
    final accent = point ? const Color(0xFFDB2777) : const Color(0xFF16305C);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: accent))),
          ]),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onPressed,
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          if (secondaryLabel != null && secondaryOnPressed != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: secondaryOnPressed,
                child: Text(secondaryLabel!, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SellingList extends StatefulWidget {
  const _SellingList();

  @override
  State<_SellingList> createState() => _SellingListState();
}

class _SellingListState extends State<_SellingList> {
  bool _selectionMode = false;
  final Set<String> _selectedKeys = <String>{};

  String _keyOf(ProductItem p) => (p.id != null && p.id!.isNotEmpty) ? p.id! : p.title;
  // 입찰이 있는 경매는 삭제할 수 없어요(입찰자 보호). 입찰 0건만 삭제 가능.
  bool _deletable(ProductItem p) => DuckAuctionStore.parseCount(p.bids) == 0;

  void _exitSelection() => setState(() {
        _selectionMode = false;
        _selectedKeys.clear();
      });

  void _navEdit(ProductItem product) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AuctionRegisterScreen(editProduct: product)),
      );

  void _navDetail(ProductItem product) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      );

  /// '수정불가'를 눌렀을 때: 상세 화면으로 이동하면서 수정 불가 사유를 팝업으로
  /// 보여줘요.
  void _navDetailEditBlocked(ProductItem product) {
    final hasBid = DuckAuctionStore.parseCount(product.bids) > 0;
    final reason = hasBid
        ? '이미 입찰이 있어 경매 내용을 수정할 수 없어요.\n입찰자 보호를 위해, 입찰이 시작된 경매는 수정이 제한돼요.'
        : '이미 종료된 경매(${product.statusLabel})라 수정할 수 없어요.';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          entryNoticeTitle: '수정불가 안내',
          entryNoticeText: reason,
        ),
      ),
    );
  }

  Future<void> _showEditDisabledReason(ProductItem product) async {
    final hasBid = DuckAuctionStore.parseCount(product.bids) > 0;
    final reason = hasBid
        ? '이미 입찰이 있어 경매 내용을 수정할 수 없어요.\n입찰자 보호를 위해, 입찰이 시작된 경매는 수정이 제한돼요.'
        : '이미 종료된 경매(${product.statusLabel})라 수정할 수 없어요.';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF334155), size: 20),
            SizedBox(width: 8),
            Text('수정불가 안내', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF16305C))),
          ],
        ),
        content: Text(reason, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF475569))),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF334155)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('경매 삭제', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message, style: const TextStyle(height: 1.55, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('아니오')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('예'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteOne(ProductItem product) async {
    final ok = await _confirmDelete(
      '이 경매를 삭제하시겠습니까?\n삭제하면 더 이상 입찰을 받을 수 없어요.\n(삭제 전에 진행된 입찰이 있으면 삭제할 수 없어요.)',
    );
    if (!ok) return;
    final result = await DuckAuctionStore.deleteProduct(product);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _deleteSelected(List<ProductItem> myProducts) async {
    final targets = myProducts
        .where((p) => _selectedKeys.contains(_keyOf(p)) && _deletable(p))
        .toList();
    if (targets.isEmpty) return;
    final ok = await _confirmDelete(
      '선택한 ${targets.length}건을 삭제하시겠습니까?\n삭제하면 더 이상 입찰을 받을 수 없어요.\n(삭제 전에 진행된 입찰이 있으면 삭제할 수 없어요.)',
    );
    if (!ok) return;
    int deleted = 0;
    int failed = 0;
    for (final p in targets) {
      final r = await DuckAuctionStore.deleteProduct(p);
      if (r.success) {
        deleted++;
      } else {
        failed++;
      }
    }
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failed == 0 ? '$deleted건을 삭제했어요.' : '$deleted건 삭제, $failed건은 삭제하지 못했어요.')),
    );
  }

  // 좁은 그리드 셀에서 쓰는 풀폭 미니 버튼.
  Widget _miniButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool filled = false,
    Color color = const Color(0xFF334155),
  }) {
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
    if (filled) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(34),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: child,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        minimumSize: const Size.fromHeight(34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: child,
    );
  }

  Widget _toolbar(List<ProductItem> myProducts) {
    final deletableKeys = myProducts.where(_deletable).map(_keyOf).toSet();
    final deletableCount = deletableKeys.length;
    if (!_selectionMode) {
      return Row(
        children: [
          OutlinedButton.icon(
            onPressed: deletableCount == 0
                ? null
                : () => setState(() {
                      _selectionMode = true;
                      _selectedKeys.clear();
                    }),
            icon: const Icon(Icons.checklist_rounded, size: 18),
            label: const Text('선택'),
          ),
          const Spacer(),
          Text('삭제 가능 $deletableCount건',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
        ],
      );
    }
    final allSelected = deletableCount > 0 && _selectedKeys.length >= deletableCount;
    return Row(
      children: [
        TextButton(onPressed: _exitSelection, child: const Text('취소')),
        TextButton(
          onPressed: deletableCount == 0
              ? null
              : () => setState(() {
                    if (allSelected) {
                      _selectedKeys.clear();
                    } else {
                      _selectedKeys
                        ..clear()
                        ..addAll(deletableKeys);
                    }
                  }),
          child: Text(allSelected ? '선택 해제' : '전체 선택'),
        ),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            disabledBackgroundColor: const Color(0xFFE7BBBB),
            foregroundColor: Colors.white,
          ),
          onPressed: _selectedKeys.isEmpty ? null : () => _deleteSelected(myProducts),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text('삭제 (${_selectedKeys.length})'),
        ),
      ],
    );
  }

  // 그리드 카드 하단 액션(좁은 셀용, 풀폭 버튼 위주).
  Future<void> _openShipmentRegister(ProductItem product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShipmentRegisterScreen(product: product)),
    );
    // 등록 화면에서 DuckAuctionStore.refreshProductsNow()로 목록이 갱신돼요.
  }

  // 판매 카드 푸터의 고정 높이(버튼 2개 = 34+6+34 기준, 여유 2px). 상태에 따라
  // 버튼이 1~2개로 달라도 이 높이로 통일해서 카드 높이가 카드마다 다르지 않게 해요.
  static const double _kSellFooterHeight = 76;

  Widget _sellFooter(ProductItem product, {required bool isFailed, required bool canEdit}) {
    final status = product.effectiveStatus;
    final Widget content;
    if (isFailed) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniButton(
            label: '경매 연장',
            icon: Icons.update_rounded,
            onPressed: () async {
              final result = await DuckAuctionStore.extendFailedAuction(product);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
            },
          ),
          const SizedBox(height: 6),
          _miniButton(
            label: '새로 등록',
            icon: Icons.add_circle_outline_rounded,
            filled: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AuctionRegisterScreen(editProduct: product, registerAsNew: true)),
            ),
          ),
        ],
      );
    } else if (canEdit) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniButton(label: '수정하기', icon: Icons.edit_outlined, onPressed: () => _navEdit(product)),
          const SizedBox(height: 6),
          _miniButton(
            label: '삭제',
            icon: Icons.delete_outline,
            color: const Color(0xFFDC2626),
            onPressed: () => _deleteOne(product),
          ),
        ],
      );
    } else if (status == 'paid') {
      // 결제 완료 후: 판매자는 운송장을 등록해요.
      content = _miniButton(
        label: '운송장 등록',
        icon: Icons.local_shipping_outlined,
        filled: true,
        onPressed: () => _openShipmentRegister(product),
      );
    } else if (status == 'shipped' || status == 'delivered' || status == 'completed') {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniButton(
            label: '배송 정보',
            icon: Icons.local_shipping_outlined,
            onPressed: () => _showShipmentInfoSheet(context, product),
          ),
          if (status == 'shipped') ...[
            const SizedBox(height: 6),
            _miniButton(
              label: '운송장 수정',
              icon: Icons.edit_outlined,
              color: const Color(0xFF64748B),
              onPressed: () => _openShipmentRegister(product),
            ),
          ],
        ],
      );
    } else {
      // 수정 불가: '수정불가'를 누르면 상세 화면으로 이동하며 사유 팝업을 보여줘요.
      content = _miniButton(
        label: '수정불가',
        icon: Icons.lock_outline,
        color: const Color(0xFF9CA3AF),
        onPressed: () => _navDetailEditBlocked(product),
      );
    }
    // 버튼이 1개든 2개든 푸터 높이를 고정해 카드 높이를 통일해요(내용은 위쪽 정렬).
    return SizedBox(
      height: _kSellFooterHeight,
      child: Align(alignment: Alignment.topCenter, child: content),
    );
  }

  Widget _card(ProductItem product) {
    final hasBid = DuckAuctionStore.parseCount(product.bids) > 0;
    final isFailed = product.effectiveStatus == 'failed';
    final isActive = product.effectiveStatus == 'active';
    final canEdit = isActive && !hasBid;
    final deletable = _deletable(product);
    final key = _keyOf(product);
    final selected = _selectedKeys.contains(key);

    if (_selectionMode) {
      // 선택 모드: 좌측 상단 라디오. 입찰 있는 경매는 선택 불가(막음 표시).
      return Opacity(
        opacity: deletable ? 1.0 : 0.55,
        child: _MyAuctionMiniCard(
          product: product,
          onTap: deletable
              ? () => setState(() {
                    if (selected) {
                      _selectedKeys.remove(key);
                    } else {
                      _selectedKeys.add(key);
                    }
                  })
              : null,
          photoOverlay: Positioned(
            top: 8,
            left: 8,
            child: Container(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: deletable
                  ? Icon(
                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 26,
                      color: selected ? const Color(0xFFDC2626) : const Color(0xFF9CA3AF),
                    )
                  : const Icon(Icons.block, size: 24, color: Color(0xFFCBD5E1)),
            ),
          ),
          footer: AbsorbPointer(child: _sellFooter(product, isFailed: isFailed, canEdit: canEdit)),
        ),
      );
    }

    return _MyAuctionMiniCard(
      product: product,
      onTap: () => _navDetail(product),
      photoOverlay: Positioned(top: 8, right: 8, child: _StatusBadge(product: product)),
      footer: _sellFooter(product, isFailed: isFailed, canEdit: canEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ValueListenableBuilder<List<ProductItem>>(
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
            onPressed: () async {
              if (await _needsTradeVerification()) {
                final ready = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const TradeReadinessScreen()),
                );
                if (ready != true || !context.mounted) return;
              }
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuctionRegisterScreen()),
              );
            },
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _toolbar(myProducts),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ResponsiveContentBounds(
                    // 태블릿에서도 가운데로 좁게 몰리지 않고 화면 폭을 꽉 채워요.
                    maxWidth: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: ResponsiveCardFlow(
                      spacing: 12,
                      runSpacing: 12,
                      phoneColumns: 2,
                      tabletColumns: 3,
                      children: myProducts.map(_card).toList(),
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
}

/// 내가 입찰(일반 입찰 또는 예약입찰)한 적 있는 경매 목록입니다.
/// products 문서의 bidderIds 배열(입찰/예약입찰 시마다 arrayUnion으로 기록)을
/// 기준으로 조회해서, 지금 내가 1위인지 아닌지를 바로 보여줍니다.
/// 내 경매 관리(판매/입찰)에서 쓰는 세로형 카드 — 사진 위, 내용 아래.
/// 홈 카드와 같은 그리드 스타일을 유지하되 하단에 관리용 액션(footer)을 붙여요.
class _MyAuctionMiniCard extends StatelessWidget {
  final ProductItem product;
  final Widget? footer;
  final Widget? photoOverlay; // 사진 Stack 위에 얹을 Positioned 위젯
  final VoidCallback? onTap;

  const _MyAuctionMiniCard({
    required this.product,
    this.footer,
    this.photoOverlay,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 118,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFFF4F5F8),
                    child: ProductPhoto(product: product, fontSize: 40),
                  ),
                ),
                if (photoOverlay != null) photoOverlay!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 3),
                Text(
                  '현재가 ${product.price}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
          if (footer != null)
            Padding(padding: const EdgeInsets.fromLTRB(8, 2, 8, 8), child: footer!),
        ],
      ),
    );
    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}

class _BiddingList extends StatelessWidget {
  final String? userId;

  const _BiddingList({required this.userId});

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    if (uid == null) {
      return const _MyEmptyList(
        icon: Icons.gavel_outlined,
        title: '로그인 후 이용할 수 있어요',
        description: '입찰한 경매를 확인하려면 로그인해주세요.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('bidderIds', arrayContains: uid)
          .orderBy('updatedAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                '입찰한 경매를 불러오지 못했어요. 잠시 후 다시 시도해주세요.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!.docs.map((doc) => ProductItem.fromFirestore(doc)).toList();

        if (products.isEmpty) {
          return const _MyEmptyList(
            icon: Icons.gavel_outlined,
            title: '입찰한 경매가 없어요',
            description: '관심 있는 경매에 입찰하거나 예약입찰을 걸면 여기에서 순위를 확인할 수 있어요.',
          );
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            ResponsiveContentBounds(
              // 태블릿에서도 가운데로 좁게 몰리지 않고 화면 폭을 꽉 채워요.
              maxWidth: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: ResponsiveCardFlow(
                spacing: 12,
                runSpacing: 12,
                phoneColumns: 2,
                tabletColumns: 3,
                children: products.map((product) {
                  final isFailed = product.effectiveStatus == 'failed';
                  final isEnded = !product.isAuctionActive;
                  final footer = _bidCardFooter(
                    context,
                    product: product,
                    uid: uid,
                    isEnded: isEnded,
                    isFailed: isFailed,
                  );

                  return _MyAuctionMiniCard(
                    product: product,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                    ),
                    footer: footer,
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 입찰 목록 카드의 하단 영역이에요. 모든 카드가 [상태 칩 + 액션 버튼]으로
  /// 높이가 같아지도록 통일했어요. 상태에 따라 버튼이 상위입찰하기/결제하기/
  /// 배송조회 등으로 바뀌어요.
  Widget _bidCardFooter(
    BuildContext context, {
    required ProductItem product,
    required String uid,
    required bool isEnded,
    required bool isFailed,
  }) {
    final status = product.effectiveStatus;
    final winnerUid = product.winnerId ?? product.lastBidUserId;
    final isWinner = winnerUid == uid;
    final isLeading = product.lastBidUserId == uid;

    // 칩(상태) + 버튼(라벨/색/동작/활성)을 상태별로 정해요.
    String chipText;
    Color chipBg;
    Color chipFg;
    String btnLabel;
    IconData btnIcon;
    bool btnEnabled = true;
    VoidCallback? onPressed;

    const green = Color(0xFF15803D), greenBg = Color(0xFFF0FDF4);
    const orange = Color(0xFFC2410C), orangeBg = Color(0xFFFFF7ED);
    const blue = Color(0xFF1D4ED8), blueBg = Color(0xFFEFF6FF);
    const slate = Color(0xFF475569), slateBg = Color(0xFFF1F5F9);

    if (isWinner &&
        (status == 'paid' || status == 'shipped' || status == 'delivered' ||
            status == 'completed' || status == 'cancelled')) {
      // 결제 이후 단계(구매자 흐름).
      chipText = product.buyerFlowLabel;
      chipBg = blueBg;
      chipFg = blue;
      if (status == 'cancelled') {
        chipBg = slateBg;
        chipFg = slate;
        btnLabel = '결제취소됨';
        btnIcon = Icons.cancel_outlined;
        btnEnabled = false;
      } else if (status == 'delivered') {
        // 배송완료 → 카드에서 바로 구매확정할 수 있어요(상세로 안 들어가도 됨).
        btnLabel = '구매확정';
        btnIcon = Icons.verified_rounded;
        onPressed = () => _confirmPurchaseFromCard(context, product);
      } else {
        btnLabel = product.hasShipment ? '배송조회' : '배송정보';
        btnIcon = Icons.local_shipping_outlined;
        onPressed = () => _showShipmentInfoSheet(context, product);
      }
    } else if (isWinner &&
        isEnded &&
        (status == 'winner_pending' || status == 'second_pending' ||
            status == 'third_pending' || status == 'sold' || status == 'ended')) {
      // 낙찰됐고 결제가 필요한 단계 → 카드에서 바로 결제.
      chipText = '낙찰됐어요';
      chipBg = greenBg;
      chipFg = green;
      btnLabel = '결제하기';
      btnIcon = Icons.credit_card_rounded;
      onPressed = () => _openCheckoutFromCard(context, product);
    } else if (!isEnded) {
      // 진행 중인 경매.
      if (isLeading) {
        chipText = '최고 입찰 중';
        chipBg = greenBg;
        chipFg = green;
        btnLabel = '경매 보기';
        btnIcon = Icons.visibility_outlined;
      } else {
        chipText = '순위가 밀렸어요';
        chipBg = orangeBg;
        chipFg = orange;
        btnLabel = '상위입찰하기';
        btnIcon = Icons.trending_up_rounded;
      }
      // 순위가 밀린 경우(!isLeading) 상세로 이동하며 하단 입찰 영역을 자동으로
      // 열어줘요. 최고 입찰 중이면 그냥 상세 보기.
      onPressed = () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product, autoOpenBid: !isLeading),
            ),
          );
    } else if (isFailed) {
      // 유찰.
      chipText = '유찰됐어요';
      chipBg = slateBg;
      chipFg = slate;
      btnLabel = '유찰됨';
      btnIcon = Icons.block_outlined;
      btnEnabled = false;
    } else {
      // 마감됐는데 내가 낙찰자가 아님(순위 밀림 + 마감). 눌러도 되고, 상세로
      // 이동하면 '마감돼서 상위입찰 불가' 사유 팝업을 보여줘요.
      chipText = '순위가 밀렸어요';
      chipBg = orangeBg;
      chipFg = orange;
      btnLabel = '상위입찰하기';
      btnIcon = Icons.trending_up_rounded;
      onPressed = () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product, autoOpenBid: true),
            ),
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
            child: Text(
              chipText.isEmpty ? '입찰 중' : chipText,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: chipFg),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: const Color(0xFF16305C),
              disabledForegroundColor: const Color(0xFF94A3B8),
              side: BorderSide(color: btnEnabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: btnEnabled ? onPressed : null,
            icon: Icon(btnIcon, size: 15),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(btnLabel, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }

  /// 낙찰 카드(배송완료 상태)에서 상세로 안 들어가고 바로 구매확정해요.
  Future<void> _confirmPurchaseFromCard(BuildContext context, ProductItem product) async {
    final productId = product.id;
    if (productId == null || productId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('구매를 확정할까요?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('구매확정 후에는 거래가 완료돼요. 상품을 충분히 확인한 뒤 진행해주세요.', style: TextStyle(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('닫기')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('구매확정'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFunctions.instance.httpsCallable('confirmPurchase').call<Map<String, dynamic>>({'productId': productId});
      await DuckAuctionStore.refreshProductsNow();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구매확정이 완료됐어요. 거래가 종료됐어요. 🎉')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구매확정에 실패했어요. 잠시 후 다시 시도해주세요.\n$e')),
        );
      }
    }
  }

  /// 낙찰 카드에서 상세로 들어가지 않고 바로 토스 결제창을 열어요.
  Future<void> _openCheckoutFromCard(BuildContext context, ProductItem product) async {
    final base = product.currentPrice > 0 ? product.currentPrice : _digitsToInt(product.price);
    final amount = base + product.shippingFee;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제 금액을 확인할 수 없어요.')),
      );
      return;
    }
    if (amount > kPgMaxPayableAmount) {
      // 국내 PG 결제금액 한도(약 21.4억) 초과 → 이니시스 원문 에러 대신 친절히 안내.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제 가능 금액을 초과했어요. 이 금액은 카드 결제로 진행할 수 없어요.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    final pid = (product.id == null || product.id!.isEmpty) ? 'NA' : product.id!;
    final orderId = '${pid}_${DateTime.now().millisecondsSinceEpoch}';
    // 웹은 웹뷰가 없으므로 결제 페이지(pay.html)로 이동해 이니시스 결제창을 띄워요.
    if (kIsWeb) {
      await DuckAuctionStore.startWebCheckout(
        orderId: orderId,
        orderName: product.title,
        amount: amount,
        productId: product.id,
      );
      return;
    }
    final result = await Navigator.of(context).push<TossPaymentResult>(
      MaterialPageRoute(
        builder: (_) => TossCheckoutScreen(
          orderId: orderId,
          orderName: product.title,
          amount: amount,
          customerName: user?.displayName ?? '덕옥션 회원',
          customerKey: user?.uid,
          productId: product.id,
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    if (result.success) {
      await DuckAuctionStore.refreshProductsNow();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결제가 완료됐어요. 판매자와 배송 정보를 확인해주세요.')),
        );
      }
    } else if (result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message!)));
    }
  }

  static int _digitsToInt(String value) {
    final digits = RegExp(r'\d+').allMatches(value).map((m) => m.group(0)!).join();
    return int.tryParse(digits) ?? 0;
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

/// 좁은 카드처럼 텍스트 없이 이모지만 필요한 자리에서 쓰는 버전.
/// 등록되지 않은 id면 null.
String? sellerBadgeEmoji(String id) {
  for (final badge in kSellerBadgeOptions) {
    if (badge['id'] == id) return badge['emoji'];
  }
  return null;
}

/// 각 배지를 여는 조건 설명이에요(잠긴 배지를 눌렀을 때 안내로 보여줘요).
const Map<String, String> kSellerBadgeCriteria = {
  'new_seller': '가입하면 바로 받는 기본 배지예요.',
  'first_sale': '첫 판매를 완료하면 열려요.',
  'sales_10': '판매 10회를 완료하면 열려요.',
  'sales_50': '판매 50회를 완료하면 열려요.',
  'veteran_seller': '판매 100회를 달성하면 열려요.',
  'honest_seller': '판매 30건 이상을 무사히 완료하면 열려요.',
  'review_star': '평점 4.5 이상 + 후기 5개 이상이면 열려요.',
  'popular_seller': '팔로워 30명을 달성하면 열려요.',
  'fast_shipping': '결제 후 24시간 내 발송 비율이 높으면 열려요. (집계 준비 중이에요)',
  'fast_reply': '채팅 첫 응답이 빠르면 열려요. (집계 준비 중이에요)',
};

/// 판매자 통계로 "실제로 획득한" 배지 집합을 계산합니다.
/// 마스터 계정은 기준과 무관하게 모든 배지를 가집니다. 그 외 계정은
/// 아래 기준을 충족한 배지만 받아요. (fast_shipping·fast_reply는 발송/응답
/// 집계 기능이 아직 없어 지금은 마스터 외에는 열리지 않습니다.)
Set<String> computeEarnedSellerBadges({
  required bool isMaster,
  required int completedSales,
  required int reviewCount,
  required double rating,
  required int followerCount,
}) {
  if (isMaster) return kSellerBadgeOptions.map((b) => b['id']!).toSet();
  final earned = <String>{'new_seller'};
  if (completedSales >= 1) earned.add('first_sale');
  if (completedSales >= 10) earned.add('sales_10');
  if (completedSales >= 30) earned.add('honest_seller');
  if (completedSales >= 50) earned.add('sales_50');
  if (completedSales >= 100) earned.add('veteran_seller');
  if (reviewCount >= 5 && rating >= 4.5) earned.add('review_star');
  if (followerCount >= 30) earned.add('popular_seller');
  return earned;
}

/// 목록 카드에 실제로 보여줄 판매자 배지 id 목록(최대 3개).
/// 판매 수 기반 배지(첫판매·10·30·50·100회)는 상품에 저장된 '실제 판매 수'로
/// 다시 검증해서, 오래된/과장된 배지가 여러 개 뜨는 걸 막아요. 반면 후기·팔로워
/// 기반 배지는 상품에 통계가 없으므로, 등록 시점에 판매자가 설정한 값을 그대로
/// 신뢰해 표시해요(설정해둔 배지는 유지). 마이페이지에서 배지를 저장할 때 이미
/// '획득한 배지만' 저장되므로, 이 조합이면 보유·설정한 배지만 정확히 보여요.
List<String> sellerCardBadgeIds(ProductItem product) {
  final earned = computeEarnedSellerBadges(
    isMaster: false,
    completedSales: product.sellerSalesCount,
    reviewCount: 1 << 20, // 후기·팔로워 기반 배지는 설정값을 신뢰(카드에 통계가 없음)
    rating: 5.0,
    followerCount: 1 << 20,
  );
  return product.sellerBadgeIds.where(earned.contains).take(3).toList();
}

/// users 문서 데이터에서 통계를 뽑아 획득 배지 집합을 계산하는 편의 함수예요.
/// (현재 로그인 사용자 본인의 문서에 대해 사용합니다.)
Set<String> earnedSellerBadgesFromData(Map<String, dynamic> data) {
  return computeEarnedSellerBadges(
    isMaster: DuckAuctionStore.isMasterAdmin,
    completedSales: (data['completedTradeCount'] as num?)?.toInt() ?? 0,
    reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
    rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
    followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
  );
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
  Set<String> _earnedBadges = <String>{'new_seller'}; // 이 계정이 실제로 획득한 배지(잠금 판정용)
  Uint8List? _newImageBytes;
  String? _profileImageUrl;
  String _originalNickname = ''; // 저장 시 이전 닉네임 예약을 반납하기 위해 보관해요.
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
      _originalNickname = _nicknameController.text;
      _introController.text = (data['sellerIntro'] as String?) ?? '';
      _profileImageUrl = data['profileImageUrl'] as String?;
      _earnedBadges = earnedSellerBadgesFromData(data);
      // 획득한 배지만 선택 상태로 불러와요(기준 미달인데 저장돼 있던 건 버려요).
      final badges = (data['sellerBadges'] as List?)?.whereType<String>().where(_earnedBadges.contains).take(3) ?? const <String>[];
      _selectedBadges.addAll(badges);
    } catch (_) {
      _nicknameController.text = user.displayName ?? '덕친';
      _originalNickname = _nicknameController.text;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final source = await pickImageSourceSheet(context);
    if (source == null) return;
    final image = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 900);
    if (image == null) return;
    final bytes = await cropPickedImage(image, aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1));
    if (bytes == null) return;
    if (mounted) setState(() => _newImageBytes = bytes);
  }

  void _toggleBadge(String id) {
    // 아직 획득하지 못한(잠긴) 배지는 선택할 수 없어요 — 조건을 안내해요.
    if (!_earnedBadges.contains(id)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(kSellerBadgeCriteria[id] ?? '아직 획득하지 못한 배지예요.'),
          duration: const Duration(milliseconds: 1400),
        ));
      return;
    }
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
      // 닉네임 중복 예약을 먼저 확보합니다(변경 시 이전 닉네임은 반납).
      // 이미 다른 사람이 쓰는 닉네임이면 여기서 막고 저장하지 않아요.
      try {
        await AuthService.reserveNickname(
          uid: user.uid,
          nickname: nickname,
          previousNickname: _originalNickname,
        );
      } on NicknameTakenException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('이미 사용 중인 닉네임이에요. 다른 닉네임을 입력해주세요.')));
          setState(() => _saving = false);
        }
        return;
      }
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
        'sellerBadges': _selectedBadges.where(_earnedBadges.contains).toList(),
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

  // 원형 아바타를 가장 확실하게 채우는 방식(DecorationImage)으로 이미지를
  // 만들어줘요. 이미지가 없으면 null을 돌려 🐥 이모지를 대신 보여줍니다.
  DecorationImage? _editAvatarImage() {
    if (_newImageBytes != null) {
      return DecorationImage(image: MemoryImage(_newImageBytes!), fit: BoxFit.cover);
    }
    if ((_profileImageUrl ?? '').trim().isNotEmpty) {
      return DecorationImage(image: NetworkImage(_profileImageUrl!.trim()), fit: BoxFit.cover);
    }
    return null;
  }

  Widget _avatar() {
    if (_newImageBytes != null) return SizedBox.expand(child: Image.memory(_newImageBytes!, fit: BoxFit.cover));
    if ((_profileImageUrl ?? '').isNotEmpty) {
      return SizedBox.expand(
        child: Image.network(_profileImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🐥', style: TextStyle(fontSize: 48)))),
      );
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
              padding: EdgeInsets.zero,
              children: [
                ResponsiveContentBounds(
                  maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF1F5F9), border: Border.all(color: Colors.white, width: 4), image: _editAvatarImage(), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 16)]),
                        child: _editAvatarImage() == null ? const Center(child: Text('🐥', style: TextStyle(fontSize: 48))) : null,
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
                const Text('조건을 달성한 배지만 선택할 수 있어요. 잠긴(🔒) 배지를 누르면 여는 조건을 알려드려요.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kSellerBadgeOptions.map((badge) {
                    final id = badge['id']!;
                    final locked = !_earnedBadges.contains(id);
                    final selected = _selectedBadges.contains(id) && !locked;
                    return FilterChip(
                      selected: selected,
                      onSelected: (_) => _toggleBadge(id),
                      labelStyle: locked ? const TextStyle(color: Color(0xFF94A3B8)) : null,
                      avatar: Text(locked ? '🔒' : badge['emoji']!),
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
              ]),
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
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                ResponsiveContentBounds(
                  maxWidth: context.responsive(phone: double.infinity, tablet: 760.0),
                  padding: const EdgeInsets.all(16),
                  child: ResponsiveCardFlow(
                    spacing: 10,
                    runSpacing: 10,
                    children: available.map((product) {
                final isSeller = product.sellerId == userUid;
                return Container(
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
              }).toList(),
                  ),
                ),
              ],
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
        return ListView(padding: EdgeInsets.zero, children: [
          ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
            padding: const EdgeInsets.all(16),
            child: Column(children: reviews.map((r) => ReviewCard(review: r, showReport: false)).toList()),
          ),
        ]);
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
      body: ListView(padding: EdgeInsets.zero, children: [
        ResponsiveContentBounds(
          maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
          padding: const EdgeInsets.all(16),
          child: Column(children: [
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
        ),
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
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              ResponsiveContentBounds(
                maxWidth: context.responsive(phone: double.infinity, tablet: 760.0),
                padding: const EdgeInsets.all(16),
                child: ResponsiveCardFlow(
                  spacing: 12,
                  runSpacing: 12,
                  children: docs.map((doc) {
              final data = doc.data();
              final status = (data['status'] as String?) ?? 'received';
              final statusText = {'received':'접수','reviewing':'검토중','rejected':'기각','hidden':'처리완료','deleted':'처리완료','warned':'처리완료','complete':'처리완료'}[status] ?? '접수';
              return Container(
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
            }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(BuildContext context, String uid, String otherUid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'blockedUsers': FieldValue.arrayRemove([otherUid]),
      }, SetOptions(merge: true));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단을 해제했어요.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('처리하지 못했어요: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: _LoginRequiredContent(icon: Icons.block_outlined, title: '차단 관리는 로그인 후 이용할 수 있어요', description: '로그인하면 차단한 사용자를 관리할 수 있어요.'));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('차단 관리')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final blocked = (snapshot.data!.data()?['blockedUsers'] as List?)?.whereType<String>().toList() ?? <String>[];
          if (blocked.isEmpty) {
            return const _PlaceholderContent(icon: Icons.block_outlined, title: '차단한 사용자가 없어요', description: '채팅방 상단의 차단 버튼으로 특정 사용자를 차단할 수 있어요.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: blocked.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final otherUid = blocked[index];
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
                builder: (context, userSnap) {
                  final name = userSnap.data?.data()?['nickname'] as String? ?? '알 수 없는 사용자';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Row(children: [
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                      TextButton(onPressed: () => _unblock(context, user.uid, otherUid), child: const Text('차단 해제')),
                    ]),
                  );
                },
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
        title: const Text('최근 본 경매'),
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.recentViewedProducts,
        builder: (context, products, _) {
          if (products.isEmpty) {
            return const _MyEmptyList(
              icon: Icons.remove_red_eye_outlined,
              title: '최근 본 경매가 없어요',
              description: '경매 상세화면을 열면 최근 본 경매로 저장돼요.',
            );
          }

          // 홈 카드와 동일한 그리드 스타일로 통일.
          return AuctionCardGrid(products: products);
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
  bool _notificationPrefsLoaded = false;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    final push = await AuthService.isPushNotificationEnabled();
    final marketing = await AuthService.isMarketingNotificationEnabled();
    if (!mounted) return;
    setState(() {
      _pushEnabled = push;
      _marketingEnabled = marketing;
      _notificationPrefsLoaded = true;
    });
  }

  Future<void> _editAddress() async {
    final saved = await showAddressEditSheet(context);
    if (saved && mounted) setState(() {});
  }

  void _showLegalDetail(_LegalContent content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(content.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      content.body,
                      style: const TextStyle(color: Color(0xFF475569), height: 1.55, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmedWarning = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 탈퇴하시겠어요?'),
        content: Text(
          '탈퇴 시 프로필 정보가 삭제되고, 등록한 경매는 숨김 처리되어 더 이상 다른 사용자에게 노출되지 않아요.\n'
          '진행 중인 거래나 채팅 기록은 상대방 보호를 위해 남아있을 수 있으며, 이 작업은 되돌릴 수 없어요.\n\n'
          '탈퇴 후 ${AuthService.rejoinCooldown.inDays}일 동안은 같은 이메일로 다시 가입할 수 없어요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('탈퇴할래요', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmedWarning != true || !mounted) return;

    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비밀번호 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('본인 확인을 위해 비밀번호를 입력해주세요.'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    passwordController.dispose();

    if (password == null || password.trim().isEmpty || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      // deleteAccount() 이후에는 currentUser가 null이 되어 기기 토큰을 지울 수
      // 없으므로, 반드시 탈퇴 처리 "전"에 먼저 지웁니다.
      await PushNotificationService.instance.removeTokenOnLogout();
      await AuthService.deleteAccount(password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원 탈퇴가 완료됐어요. 그동안 덕옥션을 이용해주셔서 감사합니다.')),
      );
      widget.onLogout();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'wrong-password' || 'invalid-credential' => '비밀번호가 올바르지 않아요.',
        'requires-recent-login' => '보안을 위해 다시 로그인한 후 탈퇴를 진행해주세요.',
        _ => '탈퇴 처리 중 오류가 발생했어요. 다시 시도해주세요.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('탈퇴 처리 중 오류가 발생했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
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
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: user == null ? null : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  final address1 = (snapshot.data?.data()?['address'] as Map?)?['address1'] as String?;
                  final hasAddress = (address1 ?? '').trim().isNotEmpty;
                  return ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: const Text('배송지 관리'),
                    subtitle: Text(hasAddress ? '등록됨' : '등록된 배송지가 없어요. 낙찰 후 상대방과 주소를 공유하려면 미리 등록해두세요.'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: _editAddress,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: '알림',
            children: [
              SwitchListTile(
                value: _pushEnabled,
                onChanged: !_notificationPrefsLoaded
                    ? null
                    : (value) {
                        setState(() => _pushEnabled = value);
                        AuthService.setPushNotificationEnabled(value);
                        if (value) {
                          PushNotificationService.instance.enable();
                        } else {
                          PushNotificationService.instance.disable();
                        }
                      },
                title: const Text('입찰/낙찰 알림'),
                subtitle: const Text('새 입찰, 낙찰, 결제 순번, 채팅 메시지를 알려드려요.'),
              ),
              SwitchListTile(
                value: _marketingEnabled,
                onChanged: !_notificationPrefsLoaded
                    ? null
                    : (value) {
                        setState(() => _marketingEnabled = value);
                        AuthService.setMarketingNotificationEnabled(value);
                      },
                title: const Text('이벤트/마케팅 알림'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: '약관 및 정책',
            children: [
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('서비스 이용약관'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () => _showLegalDetail(_LegalContent.terms),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('개인정보처리방침'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () => _showLegalDetail(_LegalContent.privacy),
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
                subtitle: Text('v1.0.0'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            onPressed: widget.onLogout,
            child: const Text('로그아웃'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFFECACA)),
            ),
            onPressed: _deletingAccount ? null : _confirmDeleteAccount,
            child: Text(_deletingAccount ? '탈퇴 처리 중...' : '회원 탈퇴'),
          ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _LegalContent {
  final String title;
  final String body;

  const _LegalContent({required this.title, required this.body});

  static const terms = _LegalContent(
    title: '서비스 이용약관',
    body: kTermsOfServiceText,
  );

  static const privacy = _LegalContent(
    title: '개인정보처리방침',
    body: kPrivacyPolicyText,
  );
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
