part of '../home_screen.dart';

class _SearchBox extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onCameraTap;

  const _SearchBox({required this.onTap, required this.onCameraTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF6B7280)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '찾고 싶은 경매를 검색해보세요',
                  style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '사진으로 검색',
                onPressed: onCameraTap,
                icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductSearchScreen extends StatefulWidget {
  final bool startWithCamera;

  const ProductSearchScreen({super.key, this.startWithCamera = false});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

enum _SearchSort { latest, deadline, priceLow, priceHigh, popular }

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  static const _recentKey = 'duck_auction_recent_searches_v2';
  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _searchImageBytes;
  String _query = '';
  bool _imageSearchMode = false;
  bool _activeOnly = true;
  bool _freeShippingOnly = false;
  _SearchSort _sort = _SearchSort.latest;
  List<String> _recentSearches = const [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    if (widget.startWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickSearchImage());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _recentSearches = prefs.getStringList(_recentKey) ?? const []);
  }

  Future<void> _saveSearch(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    final next = <String>[query, ..._recentSearches.where((item) => _duckNormalize(item) != _duckNormalize(query))].take(10).toList();
    setState(() => _recentSearches = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, next);

    try {
      final normalized = _duckNormalize(query);
      final ref = FirebaseFirestore.instance.collection('searchKeywords').doc(normalized);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final current = (snapshot.data()?['count'] as num?)?.toInt() ?? 0;
        transaction.set(ref, {
          'keyword': query,
          'normalizedKeyword': normalized,
          'count': current + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // 검색 자체는 통계 저장 실패와 무관하게 계속 동작한다.
    }
  }

  Future<void> _removeRecent(String value) async {
    final next = _recentSearches.where((item) => item != value).toList();
    setState(() => _recentSearches = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, next);
  }

  Future<void> _clearRecent() async {
    setState(() => _recentSearches = const []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }

  void _applyQuery(String value, {bool save = true}) {
    final query = value.trim();
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    setState(() {
      _query = query;
      _imageSearchMode = false;
      _searchImageBytes = null;
    });
    if (save) _saveSearch(query);
  }

  List<ProductItem> _allProducts(List<ProductItem> registeredAuctions) {
    final merged = <ProductItem>[...registeredAuctions, ...HomeTab.popularProducts, ...HomeTab.recentProducts];
    final seen = <String>{};
    return merged.where((product) => seen.add(product.id?.isNotEmpty == true ? product.id! : '${product.title}_${product.sellerName}')).toList();
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

  List<ProductItem> _filteredProducts(List<ProductItem> products) {
    var result = products.where((product) {
      if (_activeOnly && !product.isAuctionActive) return false;
      if (_freeShippingOnly && product.shippingFee > 0) return false;
      return true;
    }).toList();

    if (_imageSearchMode) {
      result.sort((a, b) {
        final aPhoto = a.resolvedImageUrls.isNotEmpty || a.imageBytes != null || a.imageBytesList.isNotEmpty;
        final bPhoto = b.resolvedImageUrls.isNotEmpty || b.imageBytes != null || b.imageBytesList.isNotEmpty;
        return (bPhoto ? 1 : 0).compareTo(aPhoto ? 1 : 0);
      });
      return result;
    }

    final query = _query.trim();
    if (query.isNotEmpty) {
      result = result.where((product) {
        final target = [
          product.title,
          product.description,
          product.category,
          product.sellerName,
          product.condition,
          ...product.tags,
        ].join(' ');
        return _duckSearchMatch(target, query) || _duckLooseSearchMatch(target, query);
      }).toList();
    }

    switch (_sort) {
      case _SearchSort.latest:
        result.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        break;
      case _SearchSort.deadline:
        result.sort((a, b) => (a.endAt ?? DateTime(2999)).compareTo(b.endAt ?? DateTime(2999)));
        break;
      case _SearchSort.priceLow:
        result.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
        break;
      case _SearchSort.priceHigh:
        result.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
        break;
      case _SearchSort.popular:
        result.sort((a, b) => _popularityOf(b).compareTo(_popularityOf(a)));
        break;
    }
    return result;
  }

  List<String> _suggestions(List<ProductItem> products) {
    final query = _query.trim();
    if (query.isEmpty) return const [];
    final candidates = <String>{};
    for (final product in products) {
      candidates.add(product.title.trim());
      candidates.add(product.category.trim());
      candidates.add(product.sellerName.trim());
      candidates.addAll(product.tags.map((tag) => tag.trim()));
    }
    candidates.removeWhere((value) => value.isEmpty || !_duckSearchMatch(value, query));
    final list = candidates.toList();
    list.sort((a, b) {
      final an = _duckNormalize(a);
      final bn = _duckNormalize(b);
      final qn = _duckNormalize(query);
      final aStarts = an.startsWith(qn) ? 0 : 1;
      final bStarts = bn.startsWith(qn) ? 0 : 1;
      if (aStarts != bStarts) return aStarts.compareTo(bStarts);
      return a.length.compareTo(b.length);
    });
    return list.take(6).toList();
  }

  Future<void> _pickSearchImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _searchImageBytes = bytes;
        _imageSearchMode = true;
        _query = '';
        _searchController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했어요.')));
    }
  }

  void _clearImageSearch() {
    setState(() {
      _searchImageBytes = null;
      _imageSearchMode = false;
    });
  }

  String _sortLabel(_SearchSort value) {
    switch (value) {
      case _SearchSort.latest: return '최신순';
      case _SearchSort.deadline: return '마감 임박순';
      case _SearchSort.priceLow: return '낮은 가격순';
      case _SearchSort.priceHigh: return '높은 가격순';
      case _SearchSort.popular: return '인기순';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFF5F6F8), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF6B7280), size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: !widget.startWithCamera,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(hintText: '경매명, 태그, 판매자, ㅊㅇㅋ 검색', border: InputBorder.none, isDense: true),
                  onSubmitted: (value) => _applyQuery(value),
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                      _imageSearchMode = false;
                      _searchImageBytes = null;
                    });
                  },
                ),
              ),
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: '검색어 지우기',
                  onPressed: () => _applyQuery('', save: false),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                ),
              IconButton(tooltip: '사진 검색', onPressed: _pickSearchImage, icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF4B5563))),
            ],
          ),
        ),
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.registeredAuctions,
        builder: (context, registeredAuctions, _) {
          final allProducts = _allProducts(registeredAuctions);
          final products = _filteredProducts(allProducts);
          final suggestions = _suggestions(allProducts);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (_query.trim().isNotEmpty && suggestions.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Column(
                    children: suggestions.map((suggestion) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.north_west_rounded, size: 18),
                      title: Text(suggestion, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _applyQuery(suggestion),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_query.trim().isEmpty && !_imageSearchMode) ...[
                _SearchLandingSection(
                  recentSearches: _recentSearches,
                  onTapRecent: _applyQuery,
                  onRemoveRecent: _removeRecent,
                  onClearRecent: _clearRecent,
                  onTapPopular: _applyQuery,
                ),
                const SizedBox(height: 14),
              ],
              if (_imageSearchMode) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _searchImageBytes == null
                            ? Container(width: 56, height: 56, color: const Color(0xFFF3F4F6), child: const Icon(Icons.image_outlined))
                            : Image.memory(_searchImageBytes!, width: 56, height: 56, fit: BoxFit.cover, filterQuality: FilterQuality.high),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('사진 검색은 앱 실기기 단계에서 이미지 유사도 기능을 연결할 예정이에요. 현재는 사진이 있는 진행 중 경매를 우선 보여줘요.', style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF4B5563), fontWeight: FontWeight.w700))),
                      IconButton(onPressed: _clearImageSearch, icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  FilterChip(label: const Text('진행 중만'), selected: _activeOnly, onSelected: (value) => setState(() => _activeOnly = value)),
                  const SizedBox(width: 8),
                  FilterChip(label: const Text('무료배송'), selected: _freeShippingOnly, onSelected: (value) => setState(() => _freeShippingOnly = value)),
                  const Spacer(),
                  PopupMenuButton<_SearchSort>(
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (_) => _SearchSort.values.map((value) => PopupMenuItem(value: value, child: Text(_sortLabel(value)))).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_sortLabel(_sort), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 5), const Icon(Icons.expand_more, size: 18)]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _imageSearchMode ? '사진 검색 결과 ${products.length}개' : _query.trim().isEmpty ? '전체 경매 ${products.length}개' : '경매 검색 결과 ${products.length}개',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (products.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: const Column(children: [Icon(Icons.search_off, size: 42, color: Color(0xFFB8BBC2)), SizedBox(height: 10), Text('검색 결과가 없어요', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('초성, 경매명 일부, 태그 또는 판매자명으로 다시 검색해보세요.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280)))]),
                )
              else
                ...products.map((product) => ProductListTile(product: product)),
              if (_query.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                _SellerSearchResults(query: _query),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SearchLandingSection extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onTapRecent;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onTapPopular;

  const _SearchLandingSection({required this.recentSearches, required this.onTapRecent, required this.onRemoveRecent, required this.onClearRecent, required this.onTapPopular});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('최근 검색', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
        if (recentSearches.isNotEmpty) TextButton(onPressed: onClearRecent, child: const Text('전체 삭제')),
      ]),
      if (recentSearches.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('최근 검색어가 없어요.', style: TextStyle(color: Color(0xFF94A3B8))))
      else
        Wrap(spacing: 8, runSpacing: 8, children: recentSearches.map((term) => InputChip(label: Text(term), onPressed: () => onTapRecent(term), onDeleted: () => onRemoveRecent(term))).toList()),
      const SizedBox(height: 18),
      const Text('인기 검색', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('searchKeywords').orderBy('count', descending: true).limit(8).snapshots(),
        builder: (context, snapshot) {
          final terms = snapshot.data?.docs.map((doc) => (doc.data()['keyword'] as String? ?? '').trim()).where((term) => term.isNotEmpty).toList() ?? const <String>[];
          final values = terms.isEmpty ? const ['치이카와', '피규어', '인형', '굿즈'] : terms;
          return Wrap(spacing: 8, runSpacing: 8, children: values.asMap().entries.map((entry) => ActionChip(avatar: CircleAvatar(radius: 10, backgroundColor: const Color(0xFFFFEEF3), child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 10, color: Color(0xFFE91E63), fontWeight: FontWeight.w900))), label: Text(entry.value), onPressed: () => onTapPopular(entry.value))).toList());
        },
      ),
    ]);
  }
}

