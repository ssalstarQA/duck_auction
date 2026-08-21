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
  final _shippingFeeController = TextEditingController(text: '1900');
  final _hopePriceController = TextEditingController();
  final _startPriceController = TextEditingController();
  final _startPriceFocusNode = FocusNode();

  final List<String> _existingImageUrls = <String>[];
  final List<Uint8List> _existingPreviewBytesList = <Uint8List>[];
  final List<Uint8List> _imageBytesList = <Uint8List>[];
  final List<String> _imageNames = <String>[];

  bool get _isEditMode => widget.editProduct != null && !widget.registerAsNew;

  String _category = '치이카와';
  String _kujiGrade = AppCategories.kujiGradeUpper;
  String _itemType = AppCategories.itemTypeEtc;
  String _condition = '미개봉';
  String _auctionType = '일반 경매';
  String _period = '24시간';
  String _bidUnit = '1,000원';
  String _shippingOption = _shipHalf;
  bool _useAiPrice = false;
  // AI 추천가: 서버(recommendPrice)가 내부 거래 데이터 + 네이버 쇼핑 + OpenAI
  // 웹검색을 종합해 계산해요. 서버가 값을 못 내면 규칙 기반 추정가로 폴백합니다.
  bool _aiComputed = false;
  int _aiSampleCount = 0;
  int? _aiDataPrice; // null이면 데이터 부족 → 규칙 기반 폴백
  bool _lowestAuctionAgreement = false;
  bool _isSubmitting = false;
  int _coverImageIndex = 0;

  // AppCategories.names(product_item.dart)가 카테고리 목록의 단일 기준이고,
  // 여기서는 '기타' 선택지만 하나 더 붙여요.
  static final List<String> _categories = [...AppCategories.names, AppCategories.etc];
  static const _conditions = ['미개봉', '개봉', '사용감 있음'];
  static const _auctionTypes = ['일반 경매', '최저가 경매'];
  static const _periods = ['12시간', '24시간', '3일', '7일'];
  static const _bidUnits = ['100원', '500원', '1,000원', '5,000원'];

  // 배송 방식 — 무료배송, 그리고 반값택배·일반택배는 각 범위 내에서 직접 입력.
  static const String _shipFree = '무료배송';
  static const String _shipHalf = '반값택배';
  static const String _shipNormal = '일반택배';
  static const List<String> _shippingOptions = [_shipFree, _shipHalf, _shipNormal];
  // 각 배송 방식의 허용 입력 범위(원).
  static const Map<String, (int, int)> _shippingRanges = {
    _shipHalf: (1500, 2000),
    _shipNormal: (3000, 4000),
  };
  // 방식 선택 시 채워줄 기본값.
  static const Map<String, int> _shippingDefaults = {_shipHalf: 1900, _shipNormal: 3500};

  String _shipRangeHint(String option) {
    final r = _shippingRanges[option];
    if (r == null) return '';
    return '${_formatWonFromInt(r.$1)} ~ ${_formatWonFromInt(r.$2)}';
  }

  @override
  void initState() {
    super.initState();
    // 이벤트(수수료 무료) 설정을 최신으로 읽어와, 등록 화면 상단 안내 배지에
    // 반영해요. 결과는 eventFeeConfig ValueNotifier로 전달돼요.
    DuckAuctionStore.loadEventFeeConfig();
    _titleController.addListener(_refreshAiPrice);
    final edit = widget.editProduct;
    if (edit != null) {
      _titleController.text = edit.title;
      _descriptionController.text = edit.description;
      _tagController.text = edit.tags.join(', ');
      // 저장된 배송비로 방식을 추정해요: 0이면 무료, 반값 범위면 반값, 그 외 일반.
      final savedFee = edit.shippingFee;
      _shippingFeeController.text = savedFee.toString();
      if (savedFee <= 0) {
        _shippingOption = _shipFree;
      } else if (savedFee >= _shippingRanges[_shipHalf]!.$1 && savedFee <= _shippingRanges[_shipHalf]!.$2) {
        _shippingOption = _shipHalf;
      } else {
        _shippingOption = _shipNormal;
      }
      _hopePriceController.text = edit.hopePrice > 0 ? edit.hopePrice.toString() : '';
      _startPriceController.text = edit.startPrice > 0 ? edit.startPrice.toString() : '';
      _existingImageUrls.addAll(edit.resolvedImageUrls);
      // 수정 화면에서는 기존 사진 URL이 느리게 로드되거나 웹 권한/CORS 문제로
      // 실패할 수 있어요. 등록 직후 로컬에 남아있는 이미지 bytes가 있으면
      // 같은 순서의 미리보기 fallback으로 보관해 썸네일 판단이 가능하게 합니다.
      _existingPreviewBytesList.addAll(edit.imageBytesList);
      if (_existingPreviewBytesList.isEmpty && edit.imageBytes != null && edit.imageBytes!.isNotEmpty) {
        _existingPreviewBytesList.add(edit.imageBytes!);
      }
      _category = edit.category;
      _kujiGrade = edit.kujiGrade ?? AppCategories.kujiGradeUpper;
      _itemType = edit.itemType;
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
    // 실제 거래 데이터 기반 값이 있으면 그걸 우선 사용해요.
    if (_aiDataPrice != null) return _aiDataPrice!;
    final title = _titleController.text.trim();
    final baseByCategory = {
      '치이카와': 14000,
      '산리오': 9000,
      '진격의 거인': 26000,
      '나의 히어로 아카데미': 15000,
      '원피스': 17000,
      '포켓몬': 13000,
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

      final source = await pickImageSourceSheet(context);
      if (source == null) return;
      if (source == ImageSource.camera) {
        await _captureFromCamera();
        return;
      }

      // 갤러리에서 여러 장 선택 → 한 장씩 크롭해서 추가해요.
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1600);
      if (picked.isEmpty) return;

      final selected = picked.take(remainingCount).toList();
      int added = 0;
      for (final image in selected) {
        final bytes = await cropPickedImage(image);
        if (bytes == null || bytes.isEmpty) continue; // 이 사진은 크롭을 취소함
        if (!mounted) return;
        setState(() {
          _imageBytesList.add(bytes);
          _imageNames.add(image.name);
        });
        // 너무 작은 사진(캡처본·스티커 등)일 때만 조용히 안내해요.
        unawaited(_warnIfLowResolution([bytes]));
        added++;
      }

      final overLimitCount = picked.length - remainingCount;
      if (overLimitCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '사진은 최대 10장까지 등록할 수 있어요. 선택한 ${picked.length}장 중 $added장만 추가했어요.',
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

  // 카메라로 한 장 촬영해서 추가해요(갤러리는 여러 장, 카메라는 한 장씩).
  Future<void> _captureFromCamera() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
      if (photo == null) return;
      final bytes = await cropPickedImage(photo);
      if (bytes == null || bytes.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _imageBytesList.add(bytes);
        _imageNames.add(photo.name);
      });
      unawaited(_warnIfLowResolution([bytes]));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라로 사진을 찍지 못했어요. 카메라 권한을 확인해주세요.')),
      );
    }
  }

  // 짧은 변 기준 이 픽셀 수보다 작으면 카드/썸네일에서 흐리게 보일
  // 가능성이 커요. 캡처본·스티커·아이콘 이미지를 실수로 고른 경우를
  // 걸러내는 정도의 느슨한 기준이라, 실제 카메라 사진은 거의 걸리지 않아요.
  static const int _lowResolutionThreshold = 500;

  Future<int?> _shortSideOf(Uint8List bytes) async {
    try {
      // 이 flutter 버전의 decodeImageFromList는 콜백 없이 bytes 하나만
      // 받고 스스로 Future를 반환해요. 예전 dart:ui 콜백 방식으로 잘못
      // 호출했던 걸 여기서 고쳤어요.
      final image = await decodeImageFromList(bytes);
      return image.width < image.height ? image.width : image.height;
    } catch (_) {
      return null;
    }
  }

  Future<void> _warnIfLowResolution(List<Uint8List> newBytesList) async {
    final shortSides = await Future.wait(newBytesList.map(_shortSideOf));
    final hasLowResolution = shortSides.any((side) => side != null && side < _lowResolutionThreshold);
    if (!hasLowResolution || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('선택한 사진 중 해상도가 낮은 사진이 있어요. 카드에서는 흐리게 보일 수 있어요.'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  // 태그를 쉼표/공백 기준으로 분리해요.
  List<String> _currentTags() {
    return _tagController.text
        .split(RegExp(r'[,\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // 토글을 켜면 실행돼요. 입력을 검증하고, DIM 로딩을 띄운 뒤 태그·제목 기준으로
  // 누적된 완료 거래를 검색해 추천가를 계산해요. 조건을 못 맞추면 토글을 OFF로 되돌립니다.
  Future<void> _applyAiPrice() async {
    final title = _titleController.text.trim();
    final tags = _currentTags();

    // 1) 태그/경매이름이 모두 비어 있으면 안내만 하고 토글 OFF로 복귀.
    if (title.isEmpty && tags.isEmpty) {
      setState(() => _useAiPrice = false);
      await _showAiInfoDialog(
        '입력이 필요해요',
        '먼저 경매 이름(제목)이나 태그를 입력해 주세요.\n같은 종류의 실제 거래 데이터를 찾아 추천 시작가를 계산해 드려요.',
      );
      return;
    }

    // 2) 전체화면 DIM 로딩(덕옥션 아이콘) 표시.
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'AI 추천가 분석',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) => const _AiLoadingOverlay(),
    );

    // 조회가 아주 빨라도 로딩 화면은 최소 5초는 보여줘요(분석하는 느낌 유지).
    final minShown = Future<void>.delayed(const Duration(seconds: 5));
    int? dataPrice;
    int sampleCount = 0;
    try {
      final result = await _fetchDataBasedPrice(tags, title);
      dataPrice = result.$1;
      sampleCount = result.$2;
    } catch (_) {
      dataPrice = null;
      sampleCount = 0;
    } finally {
      await minShown; // 최소 표시 시간 보장
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기
    }
    if (!mounted) return;

    // 3) 검색 실패 또는 조건 부족 → 무엇을 보완하면 되는지 안내 팝업 + 토글 OFF 복귀.
    //    부족해 보이는 항목(사진 없음·제목 짧음·태그 부족)을 강조해서 알려줘요.
    if (dataPrice == null) {
      setState(() {
        _useAiPrice = false;
        _aiComputed = false;
        _aiDataPrice = null;
        _aiSampleCount = sampleCount;
      });
      final cover = _coverImagePayloadForAi();
      final hasImage = cover.urls.isNotEmpty || cover.dataUrls.isNotEmpty;
      await _showAiRecommendFailedDialog(
        hasImage: hasImage,
        titleWeak: title.replaceAll(RegExp(r'\s'), '').length < 4,
        tagsWeak: tags.length < 2,
      );
      return;
    }

    // 4) 성공 → 토글 ON 유지 + 추천가를 시작가로 적용.
    setState(() {
      _aiComputed = true;
      _aiDataPrice = dataPrice;
      _aiSampleCount = sampleCount;
      _useAiPrice = true;
      _startPriceController.text = _aiRecommendedPrice.toString();
    });
  }

  Future<void> _showAiInfoDialog(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFE11D48), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF16305C))),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569))),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 추천가 계산 실패 시, 무엇을 보완하면 되는지 체크리스트로 안내해요.
  // 부족해 보이는 항목(사진 없음/제목 짧음/태그 부족)은 분홍색으로 강조하고,
  // '사진 다시 올리기'로 상품이 잘 보이는 사진을 바로 추가할 수 있게 해줘요.
  Future<void> _showAiRecommendFailedDialog({
    required bool hasImage,
    required bool titleWeak,
    required bool tagsWeak,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFE11D48), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '추천가를 계산하지 못했어요',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF16305C)),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '웹에서 이 상품의 시세를 찾기 어려웠어요.\n아래를 보완하면 더 정확한 추천가를 받을 수 있어요.',
                style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              _aiTipRow(
                '📷',
                '상품이 잘 보이는 사진',
                '상품 전체가 또렷하게 나온 사진을 대표(커버)로 올려주세요. 흐리거나 일부만 보이면 인식이 어려워요.',
                highlight: !hasImage,
              ),
              _aiTipRow(
                '🏷️',
                '정확한 상품명',
                '캐릭터·시리즈·제품명을 구체적으로 적어주세요. (예: 치이카와 우사기 인형)',
                highlight: titleWeak,
              ),
              _aiTipRow(
                '#️⃣',
                '해시태그 보완',
                '캐릭터명·시리즈명·종류를 태그로 2개 이상 넣어주세요.',
                highlight: tagsWeak,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
            child: const Text('직접 수정할게요'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _pickImage();
            },
            icon: const Icon(Icons.add_a_photo_rounded, size: 18),
            label: const Text('사진 다시 올리기'),
          ),
        ],
      ),
    );
  }

  // 실패 안내 팝업의 항목 한 줄(이모지 + 제목 + 설명). highlight면 분홍 강조 + '보완 추천' 배지.
  Widget _aiTipRow(String emoji, String title, String desc, {required bool highlight}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF1F5) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? const Color(0xFFFBCFE1) : Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: highlight ? const Color(0xFF9D174D) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    if (highlight) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '보완 추천',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // AI 추천가 요청에 쓸 대표(커버) 이미지 하나를 준비해요.
  // 등록 화면에서는 아직 업로드 전이라 로컬 bytes를 data URL로 인코딩하고,
  // 수정 화면처럼 이미 업로드된 사진이 커버면 그 URL을 그대로 보내요.
  ({List<String> urls, List<String> dataUrls}) _coverImagePayloadForAi() {
    final total = _totalImageCount;
    if (total == 0) return (urls: const [], dataUrls: const []);
    final existingCount = _existingImageUrls.length;
    final coverIndex = _coverImageIndex.clamp(0, total - 1);
    if (coverIndex < existingCount) {
      final url = _existingImageUrls[coverIndex];
      return (urls: url.isNotEmpty ? [url] : const [], dataUrls: const []);
    }
    final localIndex = coverIndex - existingCount;
    if (localIndex >= 0 && localIndex < _imageBytesList.length) {
      final bytes = _imageBytesList[localIndex];
      // 너무 큰 이미지는 콜러블 페이로드가 커지니 건너뛰어요(텍스트만으로 추천).
      if (bytes.isNotEmpty && bytes.lengthInBytes <= 3 * 1024 * 1024) {
        return (urls: const [], dataUrls: ['data:image/jpeg;base64,${base64Encode(bytes)}']);
      }
    }
    return (urls: const [], dataUrls: const []);
  }

  // 서버(recommendPrice)에 제목·태그·카테고리·상태·대표 이미지를 보내,
  // '내부 거래 데이터 + 네이버 쇼핑 + OpenAI 웹검색'을 종합한 추천가를 받아와요.
  // 블렌딩(내부 우선 + 웹 보조)은 서버에서 처리해요. 값을 못 내면 (null, 표본수)를
  // 반환해 규칙 기반 폴백(_aiRecommendedPrice)으로 넘겨요.
  Future<(int?, int)> _fetchDataBasedPrice(List<String> tags, String title) async {
    if (title.isEmpty && tags.isEmpty) return (null, 0);
    try {
      final img = _coverImagePayloadForAi();
      final res = await FirebaseFunctions.instance
          .httpsCallable('recommendPrice')
          .call<Map<String, dynamic>>({
        'title': title,
        'tags': tags,
        'category': _category,
        'condition': _condition,
        if (img.urls.isNotEmpty) 'imageUrls': img.urls,
        if (img.dataUrls.isNotEmpty) 'imageDataUrls': img.dataUrls,
      });
      final data = res.data;
      final success = data['success'] == true;
      final price = (data['price'] as num?)?.toInt() ?? 0;
      final sampleCount = (data['sampleCount'] as num?)?.toInt() ?? 0;
      if (success && price > 0) return (price, sampleCount);
      return (null, sampleCount);
    } catch (_) {
      // 네트워크/서버 오류 → 규칙 기반 폴백으로.
      return (null, 0);
    }
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
                backgroundColor: const Color(0xFF16305C),
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

    if (_totalImageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상품 사진을 최소 1장 등록해주세요.')),
      );
      return;
    }

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
    if (startPrice < 1000) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('시작가는 최소 1,000원부터 등록할 수 있어요.')),
        );
      return;
    }
    if (startPrice % 1000 != 0) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('시작가는 1,000원 단위로 입력해주세요. (예: 1,000 / 2,000 / 5,000)')),
        );
      return;
    }

    // 무료배송이면 0, 반값/일반택배는 각 범위 내 입력값이어야 해요.
    final shippingFee = _shippingOption == _shipFree ? 0 : _parseNumber(_shippingFeeController.text);
    if (_shippingOption != _shipFree) {
      final range = _shippingRanges[_shippingOption]!;
      if (shippingFee < range.$1 || shippingFee > range.$2) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('$_shippingOption 배송비는 ${_shipRangeHint(_shippingOption)} 사이로 입력해주세요.')),
          );
        return;
      }
      if (shippingFee % 100 != 0) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('배송비는 100원 단위로 입력해주세요.')),
          );
        return;
      }
    }

    if (_category == AppCategories.kuji && !AppCategories.kujiGrades.contains(_kujiGrade)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('쿠지 등급(상위상/하위상)을 선택해주세요.')),
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
      kujiGrade: _category == AppCategories.kuji ? _kujiGrade : null,
      itemType: _itemType,
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
      // 신규 등록이면 저장 단계(_saveAuctionToFirestore)에서 프로필 배지와
      // 첫 등록 여부를 새로 계산해서 채워요. 수정(edit)일 때는 등록 당시
      // 값을 그대로 들고 가야 배지가 사라지거나 NEW가 없어지지 않아요.
      sellerBadgeIds: edit?.sellerBadgeIds ?? const [],
      isSellerFirstListing: edit?.isSellerFirstListing ?? false,
      auctionType: _auctionType == '최저가 경매' ? 'lowest' : 'normal',
      startPrice: startPrice,
      currentPrice: startPrice,
      hopePrice: _parseNumber(_hopePriceController.text),
      buyNowPrice: 0,
      bidUnit: _finalBidUnit,
      shippingFee: shippingFee,
      aiRecommendedPrice: _aiRecommendedPrice,
      // 수수료 면제 여부는 최초 등록 시점에 확정돼요. 수정(edit)일 때는 그때의
      // 값을 그대로 이어가고, 신규 등록이면 저장 단계에서 이벤트 설정 기준으로
      // 다시 스탬프해요.
      feeExempt: edit?.feeExempt ?? false,
      feeRatePercent: edit?.feeRatePercent ?? 0,
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

    // result.error에 StateError로 담긴 구체적인 사유(이메일/휴대폰 인증
    // 필요, 배송지 미등록 등)가 있으면 그대로 보여주고, 없으면 일반적인
    // 실패 문구를 보여줍니다. (예전에는 항상 일반 문구만 떴어서 사용자가
    // 왜 실패했는지 알 수 없었어요.)
    final specificMessage = result.error is StateError ? (result.error as StateError).message : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(specificMessage ?? '경매 저장에 실패했습니다.\n잠시 후 다시 시도해주세요.'),
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
      _shippingFeeController.text = '1900';
      _shippingOption = _shipHalf;
      _aiComputed = false;
      _aiDataPrice = null;
      _aiSampleCount = 0;
      _useAiPrice = false;
      _hopePriceController.clear();
      _startPriceController.clear();
      _existingImageUrls.clear();
      _imageBytesList.clear();
      _imageNames.clear();
      _coverImageIndex = 0;
      _category = '치이카와';
      _kujiGrade = AppCategories.kujiGradeUpper;
      _itemType = AppCategories.itemTypeEtc;
      _condition = '미개봉';
      _auctionType = '일반 경매';
      _period = '24시간';
      _bidUnit = '1,000원';
      _useAiPrice = false;
      _lowestAuctionAgreement = false;
    });
  }

  String _categoryEmoji(String category) => AppCategories.emojiFor(category);

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
            child: Text(_isSubmitting ? (_isEditMode ? '수정 중...' : '등록 중...') : (_isEditMode ? '수정' : '등록'), style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16305C))),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ResponsiveContentBounds(
                maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
                padding: EdgeInsets.fromLTRB(context.pagePadding, 6, context.pagePadding, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              if (!_isEditMode) const _FeeEventBanner(),
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
                    onChanged: (value) => setState(() {
                      _category = value;
                      // 카테고리를 바꿨을 때 현재 세부 카테고리가 새 목록에 없으면
                      // (예: 포켓몬에서 '카드'를 고른 뒤 다른 카테고리로 이동)
                      // 기본값(기타)으로 되돌려 드롭다운 값 꼬임을 막아요.
                      if (!AppCategories.itemTypesForCategory(_category).contains(_itemType)) {
                        _itemType = AppCategories.itemTypeEtc;
                      }
                      // 카테고리가 바뀌면 이전 카테고리 기준 추천가는 무효화해요.
                      _aiComputed = false;
                      _aiDataPrice = null;
                      _aiSampleCount = 0;
                      _useAiPrice = false;
                    }),
                  ),
                  if (_category == AppCategories.kuji)
                    _RegisterSelectTile(
                      label: '쿠지 등급',
                      value: _kujiGrade,
                      items: AppCategories.kujiGrades,
                      itemDescriptions: AppCategories.kujiGradeDescriptions,
                      sheetNote: AppCategories.kujiGradeNote,
                      onChanged: (value) => setState(() => _kujiGrade = value),
                    ),
                  _RegisterSelectTile(
                    label: '세부 카테고리',
                    value: _itemType,
                    items: AppCategories.itemTypesForCategory(_category),
                    onChanged: (value) => setState(() => _itemType = value),
                  ),
                  _RegisterSelectTile(
                    label: '상품 상태',
                    value: _condition,
                    items: _conditions,
                    onChanged: (value) => setState(() => _condition = value),
                  ),
                  _RegisterSelectTile(
                    label: '배송 방식',
                    value: _shippingOption,
                    items: _shippingOptions,
                    onChanged: (value) => setState(() {
                      _shippingOption = value;
                      if (value == _shipFree) {
                        _shippingFeeController.text = '0';
                      } else {
                        final range = _shippingRanges[value]!;
                        final cur = _parseNumber(_shippingFeeController.text);
                        // 범위를 벗어난 값이면 기본값으로 맞춰줘요.
                        if (cur < range.$1 || cur > range.$2) {
                          _shippingFeeController.text = _shippingDefaults[value].toString();
                        }
                      }
                    }),
                  ),
                  if (_shippingOption != _shipFree)
                    _UnderlineTextField(
                      controller: _shippingFeeController,
                      label: '$_shippingOption 배송비',
                      hint: _shipRangeHint(_shippingOption),
                      keyboardType: TextInputType.number,
                      helperText: '${_shipRangeHint(_shippingOption)} 사이로 입력해주세요.',
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
                            aiComputed: _aiComputed,
                            aiSampleCount: _aiSampleCount,
                            aiDataBased: _aiDataPrice != null,
                            useAiPrice: _useAiPrice,
                            onUseAiPriceChanged: (value) {
                              if (value) {
                                // 토글 ON → 검증·검색 후 성공 시에만 ON 유지.
                                _applyAiPrice();
                              } else {
                                setState(() => _useAiPrice = false);
                              }
                            },
                            onApplyAiPrice: _applyAiPrice,
                            onDirectInput: _switchToDirectStartPriceInput,
                            hopePriceController: _hopePriceController,
                            startPriceController: _startPriceController,
                            startPriceFocusNode: _startPriceFocusNode,
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
            ],
          ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: ResponsiveContentBounds(
                maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
                padding: EdgeInsets.fromLTRB(context.pagePadding, 12, context.pagePadding, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16305C),
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
          ],
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
      color: const Color(0xFFF4F7FC),
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
            const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 16)),
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
                            color: const Color(0xFFF4F7FC),
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
                              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                  style: TextStyle(color: Color(0xFF16305C), fontSize: 10, fontWeight: FontWeight.w900),
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
                      child: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF16305C)),
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
        floatingLabelStyle: const TextStyle(color: Color(0xFF16305C), fontWeight: FontWeight.w800),
        disabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE4E4E4))),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE4E4E4))),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE4E4E4))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF16305C), width: 1.4)),
      ),
    );
  }
}

