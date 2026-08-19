part of '../home_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductItem product;

  /// 진입하자마자 하단 입찰 영역을 자동으로 열지 여부예요(입찰 목록의
  /// '상위입찰하기'에서 사용). 이미 마감된 경매면 입찰창 대신 불가 사유
  /// 팝업을 보여줘요.
  final bool autoOpenBid;

  /// 진입하자마자 보여줄 안내 팝업(판매 목록의 '수정불가' 등). 지정하면
  /// 이 내용을 알림 팝업으로 한 번 띄워요.
  final String? entryNoticeTitle;
  final String? entryNoticeText;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.autoOpenBid = false,
    this.entryNoticeTitle,
    this.entryNoticeText,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final PageController _imageController = PageController();

  bool isLiked = false;
  int currentImageIndex = 0;
  late int currentPrice;
  late int bidCount;
  late int likeCount;
  String? lastBidUserId;

  @override
  void initState() {
    super.initState();
    _syncFromProduct(widget.product);
    // 진입 인텐트 처리: 안내 팝업 또는 하단 입찰 영역 자동 열기.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.entryNoticeText != null) {
        _showInfoPopup(widget.entryNoticeTitle ?? '안내', widget.entryNoticeText!);
      } else if (widget.autoOpenBid) {
        final product = widget.product;
        if (!product.isAuctionActive) {
          _showInfoPopup(
            '상위입찰 불가',
            '이미 ${product.statusLabel}된 경매라 상위입찰을 할 수 없어요.',
          );
        } else {
          _showBidSheet(context, product);
        }
      }
    });
  }

  Future<void> _showInfoPopup(String title, String text) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF334155), size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF16305C))),
          ],
        ),
        content: Text(text, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF475569))),
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

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id || oldWidget.product.title != widget.product.title) {
      _syncFromProduct(widget.product);
    }
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  void _syncFromProduct(ProductItem product) {
    currentPrice = product.currentPrice > 0 ? product.currentPrice : _parseNumber(product.price);
    bidCount = _parseNumber(product.bids);
    likeCount = _parseNumber(product.likes);
    lastBidUserId = product.lastBidUserId;
    isLiked = DuckAuctionStore.isFavorite(product);
  }

  int _parseNumber(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  String _formatPrice(int value) => DuckAuctionStore.formatWonFromInt(value);

  String _formatDate(DateTime? value) {
    if (value == null) return '정보 없음';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month.$day $hour:$minute';
  }

  String _timeRemainingText(ProductItem product) {
    final endAt = product.endAt;
    if (endAt == null) return product.time;

    final diff = endAt.difference(DuckAuctionStore.devNow());
    if (diff.isNegative) return '마감됨';
    if (diff.inDays >= 1) return '${diff.inDays}일 남음';
    if (diff.inHours >= 1) return '${diff.inHours}시간 남음';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}분 남음';
    return '곧 마감';
  }

  ProductItem _mergedProduct(ProductItem latest) {
    return latest.copyWith(
      currentPrice: currentPrice,
      price: _formatPrice(currentPrice),
      bids: '$bidCount명',
      likes: '$likeCount',
      lastBidUserId: lastBidUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final productId = widget.product.id;

    if (productId != null && productId.isNotEmpty) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where(FieldPath.documentId, isEqualTo: productId)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          ProductItem product = widget.product;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final remote = ProductItem.fromFirestore(snapshot.data!.docs.first);
            product = remote.copyWith(
              imageBytes: widget.product.imageBytes,
              imageBytesList: widget.product.imageBytesList,
              imageUrl: remote.imageUrl ?? widget.product.imageUrl,
              imageUrls: remote.resolvedImageUrls.isNotEmpty ? remote.resolvedImageUrls : widget.product.resolvedImageUrls,
              coverImageUrl: remote.coverImageUrl ?? widget.product.coverImageUrl,
              coverImageIndex: remote.coverImageIndex,
              imageSchemaVersion: remote.imageSchemaVersion,
              preferUploadedImagesFirst: true,
            );
            currentPrice = product.currentPrice > 0 ? product.currentPrice : _parseNumber(product.price);
            bidCount = _parseNumber(product.bids);
            likeCount = _parseNumber(product.likes);
            lastBidUserId = product.lastBidUserId;
            isLiked = DuckAuctionStore.isFavorite(product);
          }
          // 실시간 스트림에 오류가 나면 화면 전체를 막는 대신, 마지막으로 알고 있던
          // 가격으로 계속 보여주되 상단에 얇은 안내 배너로 알려줍니다(입찰 시
          // 최신 금액이 아닐 수 있음을 사용자가 인지할 수 있게 하기 위함).
          return _buildDetailScaffold(_mergedProduct(product), hasLiveError: snapshot.hasError);
        },
      );
    }

    return _buildDetailScaffold(_mergedProduct(widget.product));
  }

  Widget _buildDetailScaffold(ProductItem product, {bool hasLiveError = false}) {
    final timeRemaining = _timeRemainingText(product);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('경매 상세', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (DuckAuctionStore.canEditProduct(product))
            IconButton(
              tooltip: '경매 수정',
              onPressed: () => _openEditProduct(product),
              icon: const Icon(Icons.edit_outlined),
              color: const Color(0xFF334155),
            ),
          if (DuckAuctionStore.canDeleteProduct(product))
            IconButton(
              tooltip: '경매 삭제',
              onPressed: () => _confirmDeleteProduct(product),
              icon: const Icon(Icons.delete_outline),
              color: const Color(0xFFEF4444),
            ),
          IconButton(
            tooltip: '신고',
            onPressed: () => _showReportSheet(product),
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: '공유 링크 복사',
            onPressed: () => _copyShareLink(product),
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: '관심 경매',
            onPressed: () => _toggleLike(product),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(isLiked),
              ),
            ),
            color: isLiked ? kAiAccent : const Color(0xFF0F172A),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          if (hasLiveError)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF7ED),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFC2410C)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '실시간 가격 정보를 불러오지 못했어요. 입찰 전 새로고침 해주세요.',
                      style: TextStyle(color: Color(0xFFC2410C), fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _DetailImageCarousel(
                  controller: _imageController,
                  product: product,
                  currentIndex: currentImageIndex,
                  likeCount: likeCount,
                  timeRemaining: timeRemaining,
                  onChanged: (index) => setState(() => currentImageIndex = index),
                ),
                const SizedBox(height: 12),
                _DetailPriceCard(
                  product: product,
                  currentPrice: currentPrice,
                  bidCount: bidCount,
                  timeRemaining: timeRemaining,
                  endAtText: _formatDate(product.endAt),
                ),
                const SizedBox(height: 12),
                _AiRecommendationCard(product: product, currentPrice: currentPrice),
                const SizedBox(height: 12),
                _SellerProfileCard(product: product),
                const SizedBox(height: 12),
                _AuctionPolicyCard(product: product, currentPrice: currentPrice, bidCount: bidCount, timeRemaining: timeRemaining),
                const SizedBox(height: 12),
                _BidHistoryCard(product: product),
                const SizedBox(height: 12),
                _AutoBidCard(product: product),
                const SizedBox(height: 12),
                _DescriptionCard(product: product),
                const SizedBox(height: 12),
                _SellerOtherProducts(currentProduct: product),
                const SizedBox(height: 12),
                _RecommendSection(currentProduct: product),
              ],
            ),
          ),
          _DetailBottomBar(
            product: product,
            currentPrice: currentPrice,
            onChat: () => _openChat(product),
            onBid: () => _showBidSheet(context, product),
          ),
        ],
      ),
    );
  }


  Future<void> _openEditProduct(ProductItem product) async {
    if (!DuckAuctionStore.canEditProduct(product)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입찰자가 생긴 상품은 수정할 수 없어요.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AuctionRegisterScreen(editProduct: product)),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _confirmDeleteProduct(ProductItem product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('경매를 삭제할까요?'),
          content: const Text('삭제한 경매는 복구할 수 없습니다. 입찰자가 생긴 경매는 삭제할 수 없어요.'),
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
        );
      },
    );

    if (confirmed != true) return;

    final result = await DuckAuctionStore.deleteProduct(product);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (result.success) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleLike(ProductItem product) async {
    if (_isGuestUser()) {
      _showLoginRequiredSheet(
        context,
        title: '관심 경매은 로그인 후 가능해요',
        description: '찜한 상품을 저장하려면 로그인/회원가입이 필요해요.',
      );
      return;
    }

    final result = await DuckAuctionStore.toggleFavorite(product);
    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '찜 저장에 실패했습니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    setState(() {
      isLiked = result.isFavorite;
      likeCount = result.likeCount;
    });
  }

  void _openChat(ProductItem product) {
    if (_isGuestUser()) {
      _showLoginRequiredSheet(
        context,
        title: '채팅은 로그인 후 가능해요',
        description: '판매자에게 문의하려면 로그인/회원가입이 필요해요.',
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SellerChatScreen(product: product)));
  }

  Future<void> _copyShareLink(ProductItem product) async {
    final idOrTitle = product.id?.isNotEmpty == true ? product.id! : Uri.encodeComponent(product.title);
    final link = 'https://duckauction.com/products/$idOrTitle';
    final text = '덕옥션에서 ${product.title} 경매를 확인해보세요.\n$link';

    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('상품 링크가 복사되었습니다.')),
    );
  }

  void _showReportSheet(ProductItem product) {
    final reasons = [
      '선정적인 상품',
      '폭력적/혐오 표현',
      '불법 상품',
      '저작권 침해',
      '사기 의심',
      '기타',
    ];
    String selectedReason = reasons.first;
    final detailController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (submitting) return;
              setSheetState(() => submitting = true);
              final result = await DuckAuctionStore.submitProductReport(
                product,
                reason: selectedReason,
                detail: detailController.text,
              );
              if (!context.mounted) return;
              Navigator.of(sheetContext).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 20 + MediaQuery.of(context).viewInsets.bottom),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('상품 신고', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text(
                        '신고 내용은 관리자 확인 후 처리됩니다. 허위 신고가 반복될 경우 서비스 이용에 제한이 있을 수 있어요.',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: reasons.map((reason) {
                          final selected = selectedReason == reason;
                          return ChoiceChip(
                            label: Text(reason),
                            selected: selected,
                            onSelected: (_) => setSheetState(() => selectedReason = reason),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: detailController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: '상세 내용 선택',
                          hintText: '신고 내용을 간단히 적어주세요.',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: submitting ? null : submit,
                          icon: submitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.flag_outlined),
                          label: Text(submitting ? '접수 중...' : '신고 접수'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(detailController.dispose);
  }



  Future<bool> _confirmBidPolicy({required int amount}) async {
    final prefs = await SharedPreferences.getInstance();
    final hasAgreed = prefs.getBool('duck_bid_policy_agreed_v1') ?? false;
    bool checked = hasAgreed;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
              actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('입찰하시겠습니까?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '입찰 금액: ${_formatPrice(amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),
                    const _BidPolicyItem(
                      text: '낙찰 후 24시간 안에 결제하지 않으면 낙찰 포기로 처리돼요.',
                    ),
                    const SizedBox(height: 10),
                    const _BidPolicyItem(
                      text: '낙찰 포기가 반복되면 입찰이 제한될 수 있어요.',
                    ),
                    const SizedBox(height: 10),
                    const _BidPolicyItem(
                      text: '낙찰 알림을 놓치지 않도록 앱 알림을 켜주세요.',
                    ),
                    const SizedBox(height: 10),
                    const _BidPolicyItem(
                      text: '다른 이용자에게 피해가 없도록 신중하게 입찰해 주세요.',
                    ),
                    if (!hasAgreed) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setDialogState(() => checked = !checked),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: checked ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: checked,
                                onChanged: (value) => setDialogState(() => checked = value ?? false),
                                visualDensity: VisualDensity.compact,
                              ),
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    '위 내용을 확인하였으며 동의합니다.',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: checked ? () => Navigator.of(dialogContext).pop(true) : null,
                  child: const Text('입찰하기'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && !hasAgreed) {
      await prefs.setBool('duck_bid_policy_agreed_v1', true);
    }
    return confirmed == true;
  }

  Future<void> _showBidSheet(BuildContext context, ProductItem product) async {
    if (_isGuestUser()) {
      _showLoginRequiredSheet(
        context,
        title: '입찰은 로그인 후 가능해요',
        description: '경매에 입찰하려면 로그인/회원가입이 필요해요.',
      );
      return;
    }
    if (await _needsTradeVerification()) {
      final ready = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const TradeReadinessScreen()),
      );
      if (ready != true || !context.mounted) return;
    }
    if (!context.mounted) return;

    final bidController = TextEditingController();
    final bidUnit = DuckAuctionStore.parseBidUnit(product.bidUnit);
    final nextPrice = DuckAuctionStore.minValidBid(currentPrice: currentPrice, bidUnit: bidUnit);
    bool isSubmitting = false;
    String? bidErrorText;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 20 + MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('입찰 금액 입력', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      '${product.title} · 현재가 ${_formatPrice(currentPrice)}',
                      style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '최소 입찰가 ${_formatPrice(nextPrice)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatPrice(bidUnit)} 단위로만 입찰할 수 있어요.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '다른 사람이 예약입찰(자동입찰)을 걸어뒀다면, 내가 입찰한 직후 곧바로 더 높은 금액으로 밀릴 수 있어요.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: bidController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        if (bidErrorText != null) setSheetState(() => bidErrorText = null);
                      },
                      decoration: InputDecoration(
                        hintText: '예: ${_formatPrice(nextPrice).replaceAll('원', '')}',
                        suffixText: '원',
                        errorText: bidErrorText,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setSheetState(() => bidErrorText = null);
                                    bidController.text = nextPrice.toString();
                                    bidController.selection = TextSelection.fromPosition(TextPosition(offset: bidController.text.length));
                                  },
                            child: const Text('최소가 입력'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    final currentInput = _parseNumber(bidController.text);
                                    final baseAmount = currentInput >= nextPrice ? currentInput : nextPrice;
                                    final nextAmount = baseAmount + bidUnit;
                                    setSheetState(() => bidErrorText = null);
                                    bidController.text = nextAmount.toString();
                                    bidController.selection = TextSelection.fromPosition(TextPosition(offset: bidController.text.length));
                                  },
                            child: Text('+${_formatPrice(bidUnit)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final currentUser = FirebaseAuth.instance.currentUser;

                              if (currentUser == null || currentUser.isAnonymous) {
                                setSheetState(() => bidErrorText = '입찰은 로그인 후 이용할 수 있어요.');
                                return;
                              }

                              if (!product.isAuctionActive) {
                                setSheetState(() => bidErrorText = '${product.statusLabel}된 경매에는 입찰할 수 없어요.');
                                return;
                              }

                              // 내 경매엔 입찰 불가. sellerId가 없는(예전) 데이터는
                              // 닉네임(고유값)으로도 한 번 더 걸러서, 자기 경매에 입찰이
                              // 들어가 뒤에서 오류가 나는 상황을 확실히 막아요.
                              final isOwnAuction = (product.sellerId != null && product.sellerId!.isNotEmpty)
                                  ? product.sellerId == currentUser.uid
                                  : (product.sellerName.trim().isNotEmpty &&
                                      product.sellerName.trim() == (currentUser.displayName ?? '').trim());
                              if (isOwnAuction) {
                                setSheetState(() => bidErrorText = '내가 등록한 상품에는 입찰할 수 없습니다.');
                                return;
                              }

                              if (lastBidUserId != null && lastBidUserId == currentUser.uid) {
                                setSheetState(() => bidErrorText = '현재 최고 입찰자는 다시 입찰할 수 없습니다.');
                                return;
                              }

                              final amount = _parseNumber(bidController.text);
                              if (!DuckAuctionStore.isValidBidAmount(amount: amount, currentPrice: currentPrice, bidUnit: bidUnit)) {
                                setSheetState(() {
                                  bidErrorText = DuckAuctionStore.invalidBidMessage(currentPrice: currentPrice, bidUnit: bidUnit);
                                });
                                return;
                              }

                              final confirmed = await _confirmBidPolicy(amount: amount);
                              if (!confirmed) return;

                              setSheetState(() => isSubmitting = true);
                              final result = await DuckAuctionStore.placeBid(product: product, amount: amount);
                              if (!mounted) return;
                              setSheetState(() => isSubmitting = false);

                              if (!result.success) {
                                setSheetState(() => bidErrorText = result.message ?? '입찰에 실패했습니다. 잠시 후 다시 시도해주세요.');
                                return;
                              }

                              setState(() {
                                currentPrice = result.product!.currentPrice > 0 ? result.product!.currentPrice : amount;
                                bidCount = _parseNumber(result.product!.bids);
                                lastBidUserId = result.product!.lastBidUserId ?? currentUser.uid;
                              });

                              Navigator.pop(sheetContext);

                              // 마감 5분 이내에 최고가로 입찰하면(=안티스나이핑 연장이
                              // 걸리면), 5분 내 상위입찰이 없으면 낙찰되고 알림을 보내준다는
                              // 안내 팝업을 띄워요. 그 외에는 기존처럼 스낵바로 안내해요.
                              final end = product.endAt;
                              final inFinalWindow = end != null &&
                                  !end.difference(DuckAuctionStore.devNow()).isNegative &&
                                  end.difference(DuckAuctionStore.devNow()) <= const Duration(minutes: 5);
                              if (!result.outbidByAutoBid && inFinalWindow && mounted) {
                                await _showAntiSnipeDialog(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result.outbidByAutoBid
                                          ? (result.message ?? '입찰이 접수됐지만 상대방의 예약입찰에 밀렸어요.')
                                          : '${_formatPrice(amount)} 입찰이 완료됐어요.',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('입찰하기'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 막판(마감 5분 이내) 최고가 입찰 시 뜨는 안내 팝업이에요. 마감이 5분
  /// 연장됐고, 5분 내 상위입찰이 없으면 낙찰되며 알림을 보내준다고 안내해요.
  /// '알림 받고 닫기'를 누르면 알림 권한을 확인해(꺼져 있으면 켜도록 안내) 낙찰
  /// 알림을 놓치지 않게 해요.
  Future<void> _showAntiSnipeDialog(BuildContext context) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('지금 최고 입찰자예요! 🎉', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '마감 직전 입찰이라 마감이 5분 연장됐어요.\n'
          '5분 동안 더 높은 입찰이 없으면 낙찰돼요.\n\n'
          '낙찰되면 알림으로 알려드릴게요. 계속 지켜보지 않아도 괜찮아요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              PushNotificationService.instance.ensureNotificationConsent(context);
            },
            child: const Text('알림 받고 닫기'),
          ),
        ],
      ),
    );
  }
}


class _BidPolicyItem extends StatelessWidget {
  final String text;

  const _BidPolicyItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text('•', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF334155))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              height: 1.38,
              fontSize: 13.5,
              letterSpacing: -0.35,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailBottomBar extends StatelessWidget {
  final ProductItem product;
  final int currentPrice;
  final VoidCallback onChat;
  final VoidCallback onBid;

  const _DetailBottomBar({
    required this.product,
    required this.currentPrice,
    required this.onChat,
    required this.onBid,
  });

  @override
  Widget build(BuildContext context) {
    final isClosed = !product.isAuctionActive;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final winnerUid = product.winnerId ?? product.lastBidUserId;
    final isWinner = uid != null && winnerUid != null && uid == winnerUid;
    final status = product.effectiveStatus;
    // 낙찰자에게 '결제하기' 버튼을 보여줘요. 실제 낙찰 경매는 마감되면
    // sold/ended 상태가 되므로(결제대기 winner_pending 외에도) 이 상태들도
    // 포함해서, 목록의 '낙찰됐어요' 표시와 동일하게 낙찰자면 결제할 수 있게 해요.
    final needsPayment = isWinner &&
        (status == 'winner_pending' ||
            status == 'second_pending' ||
            status == 'third_pending' ||
            status == 'sold' ||
            status == 'ended');
    final isBuyerFlow = isWinner &&
        (status == 'paid' || status == 'shipped' || status == 'delivered' ||
            status == 'completed' || status == 'cancelled');

    final Widget primaryButton;
    if (needsPayment) {
      primaryButton = FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: const Color(0xFFDB2777),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => _openCheckout(context),
        icon: const Icon(Icons.credit_card_rounded),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '결제하기 · ${DuckAuctionStore.formatWonFromInt(_payAmount())}',
            maxLines: 1,
            softWrap: false,
          ),
        ),
      );
    } else if (isBuyerFlow) {
      primaryButton = _buyerFlowButton(context, status);
    } else {
      primaryButton = FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: const Color(0xFF334155),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: isClosed ? null : onBid,
        icon: Icon(isClosed ? Icons.lock_outline : Icons.gavel),
        // 큰 글꼴(갤럭시 디스플레이 크게 등)에서도 '경...'처럼 잘리지 않고
        // 버튼 폭에 맞춰 글자만 줄어들게 해요.
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isClosed ? '${product.statusLabel}된 경매' : '입찰하기 · ${DuckAuctionStore.formatWonFromInt(currentPrice)}',
            maxLines: 1,
            softWrap: false,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('채팅'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: primaryButton),
          ],
        ),
      ),
    );
  }

  /// 낙찰자(구매자)에게 결제 이후 단계별로 다른 하단 버튼을 보여줘요.
  ///   판매자 확인 전 → [판매자에게 확인요청]
  ///   배송 준비중     → [배송 준비중] (대기, 비활성)
  ///   배송중          → [배송조회] + [상품 받았어요]
  ///   배송완료        → [배송조회] + [구매확정]
  ///   거래완료        → [배송조회] + [거래완료](비활성)
  ///   결제취소        → [결제취소됨] (비활성)
  Widget _buyerFlowButton(BuildContext context, String status) {
    if (status == 'cancelled') {
      return _flowSolid('결제취소됨', const Color(0xFF94A3B8), Icons.cancel_outlined, null);
    }
    if (status == 'paid') {
      final prepared = product.shippingPreparedAt != null;
      if (prepared) {
        // 판매자가 배송 준비를 시작했지만 아직 운송장 등록 전.
        return _flowSolid('배송 준비중', const Color(0xFF6366F1), Icons.inventory_2_outlined, null);
      }
      // 결제완료 · 판매자 확인 전 → 판매자에게 확인 요청(배송 준비 재촉).
      return _flowSolid(
        '판매자에게 확인요청',
        const Color(0xFFDB2777),
        Icons.notifications_active_outlined,
        () => _requestSellerConfirm(context),
      );
    }
    if (status == 'shipped') {
      return _flowPair(
        trackingOnPressed: () => _showShipmentInfoSheet(context, product),
        actionLabel: '상품 받았어요',
        actionColor: const Color(0xFF0D9488),
        actionIcon: Icons.inventory_rounded,
        actionOnPressed: () => _markDelivered(context),
      );
    }
    if (status == 'delivered') {
      return _flowPair(
        trackingOnPressed: () => _showShipmentInfoSheet(context, product),
        actionLabel: '구매확정',
        actionColor: const Color(0xFF16A34A),
        actionIcon: Icons.verified_rounded,
        actionOnPressed: () => _confirmPurchase(context),
      );
    }
    // completed
    return _flowPair(
      trackingOnPressed: () => _showShipmentInfoSheet(context, product),
      actionLabel: '거래완료',
      actionColor: const Color(0xFF16A34A),
      actionIcon: Icons.check_circle_rounded,
      actionOnPressed: null,
    );
  }

  Widget _flowSolid(String label, Color bg, IconData icon, VoidCallback? onPressed) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: bg,
        foregroundColor: Colors.white,
        disabledBackgroundColor: bg,
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, softWrap: false)),
    );
  }

  Widget _flowPair({
    required VoidCallback trackingOnPressed,
    required String actionLabel,
    required Color actionColor,
    required IconData actionIcon,
    required VoidCallback? actionOnPressed,
  }) {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            foregroundColor: const Color(0xFF16305C),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: trackingOnPressed,
          icon: const Icon(Icons.local_shipping_outlined, size: 18),
          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('배송조회', maxLines: 1, softWrap: false)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: actionColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: actionColor,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: actionOnPressed,
          icon: Icon(actionIcon, size: 18),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text(actionLabel, maxLines: 1, softWrap: false)),
        ),
      ),
    ]);
  }

  Future<void> _callBuyerFn(BuildContext context, String fn, String okMsg) async {
    final productId = product.id;
    if (productId == null) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable(fn)
          .call<Map<String, dynamic>>({'productId': productId});
      await DuckAuctionStore.refreshProductsNow();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리에 실패했어요. 잠시 후 다시 시도해주세요.\n$e')),
        );
      }
    }
  }

  Future<void> _requestSellerConfirm(BuildContext context) =>
      _callBuyerFn(context, 'requestSellerConfirm', '판매자에게 배송 준비 요청을 보냈어요.');

  Future<void> _markDelivered(BuildContext context) async {
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
    if (ok != true || !context.mounted) return;
    await _callBuyerFn(context, 'markDelivered', '수령 확인했어요. 상품을 확인하고 구매확정을 눌러주세요.');
  }

  Future<void> _confirmPurchase(BuildContext context) async {
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
    await _callBuyerFn(context, 'confirmPurchase', '구매확정이 완료됐어요. 거래가 종료됐어요. 🎉');
  }

  int _payAmount() {
    final base =
        product.currentPrice > 0 ? product.currentPrice : _digitsToInt(product.price);
    return base + product.shippingFee;
  }

  static int _digitsToInt(String value) {
    final digits =
        RegExp(r'\d+').allMatches(value).map((m) => m.group(0)!).join();
    return int.tryParse(digits) ?? 0;
  }

  static String _buildOrderId(String? productId) {
    final pid = (productId == null || productId.isEmpty) ? 'NA' : productId;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final cleaned =
        'DUCK-$pid-$ts'.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return cleaned.length > 64
        ? cleaned.substring(cleaned.length - 64)
        : cleaned;
  }

  Future<void> _openCheckout(BuildContext context) async {
    final amount = _payAmount();
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
    // 웹은 웹뷰가 없으므로 결제 페이지(pay.html)로 이동해 이니시스 결제창을 띄워요.
    // 결제 후 앱으로 돌아오면 스플래시의 결제 복귀 처리가 결과를 안내해요.
    if (kIsWeb) {
      await DuckAuctionStore.startWebCheckout(
        orderId: _buildOrderId(product.id),
        orderName: product.title,
        amount: amount,
        productId: product.id,
      );
      return;
    }
    final result = await Navigator.of(context).push<TossPaymentResult>(
      MaterialPageRoute(
        builder: (_) => TossCheckoutScreen(
          orderId: _buildOrderId(product.id),
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
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('결제가 완료됐어요',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text('결제가 정상적으로 처리됐어요.\n판매자와 배송 정보를 확인해주세요.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '결제에 실패했어요.')),
      );
    }
  }
}

class _DetailImageCarousel extends StatelessWidget {
  final PageController controller;
  final ProductItem product;
  final int currentIndex;
  final int likeCount;
  final String timeRemaining;
  final ValueChanged<int> onChanged;

  const _DetailImageCarousel({
    required this.controller,
    required this.product,
    required this.currentIndex,
    required this.likeCount,
    required this.timeRemaining,
    required this.onChanged,
  });

  List<String> get _urls {
    return product.resolvedImageUrls.where((url) => url.trim().isNotEmpty).toList();
  }

  int get _imageCount {
    final urlCount = _urls.length;
    final localCount = product.imageBytesList.length + (product.imageBytes != null ? 1 : 0);
    final count = urlCount > 0 ? urlCount : localCount;
    return count <= 0 ? 1 : count;
  }

  Uint8List? _fallbackBytesForIndex(int index, int urlCount) {
    if (product.imageBytesList.isEmpty) return index == 0 ? product.imageBytes : null;
    if (urlCount == product.imageBytesList.length && index < product.imageBytesList.length) {
      return product.imageBytesList[index];
    }
    final start = urlCount - product.imageBytesList.length;
    if (index >= start && index - start < product.imageBytesList.length) {
      return product.imageBytesList[index - start];
    }
    return index == 0 ? product.imageBytes : null;
  }

  Widget _memoryImage(Uint8List bytes) {
    return Image.memory(
      bytes,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }

  Widget _buildImageAt(int index) {
    final urls = _urls;
    if (urls.isNotEmpty && index < urls.length) {
      final fallback = _fallbackBytesForIndex(index, urls.length);
      return Image.network(
        urls[index],
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, __, ___) => fallback != null ? _memoryImage(fallback) : ProductPhoto(product: product, fontSize: 112),
      );
    }

    if (product.imageBytesList.isNotEmpty && index < product.imageBytesList.length) {
      return _memoryImage(product.imageBytesList[index]);
    }
    if (product.imageBytes != null && index == 0) {
      return _memoryImage(product.imageBytes!);
    }
    return ProductPhoto(product: product, fontSize: 112);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: controller,
              itemCount: _imageCount,
              onPageChanged: onChanged,
              itemBuilder: (context, index) {
                return Container(
                  color: const Color(0xFFF1F5F9),
                  child: _buildImageAt(index),
                );
              },
            ),
          ),
          Positioned(left: 16, top: 16, child: _SmallPill(text: product.category, icon: Icons.category_outlined)),
          Positioned(right: 16, top: 16, child: _SmallPill(text: '찜 $likeCount', icon: Icons.favorite, pink: true)),
          Positioned(
            left: 16,
            bottom: 16,
            child: _SmallPill(text: timeRemaining, icon: Icons.timer_outlined, pink: true),
          ),
          if (_imageCount > 1)
            Positioned(
              left: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CarouselArrow(
                  icon: Icons.chevron_left,
                  onTap: () {
                    final previous = currentIndex <= 0 ? _imageCount - 1 : currentIndex - 1;
                    controller.animateToPage(previous, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
                  },
                ),
              ),
            ),
          if (_imageCount > 1)
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CarouselArrow(
                  icon: Icons.chevron_right,
                  onTap: () {
                    final next = currentIndex >= _imageCount - 1 ? 0 : currentIndex + 1;
                    controller.animateToPage(next, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
                  },
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(999)),
              child: Text(
                '${currentIndex + 1}/$_imageCount',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, size: 24, color: const Color(0xFF334155)),
      ),
    );
  }
}

