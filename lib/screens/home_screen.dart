import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kpostal/kpostal.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../legal/legal_texts.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/responsive.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'phone_verification_screen.dart';



part 'widgets/home_search.dart';
part 'widgets/home_banner.dart';
part 'widgets/banner_link_screens.dart';
part 'widgets/home_sections.dart';
part 'widgets/auction_register.dart';
part 'widgets/product_detail.dart';
part 'widgets/toss_checkout_screen.dart';
part 'widgets/identity_verification_screen.dart';
part 'widgets/tabs_chat.dart';
part 'models/product_item.dart';


const Color kDuckPrimary = AppColors.primary;
const Color kAiAccent = AppColors.aiAccent;
const Color kBannerBlue = AppColors.bannerBlue;
const Color kBannerOrange = AppColors.bannerOrange;
const Color kGoldAccent = AppColors.gold;
const Color kSoftPink = Color(0xFFFFEEF3);


class SaveAuctionResult {
  final bool success;
  final ProductItem? product;
  final Object? error;

  const SaveAuctionResult.success(this.product)
      : success = true,
        error = null;

  const SaveAuctionResult.failure(this.error)
      : success = false,
        product = null;
}


class BidSaveResult {
  final bool success;
  final ProductItem? product;
  final String? message;
  final Object? error;
  // 내가 입찰했지만, 대기 중이던 다른 사람의 자동입찰(예약입찰)이 곧바로
  // 응찰해서 내가 밀렸을 때 true가 됩니다. UI에서 안내 문구를 다르게 보여줄 때 씁니다.
  final bool outbidByAutoBid;

  const BidSaveResult.success(this.product, {this.message, this.outbidByAutoBid = false})
      : success = true,
        error = null;

  const BidSaveResult.failure(this.message, [this.error])
      : success = false,
        product = null,
        outbidByAutoBid = false;
}

/// 예약입찰(자동입찰) 등록/취소 결과입니다(기획서 8번).
class AutoBidResult {
  final bool success;
  final String message;
  final Object? error;
  // 이 자동입찰이 (등록 직후 기준으로) 현재 1위인지 여부입니다.
  final bool isLeading;
  // 상대방의 더 높은 자동입찰 한도에 밀려 곧바로 종료됐는지 여부입니다.
  final bool exceeded;

  const AutoBidResult.success(this.message, {this.isLeading = false, this.exceeded = false})
      : success = true,
        error = null;

  const AutoBidResult.failure(this.message, [this.error])
      : success = false,
        isLeading = false,
        exceeded = false;
}



class FavoriteToggleResult {
  final bool success;
  final bool isFavorite;
  final int likeCount;
  final String? message;
  final Object? error;

  const FavoriteToggleResult.success({
    required this.isFavorite,
    required this.likeCount,
  })  : success = true,
        message = null,
        error = null;

  const FavoriteToggleResult.failure(this.message, [this.error])
      : success = false,
        isFavorite = false,
        likeCount = 0;
}

class DevActionResult {
  final bool success;
  final String message;
  final Object? error;

  const DevActionResult.success(this.message)
      : success = true,
        error = null;

  const DevActionResult.failure(this.message, [this.error])
      : success = false;
}

class DuckAuctionStore {
  static const String _registeredAuctionsKey = 'duck_auction_registered_auctions_v1';
  static const String _recentViewedProductsKey = 'duck_auction_recent_viewed_products_v1';
  static const String _devTimeOffsetMinutesKey = 'duck_auction_dev_time_offset_minutes_v1';

  static final ValueNotifier<List<ProductItem>> registeredAuctions = ValueNotifier<List<ProductItem>>([]);
  static final ValueNotifier<Set<String>> favoriteProductIds = ValueNotifier<Set<String>>(<String>{});
  static final ValueNotifier<List<ProductItem>> recentViewedProducts = ValueNotifier<List<ProductItem>>([]);
  static final ValueNotifier<int> devTimeOffsetMinutes = ValueNotifier<int>(0);
  static bool _loadedRegisteredAuctions = false;

  /// 출시 이벤트(수수료 무료 창) 설정이에요. 등록 화면 상단 안내 배지가 이 값을
  /// 구독해서, 무료 창이 진행 중일 때 배지를 보여줘요. 기본값은 비활성이고,
  /// loadEventFeeConfig()로 Firestore에서 최신 값을 읽어와 갱신해요.
  static final ValueNotifier<EventFeeConfig> eventFeeConfig =
      ValueNotifier<EventFeeConfig>(const EventFeeConfig());

  /// 베타 모드 플래그. Firestore의 config/app 문서 betaMode(bool)로 원격 제어합니다.
  /// 기본값 true(베타). 정식 출시 때 콘솔에서 false로 바꾸면 앱 재배포 없이
  /// 결제 게이트 우회 등 베타 처리가 즉시 해제됩니다.
  static bool betaMode = true;

  /// 이메일·휴대폰 인증을 건너뛰게 할 계정 이메일 목록이에요. Firestore의
  /// config/app 문서 verificationBypassEmails(배열)로 원격 제어합니다. 여기에
  /// 들어있는 계정은 인증 없이도 입찰·경매등록을 할 수 있어요. (베타 테스터가
  /// 문자/이메일 인증에 막히지 않게 하려는 용도. 콘솔에서 이메일만 추가하면
  /// 앱 재배포 없이 바로 적용돼요.) 비교는 소문자로 정규화해서 합니다.
  static Set<String> verificationBypassEmails = <String>{};

  /// true면 로그인한 모든 계정의 이메일·휴대폰 인증을 건너뜁니다. 베타 기간에
  /// 테스터 전원을 한 번에 우회시킬 때 써요(폐쇄 베타라 테스터만 접근 가능).
  /// Firestore config/app 문서 bypassAllVerification(bool)로 원격 제어합니다.
  static bool bypassAllVerification = false;

  /// 지금 로그인한 계정이 인증 우회 대상인지 여부.
  /// (마스터 계정은 정식 출시 후에도 항상 우회 / 전역 스위치가 켜져 있거나 /
  ///  이메일이 우회 목록에 있으면 우회)
  static bool get isVerificationBypassed {
    if (isMasterAdmin) return true; // 마스터는 베타·정식 상관없이 이메일·휴대폰·결제 인증 우회
    if (bypassAllVerification) return true;
    final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    return email != null && email.isNotEmpty && verificationBypassEmails.contains(email);
  }

