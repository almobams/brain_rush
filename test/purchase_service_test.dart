import 'dart:async';

import 'package:brain_rush/monetization/purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class FakeGateway implements PurchaseGateway {
  final controller = StreamController<List<PurchaseDetails>>.broadcast(
    sync: true,
  );
  bool available = true;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
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
  @override
  Future<void> restorePurchases() async {}
  @override
  Future<bool> buyNonConsumable(PurchaseParam param) async => true;
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
  void emit(PurchaseStatus status) => controller.add([
    PurchaseDetails(
      productID: removeAdsProductId,
      verificationData: PurchaseVerificationData(
        localVerificationData: 'store-transaction',
        serverVerificationData: '',
        source: 'test',
      ),
      transactionDate: null,
      status: status,
    ),
  ]);
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
}