class _DetailPriceCard extends StatelessWidget {
  final ProductItem product;
  final int currentPrice;
  final int bidCount;
  final String timeRemaining;
  final String endAtText;

  const _DetailPriceCard({
    required this.product,
    required this.currentPrice,
    required this.bidCount,
    required this.timeRemaining,
    required this.endAtText,
  });

  @override
  Widget build(BuildContext context) {
    final isLowest = product.auctionType == 'lowest';
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(product.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827), height: 1.18)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLowest ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: isLowest ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  isLowest ? '최저가 경매' : '일반 경매',
                  style: TextStyle(
                    color: isLowest ? const Color(0xFFC2410C) : const Color(0xFF334155),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('현재 입찰가', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            DuckAuctionStore.formatWonFromInt(currentPrice),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.8),
          ),
          const SizedBox(height: 14),
          // IntrinsicHeight + stretch로 세 칸의 높이를 항상 똑같이 맞춰요
          // (값 길이가 달라 한 칸만 두 줄이 돼도 나머지가 같이 늘어나 정렬돼요).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _MiniStat(label: '입찰', value: '$bidCount명', icon: Icons.people_alt_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(label: '남은 시간', value: timeRemaining, icon: Icons.schedule_rounded, accent: kAiAccent)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(label: '마감', value: endAtText, icon: Icons.flag_outlined)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiRecommendationCard extends StatelessWidget {
  final ProductItem product;
  final int currentPrice;

