import 'dart:async';

import 'package:brain_rush/monetization/purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class FakeGateway implements PurchaseGateway {
  final controller = StreamController<List<PurchaseDetails>>.broadcast(
    sync: true,
  );
  bool available = true;
  ProductDetailsResponse? response;
  Set<String>? requestedIds;
  int completedPurchases = 0;
  Completer<bool>? buyGate;
  Completer<void>? completionGate;
  bool buyRequested = false;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    requestedIds = ids;
    return response ??
        ProductDetailsResponse(
          productDetails: [
            ProductDetails(
              id: removeAdsProductId,
              title: 'Remove Ads',
              description: '',
              price: r'$2.99',
              rawPrice: 2.99,
              currencyCode: 'USD',
            ),
          ],
          notFoundIDs: [],
        );
  }

  @override
  Future<void> restorePurchases() async {}
  @override
  Future<bool> buyNonConsumable(PurchaseParam param) {
    buyRequested = true;
    return buyGate?.future ?? Future.value(true);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases++;
    if (completionGate != null) await completionGate!.future;
  }

  void emit(
    PurchaseStatus status, {
    bool needsCompletion = false,
    IAPError? error,
    String? purchaseID,
  }) {
    final purchase = PurchaseDetails(
      purchaseID: purchaseID,
      productID: removeAdsProductId,
      verificationData: PurchaseVerificationData(
        localVerificationData: 'store-transaction',
        serverVerificationData: '',
        source: 'test',
      ),
      transactionDate: null,
      status: status,
    );
    purchase.pendingCompletePurchase = needsCompletion;
    purchase.error = error;
    controller.add([purchase]);
  }
}

