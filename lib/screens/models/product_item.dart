part of '../home_screen.dart';

class CategoryItem {
  final String name;
  final String emoji;
  final String? imagePath;

  const CategoryItem(
    this.name, {
    this.emoji = '🎁',
    this.imagePath,
  });
}

/// 앱 전체에서 쓰는 IP/브랜드 카테고리의 단일 기준입니다.
/// 예전에는 홈 화면, 경매 등록 화면, 상품 이모지 매핑이 각자 카테고리
/// 이름 목록을 따로 들고 있어서 하나를 고치면 나머지가 안 맞는 경우가
/// 있었어요. 카테고리를 추가·삭제·순서 변경할 때는 이 목록만 고치면
/// 나머지 화면이 전부 자동으로 맞춰집니다.
class AppCategories {
  AppCategories._();

  static const List<String> names = [
    '산리오',
    '치이카와',
    '진격의 거인',
    '나의 히어로 아카데미',
    '원피스',
    '포켓몬',
    '쿠지',
  ];

  /// 전체 메뉴의 카테고리 둘러보기 목록에서 쓰는 한 줄 소개예요. "OOO 관련
  /// 경매를 확인하세요"처럼 이름만 바뀌는 뻔한 문구 대신, IP마다 다르게
  /// 써서 카드가 다 똑같아 보이지 않게 했어요. 여기 없는 카테고리(향후
  /// 추가분)는 home_sections.dart에서 기존 템플릿 문구로 자동 대체돼요.
  static const Map<String, String> categoryTaglines = {
    '산리오': '헬로키티부터 마이멜로디까지, 사랑스러운 캐릭터 굿즈',
    '치이카와': '작고 소중한 나의 친구들, 치이카와 굿즈',
    '진격의 거인': '거인에 맞선 그들의 기록, 진격의 거인 굿즈',
    '나의 히어로 아카데미': '플러스 울트라! 히어로들의 굿즈',
    '원피스': '그랜드 라인 위 모험가들의 보물, 원피스 굿즈',
    '포켓몬': '포켓몬과 함께하는 특별한 순간',
    '쿠지': '한 번의 뽑기, 특별한 확률의 쿠지 상품',
  };

  /// 위 목록에 없는 상품을 위한 catch-all이에요. 홈/전체 메뉴의 카테고리
  /// 둘러보기 목록에는 포함하지 않고, 경매 등록 시 선택지로만 제공해요.
  static const String etc = '기타';

  /// '쿠지' 카테고리 이름과, 상품에 붙는 등급 값들이에요. 등록 화면의
  /// 등급 선택 드롭다운과, 카테고리 화면의 등급 필터가 이 목록을 같이 씁니다.
  static const String kuji = '쿠지';
  static const String kujiGradeUpper = '상위상';
  static const String kujiGradeLower = '하위상';
  static const List<String> kujiGrades = [kujiGradeUpper, kujiGradeLower];

  // 이치방쿠지류 등급 체계는 알파벳이 A에 가까울수록(A상~D상·라스트원상)
  // 대형 피규어 위주로 물량이 적고 희소성이 높고, 아래로 갈수록(하위 등급)
  // 타월·클리어파일 같은 소품 굿즈 위주로 물량이 많아져요. 다만 실제
  // 등급 컷오프는 쿠지 시리즈마다 달라요(예: E상까지만 있는 쿠지도 있고
  // J상까지 있는 쿠지도 있어요).
  static const Map<String, String> kujiGradeDescriptions = {
    kujiGradeUpper: 'A상~D상·라스트원상 등 대형 피규어 위주의 상위 등급',
    kujiGradeLower: 'E상 이하 소품·굿즈 위주의 하위 등급',
  };

  static const String kujiGradeNote = '※ 등급 기준(A~D상)은 참고용이에요. 쿠지 시리즈마다 실제 컷오프가 다를 수 있어요.';

  /// IP/브랜드(위 [names])와는 별개로, 상품이 어떤 형태의 굿즈인지를
  /// 나타내는 세부 카테고리예요. 등록 화면 선택지와 카테고리 화면 필터가
  /// 이 목록을 같이 씁니다.
  static const String itemTypeFigure = '피규어';
  static const String itemTypeAcrylic = '아크릴';
  static const String itemTypeGacha = '가챠';
  static const String itemTypeDoll = '인형';
  static const String itemTypeCard = '카드';
  static const String itemTypeEtc = '기타';
  static const List<String> itemTypes = [
    itemTypeFigure,
    itemTypeAcrylic,
    itemTypeGacha,
    itemTypeDoll,
    itemTypeEtc,
  ];

  /// 카테고리(IP)별로 선택할 수 있는 세부 굿즈 유형 목록이에요. 기본값은
  /// 공통 [itemTypes]이고, 해당 IP에서 자주 거래되는 유형이 있으면 더해줘요.
  /// (예: 포켓몬은 트레이딩 '카드' 거래가 많아 '카드'를 추가로 제공해요.)
  /// 등록 화면의 '세부 카테고리' 드롭다운과 카테고리 화면 필터가 같이 씁니다.
  static List<String> itemTypesForCategory(String category) {
    switch (category) {
      case '포켓몬':
        return const [
          itemTypeFigure,
          itemTypeAcrylic,
          itemTypeGacha,
          itemTypeDoll,
          itemTypeCard,
          itemTypeEtc,
        ];
      default:
        return itemTypes;
    }
  }

