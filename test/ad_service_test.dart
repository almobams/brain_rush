import 'dart:async';

import 'package:brain_rush/monetization/ad_service.dart';
import 'package:brain_rush/monetization/purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The pinned plugin's codecs are needed to emulate its native platform channels.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';

class _FakePurchases extends PurchaseService {
  @override
  bool owned = false;
  @override
  bool loading = false;
  @override
  bool get pending => false;
  @override
  String? get price => null;

  void update({bool? owned, bool? loading}) {
    if (owned != null) this.owned = owned;
    if (loading != null) this.loading = loading;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> buy() async {}
  @override
  Future<RestoreResult> restore() async => RestoreResult.none;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final adsChannel = MethodChannel(
    'plugins.flutter.io/google_mobile_ads',
    StandardMethodCodec(AdMessageCodec()),
  );
  final umpChannel = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );
  late GoogleAdService service;
  late _FakePurchases purchases;
  late List<MethodCall> calls;
  late List<String> logs;
  bool allowed = true;
  bool updateFails = false;
  Completer<void>? consentGate;
  Completer<void>? initializationGate;

  setUp(() {
    calls = [];
    logs = [];
    allowed = true;
    updateFails = false;
    consentGate = null;
    initializationGate = null;
    purchases = _FakePurchases();
    service = GoogleAdService(purchases);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(umpChannel, (
      call,
    ) async {
      switch (call.method) {
        case 'ConsentInformation#requestConsentInfoUpdate':
          if (consentGate != null) await consentGate!.future;
          if (updateFails) {
            throw PlatformException(
              code: '1',
              message: 'Consent network unavailable',
            );
          }
          return null;
        case 'ConsentInformation#canRequestAds':
          return allowed;
        case 'ConsentInformation#getPrivacyOptionsRequirementStatus':
          return 0;
        default:
          return null;
      }
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(adsChannel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'MobileAds#initialize') {
        if (initializationGate != null) await initializationGate!.future;
        return InitializationStatus({});
      }
      return null;
    });
  });