  static Future<void> loadBetaConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app').get();
      final data = doc.data();
      final v = data?['betaMode'];
      if (v is bool) betaMode = v;
      final all = data?['bypassAllVerification'];
      if (all is bool) bypassAllVerification = all;
      final list = data?['verificationBypassEmails'];
      if (list is List) {
        verificationBypassEmails =
            list.whereType<String>().map((e) => e.trim().toLowerCase()).toSet();
      }
    } catch (_) {
      // 실패 시 기존 값 유지(기본 베타).
    }
  }

  /// 출시 이벤트(수수료 무료 창) 설정을 Firestore(config/app 문서의 eventFee 맵)에서
  /// 읽어와 eventFeeConfig 노티파이어에 반영해요. 콘솔에서 config/app 문서의
  /// eventFee 필드에 { enabled, startAt, freeWindowDays, feeRatePercent }를 넣으면
  /// 앱 재배포 없이 적용돼요. 실패하면 기존 값을 유지해요.
  ///
  /// 기본값: 이벤트 비활성(enabled=false), 기본 수수료율 3%, 무료 창 14일(2주).
  /// 즉 아무 설정도 없으면 모든 등록분에 3% 수수료가 붙어요.
  /// 정식 출시일에 "2주 무료"를 켜려면 콘솔에서 config/app 문서에 딱 이렇게만 넣으면 돼요:
  ///   eventFee: { enabled: true, startAt: <출시 시각 Timestamp>, freeWindowDays: 14, feeRatePercent: 3 }
  /// → startAt 부터 14일간 등록된 경매는 수수료 0원, 그 이후 등록분은 3%.
  /// (freeWindowDays/feeRatePercent는 생략해도 기본 14/3이 적용돼요.)
  static Future<void> loadEventFeeConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app').get();
      final raw = doc.data()?['eventFee'];
      if (raw is Map) {
        eventFeeConfig.value = EventFeeConfig.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // 실패 시 기존 값 유지.
    }
  }

  static const String addressRequiredMessage = '배송지를 먼저 등록해주세요. 마이페이지 > 설정 > 배송지 관리에서 등록할 수 있어요.';

  /// 낙찰 시 상대방에게 공개할 배송지가 미리 등록되어 있는지 확인합니다.
  /// 경매 등록/입찰/예약입찰처럼 "낙찰로 이어질 수 있는" 행동을 하기 전에
  /// 호출해서, 실제로 낙찰된 뒤에야 상대방이 주소가 없다는 걸 알게 되는
  /// 상황을 미리 막습니다.
  static Future<bool> hasRegisteredAddress(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final address1 = (doc.data()?['address'] as Map?)?['address1'] as String?;
      return (address1 ?? '').trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // 판매대금을 받을 정산 계좌(은행·계좌번호·예금주)가 등록돼 있는지 확인해요.
  // 경매 등록(판매) 전에 필수로 요구합니다.
  static Future<bool> hasRegisteredPayoutAccount(String uid) async {
    try {
      // 계좌번호는 민감정보라 본인만 읽는 비공개 서브컬렉션에 저장해요.
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('private').doc('payoutAccount')
          .get();
      final acct = doc.data();
      final bank = (acct?['bank'] as String?)?.trim() ?? '';
      final number = (acct?['accountNumber'] as String?)?.trim() ?? '';
      final holder = (acct?['holder'] as String?)?.trim() ?? '';
      return bank.isNotEmpty && number.isNotEmpty && holder.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSubscription;



  static DateTime devNow() {
    return DateTime.now().add(Duration(minutes: devTimeOffsetMinutes.value));
  }

  static String get devTimeOffsetLabel {
    final minutes = devTimeOffsetMinutes.value;
    if (minutes == 0) return '실제 시간';
    final sign = minutes > 0 ? '+' : '-';
    final absMinutes = minutes.abs();
    final days = absMinutes ~/ (24 * 60);
    final hours = (absMinutes % (24 * 60)) ~/ 60;
    final mins = absMinutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add('$days일');
    if (hours > 0) parts.add('$hours시간');
    if (mins > 0) parts.add('$mins분');
    return '$sign${parts.join(' ')}';
  }

  static Future<void> loadDevTimeOffset() async {
    if (!isMasterAdmin) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      devTimeOffsetMinutes.value = prefs.getInt(_devTimeOffsetMinutesKey) ?? 0;
    } catch (_) {}
  }

  static Future<DevActionResult> moveDevSystemTime(Duration offset) async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    try {
      final next = devTimeOffsetMinutes.value + offset.inMinutes;
      devTimeOffsetMinutes.value = next;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_devTimeOffsetMinutesKey, next);
      registeredAuctions.value = List<ProductItem>.from(registeredAuctions.value);
      recentViewedProducts.value = List<ProductItem>.from(recentViewedProducts.value);
      return DevActionResult.success('테스트 시간을 ${devTimeOffsetLabel}(으)로 이동했어요.');
    } catch (error) {
      return DevActionResult.failure('테스트 시간 이동에 실패했어요.', error);
    }
  }

  static Future<DevActionResult> resetDevSystemTime() async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    try {
      devTimeOffsetMinutes.value = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_devTimeOffsetMinutesKey);
      registeredAuctions.value = List<ProductItem>.from(registeredAuctions.value);
      recentViewedProducts.value = List<ProductItem>.from(recentViewedProducts.value);
      return const DevActionResult.success('테스트 시간을 실제 시간으로 되돌렸어요.');
    } catch (error) {
      return DevActionResult.failure('테스트 시간 초기화에 실패했어요.', error);
    }
  }

  static String _favoriteStorageKey(String uid) => 'duck_auction_favorites_$uid';

  static String _productKey(ProductItem product) {
    final id = product.id;
    if (id != null && id.isNotEmpty) return id;
    return product.title;
  }

  static Future<void> loadFavoriteProductIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      favoriteProductIds.value = <String>{};
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .get();
      final ids = snapshot.docs.map((doc) => doc.id).toSet();
      favoriteProductIds.value = ids;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoriteStorageKey(user.uid), ids.toList());
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        favoriteProductIds.value = (prefs.getStringList(_favoriteStorageKey(user.uid)) ?? const <String>[]).toSet();
      } catch (_) {
        favoriteProductIds.value = <String>{};
      }
    }
  }

  static Future<void> _saveFavoriteProductIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoriteStorageKey(user.uid), favoriteProductIds.value.toList());
    } catch (_) {}
  }

  static bool isFavorite(ProductItem product) {
    return favoriteProductIds.value.contains(_productKey(product));
  }

  static Future<FavoriteToggleResult> toggleFavorite(ProductItem product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const FavoriteToggleResult.failure('찜은 로그인 후 이용할 수 있어요.');
    }

    final key = _productKey(product);
    final before = favoriteProductIds.value;
    final wasFavorite = before.contains(key);
    final next = Set<String>.from(before);
    if (wasFavorite) {
      next.remove(key);
    } else {
      next.add(key);
    }
    favoriteProductIds.value = next;
    unawaited(_saveFavoriteProductIds());

    final currentLikeCount = parseCount(product.likes);
    final nextLikeCount = (currentLikeCount + (wasFavorite ? -1 : 1)).clamp(0, 999999).toInt();
    final updatedProduct = product.copyWith(likes: '$nextLikeCount');
    _replaceRegisteredAuction(updatedProduct);

    final productId = product.id;
    if (productId != null && productId.isNotEmpty) {
      try {
        final firestore = FirebaseFirestore.instance;
        final productRef = firestore.collection('products').doc(productId);
        final favoriteRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .doc(productId);

        final batch = firestore.batch();
        batch.update(productRef, {
          'likeCount': FieldValue.increment(wasFavorite ? -1 : 1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (wasFavorite) {
          batch.delete(favoriteRef);
        } else {
          batch.set(favoriteRef, {
            'productId': productId,
            'title': product.title,
            'sellerId': product.sellerId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      } catch (error) {
        favoriteProductIds.value = before;
        unawaited(_saveFavoriteProductIds());
        _replaceRegisteredAuction(product);
        return FavoriteToggleResult.failure('찜 저장에 실패했습니다. 잠시 후 다시 시도해주세요.', error);
      }
    }

    return FavoriteToggleResult.success(
      isFavorite: !wasFavorite,
      likeCount: nextLikeCount,
    );
  }

  static void listenToFirestoreProducts() {
    if (_productsSubscription != null) return;

    _productsSubscription = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        final previous = registeredAuctions.value;
        final products = snapshot.docs.map((doc) {
          final remote = ProductItem.fromFirestore(doc);
          ProductItem? local;
          for (final item in previous) {
            if (item.id == remote.id) {
              local = item;
              break;
            }
          }
          if (local == null) return remote;
          return remote.copyWith(
            imageBytes: local.imageBytes,
            imageBytesList: local.imageBytesList,
            imageUrl: remote.imageUrl ?? local.imageUrl,
            imageUrls: remote.resolvedImageUrls.isNotEmpty ? remote.resolvedImageUrls : local.resolvedImageUrls,
            coverImageIndex: remote.coverImageIndex,
            coverImageUrl: remote.resolvedCoverImageUrl ?? local.resolvedCoverImageUrl,
            imageSchemaVersion: remote.imageSchemaVersion,
          );
        }).toList();
        if (products.isNotEmpty) {
          registeredAuctions.value = products;
          unawaited(_saveRegisteredAuctions());
        }
      },
      onError: (_) {
        // Firestore 연결 전/권한 설정 전에는 로컬 저장본으로 앱을 계속 보여줘요.
        unawaited(loadRegisteredAuctions());
      },
    );
  }


  static Future<void> loadRecentViewedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_recentViewedProductsKey) ?? const <String>[];
      final products = rawList
          .map((raw) {
            try {
              return ProductItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<ProductItem>()
          .toList();
      recentViewedProducts.value = products;
    } catch (_) {}
  }

  static Future<void> _saveRecentViewedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = recentViewedProducts.value
          .map((product) => jsonEncode(product.toJson()))
          .toList();
      await prefs.setStringList(_recentViewedProductsKey, rawList);
    } catch (_) {}
  }

  static Future<void> addRecentViewedProduct(ProductItem product) async {
    final key = _productKey(product);
    final next = <ProductItem>[
      product,
      ...recentViewedProducts.value.where((item) => _productKey(item) != key),
    ];
    recentViewedProducts.value = next.take(30).toList();
    await _saveRecentViewedProducts();
  }

  static Future<void> loadRegisteredAuctions() async {
    if (_loadedRegisteredAuctions) return;
    _loadedRegisteredAuctions = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_registeredAuctionsKey) ?? const <String>[];
      final products = rawList
          .map((raw) {
            try {
              return ProductItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<ProductItem>()
          .toList();
      registeredAuctions.value = products;
    } catch (_) {
      // 저장된 임시 데이터 로드 실패 시 앱 실행을 막지 않아요.
    }
  }

  static Future<void> _saveRegisteredAuctions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = registeredAuctions.value
          .map((product) => jsonEncode(product.toJson()))
          .toList();
      await prefs.setStringList(_registeredAuctionsKey, rawList);
    } catch (_) {
      // 초기 버전의 로컬 저장 실패는 조용히 넘겨요. 이후 Firestore로 대체 예정입니다.
    }
  }

  static Future<SaveAuctionResult> addAuction(ProductItem product) async {
    try {
      final savedProduct = await _saveAuctionToFirestore(product);
      registeredAuctions.value = [savedProduct, ...registeredAuctions.value];
      await _saveRegisteredAuctions();
      return SaveAuctionResult.success(savedProduct);
    } catch (error) {
      return SaveAuctionResult.failure(error);
    }
  }

  static Future<ProductItem> _saveAuctionToFirestore(ProductItem product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('로그인한 사용자만 상품을 등록할 수 있어요.');
    }
    if (!DuckAuctionStore.isVerificationBypassed &&
        ((AuthService.isEmailPasswordUser && !AuthService.isEmailVerified) || !AuthService.isPhoneVerified)) {
      throw StateError('경매 등록은 이메일 인증과 휴대폰 인증을 마친 후 이용할 수 있어요.');
    }
    if (!await hasRegisteredAddress(user.uid)) {
      throw StateError(addressRequiredMessage);
    }

    // 이 판매자의 상품이 하나라도 이미 있으면 이번 등록은 "첫 경매"가
    // 아니에요. NEW 표시는 등록 시점에 딱 한 번 계산해서 이 상품에만
    // 영구히 남겨요(이후 상품이 더 늘어도 과거 첫 상품의 NEW는 유지).
    final existingListingsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: user.uid)
        .limit(1)
        .get();
    final isFirstListing = existingListingsSnapshot.docs.isEmpty;

    // ── 판매 수수료 스탬프 ──
    // 등록되는 순간의 이벤트 설정을 상품에 '박아' 둬요. 무료 창(출시 2주) 안이면
    // feeExempt=true(수수료 0원), 창 밖이면 기본 수수료율(feeRatePercent, 기본 3%)을
    // 적용해요. 등록 시점에 확정되므로 나중에 이벤트를 꺼도 이미 등록된 무료 경매엔
    // 소급되지 않고, 반대로 이벤트 전에 등록된 3% 경매도 그대로 유지돼요.
    final feeCfg = eventFeeConfig.value;
    final feeNow = devNow();
    final stampedFeeExempt = feeCfg.isWithinFreeWindow(feeNow);
    final stampedFeeRate = feeCfg.feeRatePercent;

    // 판매자가 프로필에서 골라둔 배지를 등록 시점 스냅샷으로 상품에 복사해요.
    final sellerDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final sellerBadgeIds = (sellerDoc.data()?['sellerBadges'] as List?)?.whereType<String>().take(3).toList() ??
        const <String>[];

    final docRef = FirebaseFirestore.instance.collection('products').doc();
    final uploadedUrls = <String>[];
    final uploadedPaths = <String>[];

    final uploadTargets = product.imageBytesList.isNotEmpty
        ? product.imageBytesList
        : (product.imageBytes != null ? <Uint8List>[product.imageBytes!] : <Uint8List>[]);

    for (var i = 0; i < uploadTargets.length; i++) {
      final bytes = uploadTargets[i];
      if (bytes.isEmpty) continue;
      final imageRef = FirebaseStorage.instance.ref('product_images/${docRef.id}/image_$i.jpg');
      await imageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      uploadedPaths.add(imageRef.fullPath);
      uploadedUrls.add(await imageRef.getDownloadURL());
    }

    final savedUrls = uploadedUrls.isNotEmpty ? uploadedUrls : product.resolvedImageUrls;
    final savedProduct = product.copyWith(
      id: docRef.id,
      sellerId: user.uid,
      imageUrl: savedUrls.isNotEmpty ? savedUrls.first : product.imageUrl,
      imageUrls: savedUrls,
      coverImageIndex: 0,
      coverImageUrl: savedUrls.isNotEmpty ? savedUrls.first : product.resolvedCoverImageUrl,
      imageSchemaVersion: 2,
      clearImageBytes: true,
      preferUploadedImagesFirst: false,
      sellerBadgeIds: sellerBadgeIds,
      isSellerFirstListing: isFirstListing,
      feeExempt: stampedFeeExempt,
      feeRatePercent: stampedFeeRate,
    );

    await docRef.set(savedProduct.toFirestore(
      id: docRef.id,
      sellerId: user.uid,
      imageUrl: savedProduct.imageUrl,
      imageUrls: savedProduct.imageUrls,
    )..addAll({
      if (uploadedPaths.isNotEmpty) 'imageStoragePaths': uploadedPaths,
    }));

    return savedProduct;
  }


  static Future<SaveAuctionResult> updateAuction(ProductItem product) async {
    if (!canEditProduct(product)) {
      return const SaveAuctionResult.failure('입찰자가 생긴 상품은 수정할 수 없어요.');
    }

    try {
      final updatedProduct = await _updateAuctionInFirestore(product);
      _replaceRegisteredAuction(updatedProduct);
      await _saveRegisteredAuctions();
      return SaveAuctionResult.success(updatedProduct);
    } catch (error) {
      return SaveAuctionResult.failure(error);
    }
  }

  static Future<ProductItem> _updateAuctionInFirestore(ProductItem product) async {
    final user = FirebaseAuth.instance.currentUser;
    final productId = product.id;
    if (user == null || user.isAnonymous || productId == null || productId.isEmpty) {
      throw StateError('수정할 상품 정보를 찾을 수 없어요.');
    }

    final docRef = FirebaseFirestore.instance.collection('products').doc(productId);
    final uploadedUrls = <String>[];
    final uploadedPaths = <String>[];
    for (var i = 0; i < product.imageBytesList.length; i++) {
      final bytes = product.imageBytesList[i];
      if (bytes.isEmpty) continue;
      final imageRef = FirebaseStorage.instance.ref('product_images/$productId/edit_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      await imageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      uploadedPaths.add(imageRef.fullPath);
      uploadedUrls.add(await imageRef.getDownloadURL());
    }

    final mergedUrls = <String>[
      ...product.resolvedImageUrls.where((url) => url.trim().isNotEmpty),
      ...uploadedUrls,
    ];

    // 상품을 저장할 때마다 프로필의 최신 배지로 스냅샷을 새로고침해요.
    // 이렇게 해야 이미 등록해둔 상품도 나중에 프로필에서 배지를 새로
    // 설정한 뒤 한 번 수정 저장하면 카드에 반영돼요.
    final sellerDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final sellerBadgeIds = (sellerDoc.data()?['sellerBadges'] as List?)?.whereType<String>().take(3).toList() ??
        const <String>[];

    final updatedProduct = product.copyWith(
      sellerId: user.uid,
      imageUrl: mergedUrls.isNotEmpty ? mergedUrls.first : product.imageUrl,
      imageUrls: mergedUrls,
      coverImageIndex: 0,
      coverImageUrl: mergedUrls.isNotEmpty ? mergedUrls.first : product.resolvedCoverImageUrl,
      imageSchemaVersion: 2,
      clearImageBytes: true,
      preferUploadedImagesFirst: false,
      sellerBadgeIds: sellerBadgeIds,
    );

    await docRef.update({
      ...updatedProduct.toFirestore(
        id: productId,
        sellerId: user.uid,
        imageUrl: updatedProduct.imageUrl,
        imageUrls: updatedProduct.imageUrls,
      ),
      if (uploadedPaths.isNotEmpty) 'imageStoragePaths': FieldValue.arrayUnion(uploadedPaths),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return updatedProduct;
  }

  static int parseBidUnit(String value) {
    final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return parsed <= 0 ? 1000 : parsed;
  }

  static String formatWonFromInt(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      buffer.write(raw[i]);
      final left = raw.length - i - 1;
      if (left > 0 && left % 3 == 0) buffer.write(',');
    }
    return '${buffer}원';
  }

  static int parseCount(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  /// 유효한 최소 입찰가 = 현재가 + 단위 이상이면서 "단위의 배수"인 가장 작은 금액.
  /// (시작가가 1원처럼 어중간해도 입찰가는 1,000원 단위 딱 떨어지는 금액이 되게 해요.)
  static int minValidBid({
    required int currentPrice,
    required int bidUnit,
  }) {
    final unit = bidUnit <= 0 ? 1000 : bidUnit;
    final floor = currentPrice + unit;
    return ((floor + unit - 1) ~/ unit) * unit; // 단위 배수로 올림
  }

  static bool isValidBidAmount({
    required int amount,
    required int currentPrice,
    required int bidUnit,
  }) {
    final unit = bidUnit <= 0 ? 1000 : bidUnit; // 0 방어(나눗셈 오류 예방)
    if (amount < currentPrice + unit) return false;
    // 현재가 기준 상대 배수가 아니라 "절대 배수"로 판정해요. 그래야 시작가가
    // 1원처럼 어중간해도 50,000처럼 딱 떨어지는 금액을 그대로 입력할 수 있어요.
    return amount % unit == 0;
  }

  static String invalidBidMessage({
    required int currentPrice,
    required int bidUnit,
  }) {
    final unit = bidUnit <= 0 ? 1000 : bidUnit;
    final nextPrice = minValidBid(currentPrice: currentPrice, bidUnit: bidUnit);
    return '${formatWonFromInt(nextPrice)}부터 ${formatWonFromInt(unit)} 단위로 입찰해주세요.';
  }

  /// 예약입찰(자동입찰) 최대 금액은 일반 입찰과 달리 입찰 단위의 정확한 배수일
  /// 필요는 없고, 최소 한 번은 유효하게 응찰할 수 있는 금액이면 됩니다.
  static bool isValidMaxBidAmount({
    required int maxAmount,
    required int currentPrice,
    required int bidUnit,
  }) {
    return maxAmount >= currentPrice + bidUnit;
  }

  static String invalidMaxBidMessage({
    required int currentPrice,
    required int bidUnit,
  }) {
    return '최대 입찰 금액은 최소 ${formatWonFromInt(currentPrice + bidUnit)} 이상이어야 해요.';
  }

  static ProductItem _withBidUpdated(ProductItem product, int amount, int bidCount) {
    return product.copyWith(
      currentPrice: amount,
      price: formatWonFromInt(amount),
      bids: '$bidCount명',
    );
  }

  static Future<BidSaveResult> placeBid({
    required ProductItem product,
    required int amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const BidSaveResult.failure('입찰은 로그인 후 이용할 수 있어요.');
    }
    if (!DuckAuctionStore.isVerificationBypassed &&
        ((AuthService.isEmailPasswordUser && !AuthService.isEmailVerified) || !AuthService.isPhoneVerified)) {
      return const BidSaveResult.failure('입찰은 이메일 인증과 휴대폰 인증을 마친 후 이용할 수 있어요.');
    }
    if (!await hasRegisteredAddress(user.uid)) {
      return const BidSaveResult.failure(addressRequiredMessage);
    }

    if (product.sellerId != null && product.sellerId == user.uid) {
      return const BidSaveResult.failure('내가 등록한 상품에는 입찰할 수 없습니다.');
    }
    if (product.lastBidUserId != null && product.lastBidUserId == user.uid) {
      return const BidSaveResult.failure('현재 최고 입찰자는 다시 입찰할 수 없습니다.');
    }

    final localCurrentPrice = product.currentPrice > 0 ? product.currentPrice : parseCount(product.price);
    final localBidCount = parseCount(product.bids);
    final localBidUnit = parseBidUnit(product.bidUnit);

    if (!isValidBidAmount(
      amount: amount,
      currentPrice: localCurrentPrice,
      bidUnit: localBidUnit,
    )) {
      return BidSaveResult.failure(
        invalidBidMessage(currentPrice: localCurrentPrice, bidUnit: localBidUnit),
      );
    }

    final productId = product.id;
    if (productId == null || productId.isEmpty) {
      final updatedProduct = _withBidUpdated(product, amount, localBidCount + 1).copyWith(lastBidUserId: user.uid);
      _replaceRegisteredAuction(updatedProduct);
      return BidSaveResult.success(updatedProduct);
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final productRef = firestore.collection('products').doc(productId);
      final bidRef = productRef.collection('bids').doc();
      final myAutoBidRef = productRef.collection('autoBids').doc(user.uid);
      late ProductItem updatedProduct;
      bool outbidByAutoBid = false;

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) {
          throw StateError('상품 정보를 찾을 수 없어요.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        int asInt(Object? value) {
          if (value is int) return value;
          if (value is num) return value.toInt();
          if (value is String) {
            return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          }
          return 0;
        }

        final serverStatus = (data['status'] as String? ?? 'active').toLowerCase().trim();
        final serverEndAt = data['endAt'] is Timestamp ? (data['endAt'] as Timestamp).toDate() : null;
        if (serverStatus != 'active' || (serverEndAt != null && !serverEndAt.isAfter(DateTime.now()))) {
          throw StateError('이미 마감된 경매에는 입찰할 수 없어요.');
        }

        final sellerId = data['sellerId'] as String?;
        final lastBidUserId = data['lastBidUserId'] as String?;
        if (sellerId != null && sellerId == user.uid) {
          throw StateError('내가 등록한 상품에는 입찰할 수 없습니다.');
        }
        if (lastBidUserId != null && lastBidUserId == user.uid) {
          throw StateError('현재 최고 입찰자는 다시 입찰할 수 없습니다.');
        }

        final serverCurrentPrice = asInt(data['currentPrice']);
        final serverBidCount = asInt(data['bidCount']);
        final serverBidUnit = parseBidUnit(data['bidUnit'] as String? ?? product.bidUnit);

        if (!isValidBidAmount(
          amount: amount,
          currentPrice: serverCurrentPrice,
          bidUnit: serverBidUnit,
        )) {
          throw StateError(
            invalidBidMessage(currentPrice: serverCurrentPrice, bidUnit: serverBidUnit),
          );
        }

        // 트랜잭션 규칙상 읽기는 쓰기보다 먼저 해야 해서, 현재 최고 입찰자를
        // 방어하는 예약입찰(자동입찰)이 있는지와 내가 이전에 등록해둔
        // 예약입찰이 있는지를 여기서 미리 읽어둡니다.
        DocumentSnapshot<Map<String, dynamic>>? defenderSnap;
        if (lastBidUserId != null && lastBidUserId.isNotEmpty) {
          defenderSnap = await transaction.get(productRef.collection('autoBids').doc(lastBidUserId));
        }
        final myAutoBidSnap = await transaction.get(myAutoBidRef);

        Map<String, dynamic>? defenderData;
        if (defenderSnap != null && defenderSnap.exists) {
          final d = defenderSnap.data();
          if (d != null && (d['status'] as String? ?? '') == 'active') {
            defenderData = d;
          }
        }

        // 예약입찰(자동입찰)로 현재 순위를 방어 중이던 상대가 있고, 그 한도가
        // 내가 입력한 금액 이상이면(동률 포함) 그 예약입찰이 자동으로 응찰해서
        // 순위를 지킵니다 — 먼저 등록한 사람이 우선이라는 정책과 같은 맥락이에요.
        if (defenderData != null && asInt(defenderData['maxAmount']) >= amount) {
          final defenderMax = asInt(defenderData['maxAmount']);
          final counterAmount = (amount + serverBidUnit) <= defenderMax ? amount + serverBidUnit : defenderMax;
          final defenderName = (defenderData['userName'] as String?) ?? (data['lastBidUserName'] as String?) ?? '입찰자';

          // 내 입찰 시도 자체는 기록에 남기고,
          transaction.set(bidRef, {
            'id': bidRef.id,
            'productId': productId,
            'userId': user.uid,
            'userName': user.displayName ?? user.email ?? '입찰자',
            'amount': amount,
            'isAutoBid': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 곧바로 상대방 자동입찰의 응찰 기록도 함께 남깁니다.
          if (counterAmount > serverCurrentPrice) {
            final counterBidRef = productRef.collection('bids').doc();
            transaction.set(counterBidRef, {
              'id': counterBidRef.id,
              'productId': productId,
              'userId': lastBidUserId,
              'userName': defenderName,
              'amount': counterAmount,
              'isAutoBid': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          transaction.update(productRef, {
            'currentPrice': counterAmount,
            'bidCount': serverBidCount + 2,
            'lastBidUserId': lastBidUserId,
            'lastBidUserName': defenderName,
            'lastBidAmount': counterAmount,
            'lastBidAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            // "내 경매 관리 > 입찰"에서 내가 입찰한 경매 목록을 찾을 때 씁니다.
            'bidderIds': FieldValue.arrayUnion([user.uid, lastBidUserId]),
          });

          final myOldAutoBidData = myAutoBidSnap.data();
          if (myAutoBidSnap.exists && ((myOldAutoBidData?['status'] as String?) ?? '') == 'active') {
            transaction.update(myAutoBidRef, {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
          }

          outbidByAutoBid = true;
          updatedProduct = _withBidUpdated(product, counterAmount, serverBidCount + 2).copyWith(lastBidUserId: lastBidUserId);
          return;
        }

        // 방어 중이던 상대 자동입찰의 한도가 내 입찰액보다 낮아서 못 버티면
        // 그 자동입찰은 여기서 완전히 종료됩니다(최대 금액 초과 시 종료).
        if (defenderData != null) {
          transaction.update(
            productRef.collection('autoBids').doc(lastBidUserId),
            {'status': 'exceeded', 'updatedAt': FieldValue.serverTimestamp()},
          );
        }

        final nextBidCount = serverBidCount + 1;
        transaction.update(productRef, {
          'currentPrice': amount,
          'bidCount': nextBidCount,
          'lastBidUserId': user.uid,
          'lastBidUserName': user.displayName ?? user.email ?? '입찰자',
          'lastBidAmount': amount,
          'lastBidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'bidderIds': FieldValue.arrayUnion([user.uid]),
        });
        transaction.set(bidRef, {
          'id': bidRef.id,
          'productId': productId,
          'userId': user.uid,
          'userName': user.displayName ?? user.email ?? '입찰자',
          'amount': amount,
          'isAutoBid': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 내가 낸 이번 직접 입찰이 이전에 등록해둔 내 예약입찰보다 우선하도록,
        // 기존 예약입찰은 취소 처리합니다.
        final myOldAutoBidData = myAutoBidSnap.data();
        if (myAutoBidSnap.exists && ((myOldAutoBidData?['status'] as String?) ?? '') == 'active') {
          transaction.update(myAutoBidRef, {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
        }

        updatedProduct = _withBidUpdated(product, amount, nextBidCount).copyWith(lastBidUserId: user.uid);
      });

      _replaceRegisteredAuction(updatedProduct);
      if (outbidByAutoBid) {
        return BidSaveResult.success(
          updatedProduct,
          message: '입찰이 접수됐지만, 상대방의 예약입찰(자동입찰)이 곧바로 응찰해서 현재가가 ${formatWonFromInt(updatedProduct.currentPrice)}(으)로 올랐어요.',
          outbidByAutoBid: true,
        );
      }
      return BidSaveResult.success(updatedProduct);
    } catch (error) {
      final message = error is StateError
          ? error.message
          : '입찰에 실패했습니다. 잠시 후 다시 시도해주세요.';
      return BidSaveResult.failure(message, error);
    }
  }

  /// 예약입찰(자동입찰)을 등록합니다(기획서 8번).
  ///
  /// products/{id}/autoBids/{uid} 문서 하나로 유저별 최대 입찰 한도를
  /// 관리합니다. 등록 시점에 이미 다른 사람의 예약입찰이 현재 순위를
  /// 방어하고 있다면, 그 한도와 비교해서 누가 이기는지를 그 자리에서
  /// 바로 계산합니다(진짜 최대 한도는 공개하지 않고, 이기는 데 필요한
  /// 최소 금액까지만 현재가를 올립니다). 동일한 최대 금액이면 먼저
  /// 등록한 사람이 우선입니다.
  static Future<AutoBidResult> registerAutoBid({
    required ProductItem product,
    required int maxAmount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const AutoBidResult.failure('예약입찰은 로그인 후 이용할 수 있어요.');
    }
    if (!DuckAuctionStore.isVerificationBypassed &&
        ((AuthService.isEmailPasswordUser && !AuthService.isEmailVerified) || !AuthService.isPhoneVerified)) {
      return const AutoBidResult.failure('예약입찰은 이메일 인증과 휴대폰 인증을 마친 후 이용할 수 있어요.');
    }
    if (!await hasRegisteredAddress(user.uid)) {
      return const AutoBidResult.failure(addressRequiredMessage);
    }
    if (product.sellerId != null && product.sellerId == user.uid) {
      return const AutoBidResult.failure('내가 등록한 상품에는 예약입찰을 등록할 수 없습니다.');
    }
    if (maxAmount <= 0) {
      return const AutoBidResult.failure('최대 입찰 금액을 입력해주세요.');
    }
    final productId = product.id;
    if (productId == null || productId.isEmpty) {
      return const AutoBidResult.failure('등록이 완료된 상품에서만 예약입찰을 이용할 수 있어요.');
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final productRef = firestore.collection('products').doc(productId);
      final myAutoBidRef = productRef.collection('autoBids').doc(user.uid);
      late AutoBidResult result;

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) {
          throw StateError('상품 정보를 찾을 수 없어요.');
        }
        final data = snapshot.data() ?? <String, dynamic>{};

        int asInt(Object? value) {
          if (value is int) return value;
          if (value is num) return value.toInt();
          if (value is String) {
            return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          }
          return 0;
        }

        final serverStatus = (data['status'] as String? ?? 'active').toLowerCase().trim();
        final serverEndAt = data['endAt'] is Timestamp ? (data['endAt'] as Timestamp).toDate() : null;
        if (serverStatus != 'active' || (serverEndAt != null && !serverEndAt.isAfter(DateTime.now()))) {
          throw StateError('이미 마감된 경매에는 예약입찰을 등록할 수 없어요.');
        }

        final sellerId = data['sellerId'] as String?;
        if (sellerId != null && sellerId == user.uid) {
          throw StateError('내가 등록한 상품에는 예약입찰을 등록할 수 없습니다.');
        }

        final serverCurrentPrice = asInt(data['currentPrice']);
        final serverBidCount = asInt(data['bidCount']);
        final serverBidUnit = parseBidUnit(data['bidUnit'] as String? ?? product.bidUnit);
        final lastBidUserId = data['lastBidUserId'] as String?;
        final myName = user.displayName ?? user.email ?? '입찰자';

        final myAutoBidSnap = await transaction.get(myAutoBidRef);
        final myExistingAutoBidData = myAutoBidSnap.exists ? myAutoBidSnap.data() : null;
        final existingCreatedAt = myExistingAutoBidData?['createdAt'];

        // 이미 내가 최고 입찰자라면, 새로 겨루지 않고 방어 한도만 올려둡니다.
        if (lastBidUserId != null && lastBidUserId == user.uid) {
          if (maxAmount <= serverCurrentPrice) {
            throw StateError('이미 현재가(${formatWonFromInt(serverCurrentPrice)}) 이상이어야 예약입찰을 설정할 수 있어요.');
          }
          transaction.set(myAutoBidRef, {
            'userId': user.uid,
            'userName': myName,
            'maxAmount': maxAmount,
            'status': 'active',
            'createdAt': existingCreatedAt ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          transaction.update(productRef, {
            'bidderIds': FieldValue.arrayUnion([user.uid]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          result = AutoBidResult.success(
            '예약입찰을 등록했어요. ${formatWonFromInt(maxAmount)}까지 자동으로 순위를 지켜드릴게요.',
            isLeading: true,
          );
          return;
        }

        if (!isValidMaxBidAmount(maxAmount: maxAmount, currentPrice: serverCurrentPrice, bidUnit: serverBidUnit)) {
          throw StateError(invalidMaxBidMessage(currentPrice: serverCurrentPrice, bidUnit: serverBidUnit));
        }

        DocumentSnapshot<Map<String, dynamic>>? defenderSnap;
        if (lastBidUserId != null && lastBidUserId.isNotEmpty) {
          defenderSnap = await transaction.get(productRef.collection('autoBids').doc(lastBidUserId));
        }
        Map<String, dynamic>? defenderData;
        if (defenderSnap != null && defenderSnap.exists) {
          final d = defenderSnap.data();
          if (d != null && (d['status'] as String? ?? '') == 'active') {
            defenderData = d;
          }
        }

        final bidRef = productRef.collection('bids').doc();

        if (defenderData == null) {
          // 지금 순위를 지키고 있는 다른 예약입찰이 없으면, 딱 한 단위만
          // 올려서 1위가 됩니다(진짜 최대 한도는 공개하지 않아요).
          final newPrice = serverCurrentPrice + serverBidUnit;
          transaction.set(bidRef, {
            'id': bidRef.id,
            'productId': productId,
            'userId': user.uid,
            'userName': myName,
            'amount': newPrice,
            'isAutoBid': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(productRef, {
            'currentPrice': newPrice,
            'bidCount': serverBidCount + 1,
            'lastBidUserId': user.uid,
            'lastBidUserName': myName,
            'lastBidAmount': newPrice,
            'lastBidAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'bidderIds': FieldValue.arrayUnion([user.uid]),
          });
          transaction.set(myAutoBidRef, {
            'userId': user.uid,
            'userName': myName,
            'maxAmount': maxAmount,
            'status': 'active',
            'createdAt': existingCreatedAt ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          result = AutoBidResult.success(
            '예약입찰을 등록했어요! 현재 1위예요. 현재가 ${formatWonFromInt(newPrice)}',
            isLeading: true,
          );
          return;
        }

        final defenderMax = asInt(defenderData['maxAmount']);
        final defenderName = (defenderData['userName'] as String?) ?? (data['lastBidUserName'] as String?) ?? '입찰자';

        if (maxAmount > defenderMax) {
          // 내가 상대방의 한도를 넘어서서 이깁니다. 상대 예약입찰은 종료됩니다.
          final newPrice = (defenderMax + serverBidUnit) <= maxAmount ? defenderMax + serverBidUnit : maxAmount;
          transaction.update(
            productRef.collection('autoBids').doc(lastBidUserId),
            {'status': 'exceeded', 'updatedAt': FieldValue.serverTimestamp()},
          );
          transaction.set(bidRef, {
            'id': bidRef.id,
            'productId': productId,
            'userId': user.uid,
            'userName': myName,
            'amount': newPrice,
            'isAutoBid': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(productRef, {
            'currentPrice': newPrice,
            'bidCount': serverBidCount + 1,
            'lastBidUserId': user.uid,
            'lastBidUserName': myName,
            'lastBidAmount': newPrice,
            'lastBidAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'bidderIds': FieldValue.arrayUnion([user.uid, lastBidUserId]),
          });
          transaction.set(myAutoBidRef, {
            'userId': user.uid,
            'userName': myName,
            'maxAmount': maxAmount,
            'status': 'active',
            'createdAt': existingCreatedAt ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          result = AutoBidResult.success(
            '예약입찰을 등록해서 1위가 됐어요! 현재가 ${formatWonFromInt(newPrice)}',
            isLeading: true,
          );
          return;
        }

        // 상대방의 한도가 나와 같거나 더 높아서, 상대 예약입찰이 곧바로
        // 방어에 성공합니다(동일 금액이면 먼저 등록한 사람이 우선).
        final newPrice = (defenderMax) <= (maxAmount + serverBidUnit) ? defenderMax : maxAmount + serverBidUnit;
        final iAmStillInTheRunning = maxAmount >= newPrice;

        transaction.set(myAutoBidRef, {
          'userId': user.uid,
          'userName': myName,
          'maxAmount': maxAmount,
          'status': iAmStillInTheRunning ? 'active' : 'exceeded',
          'createdAt': existingCreatedAt ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (newPrice > serverCurrentPrice) {
          transaction.set(bidRef, {
            'id': bidRef.id,
            'productId': productId,
            'userId': lastBidUserId,
            'userName': defenderName,
            'amount': newPrice,
            'isAutoBid': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(productRef, {
            'currentPrice': newPrice,
            'bidCount': serverBidCount + 1,
            'lastBidUserName': defenderName,
            'lastBidAmount': newPrice,
            'lastBidAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            // lastBidUserId는 그대로 상대방(방어자)입니다.
            'bidderIds': FieldValue.arrayUnion([user.uid, lastBidUserId]),
          });
        } else {
          transaction.update(productRef, {
            'bidderIds': FieldValue.arrayUnion([user.uid, lastBidUserId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        result = iAmStillInTheRunning
            ? AutoBidResult.success(
                '예약입찰을 등록했지만 상대방과 같은 금액이라 먼저 등록한 사람이 우선이에요. 지금은 2위로 대기 중이에요.',
              )
            : AutoBidResult.success(
                '예약입찰을 등록했지만 상대방의 예약입찰 한도가 더 높아서 밀렸어요. 최대 금액을 늘려서 다시 시도해볼 수 있어요.',
                exceeded: true,
              );
      });

      return result;
    } catch (error) {
      final message = error is StateError ? error.message : '예약입찰 등록에 실패했습니다. 잠시 후 다시 시도해주세요.';
      return AutoBidResult.failure(message, error);
    }
  }

  /// 예약입찰을 취소합니다. 단, 현재 최고 입찰자(1위)는 취소할 수 없어요.
  static Future<AutoBidResult> cancelAutoBid(ProductItem product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const AutoBidResult.failure('로그인 후 이용할 수 있어요.');
    }
    final productId = product.id;
    if (productId == null || productId.isEmpty) {
      return const AutoBidResult.failure('상품 정보를 찾을 수 없어요.');
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final productRef = firestore.collection('products').doc(productId);
      final myAutoBidRef = productRef.collection('autoBids').doc(user.uid);
      late AutoBidResult result;

      await firestore.runTransaction((transaction) async {
        final productSnap = await transaction.get(productRef);
        final myAutoBidSnap = await transaction.get(myAutoBidRef);

        if (!myAutoBidSnap.exists) {
          result = const AutoBidResult.failure('등록된 예약입찰이 없어요.');
          return;
        }
        final myData = myAutoBidSnap.data()!;
        if ((myData['status'] as String? ?? '') != 'active') {
          result = const AutoBidResult.failure('이미 종료됐거나 취소된 예약입찰이에요.');
          return;
        }

        final productData = productSnap.data() ?? <String, dynamic>{};
        final lastBidUserId = productData['lastBidUserId'] as String?;
        if (lastBidUserId != null && lastBidUserId == user.uid) {
          result = const AutoBidResult.failure('현재 최고 입찰자는 예약입찰을 취소할 수 없어요.');
          return;
        }

        transaction.update(myAutoBidRef, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        result = const AutoBidResult.success('예약입찰을 취소했어요.');
      });

      return result;
    } catch (error) {
      final message = error is StateError ? error.message : '예약입찰 취소에 실패했습니다. 잠시 후 다시 시도해주세요.';
      return AutoBidResult.failure(message, error);
    }
  }

  static void _replaceRegisteredAuction(ProductItem updatedProduct) {
    final items = List<ProductItem>.from(registeredAuctions.value);
    final index = items.indexWhere((item) {
      if (updatedProduct.id != null && updatedProduct.id!.isNotEmpty) {
        return item.id == updatedProduct.id;
      }
      return item.title == updatedProduct.title;
    });

    if (index >= 0) {
      items[index] = updatedProduct;
      registeredAuctions.value = items;
      unawaited(_saveRegisteredAuctions());
    }
  }

  static bool get isMasterAdmin {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim();
    return email == 'master@duckauction.com';
  }

  static bool canEditProduct(ProductItem product) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
    if (product.sellerId == null || product.sellerId != user.uid) return false;
    return parseCount(product.bids) == 0;
  }

  static bool canDeleteProduct(ProductItem product) {
    return canEditProduct(product);
  }

  static Future<DevActionResult> refreshProductsNow() async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      registeredAuctions.value = snapshot.docs.map(ProductItem.fromFirestore).toList();
      await _saveRegisteredAuctions();
      return DevActionResult.success('상품 ${registeredAuctions.value.length}개를 다시 불러왔어요.');
    } catch (error) {
      return DevActionResult.failure('상품 새로고침에 실패했어요.', error);
    }
  }

  /// 웹(브라우저)에서 '결제하기'를 눌렀을 때 호출해요. 웹뷰가 없는 웹에서는
  /// 결제 페이지(pay.html)로 같은 탭에서 이동해 이니시스 결제창을 띄워요.
  /// 결제가 끝나면 pay.html이 앱으로 복귀(/?pmtDone=1&...)하고, 스플래시의
  /// 결제 복귀 처리(confirmPortonePayment)가 상품을 'paid'로 갱신해요.
  /// (모바일은 이 경로 대신 웹뷰 결제 화면 TossCheckoutScreen을 써요.)
  static Future<void> startWebCheckout({
    required String orderId,
    required String orderName,
    required int amount,
    String? productId,
  }) async {
    final uri = Uri.parse('$_kPortOneBaseUrl/pay.html').replace(queryParameters: <String, String>{
      'paymentId': orderId,
      'amount': amount.toString(),
      'orderName': orderName,
      if (productId != null && productId.isNotEmpty) 'pid': productId,
    });
    await launchUrl(uri, webOnlyWindowName: '_self');
  }

  /// 웹에서 본인인증창(verify.html)을 열어요. 인증을 마치면 앱으로 복귀(전체 새로고침)
  /// 하며, 스플래시가 서버 검증(confirmIdentityVerification)을 이어서 처리해요.
  /// (모바일은 이 경로 대신 웹뷰 IdentityVerificationScreen을 써요.)
  static Future<void> startWebIdentityVerification() async {
    final uri = Uri.parse('$_kPortOneBaseUrl/verify.html');
    await launchUrl(uri, webOnlyWindowName: '_self');
  }

  static Future<DevActionResult> clearLocalDevelopmentData() async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    try {
      favoriteProductIds.value = <String>{};
      registeredAuctions.value = <ProductItem>[];
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_registeredAuctionsKey);
      return const DevActionResult.success('로컬 테스트 캐시를 비웠어요.');
    } catch (error) {
      return DevActionResult.failure('로컬 캐시 삭제에 실패했어요.', error);
    }
  }

  static Future<DevActionResult> deleteAllTestProducts() async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('products').get();
      final docs = snapshot.docs;

      for (var i = 0; i < docs.length; i += 450) {
        final batch = firestore.batch();
        for (final doc in docs.skip(i).take(450)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      registeredAuctions.value = <ProductItem>[];
      await _saveRegisteredAuctions();
      return DevActionResult.success('테스트 상품 ${docs.length}개를 삭제했어요.');
    } catch (error) {
      return DevActionResult.failure('테스트 상품 삭제에 실패했어요.', error);
    }
  }

  static Future<DevActionResult> createSampleProducts() async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const DevActionResult.failure('로그인 후 사용할 수 있어요.');
    }

    final now = devNow();
    final sellerName = user.displayName ?? user.email ?? '관리자';
    const desc = '심사·노출 확인용 샘플 경매입니다. 각 카테고리가 비어 보이지 않도록 등록해 둔 테스트 상품이에요.';

    // 각 카테고리마다 1개씩, 서로 다른 제목·이모지·가격으로 만들어 카테고리가
    // 비지 않게 하고, 같은 이미지 반복으로 보이지 않게 이모지를 전부 다르게 했어요.
    ProductItem make({
      required String category,
      required String title,
      required String emoji,
      required int price,
      required String unit,
      required Duration dur,
      required String timeLabel,
      String? kujiGrade,
      String itemType = AppCategories.itemTypeEtc,
    }) {
      final priceStr = '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}원';
      return ProductItem(
        title: title,
        description: desc,
        category: category,
        price: priceStr,
        bids: '0명',
        time: timeLabel,
        imageEmoji: emoji,
        likes: '0',
        sellerId: user.uid,
        sellerName: sellerName,
        sellerSalesCount: 0,
        startPrice: price,
        currentPrice: price,
        bidUnit: unit,
        aiRecommendedPrice: price,
        endAt: now.add(dur),
        kujiGrade: kujiGrade,
        itemType: itemType,
      );
    }

    final samples = <ProductItem>[
      make(category: '산리오', title: '산리오 마이멜로디 인형 샘플', emoji: '🎀', price: 9000, unit: '500원', dur: const Duration(days: 1), timeLabel: '1일 남음'),
      make(category: '치이카와', title: '치이카와 우사기 마스코트 샘플', emoji: '⭐', price: 14000, unit: '1,000원', dur: const Duration(hours: 6), timeLabel: '6시간 남음'),
      make(category: '진격의 거인', title: '진격의 거인 리바이 피규어 샘플', emoji: '⚔️', price: 26000, unit: '1,000원', dur: const Duration(days: 2), timeLabel: '2일 남음'),
      make(category: '나의 히어로 아카데미', title: '나히아 데쿠 아크릴 스탠드 샘플', emoji: '💥', price: 15000, unit: '1,000원', dur: const Duration(days: 3), timeLabel: '3일 남음'),
      make(category: '원피스', title: '원피스 루피 피규어 샘플', emoji: '🏴‍☠️', price: 17000, unit: '1,000원', dur: const Duration(days: 2), timeLabel: '2일 남음'),
      make(category: '포켓몬', title: '포켓몬 피카츄 프로모 카드 샘플', emoji: '⚡', price: 13000, unit: '1,000원', dur: const Duration(days: 3), timeLabel: '3일 남음', itemType: '카드'),
      make(category: '쿠지', title: '이치방쿠지 라스트원상 피규어 샘플', emoji: '🎯', price: 30000, unit: '1,000원', dur: const Duration(days: 3), timeLabel: '3일 남음', kujiGrade: AppCategories.kujiGradeUpper),
    ];

    try {
      for (final sample in samples) {
        await addAuction(sample);
      }
      return DevActionResult.success('카테고리별 샘플 경매 ${samples.length}개를 생성했어요.');
    } catch (error) {
      return DevActionResult.failure('샘플 상품 생성에 실패했어요.', error);
    }
  }

  static Future<DevActionResult> migrateProductImageSchema() async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('products').get();
      var migratedCount = 0;
      var skippedCount = 0;

      for (var i = 0; i < snapshot.docs.length; i += 450) {
        final batch = firestore.batch();
        var hasUpdate = false;

        for (final doc in snapshot.docs.skip(i).take(450)) {
          final data = doc.data();
          final product = ProductItem.fromFirestore(doc);
          final urls = product.resolvedImageUrls;
          final coverUrl = product.resolvedCoverImageUrl;

          if (urls.isEmpty || coverUrl == null || coverUrl.isEmpty) {
            skippedCount++;
            continue;
          }

          final currentUrls = (data['imageUrls'] as List?)?.whereType<String>().toList() ?? const <String>[];
          final alreadyMigrated = data['imageSchemaVersion'] == 2 &&
              data['coverImageUrl'] == coverUrl &&
              data['mainImageUrl'] == coverUrl &&
              data['imageUrl'] == coverUrl &&
              jsonEncode(currentUrls) == jsonEncode(urls);

          if (alreadyMigrated) {
            skippedCount++;
            continue;
          }

          batch.update(doc.reference, {
            'imageUrls': urls,
            'coverImageIndex': 0,
            'coverImageUrl': coverUrl,
            'mainImageUrl': coverUrl,
            'imageUrl': coverUrl,
            'imageSchemaVersion': 2,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          migratedCount++;
          hasUpdate = true;
        }

        if (hasUpdate) {
          await batch.commit();
        }
      }

      await refreshProductsNow();
      return DevActionResult.success('이미지 데이터 ${migratedCount}개를 정리했어요. 스킵 ${skippedCount}개');
    } catch (error) {
      return DevActionResult.failure('이미지 데이터 마이그레이션에 실패했어요.', error);
    }
  }


  static Future<DevActionResult> submitProductReport(
    ProductItem product, {
    required String reason,
    String detail = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const DevActionResult.failure('로그인 후 신고할 수 있어요.');
    }

    final productId = product.id;
    if (productId == null || productId.isEmpty) {
      return const DevActionResult.failure('상품 정보를 확인할 수 없어 신고를 접수하지 못했어요.');
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final reportRef = firestore.collection('reports').doc();
      final productRef = firestore.collection('products').doc(productId);

      await firestore.runTransaction((transaction) async {
        transaction.set(reportRef, {
          'id': reportRef.id,
          'productId': productId,
          'productTitle': product.title,
          'sellerUid': product.sellerId,
          'sellerName': product.sellerName,
          'reporterUid': user.uid,
          'reporterEmail': user.email,
          'reason': reason,
          'detail': detail.trim(),
          'status': 'waiting',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(productRef, {
          'reportCount': FieldValue.increment(1),
          'lastReportedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      return const DevActionResult.success('신고가 접수되었어요. 관리자 확인 후 처리됩니다.');
    } catch (error) {
      return DevActionResult.failure('신고 접수에 실패했어요. 잠시 후 다시 시도해주세요.', error);
    }
  }

  static Future<DevActionResult> handleReportAdminAction({
    required String reportId,
    required String productId,
    required String action,
  }) async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    final normalized = action.toLowerCase().trim();
    if (!const ['reviewing', 'rejected', 'hidden', 'deleted', 'seller_warning', 'complete'].contains(normalized)) {
      return const DevActionResult.failure('지원하지 않는 신고 처리예요.');
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final reportRef = firestore.collection('reports').doc(reportId);
      final updates = <String, dynamic>{
        'status': normalized == 'hidden' || normalized == 'deleted' || normalized == 'seller_warning' ? 'complete' : normalized,
        'adminAction': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (normalized == 'hidden' || normalized == 'deleted') {
        await firestore.collection('products').doc(productId).set({
          'status': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        updates['productStatusAfterAction'] = normalized;
      }

      if (normalized == 'seller_warning') {
        updates['sellerWarningIssued'] = true;
      }

      await reportRef.set(updates, SetOptions(merge: true));
      await refreshProductsNow();

      final message = <String, String>{
        'reviewing': '신고를 검토중으로 변경했어요.',
        'rejected': '신고를 기각 처리했어요.',
        'hidden': '상품을 숨김 처리하고 신고를 완료했어요.',
        'deleted': '상품을 삭제됨 처리하고 신고를 완료했어요.',
        'seller_warning': '판매자 경고 처리 기록을 남겼어요.',
        'complete': '신고를 완료 처리했어요.',
      }[normalized] ?? '신고 처리를 완료했어요.';
      return DevActionResult.success(message);
    } catch (error) {
      return DevActionResult.failure('신고 처리에 실패했어요.', error);
    }
  }


  static Future<DevActionResult> updateProductStatus(ProductItem product, String status) async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    final normalized = status.toLowerCase().trim();
    if (!const ['active', 'ended', 'sold', 'failed', 'winner_pending', 'second_pending', 'third_pending', 'paid', 'shipped', 'completed', 'hidden', 'deleted'].contains(normalized)) {
      return const DevActionResult.failure('지원하지 않는 상태값이에요.');
    }

    try {
      final label = <String, String>{
        'active': product.endAt == null ? '판매중' : product.time,
        'ended': '마감',
        'sold': '낙찰',
        'failed': '유찰',
        'winner_pending': '1순위 결제대기',
        'second_pending': '2순위 결제대기',
        'third_pending': '3순위 결제대기',
        'paid': '결제완료',
        'shipped': '배송중',
        'completed': '거래완료',
        'hidden': '숨김',
        'deleted': '삭제됨',
      }[normalized] ?? '확인필요';
      final updatedProduct = product.copyWith(
        status: normalized,
        time: label,
      );
      final productId = product.id;
      if (productId != null && productId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('products').doc(productId).update({
          'status': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      _replaceRegisteredAuction(updatedProduct);
      await _saveRegisteredAuctions();
      return DevActionResult.success('상태를 ${updatedProduct.statusLabel}(으)로 변경했어요.');
    } catch (error) {
      return DevActionResult.failure('상태 변경에 실패했어요.', error);
    }
  }


  static Future<DevActionResult> runPaymentTestScenario(ProductItem product, String scenario) async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    final normalized = scenario.toLowerCase().trim();
    final bidCount = parseCount(product.bids);
    final now = devNow();

    String status;
    String message;
    int? paymentRank;
    DateTime? paymentDeadlineAt;
    DateTime? newEndAt;
    int warningIncrement = 0;

    switch (normalized) {
      case 'winner_pending':
        if (bidCount <= 0) return const DevActionResult.failure('입찰자가 없는 상품은 유찰 처리만 가능해요.');
        status = 'winner_pending';
        paymentRank = 1;
        paymentDeadlineAt = now.add(const Duration(hours: 24));
        message = '1순위 결제대기 상태로 변경했어요. 결제 제한시간은 24시간이에요.';
        break;
      case 'winner_paid':
        status = 'paid';
        paymentRank = 1;
        message = '1순위 결제완료 상태로 변경했어요.';
        break;
      case 'winner_abandoned_to_second':
        warningIncrement = 1;
        if (bidCount >= 2) {
          status = 'second_pending';
          paymentRank = 2;
          paymentDeadlineAt = now.add(const Duration(hours: 12));
          message = '1순위 낙찰 포기 경고 1회를 기록하고 2순위 결제대기로 넘겼어요.';
        } else {
          status = 'failed';
          paymentRank = null;
          message = '2순위 입찰자가 없어 유찰 처리했어요. 1순위 낙찰 포기 경고 1회가 필요해요.';
        }
        break;
      case 'winner_timeout':
        warningIncrement = 1;
        if (bidCount >= 2) {
          status = 'second_pending';
          paymentRank = 2;
          paymentDeadlineAt = now.add(const Duration(hours: 12));
          message = '1순위 24시간 미결제로 보고 2순위 결제대기로 넘겼어요.';
        } else {
          status = 'failed';
          paymentRank = null;
          message = '1순위 24시간 미결제 후 차순위가 없어 유찰 처리했어요.';
        }
        break;
      case 'second_paid':
        if (bidCount < 2) return const DevActionResult.failure('2순위 입찰자가 없어서 처리할 수 없어요.');
        status = 'paid';
        paymentRank = 2;
        message = '2순위 결제완료 상태로 변경했어요.';
        break;
      case 'second_abandoned_to_third':
        if (bidCount < 2) return const DevActionResult.failure('2순위 입찰자가 없어서 처리할 수 없어요.');
        warningIncrement = 1;
        if (bidCount >= 3) {
          status = 'third_pending';
          paymentRank = 3;
          paymentDeadlineAt = now.add(const Duration(hours: 12));
          message = '2순위 낙찰 포기 경고 1회를 기록하고 3순위 결제대기로 넘겼어요.';
        } else {
          status = 'failed';
          paymentRank = null;
          message = '3순위 입찰자가 없어 유찰 처리했어요.';
        }
        break;
      case 'second_timeout':
        if (bidCount < 2) return const DevActionResult.failure('2순위 입찰자가 없어서 처리할 수 없어요.');
        warningIncrement = 1;
        if (bidCount >= 3) {
          status = 'third_pending';
          paymentRank = 3;
          paymentDeadlineAt = now.add(const Duration(hours: 12));
          message = '2순위 12시간 미결제로 보고 3순위 결제대기로 넘겼어요.';
        } else {
          status = 'failed';
          paymentRank = null;
          message = '2순위 미결제 후 3순위가 없어 유찰 처리했어요.';
        }
        break;
      case 'third_paid':
        if (bidCount < 3) return const DevActionResult.failure('3순위 입찰자가 없어서 처리할 수 없어요.');
        status = 'paid';
        paymentRank = 3;
        message = '3순위 결제완료 상태로 변경했어요.';
        break;
      case 'third_timeout':
      case 'all_failed':
        warningIncrement = 1;
        status = 'failed';
        paymentRank = null;
        message = '3순위까지 미결제로 보고 유찰 처리했어요. 판매자에게 삭제/재등록/연장 유도가 필요해요.';
        break;
      case 'no_bid_failed':
        status = 'failed';
        paymentRank = null;
        message = '입찰자 없는 유찰 상태로 변경했어요. 판매자에게 삭제/재등록/연장 유도가 필요해요.';
        break;
      case 'seller_extend':
        status = 'active';
        paymentRank = null;
        paymentDeadlineAt = null;
        newEndAt = now.add(const Duration(days: 7));
        message = '판매중(마감 7일 연장)으로 변경했어요.';
        break;
      case 'paid':
        status = 'paid';
        paymentRank = null;
        message = '결제완료 상태로 변경했어요.';
        break;
      case 'shipped':
        status = 'shipped';
        paymentRank = null;
        message = '배송중 상태로 변경했어요.';
        break;
      case 'completed':
        status = 'completed';
        paymentRank = null;
        message = '거래완료 상태로 변경했어요.';
        break;
      default:
        return const DevActionResult.failure('지원하지 않는 결제 테스트 시나리오예요.');
    }

    try {
      final updatedProduct = product.copyWith(
        status: status,
        endAt: newEndAt ?? product.endAt,
        time: <String, String>{
          'winner_pending': '1순위 결제대기',
          'second_pending': '2순위 결제대기',
          'third_pending': '3순위 결제대기',
          'paid': '결제완료',
          'shipped': '배송중',
          'completed': '거래완료',
          'failed': '유찰',
          // 연장 시엔 마감시각을 미래로 바꿨으니 '마감'이 아닌 남은 시간을 보여줘야
          // effectiveStatus가 옛 마감시각으로 다시 유찰을 계산하지 않아요.
          'active': newEndAt != null ? '7일 남음' : (product.endAt == null ? '판매중' : product.time),
        }[status] ?? product.time,
      );

      final updates = <String, dynamic>{
        'status': status,
        'paymentTestScenario': normalized,
        'paymentRank': paymentRank,
        'paymentDeadlineAt': paymentDeadlineAt,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (warningIncrement > 0) {
        updates['paymentWarningCount'] = FieldValue.increment(warningIncrement);
        updates['lastPaymentWarningAt'] = FieldValue.serverTimestamp();
      }
      if (newEndAt != null) {
        updates['endAt'] = Timestamp.fromDate(newEndAt);
        updates['extendedByAdminTest'] = true;
      }

      final testBuyerUid = (product.lastBidUserId ?? '').trim();
      if (testBuyerUid.isNotEmpty && const {
        'winner_pending',
        'winner_paid',
        'paid',
        'shipped',
        'completed',
      }.contains(normalized)) {
        updates['lastBidUserId'] = testBuyerUid;
        updates['winnerId'] = testBuyerUid;
        updates['buyerId'] = testBuyerUid;
        updates['testBuyerAssignedByAdmin'] = true;
      }

      final productId = product.id;
      if (productId != null && productId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('products').doc(productId).update(updates);
      }
      _replaceRegisteredAuction(updatedProduct);
      await _saveRegisteredAuctions();
      return DevActionResult.success(message);
    } catch (error) {
      return DevActionResult.failure('결제 테스트 시나리오 처리에 실패했어요.', error);
    }
  }

  static Future<DevActionResult> extendFailedAuction(ProductItem product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const DevActionResult.failure('로그인 후 이용할 수 있어요.');
    }
    if (product.sellerId == null || product.sellerId != user.uid) {
      return const DevActionResult.failure('내가 등록한 경매만 연장할 수 있어요.');
    }
    final bidCount = parseCount(product.bids);
    final canRelist = product.effectiveStatus == 'failed' ||
        (product.effectiveStatus == 'ended' && bidCount == 0);
    if (!canRelist) {
      return const DevActionResult.failure('최종 유찰된 경매만 연장할 수 있어요.');
    }

    try {
      final nextEndAt = devNow().add(const Duration(days: 7));
      final resetPrice = product.startPrice > 0 ? product.startPrice : parseCount(product.price);
      final updatedProduct = product.copyWith(
        status: 'active',
        time: '7일 남음',
        bids: '0명',
        currentPrice: resetPrice,
        lastBidUserId: '',
        endAt: nextEndAt,
        updatedAt: devNow(),
      );

      final productId = product.id;
      if (productId != null && productId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('products').doc(productId).update({
          'status': 'active',
          'currentPrice': resetPrice,
          'bidCount': 0,
          'lastBidUserId': null,
          'paymentRank': null,
          'paymentDeadlineAt': null,
          'endAt': Timestamp.fromDate(nextEndAt),
          'extendedBySeller': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _replaceRegisteredAuction(updatedProduct);
      await _saveRegisteredAuctions();
      return const DevActionResult.success('경매를 7일 연장했어요. 기존 입찰 기록은 새 경매에 반영되지 않아요.');
    } catch (error) {
      return DevActionResult.failure('경매 연장에 실패했어요.', error);
    }
  }

  static Future<DevActionResult> deleteProduct(ProductItem product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const DevActionResult.failure('로그인 후 이용할 수 있어요.');
    }
    if (product.sellerId == null || product.sellerId != user.uid) {
      return const DevActionResult.failure('내가 등록한 상품만 삭제할 수 있어요.');
    }
    if (parseCount(product.bids) > 0) {
      return const DevActionResult.failure('입찰자가 있는 경매는 삭제할 수 없어요.');
    }

    try {
      final productId = product.id;
      if (productId != null && productId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      }

      final items = List<ProductItem>.from(registeredAuctions.value)
        ..removeWhere((item) {
          if (productId != null && productId.isNotEmpty) return item.id == productId;
          return item.title == product.title;
        });
      registeredAuctions.value = items;
      await _saveRegisteredAuctions();
      return const DevActionResult.success('경매가 삭제되었어요.');
    } catch (error) {
      return DevActionResult.failure('경매 삭제에 실패했어요.', error);
    }
  }

}


bool _isGuestUser() => FirebaseAuth.instance.currentUser == null;

bool _isActiveAuction(ProductItem product) {
  // 홈의 신규 등록 경매에는 현재 실제로 진행 중인 경매만 노출한다.
  // 유찰·낙찰·마감·숨김·삭제 상태는 내 경매 관리에서만 확인한다.
  return product.effectiveStatus == 'active';
}

void _showLoginRequiredSheet(
  BuildContext context, {
  String title = '로그인이 필요한 기능이에요',
  String description = '이 기능은 로그인/회원가입 후 이용할 수 있어요.',
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        // 폭은 420으로 제한(가로 중앙)하되, 세로로는 내용만큼만 차지하게 해요.
        // ResponsiveContentBounds는 내부가 Align이라 세로로 꽉 늘어나서, 시트
        // 아래에 큰 빈 여백이 생겼어요. heightFactor: 1.0으로 높이를 내용에 맞춰요.
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.lock_outline, size: 22, color: Color(0xFF16305C)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: const Color(0xFF16305C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('로그인 / 회원가입하기', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                  foregroundColor: const Color(0xFF777777),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('계속 구경하기'),
              ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 로그인/구경 자체는 막지 않지만, 경매 등록이나 입찰처럼 실제 거래가 걸린
/// 기능을 쓰려고 할 때 이메일·휴대폰 인증이 아직 안 끝났다면 true를 돌려줍니다.
/// 게스트(비로그인) 여부는 [_isGuestUser]에서 따로 처리하므로 여기서는
/// "로그인은 했지만 인증이 덜 끝난 경우"만 봅니다.
///
/// 카드 결제로 진행 가능한 최대 금액(원)이에요. 국내 PG(이니시스)는 결제금액을
/// 32비트 정수(약 21.4억) 범위로 처리해서, 그보다 큰 금액은 오버플로우로 음수가
/// 되어 "결제 금액은 1원 이상" 같은 엉뚱한 에러가 나요. 그 전에 친절히 막기 위한
/// 한도예요. (실제 굿즈 경매엔 나올 일 없는 금액이라 안전 마진을 둬 20억으로 잡았어요.)
const int kPgMaxPayableAmount = 2000000000;

/// 경매 등록/입찰/예약입찰처럼 "낙찰로 이어질 수 있는" 행동을 하기 전에,
/// 이메일·휴대폰 인증과 배송지 등록이 모두 끝났는지 한 번에 확인합니다.
/// 배송지 확인은 Firestore 조회가 필요해서 async입니다.
Future<bool> _needsTradeVerification() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) return false;
  // 마스터 계정은 인증·배송지까지 전부 우회해서 아무 제약 없이 거래 테스트 가능해요.
  if (DuckAuctionStore.isMasterAdmin) return false;
  // 최신 우회 목록을 불러온 뒤, 이 계정이 인증 우회 대상이면 인증 없이 통과시켜요.
  // (배송지는 인증 인프라와 무관하게 폼만 채우면 되므로 그대로 요구합니다.)
  await DuckAuctionStore.loadBetaConfig();
  // 배송지·정산 계좌는 인증 우회 여부와 무관하게 폼만 채우면 되므로 그대로 요구해요.
  final hasAddress = await DuckAuctionStore.hasRegisteredAddress(user.uid);
  final hasPayout = await DuckAuctionStore.hasRegisteredPayoutAccount(user.uid);
  if (DuckAuctionStore.isVerificationBypassed) {
    return !hasAddress || !hasPayout;
  }
  if ((AuthService.isEmailPasswordUser && !AuthService.isEmailVerified) || !AuthService.isPhoneVerified) return true;
  return !hasAddress || !hasPayout;
}

/// 판매(경매) 등록 전 통합인증(CI) 본인인증이 필요한지 판별해요.
/// ※ 현재 판매 등록 게이트는 SMS 휴대폰 인증으로 대체돼 있어, 이 함수는 지금
///   호출되지 않아요. 통합인증(CI) 도입 시 게이트 호출부를 되살리면 다시 쓰입니다.
///   그때까지 보존용이라 미사용 경고를 억제해요.
// ignore: unused_element
Future<bool> _needsIdentityVerification() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) return false;
  if (DuckAuctionStore.isMasterAdmin) return false;
  await DuckAuctionStore.loadBetaConfig();
  if (DuckAuctionStore.isVerificationBypassed) return false;
  try {
    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return snap.data()?['identityVerified'] != true;
  } catch (_) {
    return false;
  }
}

/// 판매(경매) 등록 전 본인인증 게이트예요. 인증이 필요하면 안내 후 인증 플로우를
/// 띄우고, '등록을 계속 진행해도 되는지'를 돌려줍니다.
///  - 모바일: 웹뷰 본인인증 화면(IdentityVerificationScreen)에서 결과를 받아 이어감.
///  - 웹: 본인인증창(verify.html)으로 이동(앱 새로고침) → 인증 후 다시 등록을 누르게 안내.
/// ※ 현재 미사용(SMS 인증으로 대체). 통합인증 도입 시 게이트 호출부를 되살리세요.
// ignore: unused_element
Future<bool> _ensureIdentityVerified(BuildContext context) async {
  if (!await _needsIdentityVerification()) return true;
  if (!context.mounted) return false;

  final start = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('판매하려면 본인인증이 필요해요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            '안전한 거래를 위해 판매자는 KG이니시스 본인인증을 한 번만 완료하면 돼요. 인증 정보는 거래 안전 목적으로만 사용돼요.',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('본인인증 하기'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('다음에 할게요', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ),
  );
  if (start != true || !context.mounted) return false;

  if (kIsWeb) {
    // 웹은 본인인증창으로 이동하면 앱이 통째로 새로고침돼요. 인증 후 다시 눌러 등록하도록
    // 안내하고, 지금은 등록을 이어가지 않아요.
    await DuckAuctionStore.startWebIdentityVerification();
    return false;
  }

  final result = await Navigator.of(context).push<IdentityVerificationResult>(
    MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
  );
  if (result == null || !context.mounted) return false;
  if (!result.success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? '본인인증이 완료되지 않았어요.')),
    );
    return false;
  }
  final who = (result.name != null && result.name!.trim().isNotEmpty) ? '${result.name!.trim()}님, ' : '';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${who}본인인증이 완료됐어요. 이제 판매를 등록할 수 있어요.')),
  );
  return true;
}

/// 배송지 등록/수정 바텀시트입니다. 마이페이지 설정과 거래 준비 화면
/// (TradeReadinessScreen) 양쪽에서 공용으로 씁니다. 저장에 성공하면 true를
/// 반환합니다.
// 사진을 등록할 때 '카메라로 촬영' 또는 '갤러리에서 선택'을 고르게 하는
// 공용 바텀시트예요. 고른 소스를 돌려주고, 취소하면 null을 반환합니다.
Future<ImageSource?> pickImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF334155)),
            title: const Text('카메라로 촬영', style: TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF334155)),
            title: const Text('갤러리에서 선택', style: TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// 다음(카카오) 우편번호 서비스를 webview로 띄워 도로명·동으로 검색하게 해요.
// 선택하면 {postcode, address1}을 돌려주고, 취소하면 null을 반환합니다.
// 별도 API 키가 필요 없어요.
// 선택/촬영한 이미지를 크롭 화면으로 넘겨 최종 bytes를 돌려줘요.
// aspectRatio를 주면 그 비율로 고정(예: 프로필 1:1), 안 주면 자유 비율이에요.
// 웹에서는 크롭 UI 대신 원본을 그대로 사용하고, 사용자가 취소하면 null을 반환합니다.
Future<Uint8List?> cropPickedImage(XFile image, {CropAspectRatio? aspectRatio}) async {
  if (kIsWeb) return image.readAsBytes();
  final cropped = await ImageCropper().cropImage(
    sourcePath: image.path,
    aspectRatio: aspectRatio,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: '사진 편집',
        toolbarColor: const Color(0xFF334155),
        toolbarWidgetColor: Colors.white,
        // 상태바 색을 지정해요. 상단 툴바(✓/X)가 상태바(시간·배터리)와 겹치는
        // 문제는 네이티브 UCropTheme(불투명 상태바)로 함께 처리했어요.
        statusBarColor: const Color(0xFF1F2A44),
        // 비율 고정을 넘겨받았을 때만 잠그고, 상품 사진은 자유 비율이에요.
        lockAspectRatio: aspectRatio != null,
        // 하단 컨트롤(비율 선택·회전)을 보여줘요. 이게 있어야 사용자가 자유
        // 비율을 골라 원하는 영역대로 크롭 프레임을 조절할 수 있어요.
        hideBottomControls: false,
      ),
      IOSUiSettings(title: '사진 편집'),
    ],
  );
  if (cropped == null) return null;
  return cropped.readAsBytes();
}

Future<Map<String, String>?> searchKoreanAddress(BuildContext context) async {
  // kpostal 패키지로 다음(카카오) 우편번호 검색 화면을 띄워요. webview의 JS
  // 채널이 릴리즈 빌드에서 통신이 막혀 '선택이 안 되던' 문제를 이 패키지가
  // 자체적으로 해결해줘요. 별도 API 키는 필요 없어요.
  final result = await Navigator.of(context).push<Kpostal>(
    MaterialPageRoute(builder: (_) => KpostalView()),
  );
  if (result == null) return null;
  return <String, String>{
    'postcode': result.postCode,
    'address1': result.address,
  };
}

Future<bool> showAddressEditSheet(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  Map<String, dynamic> existing = const {};
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    existing = Map<String, dynamic>.from((doc.data()?['address'] as Map?) ?? const {});
  } catch (_) {}

  final postcode = TextEditingController(text: (existing['postcode'] as String?) ?? '');
  final address1 = TextEditingController(text: (existing['address1'] as String?) ?? '');
  final address2 = TextEditingController(text: (existing['address2'] as String?) ?? '');

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => Padding(
      // 키보드(viewInsets)뿐 아니라 갤럭시 제스처 내비게이션 바(viewPadding)까지
      // 더해, 저장하기 버튼이 하단 내비게이션에 가리지 않게 해요.
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(sheetContext).viewInsets.bottom + MediaQuery.of(sheetContext).viewPadding.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('배송지 관리', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text(
          '여기 등록한 배송지는 낙찰이 확정된 거래에서만 상대방(구매자/판매자)에게 공개돼요. 그 외에는 아무에게도 보이지 않아요.',
          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.4, fontSize: 13),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await searchKoreanAddress(sheetContext);
            if (result != null) {
              postcode.text = result['postcode'] ?? '';
              address1.text = result['address1'] ?? '';
            }
          },
          icon: const Icon(Icons.search_rounded),
          label: const Text('주소 검색 (도로명·동)'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 10),
        TextField(controller: postcode, readOnly: true, decoration: const InputDecoration(labelText: '우편번호', hintText: '주소 검색으로 자동 입력', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: address1, readOnly: true, decoration: const InputDecoration(labelText: '주소', hintText: '주소 검색으로 자동 입력', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: address2, decoration: const InputDecoration(labelText: '상세주소 (동·호수 등 직접 입력)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            if (address1.text.trim().isEmpty) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('주소를 입력해주세요.')));
              return;
            }
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'address': {
                'postcode': postcode.text.trim(),
                'address1': address1.text.trim(),
                'address2': address2.text.trim(),
              },
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('저장하기'),
        ),
      ]),
    ),
  );
  postcode.dispose();
  address1.dispose();
  address2.dispose();
  return saved == true;
}

/// 판매대금(낙찰금)을 받을 정산 계좌를 등록·수정하는 바텀시트예요.
/// users/{uid}.payoutAccount = {bank, accountNumber, holder} 에 저장합니다.
/// 경매 등록(판매) 전 필수 단계라 TradeReadinessScreen에서 호출해요.
Future<bool> showPayoutAccountEditSheet(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  Map<String, dynamic> existing = const {};
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('private').doc('payoutAccount')
        .get();
    existing = Map<String, dynamic>.from(doc.data() ?? const {});
  } catch (_) {}

  const banks = <String>[
    '국민은행', '신한은행', '우리은행', '하나은행', '농협은행', '기업은행',
    '카카오뱅크', '토스뱅크', '케이뱅크', 'SC제일은행', '씨티은행', '수협은행',
    '대구은행', '부산은행', '경남은행', '광주은행', '전북은행', '제주은행',
    '새마을금고', '우체국', '신협', '산업은행', '저축은행',
  ];

  final numberCtrl = TextEditingController(text: (existing['accountNumber'] as String?) ?? '');
  final holderCtrl = TextEditingController(
    text: (existing['holder'] as String?) ?? (user.displayName ?? ''),
  );
  String? selectedBank = existing['bank'] as String?;
  if (selectedBank != null && !banks.contains(selectedBank)) selectedBank = null;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + MediaQuery.of(sheetContext).viewPadding.bottom + 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('정산 계좌 등록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            '판매대금(낙찰금)을 받을 본인 명의 계좌예요. 거래가 완료되면 이 계좌로 정산돼요. 예금주는 판매자 본인과 같아야 해요.',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedBank,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '은행', border: OutlineInputBorder()),
            hint: const Text('은행 선택'),
            items: banks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (v) => setSheetState(() => selectedBank = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: numberCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '계좌번호', hintText: "'-' 없이 숫자만 입력", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: holderCtrl,
            decoration: const InputDecoration(labelText: '예금주', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              if (selectedBank == null) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('은행을 선택해주세요.')));
                return;
              }
              final number = numberCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
              if (number.length < 8) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('계좌번호를 정확히 입력해주세요.')));
                return;
              }
              if (holderCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('예금주를 입력해주세요.')));
                return;
              }
              await FirebaseFirestore.instance
                  .collection('users').doc(user.uid)
                  .collection('private').doc('payoutAccount')
                  .set({
                'bank': selectedBank,
                'accountNumber': number,
                'holder': holderCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (sheetContext.mounted) Navigator.pop(sheetContext, true);
            },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('저장하기'),
          ),
        ]),
      ),
    ),
  );
  numberCtrl.dispose();
  holderCtrl.dispose();
  return saved == true;
}

/// 알림함 화면. 현재는 users/{uid}/notifications 하위 컬렉션을 구독해서 보여줘요.
/// (푸시 발송 시 이 컬렉션에 함께 저장해두면 목록에 쌓여요.) 아직 저장된 알림이
/// 없으면 빈 상태 안내를 보여줍니다.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  /// 알림함에서 알림을 눌렀을 때, 알림 종류(type)에 맞는 화면으로 이동해요.
  ///  - 유찰(auction_failed): 내 경매 관리(재등록/연장)
  ///  - 채팅(chat_message): 해당 채팅방
  ///  - 그 외(새 입찰·아웃비드·낙찰·결제 등 productId가 있는 알림): 경매 상세
  Future<void> _openNotification(
    BuildContext context, {
    required String type,
    required String productId,
    required String roomId,
  }) async {
    final navigator = Navigator.of(context);

    if (type == 'auction_failed') {
      navigator.push(
        MaterialPageRoute(builder: (_) => const MyAuctionManageScreen()),
      );
      return;
    }

    if (productId.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, isEqualTo: productId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('연결된 경매를 찾을 수 없어요. 삭제되었을 수 있어요.')),
          );
        }
        return;
      }
      final product = ProductItem.fromFirestore(snapshot.docs.first);
      if (!context.mounted) return;
      if (type == 'chat_message') {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => SellerChatScreen(
              product: product,
              roomIdOverride: roomId.isEmpty ? null : roomId,
            ),
          ),
        );
      } else {
        navigator.push(
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        );
      }
    } catch (_) {
      // 이동 실패는 조용히 무시해요(네트워크 문제 등).
    }
  }

  Widget _empty(IconData icon, String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: const Color(0xFFB8BBC2)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('알림', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: user == null
          ? _empty(Icons.notifications_none, '알림은 로그인 후 확인할 수 있어요', '로그인하면 입찰·낙찰·채팅 등 새로운 소식을 여기에서 볼 수 있어요.')
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _empty(Icons.notifications_off_outlined, '알림을 불러오지 못했어요', '네트워크 상태를 확인한 뒤 다시 시도해 주세요.');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _empty(Icons.notifications_none, '아직 도착한 알림이 없어요', '입찰·낙찰·채팅 등 새로운 소식이 생기면 여기에 표시돼요.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final title = (data['title'] as String?)?.trim();
                    final body = (data['body'] as String?)?.trim();
                    // 서버(sendPushToUser)는 라우팅 정보를 중첩 맵 data['data']에
                    // {type, productId, roomId} 형태로 저장해요.
                    final inner = (data['data'] as Map?) ?? const {};
                    final type = (inner['type'] as String?) ?? '';
                    final productId = (inner['productId'] as String?) ?? '';
                    final roomId = (inner['roomId'] as String?) ?? '';
                    final ts = data['createdAt'];
                    String timeText = '';
                    if (ts is Timestamp) {
                      final d = ts.toDate();
                      timeText = '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
                          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                    }
                    final tappable = type == 'auction_failed' || productId.isNotEmpty;
                    return ListTile(
                      onTap: tappable
                          ? () => _openNotification(context,
                              type: type, productId: productId, roomId: roomId)
                          : null,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFE4EC),
                        child: Icon(Icons.notifications_rounded, color: Color(0xFFFF5A8A), size: 20),
                      ),
                      title: Text(title == null || title.isEmpty ? '덕옥션 알림' : title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (body != null && body.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 2), child: Text(body, style: const TextStyle(color: Color(0xFF475569)))),
                          if (timeText.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 4), child: Text(timeText, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)))),
                        ],
                      ),
                      trailing: tappable
                          ? const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1))
                          : null,
                    );
                  },
                );
              },
            ),
    );
  }
}

