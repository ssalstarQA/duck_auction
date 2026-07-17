part of '../home_screen.dart';

class AuctionRegisterScreen extends StatefulWidget {
  final ProductItem? editProduct;
  final bool registerAsNew;

  const AuctionRegisterScreen({super.key, this.editProduct, this.registerAsNew = false});

  @override
  State<AuctionRegisterScreen> createState() => _AuctionRegisterScreenState();
}

class _AuctionRegisterScreenState extends State<AuctionRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final _shippingFeeController = TextEditingController(text: '3000');
  final _hopePriceController = TextEditingController();
  final _startPriceController = TextEditingController();
  final _buyNowPriceController = TextEditingController();
  final _startPriceFocusNode = FocusNode();

  final List<String> _existingImageUrls = <String>[];
  final List<Uint8List> _existingPreviewBytesList = <Uint8List>[];
  final List<Uint8List> _imageBytesList = <Uint8List>[];
  final List<String> _imageNames = <String>[];

  bool get _isEditMode => widget.editProduct != null && !widget.registerAsNew;

  String _category = '치이카와';
  String _condition = '미개봉';
  String _auctionType = '일반 경매';
  String _period = '24시간';
  String _bidUnit = '1,000원';
  bool _useAiPrice = false;
  bool _lowestAuctionAgreement = false;
  bool _isSubmitting = false;
  int _coverImageIndex = 0;

  static const _categories = ['치이카와', '산리오', '진격의 거인', '디즈니', '포켓몬', '레고', '건담', '기타'];
  static const _conditions = ['미개봉', '개봉', '사용감 있음'];
  static const _auctionTypes = ['일반 경매', '최저가 경매'];
  static const _periods = ['12시간', '24시간', '3일', '7일'];
  static const _bidUnits = ['100원', '500원', '1,000원', '5,000원'];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_refreshAiPrice);
    final edit = widget.editProduct;
    if (edit != null) {
      _titleController.text = edit.title;
      _descriptionController.text = edit.description;
      _tagController.text = edit.tags.join(', ');
      _shippingFeeController.text = edit.shippingFee.toString();
      _hopePriceController.text = edit.hopePrice > 0 ? edit.hopePrice.toString() : '';
      _startPriceController.text = edit.startPrice > 0 ? edit.startPrice.toString() : '';
      _buyNowPriceController.text = edit.buyNowPrice > 0 ? edit.buyNowPrice.toString() : '';
      _existingImageUrls.addAll(edit.resolvedImageUrls);
      // 수정 화면에서는 기존 사진 URL이 느리게 로드되거나 웹 권한/CORS 문제로
      // 실패할 수 있어요. 등록 직후 로컬에 남아있는 이미지 bytes가 있으면
      // 같은 순서의 미리보기 fallback으로 보관해 썸네일 판단이 가능하게 합니다.
      _existingPreviewBytesList.addAll(edit.imageBytesList);
      if (_existingPreviewBytesList.isEmpty && edit.imageBytes != null && edit.imageBytes!.isNotEmpty) {
        _existingPreviewBytesList.add(edit.imageBytes!);
      }
      _category = edit.category;
      _condition = edit.condition;
      _auctionType = edit.auctionType == 'lowest' ? '최저가 경매' : '일반 경매';
      _bidUnit = edit.bidUnit;
      _useAiPrice = false;
      _period = '24시간';
    } else {
      _category = '치이카와';
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_refreshAiPrice);
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _shippingFeeController.dispose();
    _hopePriceController.dispose();
    _startPriceController.dispose();
    _buyNowPriceController.dispose();
    _startPriceFocusNode.dispose();
    super.dispose();
  }

  void _refreshAiPrice() {
    if (mounted) setState(() {});
  }

  int _parseNumber(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  String _formatWonFromInt(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      buffer.write(raw[i]);
      final left = raw.length - i - 1;
      if (left > 0 && left % 3 == 0) buffer.write(',');
    }
    return '${buffer}원';
  }

  String _formatWon(String value) {
    final number = _parseNumber(value);
    return _formatWonFromInt(number);
  }

  int get _aiRecommendedPrice {
    final title = _titleController.text.trim();
    final baseByCategory = {
      '치이카와': 14000,
      '산리오': 9000,
      '진격의 거인': 26000,
      '디즈니': 12000,
      '포켓몬': 13000,
      '레고': 30000,
      '건담': 32000,
      '기타': 10000,
    }[_category] ?? 10000;

    final conditionRate = switch (_condition) {
      '미개봉' => 1.0,
      '개봉' => 0.82,
      _ => 0.62,
    };

    final titleBonus = title.length >= 10 ? 2000 : title.length >= 5 ? 1000 : 0;
    final raw = ((baseByCategory + titleBonus) * conditionRate).round();
    return (raw / 500).round() * 500;
  }

  int get _finalStartPrice {
    if (_auctionType == '최저가 경매') return 1000;
    if (_useAiPrice) return _aiRecommendedPrice;
    return _parseNumber(_startPriceController.text);
  }

  String get _finalBidUnit => _auctionType == '최저가 경매' ? '1,000원' : _bidUnit;

  String _timeLabel(String period) {
    switch (period) {
      case '12시간':
        return '12시간 남음';
      case '24시간':
        return '1일 남음';
      case '3일':
        return '3일 남음';
      case '7일':
        return '7일 남음';
      default:
        return period;
    }
  }

  Duration _periodDuration(String period) {
    switch (period) {
      case '12시간':
        return const Duration(hours: 12);
      case '24시간':
        return const Duration(days: 1);
      case '3일':
        return const Duration(days: 3);
      case '7일':
        return const Duration(days: 7);
      default:
        return const Duration(days: 1);
    }
  }

  Future<void> _pickImage() async {
    try {
      final remainingCount = 10 - (_existingImageUrls.length + _imageBytesList.length);
      if (remainingCount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진은 최대 10장까지 등록할 수 있어요.')),
        );
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final selectedFiles = result.files
          .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
          .take(remainingCount)
          .toList();

      if (selectedFiles.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 사진을 불러오지 못했어요. 다시 선택해주세요.')),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        for (final file in selectedFiles) {
          _imageBytesList.add(file.bytes!);
          _imageNames.add(file.name);
        }
      });

      final overLimitCount = result.files.length - remainingCount;
      if (overLimitCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '사진은 최대 10장까지 등록할 수 있어요. 선택한 ${result.files.length}장 중 ${selectedFiles.length}장만 추가했어요.',
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했어요. 파일 선택 권한이나 형식을 확인해주세요.')),
      );
    }
  }

  int get _totalImageCount => _existingImageUrls.length + _imageBytesList.length;

  void _normalizeCoverImageIndex() {
    final total = _totalImageCount;
    if (total <= 0) {
      _coverImageIndex = 0;
      return;
    }
    if (_coverImageIndex >= total) _coverImageIndex = total - 1;
    if (_coverImageIndex < 0) _coverImageIndex = 0;
  }

  void _setCoverImageIndex(int index) {
    if (index < 0 || index >= _totalImageCount) return;
    setState(() => _coverImageIndex = index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${index + 1}번째 사진을 대표사진으로 설정했어요.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeExistingImageAt(int index) {
    if (index < 0 || index >= _existingImageUrls.length) return;
    setState(() {
      _existingImageUrls.removeAt(index);
      if (index < _existingPreviewBytesList.length) {
        _existingPreviewBytesList.removeAt(index);
      }
      if (_coverImageIndex == index) {
        _coverImageIndex = 0;
      } else if (_coverImageIndex > index) {
        _coverImageIndex -= 1;
      }
      _normalizeCoverImageIndex();
    });
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _imageBytesList.length) return;
    final globalIndex = _existingImageUrls.length + index;
    setState(() {
      _imageBytesList.removeAt(index);
      if (index < _imageNames.length) {
        _imageNames.removeAt(index);
      }
      if (_coverImageIndex == globalIndex) {
        _coverImageIndex = 0;
      } else if (_coverImageIndex > globalIndex) {
        _coverImageIndex -= 1;
      }
      _normalizeCoverImageIndex();
    });
  }

  void _applyAiPrice() {
    setState(() {
      _useAiPrice = true;
      _startPriceController.text = _aiRecommendedPrice.toString();
    });
  }

  void _switchToDirectStartPriceInput() {
    setState(() {
      _useAiPrice = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startPriceFocusNode.requestFocus();
    });
  }

  List<T> _moveItemToFirst<T>(List<T> source, int index) {
    final copied = List<T>.from(source);
    if (index <= 0 || index >= copied.length) return copied;
    final selected = copied.removeAt(index);
    copied.insert(0, selected);
    return copied;
  }

  String? _priceWarningText() {
    if (_auctionType == '최저가 경매') return null;
    final entered = _parseNumber(_useAiPrice ? _aiRecommendedPrice.toString() : _startPriceController.text);
    if (entered <= 0) return null;
    if (entered > (_aiRecommendedPrice * 1.5)) {
      return 'AI 추천가보다 많이 높아요. 구매자 입찰 전에도 안내 문구를 보여주는 방향으로 연결하면 좋아요.';
    }
    return null;
  }

  Future<bool> _confirmRegisterPolicy() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('경매 등록 전 확인', style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text(
            '선정적, 폭력적, 혐오, 불법 거래, 저작권 침해 등 운영정책에 위반되는 상품은 신고 또는 관리자 확인 후 사전 안내 없이 숨김/삭제 처리될 수 있습니다.\n\n등록할 상품이 운영정책에 위반되지 않는지 다시 확인해주세요.',
            style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('확인 후 등록', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (_auctionType == '최저가 경매' && !_lowestAuctionAgreement) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최저가 경매 조건에 동의해주세요.')),
      );
      return;
    }

    final startPrice = _finalStartPrice;
    if (startPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작가 또는 최소 희망가를 입력해주세요.')),
      );
      return;
    }

    if (!_isEditMode) {
      final confirmed = await _confirmRegisterPolicy();
      if (!confirmed) return;
    }

    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser;
    final edit = widget.editProduct;

    final existingCount = _existingImageUrls.length;
    final selectedCoverIndex = _totalImageCount == 0 ? 0 : _coverImageIndex.clamp(0, _totalImageCount - 1);
    final coverIsExisting = selectedCoverIndex < existingCount;
    final coverLocalIndex = selectedCoverIndex - existingCount;

    final orderedExistingImageUrls = coverIsExisting
        ? _moveItemToFirst(_existingImageUrls, selectedCoverIndex)
        : List<String>.from(_existingImageUrls);
    final orderedImageBytesList = !coverIsExisting && coverLocalIndex >= 0
        ? _moveItemToFirst(_imageBytesList, coverLocalIndex)
        : List<Uint8List>.from(_imageBytesList);

    final product = ProductItem(
      id: _isEditMode ? edit?.id : null,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      tags: _tagController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(),
      condition: _condition,
      price: _formatWonFromInt(startPrice),
      bids: '0명',
      time: _timeLabel(_period),
      imageEmoji: _categoryEmoji(_category),
      imageBytesList: orderedImageBytesList,
      imageUrl: orderedExistingImageUrls.isNotEmpty ? orderedExistingImageUrls.first : edit?.imageUrl,
      imageUrls: orderedExistingImageUrls,
      preferUploadedImagesFirst: !coverIsExisting && orderedImageBytesList.isNotEmpty,
      likes: _isEditMode ? (edit?.likes ?? '0') : '0',
      sellerId: _isEditMode ? (edit?.sellerId ?? user?.uid) : user?.uid,
      sellerName: user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : '나의 덕샵',
      sellerSalesCount: edit?.sellerSalesCount ?? 0,
      auctionType: _auctionType == '최저가 경매' ? 'lowest' : 'normal',
      startPrice: startPrice,
      currentPrice: startPrice,
      hopePrice: _parseNumber(_hopePriceController.text),
      buyNowPrice: _parseNumber(_buyNowPriceController.text),
      bidUnit: _finalBidUnit,
      shippingFee: _parseNumber(_shippingFeeController.text),
      aiRecommendedPrice: _aiRecommendedPrice,
      status: 'active',
      createdAt: _isEditMode ? (edit?.createdAt ?? DuckAuctionStore.devNow()) : DuckAuctionStore.devNow(),
      endAt: DuckAuctionStore.devNow().add(_periodDuration(_period)),
    );

    final result = _isEditMode ? await DuckAuctionStore.updateAuction(product) : await DuckAuctionStore.addAuction(product);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success && result.product != null) {
      if (_isEditMode) {
        if (!mounted) return;
        Navigator.of(context).pop(result.product);
      } else {
        await _showRegisterCompleteSheet(result.product!);
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('경매 저장에 실패했습니다.\n잠시 후 다시 시도해주세요.'),
      ),
    );
  }

  Future<void> _showRegisterCompleteSheet(ProductItem product) async {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 22),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.82, end: 1),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text('🎉', style: TextStyle(fontSize: 34)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '경매 등록 완료!',
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                const Text(
                  '이제 입찰을 기다려보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: kDuckPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                    );
                  },
                  child: const Text('상품 보러가기', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    foregroundColor: kDuckPrimary,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _resetForm();
                  },
                  child: const Text('계속 등록하기', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _tagController.clear();
      _shippingFeeController.text = '3000';
      _hopePriceController.clear();
      _startPriceController.clear();
      _buyNowPriceController.clear();
      _existingImageUrls.clear();
      _imageBytesList.clear();
      _imageNames.clear();
      _coverImageIndex = 0;
      _category = '치이카와';
      _condition = '미개봉';
      _auctionType = '일반 경매';
      _period = '24시간';
      _bidUnit = '1,000원';
      _useAiPrice = false;
      _lowestAuctionAgreement = false;
    });
  }

  String _categoryEmoji(String category) {
    switch (category) {
      case '산리오':
        return '🎀';
      case '진격의 거인':
        return '⚔️';
      case '디즈니':
        return '🐭';
      case '포켓몬':
        return '⚡';
      case '레고':
        return '🧱';
      case '건담':
        return '🤖';
      case '치이카와':
        return '⭐';
      default:
        return '🎁';
    }
  }

  @override
  Widget build(BuildContext context) {
    final warning = _priceWarningText();
    final isLowestAuction = _auctionType == '최저가 경매';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(_isEditMode ? '경매 수정' : '경매 등록', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? (_isEditMode ? '수정 중...' : '등록 중...') : (_isEditMode ? '수정' : '등록'), style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF334155))),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
            children: [
              _PhotoPickerBox(
                existingImageUrls: List<String>.from(_existingImageUrls),
                existingPreviewBytesList: List<Uint8List>.from(_existingPreviewBytesList),
                imageBytesList: List<Uint8List>.from(_imageBytesList),
                imageNames: List<String>.from(_imageNames),
                coverImageIndex: _coverImageIndex,
                onSetCoverImageIndex: _setCoverImageIndex,
                onPickImage: _pickImage,
                onRemoveExistingAt: _removeExistingImageAt,
                onRemoveAt: _removeImageAt,
              ),
              const SizedBox(height: 18),
              _PlainSection(
                children: [
                  _UnderlineTextField(
                    controller: _titleController,
                    label: '제목',
                    hint: '상품명을 입력해주세요.',
                    validator: (value) => value == null || value.trim().isEmpty ? '제목을 입력해주세요.' : null,
                  ),
                  _UnderlineTextField(
                    controller: _descriptionController,
                    label: '설명',
                    hint: '구성품, 하자 여부, 구매 시기 등을 자세히 적어주세요.',
                    maxLines: 5,
                  ),
                  _UnderlineTextField(
                    controller: _tagController,
                    label: '태그',
                    hint: '예: 치이카와, 인형, 한정판',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PlainSection(
                children: [
                  _RegisterSelectTile(
                    label: '카테고리',
                    value: _category,
                    items: _categories,
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  _RegisterSelectTile(
                    label: '상품 상태',
                    value: _condition,
                    items: _conditions,
                    onChanged: (value) => setState(() => _condition = value),
                  ),
                  _UnderlineTextField(
                    controller: _shippingFeeController,
                    label: '배송비',
                    hint: '예: 3000 / 반택 기능은 추후 연결',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PlainSection(
                title: '경매 방식',
                children: [
                  _SegmentSelector(
                    values: _auctionTypes,
                    selectedValue: _auctionType,
                    onChanged: (value) {
                      setState(() {
                        _auctionType = value;
                        if (value == '최저가 경매') {
                          _useAiPrice = false;
                          _startPriceController.text = '1000';
                          _bidUnit = '1,000원';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isLowestAuction
                        ? _LowestAuctionNotice(
                            agreed: _lowestAuctionAgreement,
                            onChanged: (value) => setState(() => _lowestAuctionAgreement = value ?? false),
                          )
                        : _NormalAuctionFields(
                            searchQuery: _titleController.text,
                            aiPrice: _aiRecommendedPrice,
                            useAiPrice: _useAiPrice,
                            onUseAiPriceChanged: (value) => setState(() {
                              _useAiPrice = value;
                              if (value) {
                                _startPriceController.text = _aiRecommendedPrice.toString();
                              }
                            }),
                            onApplyAiPrice: _applyAiPrice,
                            onDirectInput: _switchToDirectStartPriceInput,
                            hopePriceController: _hopePriceController,
                            startPriceController: _startPriceController,
                            startPriceFocusNode: _startPriceFocusNode,
                            buyNowPriceController: _buyNowPriceController,
                            bidUnit: _bidUnit,
                            bidUnits: _bidUnits,
                            onBidUnitChanged: (value) => setState(() => _bidUnit = value),
                            warning: warning,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PlainSection(
                children: [
                  _RegisterSelectTile(
                    label: '경매 기간',
                    value: _period,
                    items: _periods,
                    onChanged: (value) => setState(() => _period = value),
                  ),
                ],
              ),
              if (!_isEditMode) ...[
                const SizedBox(height: 14),
                const _RegisterPolicyNotice(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSubmitting ? null : _submit,
            child: Text(
              _isSubmitting ? (_isEditMode ? '수정 중...' : '등록 중...') : _isEditMode ? '수정 완료하기' : isLowestAuction ? '최저가 경매 등록하기' : '일반 경매 등록하기',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}


class _PhotoPickerBox extends StatefulWidget {
  final List<String> existingImageUrls;
  final List<Uint8List> existingPreviewBytesList;
  final List<Uint8List> imageBytesList;
  final List<String> imageNames;
  final int coverImageIndex;
  final ValueChanged<int> onSetCoverImageIndex;
  final VoidCallback onPickImage;
  final ValueChanged<int> onRemoveExistingAt;
  final ValueChanged<int> onRemoveAt;

  const _PhotoPickerBox({
    required this.existingImageUrls,
    this.existingPreviewBytesList = const [],
    required this.imageBytesList,
    required this.imageNames,
    required this.coverImageIndex,
    required this.onSetCoverImageIndex,
    required this.onPickImage,
    required this.onRemoveExistingAt,
    required this.onRemoveAt,
  });

  @override
  State<_PhotoPickerBox> createState() => _PhotoPickerBoxState();
}

class _PhotoPickerBoxState extends State<_PhotoPickerBox> {
  final ScrollController _scrollController = ScrollController();

  int get _totalCount => widget.existingImageUrls.length + widget.imageBytesList.length;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double offset) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _brokenPreview({required int displayIndex}) {
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined, color: Color(0xFF64748B), size: 24),
          const SizedBox(height: 6),
          Text(
            '기존 사진 $displayIndex',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '저장 후 표시',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingImage(int index) {
    final previewBytes = index < widget.existingPreviewBytesList.length
        ? widget.existingPreviewBytesList[index]
        : null;

    // 로컬 미리보기가 있으면 URL보다 우선 표시합니다.
    // 수정 화면에서 네트워크 이미지가 늦게 뜨거나 실패해도 어떤 사진인지 바로 판단할 수 있어요.
    if (previewBytes != null && previewBytes.isNotEmpty) {
      return Image.memory(
        previewBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.high,
      );
    }

    final url = widget.existingImageUrls[index].trim();
    if (url.isEmpty) return _brokenPreview(displayIndex: index + 1);
    return FirebaseStorageImage(
      source: url,
      fit: BoxFit.cover,
      fallback: _brokenPreview(displayIndex: index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showScrollHint = _totalCount >= 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '상품 이미지',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              '$_totalCount/10',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: Stack(
            children: [
              Scrollbar(
                controller: _scrollController,
                thumbVisibility: showScrollHint,
                notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(right: showScrollHint ? 38 : 0),
                  itemCount: _totalCount + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return InkWell(
                        onTap: widget.onPickImage,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 30, color: Color(0xFF475569)),
                              SizedBox(height: 7),
                              Text('사진 추가', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                              SizedBox(height: 2),
                              Text('최대 10장', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      );
                    }

                    final imageIndex = index - 1;
                    final isExisting = imageIndex < widget.existingImageUrls.length;
                    final localIndex = imageIndex - widget.existingImageUrls.length;
                    final isCover = imageIndex == widget.coverImageIndex;
                    return Stack(
                      children: [
                        InkWell(
                          onTap: () => widget.onSetCoverImageIndex(imageIndex),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCover ? kAiAccent : const Color(0xFFE2E8F0),
                                width: isCover ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isExisting
                                ? _buildExistingImage(imageIndex)
                                : Image.memory(
                                    widget.imageBytesList[localIndex],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    filterQuality: FilterQuality.high,
                                  ),
                          ),
                        ),
                        Positioned(
                          left: 7,
                          top: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCover ? kAiAccent : Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isCover ? '대표' : '${imageIndex + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        if (!isCover)
                          Positioned(
                            left: 7,
                            bottom: 7,
                            child: InkWell(
                              onTap: () => widget.onSetCoverImageIndex(imageIndex),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Text(
                                  '대표 설정',
                                  style: TextStyle(color: Color(0xFF334155), fontSize: 10, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: InkWell(
                            onTap: () => isExisting ? widget.onRemoveExistingAt(imageIndex) : widget.onRemoveAt(localIndex),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 15, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (showScrollHint)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 8,
                  child: Container(
                    width: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.white.withOpacity(0), Colors.white],
                      ),
                    ),
                  ),
                ),
              if (showScrollHint)
                Positioned(
                  right: 4,
                  top: 30,
                  child: InkWell(
                    onTap: () => _scrollBy(114),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF334155)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          showScrollHint
              ? '오른쪽으로 넘기면 다른 사진도 확인할 수 있어요. 대표 표시가 붙은 사진이 대표 이미지로 사용돼요.'
              : '대표 표시가 붙은 사진이 대표 이미지로 사용돼요. PC에서는 파일 선택, 모바일에서는 갤러리에서 여러 장을 선택할 수 있어요.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PlainSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _PlainSection({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _UnderlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final String? helperText;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;

  const _UnderlineTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.helperText,
    this.focusNode,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        color: enabled ? Colors.black : const Color(0xFF777777),
        fontWeight: enabled ? FontWeight.normal : FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        alignLabelWithHint: maxLines > 1,
        floatingLabelStyle: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w800),
        disabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE4E4E4))),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE4E4E4))),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE4E4E4))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155), width: 1.4)),
      ),
    );
  }
}

class _RegisterSelectTile extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _RegisterSelectTile({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4))),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF777777))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(value, style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w800)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final selected = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    ...items.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item, style: const TextStyle(fontWeight: FontWeight.w800)),
                        trailing: item == value ? const Icon(Icons.check, color: Color(0xFF334155)) : null,
                        onTap: () => Navigator.of(context).pop(item),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

class _SegmentSelector extends StatelessWidget {
  final List<String> values;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  const _SegmentSelector({required this.values, required this.selectedValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: values.map((value) {
          final selected = value == selectedValue;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(value),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selected ? const Color(0xFF334155) : const Color(0xFF777777),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NormalAuctionFields extends StatelessWidget {
  final String searchQuery;
  final int aiPrice;
  final bool useAiPrice;
  final ValueChanged<bool> onUseAiPriceChanged;
  final VoidCallback onApplyAiPrice;
  final VoidCallback onDirectInput;
  final TextEditingController hopePriceController;
  final TextEditingController startPriceController;
  final FocusNode startPriceFocusNode;
  final TextEditingController buyNowPriceController;
  final String bidUnit;
  final List<String> bidUnits;
  final ValueChanged<String> onBidUnitChanged;
  final String? warning;

  const _NormalAuctionFields({
    required this.searchQuery,
    required this.aiPrice,
    required this.useAiPrice,
    required this.onUseAiPriceChanged,
    required this.onApplyAiPrice,
    required this.onDirectInput,
    required this.hopePriceController,
    required this.startPriceController,
    required this.startPriceFocusNode,
    required this.buyNowPriceController,
    required this.bidUnit,
    required this.bidUnits,
    required this.onBidUnitChanged,
    required this.warning,
  });

  String _formatWonFromInt(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      buffer.write(raw[i]);
      final left = raw.length - i - 1;
      if (left > 0 && left % 3 == 0) buffer.write(',');
    }
    return '${buffer}원';
  }

  Future<void> _searchMarketPrice(BuildContext context) async {
    final keyword = searchQuery.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상품명을 먼저 입력해주세요.')));
      return;
    }
    final uri = Uri.https('search.naver.com', '/search.naver', {'query': keyword});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('네이버 검색을 열지 못했어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('normalAuction'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFF1F5), Color(0xFFFFF7FA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF9DB8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFE11D48), size: 18),
                const SizedBox(width: 6),
                Text('AI 추천가', style: AppTextStyles.aiTitle),
              ]),
              const SizedBox(height: 8),
              const Text('아직 AI 추천가가 없어요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFE11D48))),
              const SizedBox(height: 5),
              const Text(
                '유사 상품의 거래 데이터가 충분하지 않아 현재는 예상 가격을 안내하기 어려워요. 직접 시작가를 입력하거나 네이버에서 시세를 확인해주세요.',
                style: TextStyle(fontSize: 12, color: Color(0xFF777777), height: 1.45),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _searchMarketPrice(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE11D48),
                    side: const BorderSide(color: Color(0xFFE11D48)),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  icon: const Icon(Icons.search_rounded),
                  label: Text('네이버에서 시세 찾기', style: AppTextStyles.bannerButton),
                ),
              ),
            ],
          ),
        ),
        if (warning != null) ...[
          const SizedBox(height: 10),
          _NoticeBox(text: warning!),
        ],
        const SizedBox(height: 8),
        _UnderlineTextField(
          controller: hopePriceController,
          label: '최소 희망가',
          hint: '예: 15000',
          keyboardType: TextInputType.number,
        ),
        _UnderlineTextField(
          controller: startPriceController,
          focusNode: startPriceFocusNode,
          label: '시작가',
          hint: '예: 10000',
          keyboardType: TextInputType.number,
          validator: (value) {
            final number = int.tryParse((value ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return number <= 0 ? '시작가를 입력해주세요.' : null;
          },
        ),
        _UnderlineTextField(
          controller: buyNowPriceController,
          label: '즉시 구매가선택',
          hint: '비워두어도 돼요',
          keyboardType: TextInputType.number,
        ),
        _RegisterSelectTile(
          label: '입찰 단위',
          value: bidUnit,
          items: bidUnits,
          onChanged: onBidUnitChanged,
        ),
      ],
    );
  }
}

class _LowestAuctionNotice extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool?> onChanged;

  const _LowestAuctionNotice({required this.agreed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('lowestAuction'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('최저가 경매 조건', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 10),
          const _CheckLine(text: '시작가 1,000원'),
          const _CheckLine(text: '입찰 단위 1,000원 고정'),
          const _CheckLine(text: '택배비 별도'),
          const _CheckLine(text: '유찰 없음'),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: agreed,
            activeColor: const Color(0xFFE11D48),
            onChanged: onChanged,
            title: const Text('위 조건에 동의하고 최저가 경매로 등록합니다.', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  final String text;
  const _CheckLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 17, color: Color(0xFF334155)),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RegisterPolicyNotice extends StatelessWidget {
  const _RegisterPolicyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.report_problem_outlined, size: 20, color: Color(0xFFD97706)),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '운영정책 안내\n선정적, 폭력적, 혐오, 불법 거래, 저작권 침해 등 규칙에 위반되는 상품은 신고 또는 관리자 확인 후 사전 안내 없이 숨김/삭제 처리될 수 있어요.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF92400E), fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  final String text;
  const _NoticeBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFF97316)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF9A3412)))),
        ],
      ),
    );
  }
}

