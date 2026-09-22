import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract class AdService extends ChangeNotifier {
  bool get privacyChoicesAvailable;
  bool get rewardedReady;
  Future<void> initialize();
  Future<bool> showInterstitial();
  Future<bool> showRewarded();
  Future<void> showPrivacyChoices();
}

final adServiceProvider = ChangeNotifierProvider<AdService>((ref) {
  return GoogleAdService();
});

class AdConfig {
  /// V1 deliberately ships without rewarded placements or XP incentives.
  static const rewardedAdsEnabled = bool.fromEnvironment(
    'REWARDED_ADS_ENABLED',
    defaultValue: false,
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
  static String get rewarded => kDebugMode
      ? (defaultTargetPlatform == TargetPlatform.android
            ? 'ca-app-pub-3940256099942544/5224354917'
            : 'ca-app-pub-3940256099942544/1712485313')
      : (defaultTargetPlatform == TargetPlatform.android
            ? androidRewarded
            : iosRewarded);

  static RequestConfiguration get requestConfiguration =>
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.g);
}

class GoogleAdService extends AdService {
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _allowed = false, _loadingInterstitial = false, _loadingRewarded = false;
  bool _privacyChoicesAvailable = false, _disposed = false;
  @override
  bool get privacyChoicesAvailable => _privacyChoicesAvailable;
  @override
  bool get rewardedReady => AdConfig.rewardedAdsEnabled && _rewarded != null;

  @override
  Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    // The native SDK needs a configured app ID before it is touched.
    if (!kDebugMode &&
        ((defaultTargetPlatform == TargetPlatform.android
                    ? AdConfig.androidAppId
                    : AdConfig.iosAppId)
                .isEmpty ||
            AdConfig.interstitial.isEmpty)) {
      return;
    }
    final consent = ConsentInformation.instance;
    try {
      final update = Completer<void>();
      consent.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => update.complete(),
        (_) => update.complete(),
      );
      await update.future.timeout(const Duration(seconds: 12));
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      _allowed = await consent.canRequestAds();
      _privacyChoicesAvailable =
          await consent.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (!_disposed) notifyListeners();
      if (!_allowed) return;
      // Apply this global setting before SDK initialization and any ad request.
      await MobileAds.instance.updateRequestConfiguration(
        AdConfig.requestConfiguration,
      );
      await MobileAds.instance.initialize();
      _loadInterstitial();
    } catch (_) {
      // Offline and unavailable consent leave the game fully playable.
    }
  }

  void _loadInterstitial() {
    if (!_allowed ||
        _loadingInterstitial ||
        _interstitial != null ||
        AdConfig.interstitial.isEmpty ||
        _disposed) {
      return;
    }
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          if (_disposed || !_allowed) {
            ad.dispose();
            return;
          }
          _interstitial = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (_) {
          _loadingInterstitial = false;
        },
      ),
    ).catchError((_) {
      _loadingInterstitial = false;
    });
  }

  void _loadRewarded() {
    if (!AdConfig.rewardedAdsEnabled ||
        !_allowed ||
        _loadingRewarded ||
        _rewarded != null ||
        AdConfig.rewarded.isEmpty ||
        _disposed) {
      return;
    }
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdConfig.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          if (_disposed || !_allowed) {
            ad.dispose();
            return;
          }
          _rewarded = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (_) {
          _loadingRewarded = false;
        },
      ),
    ).catchError((_) {
      _loadingRewarded = false;
    });
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null || _disposed || !_allowed) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _loadInterstitial();
      },
    );
    try {
      await ad.show();
    } catch (_) {
      ad.dispose();
      if (!done.isCompleted) done.complete(false);
      _loadInterstitial();
    }
    return done.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => false,
    );
  }

  @override
  Future<bool> showRewarded() async {
    if (!AdConfig.rewardedAdsEnabled) return false;
    final ad = _rewarded;
    if (ad == null || _disposed || !_allowed) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _loadRewarded();
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (_, _) {
          earned = true;
        },
      );
    } catch (_) {
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
      await ConsentForm.showPrivacyOptionsForm((_) {});
      _allowed = await ConsentInformation.instance.canRequestAds();
      if (!_allowed) {
        _interstitial?.dispose();
        _rewarded?.dispose();
        _interstitial = null;
        _rewarded = null;
        notifyListeners();
      }
      if (_allowed) {
        _loadInterstitial();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.dispose();
  }
}
