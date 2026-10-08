import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_diagnostics.dart';
import 'purchase_service.dart';

abstract class AdService extends ChangeNotifier {
  bool get privacyChoicesAvailable;
  bool get rewardedReady;
  Future<void> initialize();
  Future<bool> showInterstitial();
  Future<bool> showRewarded();
  Future<void> showPrivacyChoices();
}

final adServiceProvider = ChangeNotifierProvider<AdService>((ref) {
  return GoogleAdService(ref.read(purchaseServiceProvider));
});

class AdConfig {
  /// Rewarded ads are used only to unlock free Daily Challenge retries.
  static const rewardedAdsEnabled = bool.fromEnvironment(
    'REWARDED_ADS_ENABLED',
    defaultValue: true,
  );
  static const androidAppId = String.fromEnvironment('ANDROID_ADMOB_APP_ID');
  static const iosAppId = String.fromEnvironment('IOS_ADMOB_APP_ID');
  static const androidInterstitial = String.fromEnvironment(
    'ANDROID_INTERSTITIAL_AD_UNIT_ID',
  );
  static const iosInterstitial = String.fromEnvironment(
    'IOS_INTERSTITIAL_AD_UNIT_ID',
  );
  static const androidRewarded = String.fromEnvironment(
    'ANDROID_REWARDED_AD_UNIT_ID',
  );
  static const iosRewarded = String.fromEnvironment('IOS_REWARDED_AD_UNIT_ID');
  static String get interstitial => kDebugMode
      ? (defaultTargetPlatform == TargetPlatform.android
            ? 'ca-app-pub-3940256099942544/1033173712'
            : 'ca-app-pub-3940256099942544/4411468910')
      : (defaultTargetPlatform == TargetPlatform.android
            ? androidInterstitial
            : iosInterstitial);
  static String get rewarded =>
      rewardedFor(defaultTargetPlatform, testAds: kDebugMode);

  static String rewardedFor(TargetPlatform platform, {required bool testAds}) =>
      testAds
      ? (platform == TargetPlatform.android
            ? 'ca-app-pub-3940256099942544/5224354917'
            : 'ca-app-pub-3940256099942544/1712485313')
      : (platform == TargetPlatform.android ? androidRewarded : iosRewarded);

  static RequestConfiguration get requestConfiguration =>
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.g);
}

class GoogleAdService extends AdService {
  GoogleAdService([this._purchaseService]) {
    _purchaseService?.addListener(_onPurchaseChanged);
  }

  final PurchaseService? _purchaseService;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _allowed = false, _loadingInterstitial = false, _loadingRewarded = false;
  bool _privacyChoicesAvailable = false, _disposed = false;
  bool _sdkInitialized = false;
  @override
  bool get privacyChoicesAvailable => _privacyChoicesAvailable;
  @override
  bool get rewardedReady =>
      AdConfig.rewardedAdsEnabled &&
      !(_purchaseService?.owned ?? false) &&
      _rewarded != null;

  String? get _interstitialSuppressionReason {
    final purchases = _purchaseService;
    if (purchases == null) return null;
    if (purchases.owned) return 'Remove Ads owned';
    if (purchases.loading) return 'Remove Ads ownership initializing';
    return null;
  }

  void _onPurchaseChanged() {
    if (_disposed) return;
    if (_purchaseService?.owned ?? false) {
      final ad = _interstitial;
      final rewarded = _rewarded;
      _interstitial = null;
      _rewarded = null;
      rewarded?.dispose();
      if (ad != null) {
        ad.dispose();
        adDebugLog(
          'loaded interstitial disposed: Remove Ads ownership activated',
        );
        notifyListeners();
      } else if (_sdkInitialized) {
        adDebugLog('interstitial load skipped: Remove Ads owned');
      }
      if (rewarded != null) notifyListeners();
      return;
    }
    if (!(_purchaseService?.loading ?? false)) {
      _loadInterstitial();
      _loadRewarded();
    }
  }