  static String emojiFor(String category) {
    switch (category) {
      case '산리오':
        return '🎀';
      case '진격의 거인':
        return '⚔️';
      case '나의 히어로 아카데미':
        return '🦸';
      case '원피스':
        return '👒';
      case '포켓몬':
        return '⚡';
      case '치이카와':
        return '⭐';
      case '쿠지':
        return '🎰';
      default:
        return '🎁';
    }
  }
}

/// 정식 출시 이벤트의 '덕옥션 수수료 무료' 설정이에요. Firestore의
/// config/app 문서의 eventFee 맵에 저장되고, 마스터 관리자가 켜고 끌 수 있어요.
/// - [enabled] : 이벤트(무료 수수료) 자체를 켜고 끄는 스위치
/// - [startAt] : 무료 기간 시작 시각(이벤트 시작일)
/// - [freeWindowDays] : 시작일부터 며칠간 등록분을 무료로 볼지(기본 14일=2주)
/// - [feeRatePercent] : 무료 창 밖 등록분에 매기는 기본 수수료율(%, 기본 3%)
///
/// 핵심은 "무료 창 안에 등록된 경매만" 무료로 판정한다는 점이에요. 각 경매는
/// 등록 시점에 feeExempt 값이 박혀서, 나중에 이벤트를 꺼도 소급되지 않아요.
class EventFeeConfig {
  final bool enabled;
  final DateTime? startAt;
  final int freeWindowDays;
  final num feeRatePercent;

  const EventFeeConfig({
    this.enabled = false,
    this.startAt,
    this.freeWindowDays = 14,
    this.feeRatePercent = 3,
  });

  DateTime? get freeWindowEnd =>
      startAt == null ? null : startAt!.add(Duration(days: freeWindowDays));

  /// [when]에 등록된 경매가 무료 대상인지 판정해요.
  bool isWithinFreeWindow(DateTime when) {
    if (!enabled || startAt == null) return false;
    final end = freeWindowEnd!;
    return !when.isBefore(startAt!) && when.isBefore(end);
  }

  /// 지금 이 순간 무료 창이 진행 중인지(등록 화면 안내 배지용).
  bool isActiveNow(DateTime now) => isWithinFreeWindow(now);

  Map<String, dynamic> toFirestore() => {
        'enabled': enabled,
        'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
        'freeWindowDays': freeWindowDays,
        'feeRatePercent': feeRatePercent,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory EventFeeConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const EventFeeConfig();
    final rawStart = data['startAt'];
    DateTime? start;
    if (rawStart is Timestamp) {
      start = rawStart.toDate();
    } else if (rawStart is String && rawStart.isNotEmpty) {
      start = DateTime.tryParse(rawStart);
    }
    return EventFeeConfig(
      enabled: data['enabled'] == true,
      startAt: start,
      freeWindowDays: (data['freeWindowDays'] as num?)?.toInt() ?? 14,
      feeRatePercent: (data['feeRatePercent'] as num?) ?? 3,
    );
  }

  EventFeeConfig copyWith({
    bool? enabled,
    DateTime? startAt,
    bool clearStart = false,
    int? freeWindowDays,
    num? feeRatePercent,
  }) {
    return EventFeeConfig(
      enabled: enabled ?? this.enabled,
      startAt: clearStart ? null : (startAt ?? this.startAt),
      freeWindowDays: freeWindowDays ?? this.freeWindowDays,
      feeRatePercent: feeRatePercent ?? this.feeRatePercent,
    );
  }
}


/// 배송 등록 화면의 택배사 선택 목록이에요. 여기만 고치면 등록 화면 드롭다운이
/// 자동으로 맞춰져요. 배송조회는 코드 매핑 없이도 되도록 네이버 검색으로 열어요
/// (네이버가 '택배사 + 송장번호'를 검색하면 배송조회 위젯을 바로 띄워줘요).
class AppCouriers {
  AppCouriers._();

  static const List<String> names = [
    'CJ대한통운',
    '우체국택배',
    '한진택배',
    '롯데택배',
    '로젠택배',
    'GS편의점택배',
    'CU편의점택배',
    '경동택배',
    '대신택배',
    '기타',
  ];

  /// 배송조회 링크(네이버 검색). 택배사 + 송장번호로 검색하면 배송조회가 떠요.
  static Uri trackingSearchUri(String courier, String trackingNumber) {
    final query = Uri.encodeComponent('$courier $trackingNumber 택배조회');
    return Uri.parse('https://search.naver.com/search.naver?query=$query');
  }
}

class ProductPhoto extends StatelessWidget {
  final ProductItem product;
  final double fontSize;

  const ProductPhoto({
    super.key,
    required this.product,
    required this.fontSize,
  });