  tearDown(() async {
    service.dispose();
    purchases.dispose();
    await Future<void>.value();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(adsChannel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(umpChannel, null);
  });

  void testIos(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      final originalDebugPrint = debugPrint;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        await body(tester);
      } finally {
        debugPrint = originalDebugPrint;
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  List<MethodCall> loads() =>
      calls.where((call) => call.method == 'loadInterstitialAd').toList();
  List<MethodCall> rewardedLoads() =>
      calls.where((call) => call.method == 'loadRewardedAd').toList();

  Future<void> event(
    String name, {
    Map<String, Object?> extra = const {},
    bool rewarded = false,
  }) async {
    final done = Completer<void>();
    // Deliver the same iOS callbacks used by the native SDK.
    binding.defaultBinaryMessenger.handlePlatformMessage(
      adsChannel.name,
      adsChannel.codec.encodeMethodCall(
        MethodCall('onAdEvent', {
          'adId':
              ((rewarded ? rewardedLoads() : loads()).last.arguments
                  as Map)['adId'],
          'eventName': name,
          ...extra,
        }),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }

  testIos('known Remove Ads owner never requests an interstitial', (
    tester,
  ) async {
    purchases.update(owned: true);
    await service.initialize();
    await tester.pump();
    expect(loads(), isEmpty);
    expect(await service.showInterstitial(), isFalse);
    expect(loads(), isEmpty);
    expect(
      logs,
      contains('[BrainRush Ads] interstitial load skipped: Remove Ads owned'),
    );
  });

  testIos(
    'ownership initialization delays preload until a free state is known',
    (tester) async {
      purchases.update(loading: true);
      await service.initialize();
      await tester.pump();
      expect(loads(), isEmpty);
      expect(
        logs,
        contains(
          '[BrainRush Ads] interstitial load skipped: Remove Ads ownership initializing',
        ),
      );
      purchases.update(loading: false);
      await tester.pump();
      expect(loads(), hasLength(1));
      await event('onAdLoaded');
    },
  );

  testIos(
    'startup restore during ownership initialization never requests an ad',
    (tester) async {
      purchases.update(loading: true);
      await service.initialize();
      await tester.pump();
      expect(loads(), isEmpty);
      purchases.update(owned: true, loading: false);
      await tester.pump();
      expect(loads(), isEmpty);
      expect(
        logs,
        contains('[BrainRush Ads] interstitial load skipped: Remove Ads owned'),
      );
    },
  );

  testIos(
    'ownership activation disposes a loaded ad and prevents further loads',
    (tester) async {
      await service.initialize();
      await tester.pump();
      await event('onAdLoaded');
      purchases.update(owned: true);
      await tester.pump();
      expect(calls.where((call) => call.method == 'disposeAd'), hasLength(1));
      expect(
        logs,
        contains(
          '[BrainRush Ads] loaded interstitial disposed: Remove Ads ownership activated',
        ),
      );
      expect(await service.showInterstitial(), isFalse);
      expect(loads(), hasLength(1));
    },
  );

  testIos('ownership activation during a load discards its result', (
    tester,
  ) async {
    await service.initialize();
    await tester.pump();
    purchases.update(owned: true);
    await event('onAdLoaded');
    await tester.pump();
    expect(calls.where((call) => call.method == 'disposeAd'), hasLength(1));
    expect(loads(), hasLength(1));
    expect(await service.showInterstitial(), isFalse);
  });

  testIos('dismissal does not preload again after ownership becomes true', (
    tester,
  ) async {
    await service.initialize();
    await tester.pump();
    await event('onAdLoaded');
    final shown = service.showInterstitial();
    purchases.update(owned: true);
    await event('adDidDismissFullScreenContent');
    expect(await shown, isTrue);
    await tester.pump();
    expect(loads(), hasLength(1));
  });

  testIos(
    'slow consent still preloads iOS test interstitial with G before SDK init',
    (tester) async {
      consentGate = Completer<void>();
      final initialization = service.initialize();
      await tester.pump(const Duration(seconds: 13));
      expect(calls, isEmpty);
      consentGate!.complete();
      await initialization;
      await tester.pump();
      expect(
        calls
            .where((call) => call.method != '_init')
            .map((call) => call.method),
        [
          'MobileAds#updateRequestConfiguration',
          'MobileAds#initialize',
          'loadInterstitialAd',
          'loadRewardedAd',
        ],
      );
      final configuration =
          calls
                  .singleWhere(
                    (call) =>
                        call.method == 'MobileAds#updateRequestConfiguration',
                  )
                  .arguments
              as Map;
      expect(configuration['maxAdContentRating'], 'G');
      expect(configuration['tagForChildDirectedTreatment'], isNull);
      expect(
        (loads().single.arguments as Map)['adUnitId'],
        'ca-app-pub-3940256099942544/4411468910',
      );
      expect(
        logs,
        contains('[BrainRush Ads] interstitial load started: testAds=true'),
      );
      expect(await service.showRewarded(), isFalse);
      expect(service.rewardedReady, isFalse);
      expect(
        (rewardedLoads().single.arguments as Map)['adUnitId'],
        'ca-app-pub-3940256099942544/1712485313',
      );
      await event('onAdLoaded');
    },
  );

  testIos('reward callback alone grants a rewarded result', (tester) async {
    await service.initialize();
    await tester.pump();
    await event('onAdLoaded', rewarded: true);
    expect(service.rewardedReady, isTrue);
    final earned = service.showRewarded();
    await event(
      'onRewardedAdUserEarnedReward',
      rewarded: true,
      extra: {'rewardItem': RewardItem(1, 'retry')},
    );
    await event('adDidDismissFullScreenContent', rewarded: true);
    expect(await earned, isTrue);
    expect(rewardedLoads(), hasLength(2));
  });

  testIos('rewarded dismissal without reward does not grant a retry', (
    tester,
  ) async {
    await service.initialize();
    await tester.pump();
    await event('onAdLoaded', rewarded: true);
    final earned = service.showRewarded();
    await event('adDidDismissFullScreenContent', rewarded: true);
    expect(await earned, isFalse);
    expect(rewardedLoads(), hasLength(2));
  });

  testIos('rewarded show failure does not grant a retry', (tester) async {
    await service.initialize();
    await tester.pump();
    await event('onAdLoaded', rewarded: true);
    final earned = service.showRewarded();
    await event(
      'didFailToPresentFullScreenContentWithError',
      rewarded: true,
      extra: {
        // ignore: invalid_use_of_protected_member
        'error': AdError(3, 'test.sdk', 'Presentation unavailable'),
      },
    );
    expect(await earned, isFalse);
    expect(rewardedLoads(), hasLength(2));
  });

  testIos('Results exit during SDK initialization never requests an early ad', (
    tester,
  ) async {
    initializationGate = Completer<void>();
    final initialization = service.initialize();
    await tester.pump();
    expect(calls.map((call) => call.method), contains('MobileAds#initialize'));
    expect(await service.showInterstitial(), isFalse);
    expect(loads(), isEmpty);
    expect(
      logs.any((log) => log.contains('SDK initialization pending or failed')),
      isTrue,
    );
    initializationGate!.complete();
    await initialization;
    await tester.pump();
    expect(loads(), hasLength(1));
    await event('onAdLoaded');
  });

  testIos('consent denial prevents initialization and all ad requests', (
    tester,
  ) async {
    allowed = false;
    await service.initialize();
    expect(await service.showInterstitial(), isFalse);
    expect(calls, isEmpty);
    expect(logs.any((log) => log.contains('canRequestAds=false')), isTrue);
    expect(
      logs.any((log) => log.contains('consent unavailable or update pending')),
      isTrue,
    );
  });

  testIos(
    'consent update failure logs error and honors SDK cached permission',
    (tester) async {
      updateFails = true;
      await service.initialize();
      await tester.pump();
      expect(
        logs.any(
          (log) => log.contains(
            'consent update failed: code=1, Consent network unavailable',
          ),
        ),
        isTrue,
      );
      expect(loads(), hasLength(1));
      await event('onAdLoaded');
    },
  );

  testIos(
    'loading skips navigation without waiting and loaded ad reports full lifecycle',
    (tester) async {
      await service.initialize();
      await tester.pump();
      expect(await service.showInterstitial(), isFalse);
      expect(
        logs.any((log) => log.contains('show skipped: ad still loading')),
        isTrue,
      );
      expect(loads(), hasLength(1));
      await event('onAdLoaded');
      final shown = service.showInterstitial();
      await event('adWillPresentFullScreenContent');
      await event('adDidDismissFullScreenContent');
      expect(await shown, isTrue);
      await tester.pump();
      expect(loads(), hasLength(2));
      expect(
        logs,
        containsAll([
          '[BrainRush Ads] interstitial loaded',
          '[BrainRush Ads] interstitial show attempted',
          '[BrainRush Ads] interstitial displayed',
          '[BrainRush Ads] interstitial dismissed',
        ]),
      );
      await event('onAdLoaded');
    },
  );

  testIos(
    'load failure logs SDK error and next eligible attempt retries without blocking',
    (tester) async {
      await service.initialize();
      await tester.pump();
      await event(
        'onAdFailedToLoad',
        extra: {
          // Native callback value; production code never constructs this error.
          // ignore: invalid_use_of_protected_member
          'loadAdError': LoadAdError(
            2,
            'test.sdk',
            'Network unavailable',
            null,
          ),
        },
      );
      expect(
        logs.any(
          (log) => log.contains(
            'load failed: code=2, domain=test.sdk, Network unavailable',
          ),
        ),
        isTrue,
      );
      expect(await service.showInterstitial(), isFalse);
      await tester.pump();
      expect(loads(), hasLength(2));
      await event('onAdLoaded');
    },
  );

  testIos('failed presentation reports error and returns false', (
    tester,
  ) async {
    await service.initialize();
    await tester.pump();
    await event('onAdLoaded');
    final shown = service.showInterstitial();
    await event(
      'didFailToPresentFullScreenContentWithError',
      extra: {
        // ignore: invalid_use_of_protected_member
        'error': AdError(3, 'test.sdk', 'Presentation unavailable'),
      },
    );
    expect(await shown, isFalse);
    expect(
      logs.any(
        (log) => log.contains(
          'failed to show: code=3, domain=test.sdk, Presentation unavailable',
        ),
      ),
      isTrue,
    );
    await tester.pump();
    await event('onAdLoaded');
  });
}