  @override
  Future<void> initialize() async {
    adDebugLog(
      'initialization started: platform=${defaultTargetPlatform.name}, '
      'testAds=$kDebugMode, rewardedEnabled=${AdConfig.rewardedAdsEnabled}',
    );
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      adDebugLog('initialization skipped: unsupported platform');
      return;
    }
    // The native SDK needs a configured app ID before it is touched.
    if (!kDebugMode &&
        ((defaultTargetPlatform == TargetPlatform.android
                    ? AdConfig.androidAppId
                    : AdConfig.iosAppId)
                .isEmpty ||
            AdConfig.interstitial.isEmpty)) {
      adDebugLog('initialization skipped: missing app/ad unit configuration');
      return;
    }
    final consent = ConsentInformation.instance;
    try {
      final update = Completer<bool>();
      adDebugLog('consent update started');
      consent.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          adDebugLog('consent update completed');
          update.complete(true);
        },
        (error) {
          adDebugLog(
            'consent update failed: code=${error.errorCode}, ${error.message}',
          );
          update.complete(false);
        },
      );
      // Initialization is already asynchronous after the first frame. Let a
      // slow consent update finish instead of permanently aborting after 12s.
      if (await update.future) {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) {
            adDebugLog(
              'consent form failed: code=${error.errorCode}, ${error.message}',
            );
          }
        });
      }
      _allowed = await consent.canRequestAds();
      adDebugLog('consent canRequestAds=$_allowed');
      _privacyChoicesAvailable =
          await consent.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (!_disposed) notifyListeners();
      if (_disposed || !_allowed) {
        adDebugLog(
          'initialization stopped: ${_disposed ? 'disposed' : 'consent does not allow ads'}',
        );
        return;
      }
      // Apply this global setting before SDK initialization and any ad request.
      await MobileAds.instance.updateRequestConfiguration(
        AdConfig.requestConfiguration,
      );
      adDebugLog(
        'global maxAdContentRating=G applied; SDK initialization started',
      );
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
      adDebugLog('SDK initialized');
      _loadInterstitial();
      _loadRewarded();
    } catch (error) {
      adDebugLog('initialization failed: $error');
      // Offline and unavailable consent leave the game fully playable.
    }
  }

  void _loadInterstitial() {
    final suppressionReason = _interstitialSuppressionReason;
    if (suppressionReason != null) {
      adDebugLog('interstitial load skipped: $suppressionReason');
      return;
    }
    if (!_allowed ||
        !_sdkInitialized ||
        _loadingInterstitial ||
        _interstitial != null ||
        AdConfig.interstitial.isEmpty ||
        _disposed) {
      return;
    }
    _loadingInterstitial = true;
    adDebugLog('interstitial load started: testAds=$kDebugMode');
    InterstitialAd.load(
      adUnitId: AdConfig.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          if (_disposed ||
              !_allowed ||
              _interstitialSuppressionReason != null) {
            adDebugLog(
              'interstitial loaded but discarded: '
              '${_interstitialSuppressionReason ?? 'disposed or consent unavailable'}',
            );
            ad.dispose();
            return;
          }
          _interstitial = ad;
          adDebugLog('interstitial loaded');
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          adDebugLog(
            'interstitial load failed: code=${error.code}, '
            'domain=${error.domain}, ${error.message}',
          );
        },
      ),
    ).catchError((Object error) {
      _loadingInterstitial = false;
      adDebugLog('interstitial load failed: $error');
    });
  }

  void _loadRewarded() {
    if (!AdConfig.rewardedAdsEnabled ||
        !_allowed ||
        !_sdkInitialized ||
        _loadingRewarded ||
        _rewarded != null ||
        AdConfig.rewarded.isEmpty ||
        (_purchaseService?.owned ?? false) ||
        (_purchaseService?.loading ?? false) ||
        _disposed) {
      return;
    }
    _loadingRewarded = true;
    adDebugLog('rewarded load started: testAds=$kDebugMode');
    RewardedAd.load(
      adUnitId: AdConfig.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          if (_disposed || !_allowed || (_purchaseService?.owned ?? false)) {
            ad.dispose();
            return;
          }
          _rewarded = ad;
          adDebugLog('rewarded loaded');
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          adDebugLog(
            'rewarded load failed: code=${error.code}, ${error.message}',
          );
          if (!_disposed) notifyListeners();
        },
      ),
    ).catchError((Object error) {
      _loadingRewarded = false;
      adDebugLog('rewarded load failed: $error');
    });
  }

  @override
  Future<bool> showInterstitial() async {
    adDebugLog('interstitial show attempted');
    final suppressionReason = _interstitialSuppressionReason;
    if (suppressionReason != null) {
      adDebugLog('interstitial show skipped: $suppressionReason');
      return false;
    }
    final ad = _interstitial;
    if (ad == null || _disposed || !_allowed || !_sdkInitialized) {
      final reason = _disposed
          ? 'disposed'
          : !_allowed
          ? 'consent unavailable or update pending'
          : !_sdkInitialized
          ? 'SDK initialization pending or failed'
          : _loadingInterstitial
          ? 'ad still loading'
          : 'no loaded ad; requesting preload for a later Results exit';
      adDebugLog('interstitial show skipped: $reason');
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        adDebugLog('interstitial displayed');
      },
      onAdDismissedFullScreenContent: (ad) {
        adDebugLog('interstitial dismissed');
        ad.dispose();
        if (!done.isCompleted) done.complete(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        adDebugLog(
          'interstitial failed to show: code=${error.code}, '
          'domain=${error.domain}, ${error.message}',
        );
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _loadInterstitial();
      },
    );
    try {
      await ad.show();
    } catch (error) {
      adDebugLog('interstitial failed to show: $error');
      ad.dispose();
      if (!done.isCompleted) done.complete(false);
      _loadInterstitial();
    }
    return done.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        adDebugLog('interstitial show timed out; continuing navigation');
        return false;
      },
    );
  }

  @override
  Future<bool> showRewarded() async {
    if (!AdConfig.rewardedAdsEnabled || (_purchaseService?.owned ?? false)) {
      return false;
    }
    final ad = _rewarded;
    if (ad == null || _disposed || !_allowed || !_sdkInitialized) {
      adDebugLog('rewarded show skipped: no loaded ad');
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    notifyListeners();
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        adDebugLog('rewarded dismissed: earned=$earned');
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        adDebugLog(
          'rewarded failed to show: code=${error.code}, ${error.message}',
        );
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _loadRewarded();
      },
    );
    try {
      adDebugLog('rewarded show attempted');
      await ad.show(
        onUserEarnedReward: (_, _) {
          earned = true;
          adDebugLog('rewarded reward callback received');
        },
      );
    } catch (error) {
      adDebugLog('rewarded failed to show: $error');
      ad.dispose();
      if (!done.isCompleted) done.complete(false);
      _loadRewarded();
    }
    return done.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => earned,
    );
  }

  @override
  Future<void> showPrivacyChoices() async {
    if (!_privacyChoicesAvailable) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) {
          adDebugLog(
            'privacy choices failed: code=${error.errorCode}, ${error.message}',
          );
        }
      });
      _allowed = await ConsentInformation.instance.canRequestAds();
      adDebugLog('privacy choices updated: canRequestAds=$_allowed');
      if (!_allowed) {
        _interstitial?.dispose();
        _rewarded?.dispose();
        _interstitial = null;
        _rewarded = null;
        notifyListeners();
      }
      if (_allowed) {
        _loadInterstitial();
        _loadRewarded();
      }
    } catch (error) {
      adDebugLog('privacy choices failed: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _purchaseService?.removeListener(_onPurchaseChanged);
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.dispose();
  }
}