class _RegisterSelectTile extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  // 선택지 옆에 작은 설명을 붙이고 싶을 때만 넣어요(예: 쿠지 등급 설명).
  final Map<String, String>? itemDescriptions;
  // 목록 전체에 대한 안내 문구가 필요할 때만 넣어요(예: 등급 기준 안내).
  final String? sheetNote;

  const _RegisterSelectTile({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemDescriptions,
    this.sheetNote,
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
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (context) => SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
                child: SingleChildScrollView(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    if (sheetNote != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        sheetNote!,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 10),
                    ...items.map((item) {
                      final description = itemDescriptions?[item];
                      final isSelected = item == value;
                      // 체크 아이콘만으로는 선택된 항목이 눈에 잘 안 들어와서,
                      // 진한 배경 대신 아주 옅은 톤 배경 + 글자색만 살짝
                      // 강조하는 정도로 넣었어요. 이 정도면 목록이 번잡해
                      // 보이지 않으면서도 선택 상태가 분명해져요.
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF16305C).withOpacity(0.06) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          title: Text(
                            item,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isSelected ? const Color(0xFF16305C) : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: description == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    description,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                  ),
                                ),
                          trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF16305C)) : null,
                          onTap: () => Navigator.of(context).pop(item),
                        ),
                      );
                    }),
                  ],
                ),
              ),
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
                    color: selected ? const Color(0xFF16305C) : const Color(0xFF777777),
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
  final bool aiComputed;
  final int aiSampleCount;
  final bool aiDataBased;
  final bool useAiPrice;
  final ValueChanged<bool> onUseAiPriceChanged;
  final VoidCallback onApplyAiPrice;
  final VoidCallback onDirectInput;
  final TextEditingController hopePriceController;
  final TextEditingController startPriceController;
  final FocusNode startPriceFocusNode;
  final String bidUnit;
  final List<String> bidUnits;
  final ValueChanged<String> onBidUnitChanged;
  final String? warning;

  const _NormalAuctionFields({
    required this.searchQuery,
    required this.aiPrice,
    required this.aiComputed,
    required this.aiSampleCount,
    required this.aiDataBased,
    required this.useAiPrice,
    required this.onUseAiPriceChanged,
    required this.onApplyAiPrice,
    required this.onDirectInput,
    required this.hopePriceController,
    required this.startPriceController,
    required this.startPriceFocusNode,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('시세 검색 페이지를 열지 못했어요.')));
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
                const Spacer(),
                Switch(
                  value: useAiPrice,
                  activeColor: const Color(0xFFE11D48),
                  onChanged: onUseAiPriceChanged,
                ),
              ]),
              const SizedBox(height: 4),
              if (useAiPrice && aiComputed) ...[
                Text(
                  '웹 시세와 실제 거래 $aiSampleCount건을 종합 분석해 뽑은 추천 시작가예요. '
                  '다만 상품의 현재 인기도나 한정판·품절로 인한 프리미엄가까지 실시간으로 반영하기는 어려워요. '
                  '실제 시세는 상태·구성품에 따라 달라질 수 있으니 참고용으로만 활용해 주세요.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF777777), height: 1.45),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatWonFromInt(aiPrice),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFE11D48)),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFFE11D48)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '이 가격이 시작가로 적용됐어요.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onApplyAiPrice,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFE11D48), padding: EdgeInsets.zero),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('다시 분석', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ] else ...[
                const Text(
                  '토글을 켜면 사진·제목·태그로 웹 전체 시세와 실제 거래 데이터를 함께 분석해 추천 시작가를 계산해 드려요. '
                  '인기도·프리미엄가가 반영된 참고용 가격이니 최종 시작가는 직접 확인 후 정해 주세요.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF777777), height: 1.45),
                ),
              ],
              const SizedBox(height: 8),
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
                  label: Text('다른 사이트에서 시세 찾기', style: AppTextStyles.bannerButton),
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