class _SellerSearchResults extends StatelessWidget {
  final String query;
  const _SellerSearchResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(100).snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]).where((doc) {
          final data = doc.data();
          final target = '${data['nickname'] ?? ''} ${data['email'] ?? ''} ${data['sellerIntro'] ?? ''}';
          return _duckSearchMatch(target, query) || _duckLooseSearchMatch(target, query);
        }).take(8).toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('판매자', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...docs.map((doc) {
            final data = doc.data();
            final nickname = (data['nickname'] as String? ?? '덕친').trim();
            final imageUrl = data['profileImageUrl'] as String?;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFFFFF3C4), backgroundImage: (imageUrl ?? '').isNotEmpty ? NetworkImage(imageUrl!) : null, child: (imageUrl ?? '').isEmpty ? const Text('🐥') : null),
                title: Text(nickname, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('팔로워 ${(data['followerCount'] as num?)?.toInt() ?? 0}명 · 후기 ${(data['reviewCount'] as num?)?.toInt() ?? 0}개'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final current = FirebaseAuth.instance.currentUser;
                  if (current?.uid == doc.id) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    duckMainTabRequest.value = 4;
                    return;
                  }
                  final auction = DuckAuctionStore.registeredAuctions.value.cast<ProductItem?>().firstWhere((item) => item?.sellerId == doc.id, orElse: () => null);
                  if (auction == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('아직 등록한 경매가 없는 판매자예요.')));
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => SellerProfileScreen(seller: auction)));
                },
              ),
            );
          }),
        ]);
      },
    );
  }
}