void main() {
  test('purchase cancellation keeps ads enabled; success and restore enable premium', () async {
    final gateway = FakeGateway();
    final service = StorePurchaseService(gateway: gateway);
    await service.initialize();
    expect(service.price, r'$2.99');
    await service.buy();
    expect(service.pending, true);
    gateway.emit(PurchaseStatus.canceled);
    await Future<void>.delayed(Duration.zero);
    expect(service.owned, false);
    gateway.emit(PurchaseStatus.purchased);
    await Future<void>.delayed(Duration.zero);
    expect(service.owned, true);
    service.dispose();

    final restored = StorePurchaseService(gateway: gateway);
    await restored.initialize();
    final pendingRestore = restored.restore();
    gateway.emit(PurchaseStatus.restored);
    expect(await pendingRestore, RestoreResult.restored);
    expect(restored.owned, true);
    restored.dispose();
    final empty = StorePurchaseService(gateway: gateway);
    await empty.initialize();
    final noPurchase = empty.restore();
    gateway.controller.add([]);
    expect(await noPurchase, RestoreResult.none);
    expect(empty.owned, false);
    empty.dispose();
    gateway.available = false;
    final offline = StorePurchaseService(gateway: gateway);
    await offline.initialize();
    expect(await offline.restore(), RestoreResult.unavailable);
    offline.dispose();
    await gateway.controller.close();
  });

  test(
    'debug IAP logs StoreKit response and status without transaction data',
    () async {
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      final gateway = FakeGateway();
      try {
        gateway.response = ProductDetailsResponse(
          productDetails: [],
          notFoundIDs: [removeAdsProductId],
          error: IAPError(
            source: 'storekit',
            code: 'query_failed',
            message: 'Product unavailable',
            details: 'secret-receipt-or-token',
          ),
        );
        final missing = StorePurchaseService(gateway: gateway);
        await missing.initialize();
        expect(gateway.requestedIds, {removeAdsProductId});
        expect(missing.price, isNull);
        expect(
          messages.join('\n'),
          contains('product query started: requested=$removeAdsProductId'),
        );
        expect(messages.join('\n'), contains('code=query_failed'));
        expect(
          messages.join('\n'),
          contains('notFoundIDs=[$removeAdsProductId]'),
        );
        expect(messages.join('\n'), isNot(contains('secret-receipt-or-token')));
        missing.dispose();

        gateway.response = null;
        final available = StorePurchaseService(gateway: gateway);
        await available.initialize();
        expect(messages.join('\n'), contains('price=\$2.99, currency=USD'));
        gateway.emit(PurchaseStatus.pending);
        gateway.emit(
          PurchaseStatus.error,
          error: IAPError(
            source: 'storekit',
            code: 'payment_failed',
            message: 'Declined',
            details: 'secret-purchase-token',
          ),
        );
        gateway.emit(PurchaseStatus.purchased, needsCompletion: true);
        await Future<void>.delayed(Duration.zero);
        expect(available.owned, isTrue);
        expect(gateway.completedPurchases, 1);
        final log = messages.join('\n');
        expect(log, contains('purchase status=pending'));
        expect(log, contains('purchase status=error'));
        expect(log, contains('purchase status=purchased'));
        expect(log, contains('ownership changed: owned=true'));
        expect(log, contains('completePurchase completed'));
        expect(log, isNot(contains('store-transaction')));
        expect(log, isNot(contains('secret-purchase-token')));
        available.dispose();
      } finally {
        await gateway.controller.close();
        debugPrint = previousDebugPrint;
      }
    },
  );

  test(
    'purchased stream result wins over a later accepted buy Future',
    () async {
      final gateway = FakeGateway()..buyGate = Completer<bool>();
      final service = StorePurchaseService(gateway: gateway);
      await service.initialize();
      final states = <(bool owned, bool pending)>[];
      service.addListener(() => states.add((service.owned, service.pending)));

      final buy = service.buy();
      expect(gateway.buyRequested, isTrue);
      expect(service.pending, isTrue);
      expect(states.last, (false, true));

      gateway.emit(PurchaseStatus.purchased);
      expect(service.owned, isTrue);
      expect(service.pending, isFalse);
      expect(states.last, (true, false));

      gateway.buyGate!.complete(true);
      await buy;
      expect(service.owned, isTrue);
      expect(service.pending, isFalse);
      expect(states.last, (true, false));
      service.dispose();
      await gateway.controller.close();
    },
  );

  for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
    test(
      '${status.name} stream result clears pending even before buy returns',
      () async {
        final gateway = FakeGateway()..buyGate = Completer<bool>();
        final service = StorePurchaseService(gateway: gateway);
        await service.initialize();
        final buy = service.buy();
        expect(service.pending, isTrue);

        gateway.emit(status);
        expect(service.pending, isFalse);
        expect(service.owned, isFalse);
        gateway.buyGate!.complete(true);
        await buy;
        expect(service.pending, isFalse);
        expect(service.owned, isFalse);
        service.dispose();
        await gateway.controller.close();
      },
    );
  }

  test('restored stream result grants ownership and clears pending', () async {
    final gateway = FakeGateway()..buyGate = Completer<bool>();
    final service = StorePurchaseService(gateway: gateway);
    await service.initialize();
    final buy = service.buy();
    expect(service.pending, isTrue);
    gateway.emit(PurchaseStatus.restored);
    expect(service.owned, isTrue);
    expect(service.pending, isFalse);
    gateway.buyGate!.complete(true);
    await buy;
    expect(service.pending, isFalse);
    service.dispose();
    await gateway.controller.close();
  });

  test(
    'duplicate purchased events complete the transaction only once',
    () async {
      final gateway = FakeGateway()
        ..buyGate = Completer<bool>()
        ..completionGate = Completer<void>();
      final service = StorePurchaseService(gateway: gateway);
      await service.initialize();
      final observedPending = <bool>[];
      service.addListener(() => observedPending.add(service.pending));
      final buy = service.buy();
      expect(service.pending, isTrue);

      gateway.emit(
        PurchaseStatus.purchased,
        purchaseID: 'same-transaction',
        needsCompletion: true,
      );
      expect(service.owned, isTrue);
      expect(service.pending, isFalse);
      expect(observedPending.last, isFalse);
      expect(gateway.completedPurchases, 1);
      gateway.emit(
        PurchaseStatus.purchased,
        purchaseID: 'same-transaction',
        needsCompletion: true,
      );
      expect(gateway.completedPurchases, 1);
      expect(service.pending, isFalse);

      gateway.completionGate!.complete();
      await Future<void>.delayed(Duration.zero);
      gateway.emit(
        PurchaseStatus.purchased,
        purchaseID: 'same-transaction',
        needsCompletion: true,
      );
      expect(gateway.completedPurchases, 1);
      gateway.buyGate!.complete(true);
      await buy;
      expect(service.pending, isFalse);
      service.dispose();
      await gateway.controller.close();
    },
  );
}