  const _AiRecommendationCard({required this.product, required this.currentPrice});

  String _formatWonFromInt(int value) {
    if (value <= 0) return '추천 준비 중';
    return DuckAuctionStore.formatWonFromInt(value);
  }

  @override
  Widget build(BuildContext context) {
    const recommended = 0; // 내부 거래 데이터가 충분히 쌓이기 전까지 추천가를 제공하지 않음
    if (recommended <= 0) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7FA),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFFC5D4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: kAiAccent),
                SizedBox(width: 8),
                Text('AI 추천가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF9F1239))),
              ],
            ),
            const SizedBox(height: 12),
            const Text('AI 추천가 기능을 준비하고 있어요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFBE123C))),
            const SizedBox(height: 6),
            const Text('거래 데이터가 더 쌓이면 이 자리에서 예상 가격을 안내해드릴게요. 그 전까지는 다른 사이트에서 시세를 참고해주세요.', style: TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w700, height: 1.4)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final query = Uri.encodeComponent('${product.title} 가격');
                  final uri = Uri.parse('https://search.naver.com/search.naver?query=$query');
                  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('시세 검색 페이지를 열 수 없어요.')));
                  }
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text('다른 사이트에서 시세 찾기'),
              ),
            ),
          ],
        ),
      );
    }
    final diff = currentPrice - recommended;
    final diffText = diff == 0
        ? 'AI 추천가와 비슷한 가격이에요.'
        : diff > 0
            ? 'AI 추천가보다 ${DuckAuctionStore.formatWonFromInt(diff)} 높아요.'
            : 'AI 추천가보다 ${DuckAuctionStore.formatWonFromInt(diff.abs())} 저렴해요.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1F5), Color(0xFFFFE4EC)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFB3C7)),
        boxShadow: [BoxShadow(color: const Color(0xFFFF5A8A).withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.auto_awesome_rounded, color: kAiAccent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('AI 추천가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF9F1239))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.86), borderRadius: BorderRadius.circular(999)),
                child: const Text('Beta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFBE123C))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_formatWonFromInt(recommended), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFBE123C))),
          const SizedBox(height: 6),
          Text(diffText, style: const TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w800, height: 1.35)),
          const SizedBox(height: 8),
          const Text(
            '현재는 카테고리·상품 상태·입찰 데이터를 기반으로 안내하며, 거래 데이터가 쌓이면 추천 정확도를 높일 예정이에요.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9F1239), fontWeight: FontWeight.w600, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SellerProfileCard extends StatelessWidget {
  final ProductItem product;

  const _SellerProfileCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        final currentUser = FirebaseAuth.instance.currentUser;
        final isMyProfile = currentUser != null &&
            product.sellerId != null &&
            product.sellerId!.isNotEmpty &&
            product.sellerId == currentUser.uid;

        if (isMyProfile) {
          duckMainTabRequest.value = 4;
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SellerProfileScreen(seller: product)),
        );
      },
      child: _DetailCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(18)),
            child: const Center(child: Text('🐥', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        product.sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (product.isSellerFirstListing) ...[
                      const SizedBox(width: 6),
                      const _SelectedSellerBadge(label: '🆕 NEW'),
                    ],
                    // 실제로 획득한 뱃지만(판매 횟수 기준) + 아이콘만 표시하고,
                    // 탭하면 뱃지 이름이 뜨게 해서 화면이 잘리지 않게 했어요.
                    for (final id in product.sellerBadgeIds
                        .where(computeEarnedSellerBadges(
                          isMaster: false,
                          completedSales: product.sellerSalesCount,
                          reviewCount: 0,
                          rating: 0,
                          followerCount: 0,
                        ).contains)
                        .take(4)) ...[
                      const SizedBox(width: 5),
                      Tooltip(
                        message: sellerBadgeLabel(id),
                        triggerMode: TooltipTriggerMode.tap,
                        preferBelow: false,
                        child: Text(sellerBadgeEmoji(id) ?? '', style: const TextStyle(fontSize: 15)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '거래 ${product.sellerSalesCount}건 · 평점 ${_sellerRating(product.sellerSalesCount)} · 응답 빠름',
                  style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
      ),
    );
  }

  String _sellerRating(int salesCount) {
    if (salesCount >= 300) return '5.0';
    if (salesCount >= 100) return '4.9';
    if (salesCount >= 50) return '4.8';
    if (salesCount >= 10) return '4.7';
    return '신규';
  }
}

class _AuctionPolicyCard extends StatelessWidget {
  final ProductItem product;
  final int currentPrice;
  final int bidCount;
  final String timeRemaining;

  const _AuctionPolicyCard({required this.product, required this.currentPrice, required this.bidCount, required this.timeRemaining});

  String _formatWonFromInt(int value) {
    if (value <= 0) return '미설정';
    return DuckAuctionStore.formatWonFromInt(value);
  }

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('경매 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          _InfoRow(label: '상태', value: product.statusLabel),
          _InfoRow(label: '현재가', value: DuckAuctionStore.formatWonFromInt(currentPrice)),
          _InfoRow(label: '입찰자', value: '$bidCount명'),
          _InfoRow(label: '남은 시간', value: timeRemaining),
          _InfoRow(label: '입찰 단위', value: product.bidUnit),
          _InfoRow(label: '시작가', value: _formatWonFromInt(product.startPrice)),
          _InfoRow(label: '최소 희망가', value: _formatWonFromInt(product.hopePrice)),
          _InfoRow(label: '즉시 구매가', value: _formatWonFromInt(product.buyNowPrice)),
          _InfoRow(label: '배송비', value: product.shippingFee <= 0 ? '무료/미설정' : _formatWonFromInt(product.shippingFee)),
          // 덕옥션 판매 수수료는 판매자 본인에게만 보여줘요.
          if (FirebaseAuth.instance.currentUser?.uid == product.sellerId)
            _InfoRow(label: '덕옥션 수수료', value: product.platformFeeLabel),
        ],
      ),
    );
  }
}

