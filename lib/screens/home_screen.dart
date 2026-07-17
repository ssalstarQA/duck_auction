import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'login_screen.dart';



part 'widgets/home_search.dart';
part 'widgets/home_banner.dart';
part 'widgets/banner_link_screens.dart';
part 'widgets/home_sections.dart';
part 'widgets/auction_register.dart';
part 'widgets/product_detail.dart';
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

  const BidSaveResult.success(this.product)
      : success = true,
        message = null,
        error = null;

  const BidSaveResult.failure(this.message, [this.error])
      : success = false,
        product = null;
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

  static final ValueNotifier<List<ProductItem>> cartItems = ValueNotifier<List<ProductItem>>([]);
  static final ValueNotifier<List<ProductItem>> registeredAuctions = ValueNotifier<List<ProductItem>>([]);
  static final ValueNotifier<Set<String>> favoriteProductIds = ValueNotifier<Set<String>>(<String>{});
  static final ValueNotifier<List<ProductItem>> recentViewedProducts = ValueNotifier<List<ProductItem>>([]);
  static final ValueNotifier<int> devTimeOffsetMinutes = ValueNotifier<int>(0);
  static bool _loadedRegisteredAuctions = false;
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

    final updatedProduct = product.copyWith(
      sellerId: user.uid,
      imageUrl: mergedUrls.isNotEmpty ? mergedUrls.first : product.imageUrl,
      imageUrls: mergedUrls,
      coverImageIndex: 0,
      coverImageUrl: mergedUrls.isNotEmpty ? mergedUrls.first : product.resolvedCoverImageUrl,
      imageSchemaVersion: 2,
      clearImageBytes: true,
      preferUploadedImagesFirst: false,
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

  static bool isValidBidAmount({
    required int amount,
    required int currentPrice,
    required int bidUnit,
  }) {
    if (amount < currentPrice + bidUnit) return false;
    return (amount - currentPrice) % bidUnit == 0;
  }

  static String invalidBidMessage({
    required int currentPrice,
    required int bidUnit,
  }) {
    final nextPrice = currentPrice + bidUnit;
    return '입찰 단위는 ${formatWonFromInt(bidUnit)}입니다. ${formatWonFromInt(nextPrice)}부터 ${formatWonFromInt(bidUnit)} 단위로 입찰해주세요.';
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
      late ProductItem updatedProduct;

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

        final nextBidCount = serverBidCount + 1;
        transaction.update(productRef, {
          'currentPrice': amount,
          'bidCount': nextBidCount,
          'lastBidUserId': user.uid,
          'lastBidUserName': user.displayName ?? user.email ?? '입찰자',
          'lastBidAmount': amount,
          'lastBidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(bidRef, {
          'id': bidRef.id,
          'productId': productId,
          'userId': user.uid,
          'userName': user.displayName ?? user.email ?? '입찰자',
          'amount': amount,
          'createdAt': FieldValue.serverTimestamp(),
        });

        updatedProduct = _withBidUpdated(product, amount, nextBidCount).copyWith(lastBidUserId: user.uid);
      });

      _replaceRegisteredAuction(updatedProduct);
      return BidSaveResult.success(updatedProduct);
    } catch (error) {
      final message = error is StateError
          ? error.message
          : '입찰에 실패했습니다. 잠시 후 다시 시도해주세요.';
      return BidSaveResult.failure(message, error);
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


  static bool isInCart(ProductItem product) {
    return cartItems.value.any((item) => item.title == product.title);
  }

  static void toggleCart(ProductItem product) {
    final items = List<ProductItem>.from(cartItems.value);
    final index = items.indexWhere((item) => item.title == product.title);

    if (index >= 0) {
      items.removeAt(index);
    } else {
      items.add(product);
    }

    cartItems.value = items;
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

  static Future<DevActionResult> clearLocalDevelopmentData() async {
    if (!isMasterAdmin) {
      return const DevActionResult.failure('master 계정에서만 사용할 수 있어요.');
    }

    try {
      cartItems.value = <ProductItem>[];
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
    final samples = <ProductItem>[
      ProductItem(
        title: '치이카와 마스코트 샘플',
        description: '개발 테스트용 샘플 상품입니다.',
        category: '치이카와',
        price: '14,000원',
        bids: '0명',
        time: '6시간 남음',
        imageEmoji: '⭐',
        likes: '0',
        sellerId: user.uid,
        sellerName: user.displayName ?? user.email ?? '관리자',
        sellerSalesCount: 0,
        startPrice: 14000,
        currentPrice: 14000,
        bidUnit: '1,000원',
        aiRecommendedPrice: 14000,
        endAt: now.add(const Duration(hours: 6)),
      ),
      ProductItem(
        title: '산리오 키링 샘플',
        description: '개발 테스트용 샘플 상품입니다.',
        category: '산리오',
        price: '8,000원',
        bids: '0명',
        time: '1일 남음',
        imageEmoji: '🎀',
        likes: '0',
        sellerId: user.uid,
        sellerName: user.displayName ?? user.email ?? '관리자',
        sellerSalesCount: 0,
        startPrice: 8000,
        currentPrice: 8000,
        bidUnit: '500원',
        aiRecommendedPrice: 9000,
        endAt: now.add(const Duration(days: 1)),
      ),
      ProductItem(
        title: '포켓몬 랜덤 굿즈 샘플',
        description: '개발 테스트용 샘플 상품입니다.',
        category: '포켓몬',
        price: '12,000원',
        bids: '0명',
        time: '3일 남음',
        imageEmoji: '⚡',
        likes: '0',
        sellerId: user.uid,
        sellerName: user.displayName ?? user.email ?? '관리자',
        sellerSalesCount: 0,
        startPrice: 12000,
        currentPrice: 12000,
        bidUnit: '1,000원',
        aiRecommendedPrice: 13000,
        endAt: now.add(const Duration(days: 3)),
      ),
    ];

    try {
      for (final sample in samples) {
        await addAuction(sample);
      }
      return DevActionResult.success('샘플 상품 ${samples.length}개를 생성했어요.');
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
        message = '판매자 연장 테스트 상태로 변경했어요.';
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
        time: <String, String>{
          'winner_pending': '1순위 결제대기',
          'second_pending': '2순위 결제대기',
          'third_pending': '3순위 결제대기',
          'paid': '결제완료',
          'shipped': '배송중',
          'completed': '거래완료',
          'failed': '유찰',
          'active': product.endAt == null ? '판매중' : product.time,
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
      if (normalized == 'seller_extend') {
        updates['endAt'] = Timestamp.fromDate(now.add(const Duration(days: 7)));
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
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.lock_outline, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: const Color(0xFF334155),
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
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: const Color(0xFF777777),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('계속 구경하기'),
              ),
            ],
          ),
        ),
      );
    },
  );
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
        onOpenCart: () => setState(() => selectedIndex = 3),
      ),
      const AuctionTab(),
      const FavoriteTab(),
      const CartTab(),
      MyPageTab(onLogout: _logout),
    ];

    void selectTab(int index) {
      if (_isGuestUser() && index >= 2) {
        _showLoginRequiredSheet(
          context,
          title: '로그인 후 이용할 수 있어요',
          description: '관심상품, 장바구니, 마이페이지는 로그인/회원가입 후 사용할 수 있어요.',
        );
        return;
      }
      setState(() => selectedIndex = index);
    }

    void openRegister() {
      if (_isGuestUser()) {
        _showLoginRequiredSheet(
          context,
          title: '경매 등록은 로그인 후 가능해요',
          description: '상품을 등록하고 입찰 관리를 하려면 로그인/회원가입이 필요해요.',
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AuctionRegisterScreen()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: pages[selectedIndex],
      bottomNavigationBar: _DuckBottomNavigationBar(
        selectedIndex: selectedIndex,
        onSelect: selectTab,
        onRegister: openRegister,
      ),
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
        height: 78,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
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
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF334155).withOpacity(0.22),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ),
            Expanded(child: _BottomNavItem(icon: Icons.shopping_bag_outlined, label: '장바구니', selected: selectedIndex == 3, onTap: () => onSelect(3))),
            Expanded(child: _BottomNavItem(icon: Icons.person_outline_rounded, label: '마이페이지', selected: selectedIndex == 4, onTap: () => onSelect(4))),
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
    final color = selected ? const Color(0xFF334155) : const Color(0xFF6B7280);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
  final VoidCallback onOpenCart;

  const HomeTab({
    super.key,
    required this.onLogout,
    required this.onOpenCart,
  });

  static const categories = [
    CategoryItem('산리오'),
    CategoryItem('치이카와'),
    CategoryItem('진격의 거인'),
    CategoryItem('디즈니'),
    CategoryItem('포켓몬'),
    CategoryItem('레고'),
    CategoryItem('건담'),
    CategoryItem('전체보기'),
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
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nickname = user?.displayName ?? '덕친';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        toolbarHeight: 72,
        title: SizedBox(
          width: 116,
          height: 62,
          child: Image.asset(
            'assets/image/main_title.png',
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
          ),
        ),
        actions: [
          ValueListenableBuilder<List<ProductItem>>(
            valueListenable: DuckAuctionStore.cartItems,
            builder: (context, cartItems, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: '장바구니',
                    onPressed: onOpenCart,
                    icon: const Icon(Icons.shopping_bag_outlined),
                  ),
                  if (cartItems.isNotEmpty)
                    Positioned(
                      right: 7,
                      top: 11,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          cartItems.length > 9 ? '9+' : '${cartItems.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: '알림',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: user == null ? '로그인/가입' : '로그아웃',
            onPressed: user == null
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                : onLogout,
            icon: Icon(user == null ? Icons.login : Icons.logout),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
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
            const SizedBox(height: 14),
            _HeroBanner(nickname: nickname),
            const SizedBox(height: 18),
            _QuickMenuRow(
              onRegisterTap: () {
                if (_isGuestUser()) {
                  _showLoginRequiredSheet(
                    context,
                    title: '경매 등록은 로그인 후 가능해요',
                    description: '경매를 등록하려면 로그인/회원가입이 필요해요.',
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuctionRegisterScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: '마감 임박 경매', trailing: '더보기', icon: Icons.local_fire_department_rounded),
            const SizedBox(height: 10),
            _HorizontalProductList(products: popularProducts.reversed.toList()),
            const SizedBox(height: 24),
            const _SectionHeader(title: '인기 경매', trailing: '더보기', icon: Icons.trending_up_rounded),
            const SizedBox(height: 10),
            _HorizontalProductList(products: popularProducts),
            const SizedBox(height: 24),
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

                return Column(
                  children: products
                      .map((product) => ProductListTile(product: product))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 14),
            const _SectionHeader(title: '최근 본 경매', trailing: '더보기', icon: Icons.history_rounded),
            const SizedBox(height: 10),
            _HorizontalProductList(products: recentProducts),
          ],
        ),
      ),
    );
  }
}

