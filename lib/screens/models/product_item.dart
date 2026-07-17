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
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? endAt;

  const ProductItem({
    this.id,
    required this.title,
    this.description = '',
    required this.category,
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
    this.createdAt,
    this.updatedAt,
    this.endAt,
  });

  ProductItem copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? endAt,
  }) {
    return ProductItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
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
    if (raw == 'completed' || raw == 'trade_completed') return 'completed';
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
      case 'completed':
        return '거래완료';
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
      case 'completed':
        return const Color(0xFF16A34A);
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
      'tags': tags,
      'condition': condition,
      'sellerId': sellerId,
      'sellerName': sellerName,
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
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      endAt: parseDate(json['endAt']),
    );
  }

  factory ProductItem.fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

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

    String emojiForCategory(String category) {
      switch (category) {
        case '산리오': return '🎀';
        case '진격의 거인': return '⚔️';
        case '디즈니': return '🐭';
        case '포켓몬': return '⚡';
        case '레고': return '🧱';
        case '건담': return '🤖';
        case '치이카와': return '⭐';
        default: return '🎁';
      }
    }

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
      createdAt: asDate(data['createdAt']),
      updatedAt: asDate(data['updatedAt']),
      endAt: endAt,
    );
  }
}