/// 상품 상세의 "입찰내역" 카드입니다(기획서 9번).
/// products/{id}/bids 서브컬렉션을 실시간 구독해서 닉네임 일부를 가린 채
/// 입찰 금액/시간을 최신순으로 보여줍니다.
class _BidHistoryCard extends StatelessWidget {
  final ProductItem product;

  const _BidHistoryCard({required this.product});

  /// 닉네임의 첫 글자만 남기고 나머지는 '*'로 가립니다.
  /// 예) "홍길동" -> "홍**", "duckfan" -> "d******"
  static String _maskNickname(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '입찰자';
    if (trimmed.length == 1) return '$trimmed*';
    final maskedLength = (trimmed.length - 1).clamp(1, 6);
    return '${trimmed.substring(0, 1)}${'*' * maskedLength}';
  }

  static String _formatBidTime(DateTime? value) {
    if (value == null) return '방금 전';
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month.$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final productId = product.id;
    if (productId == null || productId.isEmpty) {
      // 등록 직후라 아직 서버에 저장되지 않은 상품(로컬 임시 상품)에는
      // 입찰내역 서브컬렉션 자체가 없으므로 카드를 표시하지 않습니다.
      return const SizedBox.shrink();
    }

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('입찰내역', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .doc(productId)
                .collection('bids')
                .orderBy('createdAt', descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  '입찰내역을 불러오지 못했어요.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Text(
                  '아직 입찰 내역이 없어요. 첫 입찰의 주인공이 되어보세요!',
                  style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                );
              }

              return Column(
                children: List.generate(docs.length, (index) {
                  final data = docs[index].data();
                  final rawAmount = data['amount'];
                  final amount = rawAmount is num ? rawAmount.toInt() : int.tryParse('$rawAmount') ?? 0;
                  final userName = (data['userName'] as String?) ?? '입찰자';
                  final rawCreatedAt = data['createdAt'];
                  final createdAt = rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null;
                  final isAutoBid = data['isAutoBid'] == true;
                  final isTopBid = index == 0;

                  return Padding(
                    padding: EdgeInsets.only(bottom: index == docs.length - 1 ? 0 : 10),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: isTopBid ? const Color(0xFFF97316) : const Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _maskNickname(userName),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                                ),
                              ),
                              if (isAutoBid) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '자동',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          DuckAuctionStore.formatWonFromInt(amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: isTopBid ? const Color(0xFFF97316) : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 62,
                          child: Text(
                            _formatBidTime(createdAt),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 상품 상세의 "예약입찰(자동입찰)" 카드입니다(기획서 8번).
/// 로그인한 사용자 본인의 자동입찰 상태(products/{id}/autoBids/{uid})를
/// 실시간으로 보여주고, 등록/취소를 여기서 처리합니다.
class _AutoBidCard extends StatelessWidget {
  final ProductItem product;

  const _AutoBidCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final productId = product.id;
    final user = FirebaseAuth.instance.currentUser;
    if (productId == null || productId.isEmpty) return const SizedBox.shrink();
    if (user == null || user.isAnonymous) return const SizedBox.shrink();
    if (product.sellerId != null && product.sellerId == user.uid) return const SizedBox.shrink();
    if (!product.isAuctionActive) return const SizedBox.shrink();

    final isLeading = product.lastBidUserId == user.uid;

    return _DetailCard(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .collection('autoBids')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final status = data?['status'] as String?;
          final hasActiveAutoBid = status == 'active';
          final rawMaxAmount = data?['maxAmount'];
          final maxAmountValue = rawMaxAmount is num ? rawMaxAmount.toInt() : 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFFF97316), size: 20),
                  SizedBox(width: 6),
                  Text('예약입찰(자동입찰)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '최대 금액을 정해두면, 다른 사람이 더 높게 입찰할 때마다 그 금액 안에서 자동으로 응찰해드려요.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w600, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (hasActiveAutoBid)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLeading ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isLeading ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLeading ? '현재 1위로 방어 중이에요' : '대기 중이에요 (2위 이하)',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isLeading ? const Color(0xFF15803D) : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '최대 ${DuckAuctionStore.formatWonFromInt(maxAmountValue)}까지 자동 응찰',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      if (!isLeading)
                        TextButton(
                          onPressed: () => _cancel(context, product),
                          child: const Text('취소'),
                        ),
                    ],
                  ),
                )
              else ...[
                if (status == 'exceeded')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      '이전 예약입찰은 한도를 넘어서 종료됐어요. 최대 금액을 올려 다시 등록할 수 있어요.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _register(context, product),
                    icon: const Icon(Icons.bolt_outlined, size: 18),
                    label: const Text('예약입찰 등록하기'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _register(BuildContext context, ProductItem product) async {
    if (await _needsTradeVerification()) {
      final ready = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const TradeReadinessScreen()),
      );
      if (ready != true || !context.mounted) return;
    }
    if (!context.mounted) return;

    final controller = TextEditingController();
    final bidUnit = DuckAuctionStore.parseBidUnit(product.bidUnit);
    final minAmount = product.currentPrice + bidUnit;
    bool isSubmitting = false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sbContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 20 + MediaQuery.of(sbContext).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('예약입찰(자동입찰) 등록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      '${product.title} · 현재가 ${DuckAuctionStore.formatWonFromInt(product.currentPrice)}',
                      style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '입력한 금액까지만 자동으로 입찰해요. 실제로는 이기는 데 필요한 만큼만 올라가고, 입력한 금액 자체는 다른 사람에게 공개되지 않아요.',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700, height: 1.4),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '경매 종료 전에는 취소할 수 있지만, 현재 1위로 방어 중일 때는 취소할 수 없어요. 최대 금액이 같으면 먼저 등록한 사람이 우선이에요.',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        if (errorText != null) setSheetState(() => errorText = null);
                      },
                      decoration: InputDecoration(
                        hintText: '예: ${DuckAuctionStore.formatWonFromInt(minAmount).replaceAll('원', '')}',
                        suffixText: '원',
                        errorText: errorText,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final raw = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                              final amount = int.tryParse(raw) ?? 0;
                              if (amount < minAmount) {
                                setSheetState(() => errorText = '최소 ${DuckAuctionStore.formatWonFromInt(minAmount)} 이상 입력해주세요.');
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              final result = await DuckAuctionStore.registerAutoBid(product: product, maxAmount: amount);
                              if (!sbContext.mounted) return;
                              setSheetState(() => isSubmitting = false);

                              if (!result.success) {
                                setSheetState(() => errorText = result.message);
                                return;
                              }

                              Navigator.pop(sheetContext);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('등록하기'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancel(BuildContext context, ProductItem product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('예약입찰 취소'),
        content: const Text('등록해둔 예약입찰을 취소할까요? 취소하면 더 이상 자동으로 응찰하지 않아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('아니요')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('취소하기')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await DuckAuctionStore.cancelAutoBid(product);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }
}

class _DescriptionCard extends StatelessWidget {
  final ProductItem product;

  const _DescriptionCard({required this.product});

  String get _auctionTypeLabel => product.auctionType == 'lowest' ? '최저가 경매' : '일반 경매';

  @override
  Widget build(BuildContext context) {
    final description = product.description.trim().isEmpty ? '판매자가 아직 경매 설명을 입력하지 않았어요.' : product.description.trim();

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('경매 설명', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              _SmallPill(text: product.condition, icon: Icons.verified_outlined),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(height: 1.58, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
          if (product.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: product.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text('#$tag', style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w800)),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),
          _InfoRow(label: '카테고리', value: product.category),
          _InfoRow(label: '경매 물품 상태', value: product.condition),
          _InfoRow(label: '경매 방식', value: _auctionTypeLabel),
        ],
      ),
    );
  }
}

class _SellerOtherProducts extends StatelessWidget {
  final ProductItem currentProduct;

  const _SellerOtherProducts({required this.currentProduct});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ProductItem>>(
      valueListenable: DuckAuctionStore.registeredAuctions,
      builder: (context, products, _) {
        final sellerId = currentProduct.sellerId;
        final others = products.where((item) {
          final sameSeller = sellerId != null && sellerId.isNotEmpty ? item.sellerId == sellerId : item.sellerName == currentProduct.sellerName;
          final differentProduct = item.id != null && currentProduct.id != null ? item.id != currentProduct.id : item.title != currentProduct.title;
          final isActive = item.effectiveStatus == 'active';
          return sameSeller && differentProduct && isActive;
        }).take(6).toList();

        if (others.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: '${currentProduct.sellerName}님의 다른 경매'),
            const SizedBox(height: 10),
            _HorizontalProductList(products: others),
          ],
        );
      },
    );
  }
}

class _RecommendSection extends StatelessWidget {
  final ProductItem currentProduct;

  const _RecommendSection({required this.currentProduct});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ProductItem>>(
      valueListenable: DuckAuctionStore.registeredAuctions,
      builder: (context, products, _) {
        final source = products.isNotEmpty ? products : HomeTab.popularProducts;
        final recommends = source
            .where((item) => item.title != currentProduct.title && item.category == currentProduct.category)
            .take(6)
            .toList();
        final fallback = recommends.isEmpty
            ? source.where((item) => item.title != currentProduct.title).take(6).toList()
            : recommends;

        if (fallback.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: '비슷한 경매'),
            const SizedBox(height: 10),
            _HorizontalProductList(products: fallback),
          ],
        );
      },
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;

  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = const Color(0xFF334155),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value, softWrap: true, style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w900, height: 1.25)),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool pink;