String _duckNormalize(String value) => value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

bool _duckIsOnlyKoreanConsonants(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;
  return RegExp(r'^[ㄱ-ㅎ]+$').hasMatch(text);
}

String _duckInitials(String value) {
  const initials = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 0xAC00 && rune <= 0xD7A3) {
      buffer.write(initials[(rune - 0xAC00) ~/ 588]);
    } else {
      buffer.write(String.fromCharCode(rune).toLowerCase());
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), '');
}

bool _duckSearchMatch(String target, String query) {
  final normalizedTarget = _duckNormalize(target);
  final normalizedQuery = _duckNormalize(query);
  final initialTarget = _duckInitials(target);
  if (_duckIsOnlyKoreanConsonants(normalizedQuery)) return initialTarget.contains(normalizedQuery);
  return normalizedTarget.contains(normalizedQuery) || initialTarget.contains(normalizedQuery);
}

bool _duckLooseSearchMatch(String target, String query) {
  final a = _duckNormalize(target);
  final b = _duckNormalize(query);
  if (b.length < 2 || a.isEmpty) return false;
  var index = 0;
  for (final rune in a.runes) {
    if (index < b.runes.length && rune == b.runes.elementAt(index)) index++;
    if (index == b.runes.length) return true;
  }
  return false;
}