  static Future<String?> _loadCoverUrlFromFirestore(String productId) async {
    // null 결과를 캐시하지 않습니다. 저장 직후 Storage URL 반영보다
    // 홈 카드가 먼저 그려지면 null이 캐시되어 계속 별 아이콘만 남을 수 있어서요.
    try {
      final doc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      final data = doc.data();
      if (data == null) return null;
      final urls = ProductItem._imageUrlsFromJson(data);
      if (urls.isEmpty) return null;
      final rawIndex = ProductItem._asInt(data['coverImageIndex']);
      final index = ProductItem._safeCoverIndex(rawIndex, urls.length);
      return urls[index];
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = product.imageBytesList.isNotEmpty
        ? product.imageBytesList.first
        : product.imageBytes;
    final url = product.resolvedCoverImageUrl;

    Widget placeholder() => Center(
          child: Text(product.imageEmoji, style: TextStyle(fontSize: fontSize)),
        );

    Widget localImage() {
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        );
      }
      return placeholder();
    }

    Widget storageImage(String source) {
      return FirebaseStorageImage(
        source: source,
        fit: BoxFit.cover,
        fallback: localImage(),
      );
    }

    if (url != null && url.trim().isNotEmpty) {
      return storageImage(url);
    }

    // 메인 목록은 예전 로컬 저장본/낡은 ProductItem이 먼저 그려질 때가 있어서
    // product.id가 있으면 Firestore 원본에서 대표 이미지만 한 번 더 찾아옵니다.
    final productId = product.id;
    if (productId != null && productId.trim().isNotEmpty) {
      return FutureBuilder<String?>(
        future: _loadCoverUrlFromFirestore(productId),
        builder: (context, snapshot) {
          final remoteUrl = snapshot.data;
          if (remoteUrl != null && remoteUrl.trim().isNotEmpty) {
            return storageImage(remoteUrl);
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ImageLoadingPlaceholder();
          }
          return localImage();
        },
      );
    }

    return localImage();
  }
}

class FirebaseStorageImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final Widget fallback;

  const FirebaseStorageImage({
    super.key,
    required this.source,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  static final Map<String, Future<Uint8List?>> _memoryCache = <String, Future<Uint8List?>>{};

  static bool _looksLikeFirebaseStorage(String value) {
    return value.startsWith('gs://') ||
        value.contains('firebasestorage.googleapis.com') ||
        value.startsWith('product_images/') ||
        value.startsWith('home_banners/') ||
        value.startsWith('banner_images/');
  }

  static Reference? _refFromSource(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    try {
      if (trimmed.startsWith('gs://') || trimmed.contains('firebasestorage.googleapis.com')) {
        return FirebaseStorage.instance.refFromURL(trimmed);
      }
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        return FirebaseStorage.instance.ref(trimmed);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<Uint8List?> _loadBytes(String source) {
    final cached = _memoryCache[source];
    if (cached != null) return cached;

    final future = () async {
      final ref = _refFromSource(source);
      if (ref == null) return null;
      try {
        return await ref.getData(10 * 1024 * 1024);
      } catch (_) {
        // 저장 직후 홈이 먼저 그려지면 일시적으로 실패할 수 있습니다.
        // 실패(null)를 캐시하면 계속 별 아이콘만 남으므로 실패 캐시는 지웁니다.
        _memoryCache.remove(source);
        return null;
      }
    }();

    _memoryCache[source] = future;
    return future;
  }

  Widget _networkImage(String value) {
    if (!value.startsWith('http://') && !value.startsWith('https://')) return fallback;
    return Image.network(
      value,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const _ImageLoadingPlaceholder();
      },
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = source.trim();
    if (value.isEmpty) return fallback;

    if (!_looksLikeFirebaseStorage(value)) {
      return _networkImage(value);
    }

    return FutureBuilder<Uint8List?>(
      future: _loadBytes(value),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ImageLoadingPlaceholder();
        }
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            width: double.infinity,
            height: double.infinity,
            fit: fit,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          );
        }
        return _networkImage(value);
      },
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class ProductItem {
  final String? id;
  final String title;
  final String description;
  final String category;
  // '쿠지' 카테고리에서만 쓰는 등급 값이에요('상위상'/'하위상'). 다른
  // 카테고리 상품에서는 항상 null입니다.
  final String? kujiGrade;
  // 피규어/아크릴/가챠/인형/기타처럼, 어떤 IP 카테고리든 상관없이 상품의
  // 형태를 나타내는 세부 카테고리예요.
  final String itemType;
  final List<String> tags;
  final String condition;
  final String price;
  final String bids;
  final String time;
  final String imageEmoji;
  final Uint8List? imageBytes;
  final List<Uint8List> imageBytesList;
  final String? imageUrl;
  final List<String> imageUrls;
  final int coverImageIndex;
  final String? coverImageUrl;
  final int imageSchemaVersion;
  final bool preferUploadedImagesFirst;
  final String likes;
  final String? sellerId;
  final String sellerName;
  final int sellerSalesCount;
  // 판매자가 프로필에서 직접 골라 켜둔 배지(최대 3개, kSellerBadgeOptions의
  // id 목록). 등록 시점에 판매자 프로필의 sellerBadges를 그대로 복사해 두는
  // 값이라, 이후 프로필에서 배지를 바꿔도 이미 등록된 상품에는 소급 반영되지
  // 않아요(sellerName과 같은 방식).
  final List<String> sellerBadgeIds;
  // 이 상품이 이 판매자의 "생애 첫 경매 등록"이었는지 여부. 등록 시점에 한 번
  // 계산해서 그 상품 문서에만 영구히 남기는 값이에요. 그래서 신규 판매자의
  // 이후 등록 상품에는 NEW가 계속 붙지 않고, 정말 첫 상품에만 남아요.
  final bool isSellerFirstListing;
  final String auctionType;
  final int startPrice;
  final int currentPrice;
  final int hopePrice;
  final int buyNowPrice;
  final String bidUnit;
  final int shippingFee;
  final int aiRecommendedPrice;
  final String status;
  final String? lastBidUserId;
  final String? winnerId;
  final bool feeExempt;
  final num feeRatePercent;
  final String shippingCourier;
  final String shippingTrackingNumber;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? shippingPreparedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? endAt;

  const ProductItem({
    this.id,
    required this.title,
    this.description = '',
    required this.category,
    this.kujiGrade,
    this.itemType = AppCategories.itemTypeEtc,
    this.tags = const [],
    this.condition = '미개봉',
    required this.price,
    required this.bids,
    required this.time,
    required this.imageEmoji,
    this.imageBytes,
    this.imageBytesList = const [],
    this.imageUrl,
    this.imageUrls = const [],
    this.coverImageIndex = 0,
    this.coverImageUrl,
    this.imageSchemaVersion = 2,
    this.preferUploadedImagesFirst = false,
    required this.likes,
    this.sellerId,
    required this.sellerName,
    required this.sellerSalesCount,
    this.sellerBadgeIds = const [],
    this.isSellerFirstListing = false,
    this.auctionType = 'normal',
    this.startPrice = 0,
    this.currentPrice = 0,
    this.hopePrice = 0,
    this.buyNowPrice = 0,
    this.bidUnit = '1,000원',
    this.shippingFee = 0,
    this.aiRecommendedPrice = 0,
    this.status = 'active',
    this.lastBidUserId,
    this.winnerId,
    this.feeExempt = false,
    this.feeRatePercent = 0,
    this.shippingCourier = '',
    this.shippingTrackingNumber = '',
    this.shippedAt,
    this.deliveredAt,
    this.shippingPreparedAt,
    this.createdAt,
    this.updatedAt,
    this.endAt,
  });

  ProductItem copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? kujiGrade,
    bool clearKujiGrade = false,
    String? itemType,
    List<String>? tags,
    String? condition,
    String? price,
    String? bids,
    String? time,
    String? imageEmoji,
    Uint8List? imageBytes,
    List<Uint8List>? imageBytesList,
    bool clearImageBytes = false,
    String? imageUrl,
    List<String>? imageUrls,
    int? coverImageIndex,
    String? coverImageUrl,
    int? imageSchemaVersion,
    bool? preferUploadedImagesFirst,
    String? likes,
    String? sellerId,
    String? sellerName,
    int? sellerSalesCount,
    List<String>? sellerBadgeIds,
    bool? isSellerFirstListing,
    String? auctionType,
    int? startPrice,
    int? currentPrice,
    int? hopePrice,
    int? buyNowPrice,
    String? bidUnit,
    int? shippingFee,
    int? aiRecommendedPrice,
    String? status,
    String? lastBidUserId,
    String? winnerId,
    bool? feeExempt,
    num? feeRatePercent,
    String? shippingCourier,
    String? shippingTrackingNumber,
    DateTime? shippedAt,
    DateTime? deliveredAt,
    DateTime? shippingPreparedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? endAt,
  }) {
    return ProductItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      kujiGrade: clearKujiGrade ? null : kujiGrade ?? this.kujiGrade,
      itemType: itemType ?? this.itemType,
      tags: tags ?? this.tags,
      condition: condition ?? this.condition,
      price: price ?? this.price,
      bids: bids ?? this.bids,
      time: time ?? this.time,
      imageEmoji: imageEmoji ?? this.imageEmoji,
      imageBytes: clearImageBytes ? null : imageBytes ?? this.imageBytes,
      imageBytesList: clearImageBytes ? const [] : imageBytesList ?? this.imageBytesList,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      coverImageIndex: coverImageIndex ?? this.coverImageIndex,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      imageSchemaVersion: imageSchemaVersion ?? this.imageSchemaVersion,
      preferUploadedImagesFirst: preferUploadedImagesFirst ?? this.preferUploadedImagesFirst,
      likes: likes ?? this.likes,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerSalesCount: sellerSalesCount ?? this.sellerSalesCount,
      sellerBadgeIds: sellerBadgeIds ?? this.sellerBadgeIds,
      isSellerFirstListing: isSellerFirstListing ?? this.isSellerFirstListing,
      auctionType: auctionType ?? this.auctionType,
      startPrice: startPrice ?? this.startPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      hopePrice: hopePrice ?? this.hopePrice,
      buyNowPrice: buyNowPrice ?? this.buyNowPrice,
      bidUnit: bidUnit ?? this.bidUnit,
      shippingFee: shippingFee ?? this.shippingFee,
      aiRecommendedPrice: aiRecommendedPrice ?? this.aiRecommendedPrice,
      status: status ?? this.status,
      lastBidUserId: lastBidUserId ?? this.lastBidUserId,
      winnerId: winnerId ?? this.winnerId,
      feeExempt: feeExempt ?? this.feeExempt,
      feeRatePercent: feeRatePercent ?? this.feeRatePercent,
      shippingCourier: shippingCourier ?? this.shippingCourier,
      shippingTrackingNumber: shippingTrackingNumber ?? this.shippingTrackingNumber,
      shippedAt: shippedAt ?? this.shippedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      shippingPreparedAt: shippingPreparedAt ?? this.shippingPreparedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      endAt: endAt ?? this.endAt,
    );
  }

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? fallback;
    return fallback;
  }

  static int _safeCoverIndex(int index, int length) {
    if (length <= 0) return 0;
    if (index < 0) return 0;
    if (index >= length) return 0;
    return index;
  }

  static List<String> _normalizeImageUrls(Iterable<String?> urls) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in urls) {
      final value = raw?.trim();
      if (value == null || value.isEmpty) continue;
      if (seen.add(value)) result.add(value);
    }
    return result;
  }

  static List<String> _urlsFromAny(Object? raw) {
    final urls = <String>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is String) {
          urls.add(item);
        } else if (item is Map) {
          final url = item['url'] ?? item['imageUrl'] ?? item['downloadUrl'] ?? item['src'];
          if (url is String) urls.add(url);
        }
      }
    }
    return _normalizeImageUrls(urls);
  }

  static bool _isHttpOrGsImageSource(String value) {
    final v = value.trim();
    return v.startsWith('http://') || v.startsWith('https://') || v.startsWith('gs://');
  }

  static bool _isStoragePathImageSource(String value) {
    final v = value.trim();
    return !v.startsWith('http://') &&
        !v.startsWith('https://') &&
        !v.startsWith('gs://') &&
        (v.startsWith('product_images/') ||
            v.startsWith('home_banners/') ||
            v.startsWith('banner_images/'));
  }

  static List<String> _imageUrlsFromJson(Map<String, dynamic> json) {
    final allImageFields = _normalizeImageUrls(<String?>[
      json['coverImageUrl'] as String?,
      json['mainImageUrl'] as String?,
      json['imageUrl'] as String?,
      json['legacyImageUrl'] as String?,
      json['downloadUrl'] as String?,
      ..._urlsFromAny(json['imageUrls']),
      ..._urlsFromAny(json['images']),
      ..._urlsFromAny(json['photos']),
    ]);

    // Firestore에는 같은 사진이 downloadURL(imageUrl)과 storagePath(imageStoragePaths)로
    // 동시에 남아 있을 수 있습니다. 홈/수정화면에서 1장이 2장처럼 보이지 않게
    // 실제 URL/gs URL이 하나라도 있으면 storage path는 목록에서 제외합니다.
    final realUrls = _normalizeImageUrls(allImageFields.where(_isHttpOrGsImageSource));
    if (realUrls.isNotEmpty) return realUrls;

    final pathUrls = _normalizeImageUrls(<String?>[
      ...allImageFields.where(_isStoragePathImageSource),
      json['imageStoragePath'] as String?,
      json['storagePath'] as String?,
      json['path'] as String?,
      ..._urlsFromAny(json['imageStoragePaths']),
      ..._urlsFromAny(json['storagePaths']),
    ].where((value) => value == null || _isStoragePathImageSource(value)));

    return pathUrls;
  }

  List<String> get resolvedImageUrls {
    return _normalizeImageUrls(<String?>[
      coverImageUrl,
      if (imageUrls.isNotEmpty && coverImageIndex >= 0 && coverImageIndex < imageUrls.length) imageUrls[coverImageIndex],
      imageUrl,
      ...imageUrls,
    ]);
  }



  String get effectiveStatus {
    final raw = status.toLowerCase().trim();
    if (raw == 'deleted' || raw == 'hidden') return raw;
    if (raw == 'failed' || raw == 'unsold' || raw == 'no_bid') return 'failed';
    if (raw == 'winner_pending' || raw == 'payment_pending' || raw == 'first_pending') return 'winner_pending';
    if (raw == 'second_pending' || raw == 'runner_up_pending') return 'second_pending';
    if (raw == 'third_pending') return 'third_pending';
    if (raw == 'paid' || raw == 'payment_completed') return 'paid';
    if (raw == 'shipped' || raw == 'shipping') return 'shipped';
    if (raw == 'delivered') return 'delivered';
    if (raw == 'completed' || raw == 'trade_completed') return 'completed';
    if (raw == 'cancelled' || raw == 'canceled' || raw == 'refunded' || raw == 'payment_cancelled') return 'cancelled';
    if (raw == 'sold') return 'sold';

    // 입찰자 없이 종료된 경매는 단순 '마감'이 아니라 판매자가
    // 연장하거나 새로 등록할 수 있는 '유찰'로 취급한다.
    final bidMatch = RegExp(r'\d+').firstMatch(bids);
    final bidCount = int.tryParse(bidMatch?.group(0) ?? '0') ?? 0;
    final hasEnded = raw == 'ended' ||
        raw == 'closed' ||
        (endAt != null && !endAt!.isAfter(DuckAuctionStore.devNow())) ||
        time.trim() == '마감';
    if (hasEnded && bidCount == 0) return 'failed';
    if (hasEnded) return 'ended';
    return 'active';
  }

  bool get isAuctionActive => effectiveStatus == 'active';

  bool get isLowestAuction => auctionType == 'lowest';

  /// 운송장(택배사 + 송장번호)이 등록됐는지 여부예요.
  bool get hasShipment =>
      shippingCourier.trim().isNotEmpty && shippingTrackingNumber.trim().isNotEmpty;

  /// 구매자·판매자에게 보여줄 배송 상태 문구예요.
  String get deliveryStatusLabel {
    switch (effectiveStatus) {
      case 'shipped':
        return '배송중';
      case 'delivered':
        return '배송완료';
      case 'completed':
        return '거래완료';
      case 'cancelled':
        return '결제취소';
      case 'paid':
      case 'sold':
      case 'winner_pending':
      case 'second_pending':
      case 'third_pending':
        if (hasShipment) return '배송중';
        return shippingPreparedAt != null ? '배송 준비중' : '결제완료';
      default:
        return '';
    }
  }

  /// 낙찰자(구매자) 관점의 거래 단계 문구예요. 결제 이후 흐름을 더 잘게 나눠
  /// 보여줘요: 판매자 확인 전 → 배송 준비중 → 배송중 → 배송완료 → 거래완료.
  /// 결제 이전 단계(입찰/낙찰 등)에서는 빈 문자열을 반환해요.
  String get buyerFlowLabel {
    switch (effectiveStatus) {
      case 'shipped':
        return '배송중';
      case 'delivered':
        return '배송완료';
      case 'completed':
        return '거래완료';
      case 'cancelled':
        return '결제취소';
      case 'paid':
      case 'sold':
      case 'winner_pending':
      case 'second_pending':
      case 'third_pending':
        if (hasShipment) return '배송중';
        return shippingPreparedAt != null ? '배송 준비중' : '판매자 확인 전';
      default:
        return '';
    }
  }

  /// 이 경매에 적용되는 덕옥션 판매 수수료(원)예요. 이벤트로 면제(feeExempt)면
  /// 0원, 아니면 현재가(낙찰가) 기준 feeRatePercent%를 반올림해 계산해요.
  int get platformFeeAmount =>
      platformFeeFor(currentPrice > 0 ? currentPrice : startPrice);

  int platformFeeFor(int price) {
    if (feeExempt || !feeRatePercent.isFinite || feeRatePercent <= 0 || price <= 0) return 0;
    return (price * feeRatePercent / 100).round();
  }

  /// 판매자에게 보여줄 수수료 안내 문구예요.
  String get platformFeeLabel {
    if (feeExempt) return '무료 (출시 이벤트)';
    if (feeRatePercent <= 0) return '무료';
    final amount = platformFeeAmount;
    if (amount <= 0) return '판매가의 ${_trimNum(feeRatePercent)}%';
    return '${DuckAuctionStore.formatWonFromInt(amount)} (${_trimNum(feeRatePercent)}%)';
  }

  static String _trimNum(num n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  /// 종료까지 3시간 이하로 남았는지. 마감 임박 뱃지를 언제 보여줄지
  /// 판단하는 용도라, endAt이 없거나 이미 지났으면 false예요.
  bool get isEndingSoon {
    final end = endAt;
    if (end == null) return false;
    final diff = end.difference(DuckAuctionStore.devNow());
    return !diff.isNegative && diff <= const Duration(hours: 3);
  }

  /// 등록된 지 얼마나 지났는지 사람이 읽기 좋은 형태로 반환해요.
  /// createdAt이 없으면 빈 문자열을 반환하니, 쓰는 쪽에서 비어있으면
  /// 이어붙이지 않도록 처리해야 해요.
  String get postedAgoLabel {
    final created = createdAt;
    if (created == null) return '';
    final diff = DuckAuctionStore.devNow().difference(created);
    if (diff.isNegative || diff.inMinutes < 1) return '방금 등록';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${created.year}.${created.month.toString().padLeft(2, '0')}.${created.day.toString().padLeft(2, '0')}';
  }

  String get statusLabel {
    switch (effectiveStatus) {
      case 'active':
        return '판매중';
      case 'ended':
        return '마감';
      case 'failed':
        return '유찰';
      case 'sold':
        return '낙찰';
      case 'winner_pending':
        return '1순위 결제대기';
      case 'second_pending':
        return '2순위 결제대기';
      case 'third_pending':
        return '3순위 결제대기';
      case 'paid':
        return '결제완료';
      case 'shipped':
        return '배송중';
      case 'delivered':
        return '배송완료';
      case 'completed':
        return '거래완료';
      case 'cancelled':
        return '결제취소';
      case 'hidden':
        return '숨김';
      case 'deleted':
        return '삭제됨';
      default:
        return '확인필요';
    }
  }

  Color get statusColor {
    switch (effectiveStatus) {
      case 'active':
        return const Color(0xFF16A34A);
      case 'ended':
        return const Color(0xFFF97316);
      case 'failed':
        return const Color(0xFF2563EB);
      case 'sold':
        return const Color(0xFF7C3AED);
      case 'winner_pending':
      case 'second_pending':
      case 'third_pending':
        return const Color(0xFFDB2777);
      case 'paid':
        return const Color(0xFF0891B2);
      case 'shipped':
        return const Color(0xFF2563EB);
      case 'delivered':
        return const Color(0xFF0D9488);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'hidden':
        return const Color(0xFF64748B);
      case 'deleted':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF334155);
    }
  }

  String? get resolvedCoverImageUrl {
    final urls = resolvedImageUrls;
    if (urls.isEmpty) return null;
    return urls.first;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'kujiGrade': kujiGrade,
      'itemType': itemType,
      'tags': tags,
      'condition': condition,
      'price': price,
      'bids': bids,
      'time': time,
      'imageEmoji': imageEmoji,
      // 로컬 bytes를 SharedPreferences에 저장하면 Chrome 프로필/blob 캐시에만 의존하게 되고
      // 프로젝트 용량도 커집니다. 새 실행 복구는 Firestore/Storage URL 기준으로만 합니다.
      'imageBytes': null,
      'imageBytesList': const <String>[],
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'coverImageIndex': coverImageIndex,
      'coverImageUrl': coverImageUrl,
      'imageSchemaVersion': imageSchemaVersion,
      'preferUploadedImagesFirst': preferUploadedImagesFirst,
      'likes': likes,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerSalesCount': sellerSalesCount,
      'sellerBadgeIds': sellerBadgeIds,
      'isSellerFirstListing': isSellerFirstListing,
      'auctionType': auctionType,
      'startPrice': startPrice,
      'currentPrice': currentPrice,
      'hopePrice': hopePrice,
      'buyNowPrice': buyNowPrice,
      'bidUnit': bidUnit,
      'shippingFee': shippingFee,
      'aiRecommendedPrice': aiRecommendedPrice,
      'status': status,
      'lastBidUserId': lastBidUserId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore({
    required String id,
    required String sellerId,
    String? imageUrl,
    List<String>? imageUrls,
  }) {
    final urls = _normalizeImageUrls(imageUrls ?? resolvedImageUrls);
    final safeIndex = _safeCoverIndex(coverImageIndex, urls.length);
    final mainUrl = imageUrl ?? coverImageUrl ?? (urls.isNotEmpty ? urls[safeIndex] : this.imageUrl);
    final finalUrls = urls.isNotEmpty
        ? _normalizeImageUrls(<String>[if (mainUrl != null) mainUrl, ...urls])
        : _normalizeImageUrls(<String>[if (mainUrl != null) mainUrl, if (this.imageUrl != null) this.imageUrl!]);
    final now = Timestamp.fromDate(createdAt ?? DuckAuctionStore.devNow());
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'kujiGrade': kujiGrade,
      'itemType': itemType,
      'tags': tags,
      'condition': condition,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerBadgeIds': sellerBadgeIds,
      'isSellerFirstListing': isSellerFirstListing,
      'imageUrls': finalUrls,
      'coverImageIndex': 0,
      'coverImageUrl': mainUrl,
      'mainImageUrl': mainUrl,
      'imageUrl': mainUrl,
      'imageSchemaVersion': 2,
      'auctionType': auctionType,
      'startPrice': startPrice,
      'currentPrice': currentPrice,
      'hopePrice': hopePrice,
      'buyNowPrice': buyNowPrice,
      'bidUnit': bidUnit,
      'shippingFee': shippingFee,
      'aiRecommendedPrice': aiRecommendedPrice,
      'status': status,
      'lastBidUserId': lastBidUserId,
      'feeExempt': feeExempt,
      'feeRatePercent': feeRatePercent,
      'shippingCourier': shippingCourier,
      'shippingTrackingNumber': shippingTrackingNumber,
      'bidCount': DuckAuctionStore.parseCount(bids),
      'likeCount': DuckAuctionStore.parseCount(likes),
      'viewCount': 0,
      'createdAt': now,
      'updatedAt': FieldValue.serverTimestamp(),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
    };
  }

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    Uint8List? decodedImage;
    final encodedImage = json['imageBytes'];
    if (encodedImage is String && encodedImage.isNotEmpty) {
      try {
        decodedImage = base64Decode(encodedImage);
      } catch (_) {
        decodedImage = null;
      }
    }

    final decodedList = <Uint8List>[];
    final rawList = json['imageBytesList'];
    if (rawList is List) {
      for (final raw in rawList) {
        if (raw is String && raw.isNotEmpty) {
          try {
            decodedList.add(base64Decode(raw));
          } catch (_) {}
        }
      }
    }

    DateTime? parseDate(Object? raw) {
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return ProductItem(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '제목 없음',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '기타',
      kujiGrade: json['kujiGrade'] as String?,
      itemType: json['itemType'] as String? ?? AppCategories.itemTypeEtc,
      tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      condition: json['condition'] as String? ?? '미개봉',
      price: json['price'] as String? ?? '0원',
      bids: json['bids'] as String? ?? '0명',
      time: json['time'] as String? ?? '기간 없음',
      imageEmoji: json['imageEmoji'] as String? ?? '🎁',
      imageBytes: decodedImage,
      imageBytesList: decodedList,
      imageUrl: json['imageUrl'] as String?,
      imageUrls: _imageUrlsFromJson(json),
      coverImageIndex: _asInt(json['coverImageIndex']),
      coverImageUrl: json['coverImageUrl'] as String?,
      imageSchemaVersion: _asInt(json['imageSchemaVersion'], fallback: 1),
      preferUploadedImagesFirst: json['preferUploadedImagesFirst'] == true,
      likes: json['likes'] as String? ?? '0',
      sellerId: json['sellerId'] as String?,
      sellerName: json['sellerName'] as String? ?? '나의 덕샵',
      sellerSalesCount: json['sellerSalesCount'] as int? ?? 0,
      sellerBadgeIds: (json['sellerBadgeIds'] as List?)?.whereType<String>().toList() ?? const [],
      isSellerFirstListing: json['isSellerFirstListing'] == true,
      auctionType: json['auctionType'] as String? ?? 'normal',
      startPrice: json['startPrice'] as int? ?? 0,
      currentPrice: json['currentPrice'] as int? ?? 0,
      hopePrice: json['hopePrice'] as int? ?? 0,
      buyNowPrice: json['buyNowPrice'] as int? ?? 0,
      bidUnit: json['bidUnit'] as String? ?? '1,000원',
      shippingFee: json['shippingFee'] as int? ?? 0,
      aiRecommendedPrice: json['aiRecommendedPrice'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      lastBidUserId: json['lastBidUserId'] as String?,
      winnerId: (json['winnerId'] ?? json['buyerId']) as String?,
      feeExempt: json['feeExempt'] == true,
      feeRatePercent: (json['feeRatePercent'] as num?) ?? 0,
      shippingCourier: json['shippingCourier'] as String? ?? '',
      shippingTrackingNumber: json['shippingTrackingNumber'] as String? ?? '',
      shippedAt: parseDate(json['shippedAt']),
      deliveredAt: parseDate(json['deliveredAt']),
      shippingPreparedAt: parseDate(json['shippingPreparedAt']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      endAt: parseDate(json['endAt']),
    );
  }

  factory ProductItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    int asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return 0;
    }

    DateTime? asDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    String formatWon(int value) {
      final raw = value.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < raw.length; i++) {
        buffer.write(raw[i]);
        final left = raw.length - i - 1;
        if (left > 0 && left % 3 == 0) buffer.write(',');
      }
      return '${buffer}원';
    }

    String remainingLabel(DateTime? endAt) {
      if (endAt == null) return '기간 없음';
      final diff = endAt.difference(DuckAuctionStore.devNow());
      if (diff.isNegative) return '마감';
      if (diff.inHours < 1) return '${diff.inMinutes}분 남음';
      if (diff.inHours < 24) return '${diff.inHours}시간 남음';
      return '${diff.inDays}일 남음';
    }

    String emojiForCategory(String category) => AppCategories.emojiFor(category);

    final category = data['category'] as String? ?? '기타';
    final currentPrice = asInt(data['currentPrice']);
    final bidCount = asInt(data['bidCount']);
    final likeCount = asInt(data['likeCount']);
    final endAt = asDate(data['endAt']);
    final imageUrls = _imageUrlsFromJson(data);
    final coverIndex = asInt(data['coverImageIndex']);
    final safeCoverIndex = _safeCoverIndex(coverIndex, imageUrls.length);
    final imageUrl = imageUrls.isNotEmpty ? imageUrls[safeCoverIndex] : null;

    return ProductItem(
      id: doc.id,
      title: data['title'] as String? ?? '제목 없음',
      description: data['description'] as String? ?? '',
      category: category,
      kujiGrade: data['kujiGrade'] as String?,
      itemType: data['itemType'] as String? ?? AppCategories.itemTypeEtc,
      tags: (data['tags'] as List?)?.whereType<String>().toList() ?? const [],
      condition: data['condition'] as String? ?? '미개봉',
      price: formatWon(currentPrice),
      bids: '${bidCount}명',
      time: remainingLabel(endAt),
      imageEmoji: emojiForCategory(category),
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      coverImageIndex: safeCoverIndex,
      coverImageUrl: imageUrl,
      imageSchemaVersion: asInt(data['imageSchemaVersion']) <= 0 ? 1 : asInt(data['imageSchemaVersion']),
      preferUploadedImagesFirst: data['preferUploadedImagesFirst'] == true,
      likes: '$likeCount',
      sellerId: data['sellerId'] as String?,
      sellerName: data['sellerName'] as String? ?? '나의 덕샵',
      sellerSalesCount: 0,
      sellerBadgeIds: (data['sellerBadgeIds'] as List?)?.whereType<String>().toList() ?? const [],
      isSellerFirstListing: data['isSellerFirstListing'] == true,
      auctionType: data['auctionType'] as String? ?? 'normal',
      startPrice: asInt(data['startPrice']),
      currentPrice: currentPrice,
      hopePrice: asInt(data['hopePrice']),
      buyNowPrice: asInt(data['buyNowPrice']),
      bidUnit: data['bidUnit'] as String? ?? '1,000원',
      shippingFee: asInt(data['shippingFee']),
      aiRecommendedPrice: asInt(data['aiRecommendedPrice']),
      status: data['status'] as String? ?? 'active',
      lastBidUserId: data['lastBidUserId'] as String?,
      winnerId: (data['winnerId'] ?? data['buyerId']) as String?,
      feeExempt: data['feeExempt'] == true,
      feeRatePercent: (data['feeRatePercent'] as num?) ?? 0,
      shippingCourier: data['shippingCourier'] as String? ?? '',
      shippingTrackingNumber: data['shippingTrackingNumber'] as String? ?? '',
      shippedAt: asDate(data['shippedAt']),
      deliveredAt: asDate(data['deliveredAt']),
      shippingPreparedAt: asDate(data['shippingPreparedAt']),
      createdAt: asDate(data['createdAt']),
      updatedAt: asDate(data['updatedAt']),
      endAt: endAt,
    );
  }
}
