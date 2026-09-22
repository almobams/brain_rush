import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const removeAdsProductId = 'brain_rush_remove_ads';

enum RestoreResult { restored, none, unavailable }

abstract class PurchaseGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);
  Future<void> restorePurchases();
  Future<bool> buyNonConsumable(PurchaseParam param);
  Future<void> completePurchase(PurchaseDetails purchase);
}

class PlatformPurchaseGateway implements PurchaseGateway {
  final InAppPurchase _iap = InAppPurchase.instance;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;
  @override
  Future<bool> isAvailable() => _iap.isAvailable();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) =>
      _iap.queryProductDetails(ids);
  @override
  Future<void> restorePurchases() => _iap.restorePurchases();
  @override
  Future<bool> buyNonConsumable(PurchaseParam param) =>
      _iap.buyNonConsumable(purchaseParam: param);
  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);
}

abstract class PurchaseService extends ChangeNotifier {
  bool get owned;
  bool get loading;
  bool get pending;
  String? get price;
  Future<void> initialize();
  Future<void> buy();
  Future<RestoreResult> restore();
}

final purchaseServiceProvider = ChangeNotifierProvider<PurchaseService>((ref) {
  return StorePurchaseService();
});

class StorePurchaseService extends PurchaseService {
  StorePurchaseService({PurchaseGateway? gateway})
    : _gateway = gateway ?? PlatformPurchaseGateway();
  final PurchaseGateway _gateway;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  bool _owned = false, _loading = true, _pending = false, _disposed = false;
  Completer<RestoreResult>? _restore;
  @override
  bool get owned => _owned;
  @override
  bool get loading => _loading;
  @override
  bool get pending => _pending;
  @override
  String? get price => _product?.price;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> initialize() async {
    _subscription = _gateway.purchaseStream.listen(
      _updates,
      onError: (_) {
        _pending = false;
        if (_restore != null && !_restore!.isCompleted) {
          _restore!.complete(RestoreResult.unavailable);
        }
        _restore = null;
        _changed();
      },
    );
    try {
      if (!await _gateway.isAvailable()) return;
      final response = await _gateway.queryProductDetails({removeAdsProductId});
      if (response.error == null) {
        for (final product in response.productDetails) {
          if (product.id == removeAdsProductId) _product = product;
        }
      }
      // Ask the store to re-emit past non-consumable purchases on each launch.
      await _gateway.restorePurchases();
    } catch (_) {
      // Store services can be absent, especially in a simulator.
    } finally {
      _loading = false;
      _changed();
    }
  }

  Future<void> _updates(List<PurchaseDetails> updates) async {
    if (updates.isEmpty && _restore != null && !_restore!.isCompleted) {
      _restore!.complete(RestoreResult.none);
    }
    for (final purchase in updates) {
      if (purchase.productID != removeAdsProductId) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // No account/backend exists. Accept only a matching transaction emitted by the platform store.
          if (purchase.verificationData.localVerificationData.isNotEmpty ||
              purchase.verificationData.serverVerificationData.isNotEmpty) {
            _owned = true;
            if (_restore != null && !_restore!.isCompleted) {
              _restore!.complete(RestoreResult.restored);
            }
          }
          _pending = false;
        case PurchaseStatus.pending:
          _pending = true;
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
          _pending = false;
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _gateway.completePurchase(purchase);
        } catch (_) {}
      }
    }
    _changed();
  }

  @override
  Future<void> buy() async {
    if (_product == null || _pending || _owned) return;
    try {
      _pending = await _gateway.buyNonConsumable(
        PurchaseParam(productDetails: _product!),
      );
    } catch (_) {
      _pending = false;
    }
    _changed();
  }

  @override
  Future<RestoreResult> restore() async {
    if (_restore != null) return _restore!.future;
    final completer = Completer<RestoreResult>();
    _restore = completer;
    try {
      if (!await _gateway.isAvailable()) return RestoreResult.unavailable;
      await _gateway.restorePurchases();
      // Restoration updates are delivered on purchaseStream. Allow them to arrive.
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => RestoreResult.none,
      );
    } catch (_) {
      return RestoreResult.unavailable;
    } finally {
      _restore = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