// AI 추천가 분석 중 전체화면에 띄우는 라이트그레이 DIM + 덕옥션 마스코트 로딩 오버레이.
/// 출시 이벤트 기간에 등록 화면 맨 위에 뜨는 "수수료 무료" 안내 배지예요.
/// 이벤트가 켜져 있고 지금이 무료 창 안일 때만 보여요.
class _FeeEventBanner extends StatelessWidget {
  const _FeeEventBanner();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EventFeeConfig>(
      valueListenable: DuckAuctionStore.eventFeeConfig,
      builder: (context, config, _) {
        if (!config.isActiveNow(DuckAuctionStore.devNow())) {
          return const SizedBox.shrink();
        }
        final end = config.freeWindowEnd;
        final endLabel = end == null
            ? ''
            : ' (${end.month}월 ${end.day}일 등록분까지)';
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE1EC), Color(0xFFFFF3D6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF6C6D8)),
          ),
          child: Row(
            children: [
              const Text('🏴‍☠️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '지금 등록하면 덕옥션 수수료 무료!',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFF9D174D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '정식 출시 이벤트 기간에 등록한 경매는 판매 수수료가 없어요$endLabel.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF9A5B27),
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
  }
}

class _AiLoadingOverlay extends StatelessWidget {
  const _AiLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        // 약간 회색의 반투명 딤 — 뒤 화면이 은은하게 비쳐요.
        color: const Color(0xF0EDEEF0),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Image.asset(
                // 마스코트 + 로고 + "잠시만 기다려주세요!"가 합쳐진 전용 로딩 아이콘.
                'assets/image/image/ai_loading.png',
                width: 300,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3.2, color: Color(0xFFE11D48)),
            ),
          ],
        ),
      ),
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
          const Icon(Icons.check_circle, size: 17, color: Color(0xFF16305C)),
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

