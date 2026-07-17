part of '../home_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductItem product;

  const ProductDetailScreen({
    super.key,
    required this.product,
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
          return _buildDetailScaffold(_mergedProduct(product));
        },
      );
    }

    return _buildDetailScaffold(_mergedProduct(widget.product));
  }

  Widget _buildDetailScaffold(ProductItem product) {
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
      bottomNavigationBar: _DetailBottomBar(
        product: product,
        currentPrice: currentPrice,
        onOpenCart: () => _toggleCart(product),
        onChat: () => _openChat(product),
        onBid: () => _showBidSheet(context, product),
      ),
      body: ListView(
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
          _DescriptionCard(product: product),
          const SizedBox(height: 12),
          _SellerOtherProducts(currentProduct: product),
          const SizedBox(height: 12),
          _RecommendSection(currentProduct: product),
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
      MaterialPageRoute(
        builder: (_) => AuctionRegisterScreen(editProduct: product),
      ),
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

  void _toggleCart(ProductItem product) {
    if (_isGuestUser()) {
      _showLoginRequiredSheet(
        context,
        title: '장바구니는 로그인 후 가능해요',
        description: '관심 있는 경매를 장바구니에 담으려면 로그인/회원가입이 필요해요.',
      );
      return;
    }

    final wasInCart = DuckAuctionStore.isInCart(product);
    DuckAuctionStore.toggleCart(product);

    if (!wasInCart) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('장바구니에 담았어요.'),
          action: SnackBarAction(
            label: '보러가기',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장바구니에서 제거했어요.')),
      );
    }
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
    final link = 'https://duckauction.app/products/$idOrTitle';
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

  void _showBidSheet(BuildContext context, ProductItem product) {
    final bidController = TextEditingController();
    final bidUnit = DuckAuctionStore.parseBidUnit(product.bidUnit);
    final nextPrice = currentPrice + bidUnit;
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

                              if (product.sellerId != null && product.sellerId == currentUser.uid) {
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${_formatPrice(amount)} 입찰이 완료됐어요.')),
                              );
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
  final VoidCallback onOpenCart;
  final VoidCallback onChat;
  final VoidCallback onBid;

  const _DetailBottomBar({
    required this.product,
    required this.currentPrice,
    required this.onOpenCart,
    required this.onChat,
    required this.onBid,
  });

  @override
  Widget build(BuildContext context) {
    final isClosed = !product.isAuctionActive;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            ValueListenableBuilder<List<ProductItem>>(
              valueListenable: DuckAuctionStore.cartItems,
              builder: (context, cartItems, _) {
                final inCart = DuckAuctionStore.isInCart(product);
                return IconButton.filledTonal(
                  tooltip: inCart ? '장바구니에서 제거' : '장바구니 담기',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    backgroundColor: inCart ? const Color(0xFFF1F5F9) : const Color(0xFFF2F3F6),
                    foregroundColor: inCart ? const Color(0xFF334155) : const Color(0xFF374151),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onOpenCart,
                  icon: Icon(inCart ? Icons.shopping_bag : Icons.shopping_bag_outlined),
                );
              },
            ),
            const SizedBox(width: 8),
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
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isClosed ? null : onBid,
                icon: Icon(isClosed ? Icons.lock_outline : Icons.gavel),
                label: Text(isClosed ? '${product.statusLabel}된 경매' : '입찰하기 · ${DuckAuctionStore.formatWonFromInt(currentPrice)}'),
              ),
            ),
          ],
        ),
      ),
    );
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
          Row(
            children: [
              Expanded(child: _MiniStat(label: '입찰', value: '$bidCount명', icon: Icons.people_alt_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: '남은 시간', value: timeRemaining, icon: Icons.schedule_rounded, accent: kAiAccent)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: '마감', value: endAtText, icon: Icons.flag_outlined)),
            ],
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
            const Text('아직 AI 추천가가 없어요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFBE123C))),
            const SizedBox(height: 6),
            const Text('유사 경매의 거래 데이터가 충분하지 않아 현재는 예상 가격을 안내하기 어려워요.', style: TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w700, height: 1.4)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final query = Uri.encodeComponent('${product.title} 가격');
                  final uri = Uri.parse('https://search.naver.com/search.naver?query=$query');
                  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('네이버 검색을 열 수 없어요.')));
                  }
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text('네이버에서 시세 찾기'),
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
                  children: [
                    Flexible(
                      child: Text(
                        product.sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SellerBadge(salesCount: product.sellerSalesCount),
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
        ],
      ),
    );
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
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w900)),
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

        return Scaffold(
          backgroundColor: Colors.white,
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

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 235,
                    pinned: true,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.white,
                    title: const Text('판매자 프로필', style: TextStyle(fontWeight: FontWeight.w900)),
                    actions: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share_rounded)),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      background: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(child: _coverImage(profileCoverImageUrl)),
                            Positioned.fill(child: ColoredBox(color: Color(0x4D000000))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 0),
                              padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
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
                                  if (badges.isNotEmpty)
                                    SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, shrinkWrap: true, children: badges.map((id) => Padding(padding: const EdgeInsets.only(right: 6), child: _SelectedSellerBadge(label: sellerBadgeLabel(id)))).toList()))
                                  else
                                    SellerBadge(salesCount: seller.sellerSalesCount),
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
                              top: -51,
                              child: Container(
                                width: 102,
                                height: 102,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF1F5F9),
                                  border: Border.all(color: Colors.white, width: 5),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 5))],
                                ),
                                child: _profileAvatar(profileImageUrl),
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
                          child: badges.isEmpty
                              ? Wrap(spacing: 8, runSpacing: 8, children: [SellerBadge(salesCount: seller.sellerSalesCount)])
                              : SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: badges.map((id) => Padding(padding: const EdgeInsets.only(right: 6), child: _SelectedSellerBadge(label: sellerBadgeLabel(id)))).toList())),
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
                    ),
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

class SellerBadge extends StatelessWidget {
  final int salesCount;

  const SellerBadge({super.key, required this.salesCount});

  String get label {
    if (salesCount >= 300) return '👑 파워 판매자';
    if (salesCount >= 100) return '🏅 인기 판매자';
    if (salesCount >= 50) return '✅ 믿음 판매자';
    if (salesCount >= 10) return '🌱 새싹 판매자';
    return '첫 판매 도전';
  }

  Color get color {
    if (salesCount >= 300) return const Color(0xFFFFF1F2);
    if (salesCount >= 100) return const Color(0xFFFFF7ED);
    if (salesCount >= 50) return const Color(0xFFF0FDF4);
    return const Color(0xFFF1F5F9);
  }

  Color get textColor {
    if (salesCount >= 300) return const Color(0xFFBE123C);
    if (salesCount >= 100) return const Color(0xFFC2410C);
    if (salesCount >= 50) return const Color(0xFF15803D);
    return const Color(0xFF475569);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w900)),
    );
  }
}