/// 경매 등록/입찰을 처음 시도할 때 필요한 준비 항목(이메일 인증, 휴대폰
/// 인증, 배송지 등록)을 한 화면에서 순서대로 안내합니다. 항목마다 따로
/// 막히는 대신, 부족한 걸 한 번에 보여주고 이어서 처리할 수 있게 한
/// 화면이에요. 결제수단 등록은 아직 실제 결제 연동 전이라 준비중 표시만
/// 하고 통과를 막지는 않습니다.
///
/// ※ 주의: 여기서 말하는 "결제수단 등록"은 구매자가 결제할 카드/수단을
///   저장하는 게 아니라, "판매자가 판매대금을 정산받을 계좌"를 등록하는
///   단계다. 자세한 설계 메모는 아래 build() 안의 [정산계좌] 주석 참고.
///
/// 필수 항목(이메일/휴대폰/배송지)을 모두 마치면 "계속하기"가 활성화되고,
/// 눌러서 닫으면 true를 반환합니다. 중간에 나가면 false(또는 null)를
/// 반환하므로 호출부에서는 결과가 true일 때만 원래 하려던 동작을 이어가면
/// 됩니다.
class TradeReadinessScreen extends StatefulWidget {
  const TradeReadinessScreen({super.key});

  @override
  State<TradeReadinessScreen> createState() => _TradeReadinessScreenState();
}

