import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/localization/strings.dart';
import 'package:brain_rush/main.dart';
import 'package:brain_rush/monetization/ad_service.dart';
import 'package:brain_rush/monetization/purchase_service.dart';
import 'package:brain_rush/screens/secondary_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Purchases extends PurchaseService {
  _Purchases([this._owned = false]);

  bool _owned;
  int buys = 0;
  int restores = 0;

  @override
  bool get owned => _owned;
  @override
  bool get loading => false;
  @override
  bool get pending => false;
  @override
  String? get price => 'SAR 9.99';

  void setOwned(bool value) {
    _owned = value;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> buy() async {
    buys++;
  }

  @override
  Future<RestoreResult> restore() async {
    restores++;
    return RestoreResult.none;
  }
}

class _Ads extends AdService {
  @override
  bool get privacyChoicesAvailable => false;
  @override
  bool get rewardedReady => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> showInterstitial() async => false;
  @override
  Future<bool> showRewarded() async => false;
  @override
  Future<void> showPrivacyChoices() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Home shortcuts and Settings follow Remove Ads ownership', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final purchases = _Purchases();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        purchaseServiceProvider.overrideWith((ref) => purchases),
        adServiceProvider.overrideWith((ref) => _Ads()),
      ],
    );
    container.read(storeProvider).onboardingCompleted = true;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BrainRushApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('homeStatsShortcut')), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, Strings.en['settings']!),
      findsNothing,
    );
    expect(find.byTooltip(Strings.en['settings']!), findsOneWidget);
    expect(find.byKey(const Key('homeRemoveAds')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip(Strings.en['settings']!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('SAR 9.99'), findsOneWidget);
    final buy = find.byKey(const Key('settingsPurchaseButton'));
    expect(buy, findsOneWidget);
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    expect(purchases.buys, 1);
    final restore = find.byKey(const Key('restorePurchasesButton'));
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pump();
    expect(purchases.restores, 1);

    purchases.setOwned(true);
    await tester.pump();
    expect(find.text(Strings.en['adFreeActive']!), findsOneWidget);
    expect(buy, findsNothing);
    expect(restore, findsOneWidget);
    Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('homeRemoveAds')), findsNothing);
    expect(find.byKey(const Key('homeStatsShortcut')), findsOneWidget);
    expect(find.byTooltip(Strings.en['settings']!), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final language in ['ar', 'ur', 'fa']) {
    for (final owned in [false, true]) {
      testWidgets(
        '$language Settings purchase section fits at 320px, owned=$owned',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final prefs = await SharedPreferences.getInstance();
        final purchases = _Purchases(owned);
          final container = ProviderContainer(
            overrides: [
              preferencesProvider.overrideWithValue(prefs),
              purchaseServiceProvider.overrideWith((ref) => purchases),
              adServiceProvider.overrideWith((ref) => _Ads()),
            ],
          );
          container.read(storeProvider)
            ..onboardingCompleted = true
            ..language = language;
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const BrainRushApp(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.byKey(const Key('homeRemoveAds')),
            owned ? findsNothing : findsOneWidget,
          );
        await tester.tap(find.byTooltip(Strings(language).t('settings')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
          final purchaseSection = find.byKey(
            const Key('settingsPurchaseSection'),
          );
          await tester.ensureVisible(purchaseSection);
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.byKey(const Key('restorePurchasesButton')),
            findsOneWidget,
          );
          expect(
            find.text(Strings(language).t('adFreeActive')),
            owned ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const Key('settingsPurchaseButton')),
            owned ? findsNothing : findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        },
      );
    }
  }
}
