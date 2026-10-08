import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'iap_diagnostics.dart';

const removeAdsProductId = 'brain_rush_remove_ads';

// Deliberately omit error details: platform payloads may contain transaction data.
String _iapErrorSummary(IAPError error) =>
    'source=${error.source}, code=${error.code}, message=${error.message}';

String _exceptionSummary(Object error) => switch (error) {
  PlatformException(:final code, :final message) =>
    'PlatformException code=$code, message=$message',
  IAPError() => _iapErrorSummary(error),
  _ => '${error.runtimeType}',
};

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
  final Set<Object> _completingPurchases = {};
  final Set<Object> _completedPurchases = {};
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
    iapDebugLog('initialization started');
    _subscription = _gateway.purchaseStream.listen(
      _updates,
      onError: (Object error) {
        iapDebugLog('purchase stream error: ${_exceptionSummary(error)}');
        _pending = false;
        if (_restore != null && !_restore!.isCompleted) {
          _restore!.complete(RestoreResult.unavailable);
          iapDebugLog('restore completed: unavailable (purchase stream error)');
        }
        _restore = null;
        _changed();
      },
    );
    try {
      final available = await _gateway.isAvailable();
      iapDebugLog('InAppPurchase.isAvailable()=$available');
      if (!available) {
        iapDebugLog('product query skipped: StoreKit unavailable');
        return;
      }
      iapDebugLog('product query started: requested=$removeAdsProductId');
      final response = await _gateway.queryProductDetails({removeAdsProductId});
      iapDebugLog(
        'product query response: error=${response.error == null ? 'none' : _iapErrorSummary(response.error!)}, '
        'returnedIDs=${response.productDetails.map((product) => product.id).toList()}, '
        'notFoundIDs=${response.notFoundIDs}',
      );
      if (response.error == null) {
        for (final product in response.productDetails) {
          if (product.id == removeAdsProductId) {
            _product = product;
            iapDebugLog(
              'product resolved: id=${product.id}, price=${product.price}, '
              'currency=${product.currencyCode}',
            );
          }
        }
      }
      if (_product == null) {
        iapDebugLog('product unresolved; purchase remains unavailable');
      }
      // Ask the store to re-emit past non-consumable purchases on each launch.
      iapDebugLog('restore started: startup');
      await _gateway.restorePurchases();
      iapDebugLog(
        'restore request completed: startup; awaiting purchase stream',
      );
    } catch (error) {
      iapDebugLog(
        'initialization or startup restore failed: ${_exceptionSummary(error)}',
      );
      // Store services can be absent, especially in a simulator.
    } finally {
      _loading = false;
      iapDebugLog(
        'initialization completed: productAvailable=${_product != null}, '
        'owned=$_owned',
      );
      _changed();
    }
  }

  Future<void> _updates(List<PurchaseDetails> updates) async {
    iapDebugLog('purchase stream update: count=${updates.length}');
    if (updates.isEmpty && _restore != null && !_restore!.isCompleted) {
      _restore!.complete(RestoreResult.none);
      iapDebugLog('restore completed: no purchases (empty stream update)');
    }
    for (final purchase in updates) {
      iapDebugLog(
        'purchase status=${purchase.status.name}, '
        'productID=${purchase.productID}, '
        'pendingCompletePurchase=${purchase.pendingCompletePurchase}'
        '${purchase.error == null ? '' : ', error=${_iapErrorSummary(purchase.error!)}'}',
      );
      if (purchase.productID != removeAdsProductId) {
        iapDebugLog('purchase ignored: product ID does not match Remove Ads');
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // No account/backend exists. Accept only a matching transaction emitted by the platform store.
          final hasVerificationData =
              purchase.verificationData.localVerificationData.isNotEmpty ||
              purchase.verificationData.serverVerificationData.isNotEmpty;
          iapDebugLog(
            'matching purchase verification data present=$hasVerificationData',
          );
          if (hasVerificationData) {
            final wasOwned = _owned;
            _owned = true;
            if (!wasOwned) iapDebugLog('ownership changed: owned=true');
            if (_restore != null && !_restore!.isCompleted) {
              _restore!.complete(RestoreResult.restored);
              iapDebugLog('restore completed: restored');
            }
          }
          _pending = false;
        case PurchaseStatus.pending:
          if (!_owned) _pending = true;
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
          _pending = false;
      }
      // StoreKit may complete the purchase Future before completePurchase does.
      // Publish the authoritative stream state to the UI immediately.
      _changed();
      if (purchase.pendingCompletePurchase) {
        final completionKey = purchase.purchaseID ?? purchase;
        if (_completingPurchases.contains(completionKey) ||
            _completedPurchases.contains(completionKey)) {
          iapDebugLog('completePurchase skipped: duplicate transaction');
        } else {
          _completingPurchases.add(completionKey);
          iapDebugLog(
            'completePurchase started: status=${purchase.status.name}',
          );
          try {
            await _gateway.completePurchase(purchase);
            _completedPurchases.add(completionKey);
            iapDebugLog('completePurchase completed');
          } catch (error) {
            iapDebugLog('completePurchase failed: ${_exceptionSummary(error)}');
          } finally {
            _completingPurchases.remove(completionKey);
          }
        }
      } else {
        iapDebugLog('completePurchase skipped: transaction already completed');
      }
    }
  }

  @override
  Future<void> buy() async {
    if (_product == null || _pending || _owned) {
      iapDebugLog(
        'buy skipped: productAvailable=${_product != null}, pending=$_pending, owned=$_owned',
      );
      return;
    }
    iapDebugLog('buy started: productID=${_product!.id}');
    _pending = true;
    _changed();
    try {
      final accepted = await _gateway.buyNonConsumable(
        PurchaseParam(productDetails: _product!),
      );
      // A true return means the request was accepted, not that it is still
      // pending. The purchase stream may already have resolved it.
      if (!accepted) _pending = false;
      iapDebugLog(
        'buy request returned: accepted=$accepted, owned=$_owned, pending=$_pending; '
        'purchase stream is authoritative',
      );
    } catch (error) {
      iapDebugLog('buy request failed: ${_exceptionSummary(error)}');
      _pending = false;
    }
    _changed();
  }

  @override
  Future<RestoreResult> restore() async {
    if (_restore != null) {
      iapDebugLog('restore joined existing request');
      return _restore!.future;
    }
    iapDebugLog('restore started: user requested');
    final completer = Completer<RestoreResult>();
    _restore = completer;
    try {
      final available = await _gateway.isAvailable();
      iapDebugLog('restore InAppPurchase.isAvailable()=$available');
      if (!available) {
        iapDebugLog('restore completed: unavailable (StoreKit unavailable)');
        return RestoreResult.unavailable;
      }
      await _gateway.restorePurchases();
      iapDebugLog('restore request completed: awaiting purchase stream');
      // Restoration updates are delivered on purchaseStream. Allow them to arrive.
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => RestoreResult.none,
      );
      iapDebugLog('restore completed: ${result.name}');
      return result;
    } catch (error) {
      iapDebugLog('restore error: ${_exceptionSummary(error)}');
      iapDebugLog('restore completed: unavailable');
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