class _TradeReadinessScreenState extends State<TradeReadinessScreen> {
  bool _hasAddress = false;
  bool _loadingAddress = true;
  bool _hasPayout = false;
  bool _loadingPayout = true;

  @override
  void initState() {
    super.initState();
    _refreshAddress();
    _refreshPayout();
    _loadBeta();
  }

  Future<void> _refreshPayout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingPayout = false);
      return;
    }
    setState(() => _loadingPayout = true);
    final has = await DuckAuctionStore.hasRegisteredPayoutAccount(uid);
    if (!mounted) return;
    setState(() {
      _hasPayout = has;
      _loadingPayout = false;
    });
  }

  Future<void> _goEditPayout() async {
    await showPayoutAccountEditSheet(context);
    await _refreshPayout();
  }

  Future<void> _loadBeta() async {
    await DuckAuctionStore.loadBetaConfig();
    if (mounted) setState(() {});
  }

  Future<void> _refreshAddress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingAddress = false);
      return;
    }
    setState(() => _loadingAddress = true);
    final has = await DuckAuctionStore.hasRegisteredAddress(uid);
    if (!mounted) return;
    setState(() {
      _hasAddress = has;
      _loadingAddress = false;
    });
  }

  Future<void> _goVerifyEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: user?.email ?? '')),
    );
    if (mounted) setState(() {});
  }

  Future<void> _goVerifyPhone() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _goEditAddress() async {
    await showAddressEditSheet(context);
    await _refreshAddress();
  }

  // '나중에 할게요'를 누르면 바로 나가지 않고, 인증이 왜 필요한지 먼저 안내해요.
  Future<void> _confirmSkipReadiness() async {
    final skip = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('인증을 먼저 마치는 게 좋아요', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          '이메일·휴대폰 인증은 안전한 거래를 위한 최소 절차예요.\n\n'
          '· 인증을 마치지 않으면 경매 등록·입찰 같은 거래 기능을 이용할 수 없어요.\n'
          '· 한 사람이 여러 계정을 만들어 경매 가격을 조작하는 것을 막기 위해 꼭 필요해요.',
          style: TextStyle(height: 1.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF777777)),
            child: const Text('그래도 나중에', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16305C)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('지금 인증할게요', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (skip == true && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    // 인증 우회 대상 계정은 이메일·휴대폰 인증을 완료한 것으로 처리해요.
    // 마스터는 배송지까지 완료 처리해서 모든 단계를 통과한 것으로 봐요.
    final bypassed = DuckAuctionStore.isVerificationBypassed;
    final isMaster = DuckAuctionStore.isMasterAdmin;
    // 이메일 인증은 이메일/비밀번호 가입자에게만 요구·표시해요.
    // (SNS 로그인 사용자는 제공자가 신원을 이미 확인했고, 카카오/네이버는
    //  이메일 자체가 없을 수 있어서 이메일 인증 단계가 의미 없어요.)
    final isEmailUser = AuthService.isEmailPasswordUser;
    final needsEmail = !bypassed && isEmailUser && !AuthService.isEmailVerified;
    final needsPhone = !bypassed && !AuthService.isPhoneVerified;
    final needsAddress = !isMaster && !_hasAddress;
    final needsPayout = !isMaster && !_hasPayout;
    final allReady = !needsEmail && !needsPhone && !needsAddress && !needsPayout && !_loadingAddress && !_loadingPayout;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('거래 준비하기')),
      body: SafeArea(
        child: ResponsiveContentBounds(
          maxWidth: context.responsive(phone: double.infinity, tablet: 480.0),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('안전한 거래를 위해 아래 항목을 준비해주세요', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('낙찰·판매 진행에 필요한 정보예요.\n한 번만 등록해두면 계속 쓸 수 있어요.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.4)),
              const SizedBox(height: 22),
              // 이메일 인증 단계는 이메일/비밀번호 가입자에게만 보여줘요.
              if (isEmailUser)
                _ReadinessStepTile(
                  icon: Icons.mail_outline,
                  title: '이메일 인증',
                  done: !needsEmail,
                  buttonText: '이메일 인증하러 가기',
                  onTap: _goVerifyEmail,
                ),
              _ReadinessStepTile(
                icon: Icons.sms_outlined,
                title: '휴대폰 본인 인증',
                done: !needsPhone,
                buttonText: '휴대폰 인증하러 가기',
                onTap: _goVerifyPhone,
              ),
              _loadingAddress
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                  : _ReadinessStepTile(
                      icon: Icons.local_shipping_outlined,
                      title: '배송지 등록',
                      done: !needsAddress,
                      buttonText: '배송지 등록하기',
                      onTap: _goEditAddress,
                    ),
              // [정산계좌] 판매대금(낙찰금)을 받을 판매자 본인 계좌를 등록하는 단계예요.
              // 경매 등록(판매) 전 필수라서, 마스터를 제외하면 항상 보여줘요.
              // (구매자 입찰은 낙찰 시 토스 결제창에서 즉시 결제하므로 계좌 저장이 필요 없어요.)
              if (!isMaster)
                (_loadingPayout
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                    : _ReadinessStepTile(
                        icon: Icons.account_balance_outlined,
                        title: '정산 계좌 등록',
                        subtitle: '판매대금(낙찰금)을 받을 본인 명의 계좌를 등록해요.',
                        done: !needsPayout,
                        buttonText: '정산 계좌 등록하기',
                        onTap: _goEditPayout,
                      )),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF16305C),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                ),
                onPressed: allReady ? () => Navigator.of(context).pop(true) : null,
                child: Text(allReady ? '계속하기' : '남은 항목을 먼저 완료해주세요', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: const Color(0xFF777777)),
                onPressed: _confirmSkipReadiness,
                child: const Text('나중에 할게요'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ReadinessStepTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool done;
  final bool disabled;
  final String buttonText;
  final String? subtitle;
  final VoidCallback? onTap;

  const _ReadinessStepTile({
    required this.icon,
    required this.title,
    required this.done,
    required this.buttonText,
    this.disabled = false,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF0FDF4) : (disabled ? const Color(0xFFF4F7FC) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: done ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
          child: Icon(done ? Icons.check_rounded : icon, color: done ? Colors.white : const Color(0xFF64748B), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4)),
            ],
            if (!done) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: disabled ? const Color(0xFF94A3B8) : const Color(0xFF16305C),
                    side: BorderSide(color: disabled ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
                  ),
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

final ValueNotifier<int> duckMainTabRequest = ValueNotifier<int>(-1);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    DuckAuctionStore.loadDevTimeOffset();
    DuckAuctionStore.loadRegisteredAuctions();
    DuckAuctionStore.loadFavoriteProductIds();
    DuckAuctionStore.loadRecentViewedProducts();
    DuckAuctionStore.listenToFirestoreProducts();
    duckMainTabRequest.addListener(_handleTabRequest);
    // 앱을 열었을 때(또는 가입 직후 홈 진입 시) 알림 권한이 없으면, 중요 알림을
    // 놓칠 수 있다고 안내하고 동의를 받아요. (앱 실행당 한 번만 물어봐요.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PushNotificationService.instance.ensureNotificationConsent(context);
    });
  }

  void _handleTabRequest() {
    final requestedIndex = duckMainTabRequest.value;
    if (!mounted || requestedIndex < 0 || requestedIndex > 4) return;
    setState(() => selectedIndex = requestedIndex);
    duckMainTabRequest.value = -1;
  }

  @override
  void dispose() {
    duckMainTabRequest.removeListener(_handleTabRequest);
    super.dispose();
  }

  Future<void> _logout() async {
    // 실수로 눌러 로그아웃되지 않도록 확인창을 먼저 띄워요.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('로그아웃할까요?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('로그아웃하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('아니오', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF334155)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // signOut() 이후에는 currentUser가 null이 되어 기기 토큰을 지울 수 없으므로,
    // 반드시 로그아웃 "전"에 먼저 지웁니다.
    await PushNotificationService.instance.removeTokenOnLogout();
    await AuthService.signOut();
    DuckAuctionStore.favoriteProductIds.value = <String>{};

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
        onLogout: _logout,
        onOpenFavorites: () => setState(() => selectedIndex = 2),
      ),
      const AuctionTab(),
      const FavoriteTab(),
      MyPageTab(onLogout: _logout),
    ];

    void selectTab(int index) {
      if (_isGuestUser() && index >= 2) {
        _showLoginRequiredSheet(
          context,
          title: '로그인 후 이용할 수 있어요',
          description: '찜한 경매와 마이페이지는 로그인/회원가입 후 사용할 수 있어요.',
        );
        return;
      }
      setState(() => selectedIndex = index);
    }

    Future<void> openRegister() async {
      if (_isGuestUser()) {
        _showLoginRequiredSheet(
          context,
          title: '경매 등록은 로그인 후 가능해요',
          description: '상품을 등록하고 입찰 관리를 하려면 로그인/회원가입이 필요해요.',
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
      // 판매(경매) 등록 전 본인인증은 현재 SMS 휴대폰 인증(위 TradeReadinessScreen의
      // 이메일·휴대폰 인증)으로 처리해요. 통합인증(CI) 본인인증 게이트는 추후 도입
      // 예정이라 지금은 호출하지 않아요. (필요 시 아래 한 줄을 되살리면 다시 켜져요.)
      // if (!await _ensureIdentityVerified(context) || !context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AuctionRegisterScreen()),
      );
    }

    // 태블릿 이상 화면에서는 하단 탭 대신 좌측 내비게이션 레일을 사용해요.
    // 폰에서는 기존과 동일하게 하단 탭바를 사용합니다.
    if (context.isTablet) {
      return _wrapWithExitConfirm(Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DuckNavigationRail(
              selectedIndex: selectedIndex,
              onSelect: selectTab,
              onRegister: openRegister,
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
            Expanded(child: pages[selectedIndex]),
          ],
        ),
      ));
    }

    return _wrapWithExitConfirm(Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: pages[selectedIndex],
      bottomNavigationBar: _DuckBottomNavigationBar(
        selectedIndex: selectedIndex,
        onSelect: selectTab,
        onRegister: openRegister,
      ),
    ));
  }

  /// 홈에서 뒤로가기 처리: 홈이 아닌 다른 탭이면 홈 탭으로 돌아가고,
  /// 홈 탭에서 다시 뒤로가기를 누르면 "앱을 종료할까요?" 확인창을 띄워요.
  Future<void> _handleBackPressed() async {
    if (selectedIndex != 0) {
      setState(() => selectedIndex = 0);
      return;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('앱을 종료할까요?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('덕옥션을 종료하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('아니오', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  /// 시스템 뒤로가기를 가로채(canPop:false) 종료 확인을 거치게 감싸줍니다.
  Widget _wrapWithExitConfirm(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: child,
    );
  }
}


class _DuckBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onRegister;

  const _DuckBottomNavigationBar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: _BottomNavItem(icon: Icons.home_rounded, label: '홈', selected: selectedIndex == 0, onTap: () => onSelect(0))),
            Expanded(child: _BottomNavItem(icon: Icons.gavel_outlined, label: '경매', selected: selectedIndex == 1, onTap: () => onSelect(1))),
            Expanded(
              child: Center(
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRegister,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16305C),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16305C).withOpacity(0.22),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
            Expanded(child: _BottomNavItem(icon: Icons.favorite_border_rounded, label: '찜', selected: selectedIndex == 2, onTap: () => onSelect(2))),
            Expanded(child: _BottomNavItem(icon: Icons.person_outline_rounded, label: '마이페이지', selected: selectedIndex == 3, onTap: () => onSelect(3))),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF16305C) : const Color(0xFF6B7280);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 태블릿 이상 화면에서 하단 탭바 대신 사용하는 좌측 내비게이션 레일.