  const _SmallPill({required this.text, required this.icon, this.pink = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pink ? const Color(0xFFFFEEF3) : const Color(0xFFF2F3F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pink ? const Color(0xFFFFC5D4) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: pink ? kAiAccent : const Color(0xFF4B5563)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: pink ? const Color(0xFFBE123C) : const Color(0xFF4B5563),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class SellerProfileScreen extends StatelessWidget {
  final ProductItem seller;

  const SellerProfileScreen({super.key, required this.seller});

  String _rating(int count) {
    if (count >= 300) return '5.0';
    if (count >= 100) return '4.9';
    if (count >= 50) return '4.8';
    if (count >= 10) return '4.7';
    return '신규';
  }

  Widget _coverImage(String? profileCoverImageUrl) {
    if ((profileCoverImageUrl ?? '').trim().isNotEmpty) {
      return Image.network(
        profileCoverImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, __, ___) => ProductPhoto(product: seller, fontSize: 90),
      );
    }

    final urls = seller.resolvedImageUrls.where((url) => url.trim().isNotEmpty).toList();
    if (urls.isNotEmpty) {
      return Image.network(
        urls.first,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, __, ___) => ProductPhoto(product: seller, fontSize: 90),
      );
    }
    if (seller.imageBytesList.isNotEmpty) {
      return Image.memory(seller.imageBytesList.first, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    if (seller.imageBytes != null) {
      return Image.memory(seller.imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    return ProductPhoto(product: seller, fontSize: 90);
  }

  Widget _profileAvatar(String? url) {
    if ((url ?? '').trim().isNotEmpty) {
      return Image.network(
        url!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const Center(child: Text('🐥', style: TextStyle(fontSize: 45))),
      );
    }
    return const Center(child: Text('🐥', style: TextStyle(fontSize: 45)));
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = seller.sellerId;
    final profileStream = sellerId != null && sellerId.isNotEmpty
        ? FirebaseFirestore.instance.collection('users').doc(sellerId).snapshots()
        : const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileStream,
      builder: (context, profileSnapshot) {
        final data = profileSnapshot.data?.data() ?? <String, dynamic>{};
        final nickname = ((data['nickname'] as String?) ?? seller.sellerName).trim();
        final profileImageUrl = data['profileImageUrl'] as String?;
        final profileCoverImageUrl = data['profileCoverImageUrl'] as String?;
        final intro = ((data['sellerIntro'] as String?) ?? '').trim();
        final badges = (data['sellerBadges'] as List?)?.whereType<String>().take(3).toList() ?? <String>[];
        final signedInUser = FirebaseAuth.instance.currentUser;
        final fallbackEmail = signedInUser?.uid == sellerId ? signedInUser?.email : null;
        final email = ((data['email'] as String?) ?? fallbackEmail ?? '').toLowerCase();
        final isMaster = email == 'master@duckauction.com';
        final joinedAt = data['createdAt'];
        final joinedText = joinedAt is Timestamp
            ? '${joinedAt.toDate().year}.${joinedAt.toDate().month.toString().padLeft(2, '0')}.${joinedAt.toDate().day.toString().padLeft(2, '0')}'
            : '-';
        final followerCount = (data['followerCount'] as num?)?.toInt() ?? 0;
        final followingCount = (data['followingCount'] as num?)?.toInt() ?? 0;
        final recentAccessText = (data['lastSeenAt'] is Timestamp) ? '최근 접속' : '-';
        // 이 판매자가 실제로 획득한 배지만 노출해요(기준 미달 배지는 숨김).
        final sellerEarnedBadges = computeEarnedSellerBadges(
          isMaster: isMaster,
          completedSales: (data['completedTradeCount'] as num?)?.toInt() ?? 0,
          reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
          rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
          followerCount: followerCount,
        );
        final visibleBadges = badges.where(sellerEarnedBadges.contains).toList();

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            foregroundColor: const Color(0xFF1F2937),
            title: const Text('판매자 프로필', style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share_rounded)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
            ],
          ),
          body: ValueListenableBuilder<List<ProductItem>>(
            valueListenable: DuckAuctionStore.registeredAuctions,
            builder: (context, products, _) {
              final sellerProducts = products.where((item) {
                if (sellerId != null && sellerId.isNotEmpty) return item.sellerId == sellerId;
                return item.sellerName == seller.sellerName;
              }).toList();
              final active = sellerProducts.where((item) => item.effectiveStatus == 'active').toList();
              final completed = sellerProducts.where((item) => item.effectiveStatus == 'completed' || item.effectiveStatus == 'sold').length;
              final rating = _rating(seller.sellerSalesCount);

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      ClipRect(
                        child: SizedBox(
                          height: 185,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _coverImage(profileCoverImageUrl),
                              const ColoredBox(color: Color(0x4D000000)),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(0, 138, 0, 0),
                        padding: const EdgeInsets.fromLTRB(20, 66, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Column(
                          children: [
                            Text(nickname.isEmpty ? '덕친' : nickname, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            if (visibleBadges.isNotEmpty)
                              SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, shrinkWrap: true, children: visibleBadges.map((id) => Padding(padding: const EdgeInsets.only(right: 6), child: _SelectedSellerBadge(label: sellerBadgeLabel(id)))).toList())),
                            const SizedBox(height: 13),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🐥', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 4),
                                Text(rating, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                                const SizedBox(width: 12),
                                Text('판매완료 $completed건', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(18)),
                              child: Row(
                                children: [
                                  Expanded(child: _SellerProfileStat(icon: Icons.calendar_month_outlined, label: '가입일', value: joinedText)),
                                  const _ProfileDivider(),
                                  Expanded(child: _SellerProfileStat(icon: Icons.schedule_rounded, label: '최근 접속', value: recentAccessText)),
                                  const _ProfileDivider(),
                                  Expanded(child: _SellerProfileStat(icon: Icons.people_outline_rounded, label: '팔로워', value: '$followerCount', onTap: sellerId == null || sellerId.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FollowListScreen(userId: sellerId, mode: FollowListMode.followers, title: '${nickname.isEmpty ? '덕친' : nickname}의 팔로워'))))),
                                  const _ProfileDivider(),
                                  Expanded(child: _SellerProfileStat(icon: Icons.person_add_alt_1_outlined, label: '팔로잉', value: '$followingCount', onTap: sellerId == null || sellerId.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FollowListScreen(userId: sellerId, mode: FollowListMode.following, title: '${nickname.isEmpty ? '덕친' : nickname}의 팔로잉'))))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 88,
                        child: Container(
                          width: 104,
                          height: 104,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                            border: Border.all(color: Colors.white, width: 5),
                            image: (profileImageUrl != null && profileImageUrl.trim().isNotEmpty)
                                ? DecorationImage(image: NetworkImage(profileImageUrl.trim()), fit: BoxFit.cover)
                                : null,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 5))],
                          ),
                          child: (profileImageUrl == null || profileImageUrl.trim().isEmpty)
                              ? const Center(child: Text('🐥', style: TextStyle(fontSize: 45)))
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _ProfileSection(
                    title: '판매자 소개',
                    child: Text(
                      intro.isEmpty ? '안녕하세요! 좋은 거래 약속드릴게요 😊\n꼼꼼한 포장과 빠른 답변으로 거래할게요.' : intro,
                      style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, height: 1.5),
                    ),
                  ),
                  _ProfileSection(
                    title: '판매자 배지',
                    child: visibleBadges.isEmpty
                        ? const Text(
                            '아직 설정한 배지가 없어요.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                          )
                        : SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: visibleBadges.map((id) => Padding(padding: const EdgeInsets.only(right: 6), child: _SelectedSellerBadge(label: sellerBadgeLabel(id)))).toList())),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(children: [
                      const Expanded(child: Text('판매자의 경매', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                      Text('${active.length}개', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  if (active.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _DetailCard(child: Text('현재 진행 중인 경매가 없어요.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700))),
                    )
                  else
                    ...active.map((item) => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: ProductListTile(product: item))),
                  _ProfileSection(
                    title: '거래 후기',
                    trailing: isMaster ? '🐥 4.8 / 5.0' : (rating == '신규' ? null : '🐥 $rating / 5.0'),
                    child: _SellerReviewTabs(sellerUid: sellerId, isMaster: isMaster),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                    child: Row(children: [
                      Expanded(child: _FollowButton(sellerId: sellerId, sellerName: nickname.isEmpty ? '덕친' : nickname)),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chat_bubble_outline_rounded), label: const Text('채팅하기'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: const Color(0xFFE91E63)))),
                    ]),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

enum FollowListMode { followers, following }

class _FollowButton extends StatelessWidget {
  final String? sellerId;
  final String sellerName;
  const _FollowButton({required this.sellerId, required this.sellerName});

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;
    if (sellerId == null || sellerId!.isEmpty || current == null || current.isAnonymous || current.uid == sellerId) {
      return FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.person_outline_rounded),
        label: Text(current?.uid == sellerId ? '내 프로필' : '팔로우'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: const Color(0xFFE91E63)),
      );
    }
    final followRef = FirebaseFirestore.instance.collection('users').doc(sellerId).collection('followers').doc(current.uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: followRef.snapshots(),
      builder: (context, snapshot) {
        final following = snapshot.data?.exists == true;
        return FilledButton.icon(
          onPressed: () => _toggleFollow(context, targetUid: sellerId!, targetName: sellerName, currentlyFollowing: following),
          icon: Icon(following ? Icons.person_remove_alt_1_rounded : Icons.person_add_alt_1_rounded),
          label: Text(following ? '팔로잉' : '팔로우'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: following ? const Color(0xFFF1F5F9) : const Color(0xFFE91E63),
            foregroundColor: following ? const Color(0xFF475569) : Colors.white,
          ),
        );
      },
    );
  }
}

Future<void> _toggleFollow(BuildContext context, {required String targetUid, required String targetName, required bool currentlyFollowing}) async {
  final current = FirebaseAuth.instance.currentUser;
  if (current == null || current.isAnonymous || current.uid == targetUid) return;
  final db = FirebaseFirestore.instance;
  final followerRef = db.collection('users').doc(targetUid).collection('followers').doc(current.uid);
  final followingRef = db.collection('users').doc(current.uid).collection('following').doc(targetUid);
  final myUserRef = db.collection('users').doc(current.uid);
  final targetUserRef = db.collection('users').doc(targetUid);
  try {
    await db.runTransaction((tx) async {
      final existing = await tx.get(followerRef);
      final shouldUnfollow = existing.exists;
      if (shouldUnfollow) {
        tx.delete(followerRef);
        tx.delete(followingRef);
        tx.set(targetUserRef, {'followerCount': FieldValue.increment(-1), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        tx.set(myUserRef, {'followingCount': FieldValue.increment(-1), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      } else {
        final now = FieldValue.serverTimestamp();
        tx.set(followerRef, {'uid': current.uid, 'nickname': current.displayName ?? current.email ?? '덕친', 'email': current.email, 'createdAt': now});
        tx.set(followingRef, {'uid': targetUid, 'nickname': targetName, 'createdAt': now});
        tx.set(targetUserRef, {'uid': targetUid, 'followerCount': FieldValue.increment(1), 'updatedAt': now}, SetOptions(merge: true));
        tx.set(myUserRef, {'uid': current.uid, 'email': current.email, 'followingCount': FieldValue.increment(1), 'updatedAt': now}, SetOptions(merge: true));
      }
    });
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(currentlyFollowing ? '팔로우를 취소했어요.' : '$targetName님을 팔로우했어요.')));
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('팔로우 처리에 실패했어요: $error')));
  }
}

class FollowListScreen extends StatelessWidget {
  final String userId;
  final FollowListMode mode;
  final String title;
  const FollowListScreen({super.key, required this.userId, required this.mode, required this.title});

  @override
  Widget build(BuildContext context) {
    final collection = mode == FollowListMode.followers ? 'followers' : 'following';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).collection(collection).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('목록을 불러오지 못했어요.\n${snapshot.error}', textAlign: TextAlign.center)));
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) return Center(child: Text(mode == FollowListMode.followers ? '아직 팔로워가 없어요.' : '아직 팔로우한 판매자가 없어요.', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final uid = ((data['uid'] as String?) ?? docs[index].id).trim();
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                builder: (context, userSnapshot) {
                  final profile = userSnapshot.data?.data() ?? data;
                  final nickname = ((profile['nickname'] as String?) ?? data['nickname'] as String? ?? '덕친').trim();
                  final imageUrl = profile['profileImageUrl'] as String?;
                  return Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: const Color(0xFFFFF3C4), backgroundImage: (imageUrl ?? '').isNotEmpty ? NetworkImage(imageUrl!) : null, child: (imageUrl ?? '').isEmpty ? const Text('🐥') : null),
                      title: Text(nickname.isEmpty ? '덕친' : nickname, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: const Text('프로필 보기', style: TextStyle(color: Color(0xFF64748B))),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        final products = DuckAuctionStore.registeredAuctions.value.where((item) => item.sellerId == uid).toList();
                        if (products.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('현재 확인할 수 있는 판매자 경매가 없어요.')));
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => SellerProfileScreen(seller: products.first)));
                      },
                    ),
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

class _SelectedSellerBadge extends StatelessWidget {
  final String label;
  const _SelectedSellerBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF475569))),
    );
  }
}

class _TestReview extends StatelessWidget {
  final String name;
  final int rating;
  final String text;
  const _TestReview({required this.name, required this.rating, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900))), Text(List.filled(rating.clamp(0, 5).toInt(), '🐥').join(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(color: Color(0xFF475569), height: 1.4)),
      ]),
    );
  }
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 35, color: const Color(0xFFE5E7EB));
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const _ProfileSection({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              if (trailing != null) Text(trailing!, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFA726))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SellerProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _SellerProfileStat({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Column(
      children: [
        Icon(icon, size: 21, color: const Color(0xFF64748B)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
      ],
    );
    if (onTap == null) return child;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: child));
  }
}

