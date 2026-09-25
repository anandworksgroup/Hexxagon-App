import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob unit ids, injected at build time so live ids never live in git:
///
/// ```bash
/// flutter build appbundle --release --dart-define-from-file=config/ads.json
/// ```
///
/// Anything not supplied falls back to Google's public test unit, which serves
/// test ads and is always policy-safe. Debug builds always use test units —
/// clicking your own live ads can get the AdMob account suspended.
class AdConfig {
  const AdConfig._();

  static const String _androidInterstitial = String.fromEnvironment('ADMOB_ANDROID_INTERSTITIAL');
  static const String _iosInterstitial = String.fromEnvironment('ADMOB_IOS_INTERSTITIAL');

  static const String _testAndroidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';

  static String get interstitialUnitId => Platform.isIOS
      ? _pick(_iosInterstitial, _testIosInterstitial)
      : _pick(_androidInterstitial, _testAndroidInterstitial);

  /// True when this build would request ads from a test unit.
  static bool get usingTestUnits =>
      !kReleaseMode || (Platform.isIOS ? _iosInterstitial.isEmpty : _androidInterstitial.isEmpty);

  static String _pick(String configured, String test) {
    if (!kReleaseMode || configured.isEmpty) return test;
    return configured;
  }
}