/// 항목 구성과 동작은 [_DuckBottomNavigationBar]와 동일하게 맞춰져 있어요.
class _DuckNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onRegister;

  const _DuckNavigationRail({
    required this.selectedIndex,
    required this.onSelect,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final railWidth = context.responsive(phone: 84.0, tablet: 88.0, tabletLarge: 104.0);

    return SafeArea(
      child: Container(
        width: railWidth,
        color: Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 18),
            Tooltip(
              message: '경매 등록',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRegister,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16305C),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16305C).withOpacity(0.22),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _RailNavItem(icon: Icons.home_rounded, label: '홈', selected: selectedIndex == 0, onTap: () => onSelect(0)),
                  _RailNavItem(icon: Icons.gavel_outlined, label: '경매', selected: selectedIndex == 1, onTap: () => onSelect(1)),
                  _RailNavItem(icon: Icons.favorite_border_rounded, label: '찜', selected: selectedIndex == 2, onTap: () => onSelect(2)),
                  _RailNavItem(icon: Icons.person_outline_rounded, label: '마이', selected: selectedIndex == 3, onTap: () => onSelect(3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF16305C) : const Color(0xFF6B7280);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF0F9) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onOpenFavorites;

  const HomeTab({
    super.key,
    required this.onLogout,
    required this.onOpenFavorites,
  });

  // AppCategories.names(product_item.dart)가 카테고리 목록의 단일
  // 기준이에요. 여기서는 그 목록 뒤에 '전체보기' 타일만 하나 더 붙입니다.
  static final List<CategoryItem> categories = [
    ...AppCategories.names.map((name) => CategoryItem(name)),
    const CategoryItem('전체보기'),
  ];

  static const popularProducts = [
    ProductItem(
      title: '치이카와 인형 세트',
      category: '치이카와',
      price: '18,000원',
      bids: '24명',
      time: '1시간 남음',
      imageEmoji: '⭐',
      likes: '41',
      sellerName: '별별굿즈',
      sellerSalesCount: 128,
      sellerBadgeIds: ['veteran_seller', 'sales_50', 'honest_seller'],
    ),
    ProductItem(
      title: '쿠로미 키링',
      category: '산리오',
      price: '7,500원',
      bids: '8명',
      time: '5시간 남음',
      imageEmoji: '🎀',
      likes: '18',
      sellerName: '쿠로미상점',
      sellerSalesCount: 52,
      sellerBadgeIds: ['sales_50', 'honest_seller', 'sales_10'],
    ),
    ProductItem(
      title: '리바이 피규어',
      category: '진격의 거인',
      price: '32,000원',
      bids: '17명',
      time: '1일 남음',
      imageEmoji: '⚔️',
      likes: '29',
      sellerName: '조사병단샵',
      sellerSalesCount: 310,
      sellerBadgeIds: ['veteran_seller', 'honest_seller', 'sales_50'],
    ),
    ProductItem(
      title: '포켓몬 랜덤 굿즈',
      category: '게임',
      price: '12,000원',
      bids: '11명',
      time: '3시간 남음',
      imageEmoji: '⚡',
      likes: '22',
      sellerName: '피카굿즈',
      sellerSalesCount: 18,
      sellerBadgeIds: ['sales_10', 'first_sale', 'new_seller'],
    ),
  ];

  static const recentProducts = [
    ProductItem(
      title: '하치와레 마스코트',
      category: '치이카와',
      price: '14,000원',
      bids: '6명',
      time: '6시간 남음',
      imageEmoji: '💙',
      likes: '12',
      sellerName: '하치샵',
      sellerSalesCount: 9,
      sellerBadgeIds: ['first_sale', 'new_seller'],
    ),
    ProductItem(
      title: '마이멜로디 파우치',
      category: '산리오',
      price: '9,000원',
      bids: '4명',
      time: '2일 남음',
      imageEmoji: '🌸',
      likes: '9',
      sellerName: '멜로디마켓',
      sellerSalesCount: 74,
      sellerBadgeIds: ['sales_50', 'honest_seller', 'sales_10'],
    ),
    ProductItem(
      title: '진격거 아크릴 스탠드',
      category: '진격의 거인',
      price: '16,500원',
      bids: '13명',
      time: '8시간 남음',
      imageEmoji: '🪽',
      likes: '21',
      sellerName: '애니덕후상점',
      sellerSalesCount: 156,
      sellerBadgeIds: ['veteran_seller', 'honest_seller', 'sales_50'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;
    final nickname = user?.displayName ?? '덕친';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        toolbarHeight: 62,
        // 번개장터류 마켓 앱처럼 상단을 깔끔하게: 로고 대신
        // [전체 메뉴 아이콘][검색 아이콘] 순서로 두고, 아래쪽 검색창(_SearchBox)은
        // 그대로 유지합니다.
        leading: IconButton(
          tooltip: '전체 메뉴',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AllMenuScreen()),
            );
          },
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF16305C)),
        ),
        title: IconButton(
          tooltip: '검색',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProductSearchScreen(),
              ),
            );
          },
          icon: const Icon(Icons.search, color: Color(0xFF16305C)),
        ),
        actions: [
          IconButton(
            tooltip: '알림',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: isGuest ? '로그인 / 회원가입' : '로그아웃',
            onPressed: isGuest
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                : onLogout,
            icon: Icon(isGuest ? Icons.login : Icons.logout),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ResponsiveContentBounds(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                10,
                context.pagePadding,
                context.responsive(phone: 84.0, tablet: 28.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchBox(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProductSearchScreen(),
                        ),
                      );
                    },
                    onCameraTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProductSearchScreen(startWithCamera: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _HeroBanner(nickname: nickname),
                  const SizedBox(height: 12),
                  _QuickMenuRow(
                    onRegisterTap: () async {
                      if (_isGuestUser()) {
                        _showLoginRequiredSheet(
                          context,
                          title: '경매 등록은 로그인 후 가능해요',
                          description: '경매를 등록하려면 로그인/회원가입이 필요해요.',
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
                      // 판매(경매) 등록 전 본인인증은 현재 SMS 휴대폰 인증으로 처리해요.
                      // 통합인증(CI) 게이트는 추후 도입 예정이라 지금은 호출하지 않아요.
                      // if (!await _ensureIdentityVerified(context) || !context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuctionRegisterScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SectionHeader(title: '마감 임박 경매', trailing: '더보기', icon: Icons.local_fire_department_rounded),
                  const SizedBox(height: 8),
                  _HorizontalProductList(products: popularProducts.reversed.toList()),
                  const SizedBox(height: 18),
                  const _SectionHeader(title: '인기 경매', trailing: '더보기', icon: Icons.trending_up_rounded),
                  const SizedBox(height: 8),
                  _HorizontalProductList(products: popularProducts),
                  const SizedBox(height: 18),
                  const _SectionHeader(title: '신규 등록 경매', trailing: '더보기', icon: Icons.new_releases_rounded),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<List<ProductItem>>(
                    valueListenable: DuckAuctionStore.registeredAuctions,
                    builder: (context, registeredAuctions, _) {
                      final activeRegisteredAuctions = registeredAuctions
                          .where(_isActiveAuction)
                          .toList()
                        ..sort((a, b) {
                          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                          return bDate.compareTo(aDate);
                        });

                      if (registeredAuctions.isNotEmpty && activeRegisteredAuctions.isEmpty) {
                        return const _EmptyAuctionSection(
                          message: '진행 중인 신규 등록 경매가 없어요.',
                          description: '유찰·낙찰·마감된 경매는 신규 등록 목록에서 자동으로 숨겨져요.',
                        );
                      }

                      final products = registeredAuctions.isEmpty
                          ? popularProducts
                          : activeRegisteredAuctions;

                      // 다른 섹션(마감임박·인기·최근본)과 동일한 가로형 카드로
                      // 통일해서, 상품 이름까지 잘 보이게 했어요.
                      return _HorizontalProductList(products: products);
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SectionHeader(title: '최근 본 경매', trailing: '더보기', icon: Icons.history_rounded),
                  const SizedBox(height: 8),
                  _HorizontalProductList(products: recentProducts),
                  const SizedBox(height: 24),
                  const _HomeBusinessFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// 홈 화면 하단에 붙는 사업자정보 푸터예요. 전자상거래법 고지를 홈에서도
/// 바로 볼 수 있게 상호·대표자·사업자등록번호·주소·연락처 + 중개자 고지를
/// 간략히 보여주고, 전체 내용은 사업자정보 화면으로 연결합니다.
class _HomeBusinessFooter extends StatelessWidget {
  const _HomeBusinessFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('덕옥션 사업자정보',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          const Text(
            '상호: 덕옥션 · 대표: 이현선\n'
            '사업자등록번호: 748-15-02875\n'
            '주소: 인천광역시 미추홀구 주안로 39, 1106호(주안동)\n'
            '문의: micket0012@gmail.com · 010-4553-0838',
            style: TextStyle(fontSize: 11.5, height: 1.6, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          const Text(
            '덕옥션은 통신판매중개자로서 통신판매의 당사자가 아니며, 개별 판매자가 등록한 '
            '상품·거래정보 및 거래에 대해 책임을 지지 않습니다. 상품·거래·배송·환불 등 '
            '거래에 관한 의무와 책임은 각 판매 회원(판매자)에게 있습니다.',
            style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xFFB6BCC6)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BusinessInfoScreen()),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('사업자정보·약관 전체보기 ›',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            ),
          ),
        ],
      ),
    );
  }
}