class _SellerReviewTabs extends StatefulWidget {
  final String? sellerUid;
  final bool isMaster;
  const _SellerReviewTabs({required this.sellerUid, required this.isMaster});

  @override
  State<_SellerReviewTabs> createState() => _SellerReviewTabsState();
}

class _SellerReviewTabsState extends State<_SellerReviewTabs> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    const labels = ['전체', '판매', '구매'];
    final sellerUid = widget.sellerUid;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
        child: Row(children: List.generate(3, (i) => Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => index = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(color: index == i ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: index == i ? [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8)] : null),
            child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: index == i ? const Color(0xFFE91E63) : const Color(0xFF64748B))),
          ),
        )))),
      ),
      const SizedBox(height: 12),
      if (sellerUid == null || sellerUid.isEmpty)
        const Text('아직 등록된 거래 후기가 없어요.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700))
      else
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('reviews').where('recipientUid', isEqualTo: sellerUid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('후기를 불러오지 못했어요.', style: TextStyle(color: Color(0xFF64748B)));
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
            final wantedType = index == 1 ? 'sale' : index == 2 ? 'purchase' : null;
            final reviews = snapshot.data!.docs.map(ReviewRecord.fromDoc).where((r) => !r.hidden && (wantedType == null || r.type == wantedType)).toList()
              ..sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
            if (reviews.isEmpty && widget.isMaster) {
              final fallback = const [
                _TestReview(name: '오리친구', rating: 5, text: '포장이 정말 꼼꼼하고 배송도 빨랐어요!'),
                _TestReview(name: '치이러버', rating: 5, text: '설명과 같은 상태로 잘 받았습니다 😊'),
                _TestReview(name: '덕질중', rating: 4, text: '답변이 빠르고 친절해서 안심하고 거래했어요.'),
                _TestReview(name: '피규어콩', rating: 5, text: '재거래하고 싶은 판매자예요!'),
                _TestReview(name: '쿠로미짱', rating: 5, text: '안전하게 포장해 주셔서 감사합니다.'),
              ];
              return Column(children: fallback);
            }
            if (reviews.isEmpty) return const Text('아직 등록된 거래 후기가 없어요.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700));
            return Column(children: reviews.map((review) => ReviewCard(review: review)).toList());
          },
        ),
    ]);
  }
}

