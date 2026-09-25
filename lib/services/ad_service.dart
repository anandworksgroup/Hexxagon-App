import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// AdMob interstitials.
///
/// Rule: one full-screen ad after a finished game — a completed level, a
/// finished battle, a lost game — shown before the result screen, never
/// during play.
///
/// The game itself is fully offline; ads are the only part that wants the
/// internet, so every path here fails soft. Offline, no consent, no fill or a
/// slow load all mean "no ad this time" and the player carries straight on.
class AdService {
  AdService({
    this.loadWait = const Duration(seconds: 3),
    bool? platformSupported,
  }) : _platformSupported =
           platformSupported ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// How long a player may be kept waiting for an ad that is still loading.
  final Duration loadWait;
  final bool _platformSupported;

  static const Duration _minRetry = Duration(seconds: 8);
  static const Duration _maxRetry = Duration(minutes: 2);

  bool _initStarted = false;
  bool _ready = false;
  bool _loading = false;
  bool _showing = false;
  bool _disposed = false;
  InterstitialAd? _ad;
  Completer<void>? _pendingLoad;
  Duration _retry = _minRetry;
  Timer? _retryTimer;

  bool get isAdLoaded => _ad != null;
  bool get isShowingAd => _showing;

  /// Consent, then SDK start, then preload. Never awaited by startup.
  Future<void> init() async {
    if (_initStarted || !_platformSupported) return;
    _initStarted = true;
    if (kReleaseMode && AdConfig.usingTestUnits) {
      debugPrint(
        'AdService: release build is using TEST ad units. '
        'Pass --dart-define-from-file=config/ads.json.',
      );
    }
    await _gatherConsent();
    if (!await _canRequestAds()) return;
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('AdService: SDK init failed ($e)');
      return;
    }
    if (_disposed) return;
    _ready = true;
    unawaited(_load());
  }

  /// Google UMP (GDPR/EEA, UK, Switzerland, US state privacy laws). Ads may
  /// only be requested once the SDK reports consent is in place.
  Future<void> _gatherConsent() async {
    final updated = Completer<bool>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!updated.isCompleted) updated.complete(true);
        },
        (FormError error) {
          debugPrint('Consent: info update failed (${error.message})');
          if (!updated.isCompleted) updated.complete(false);
        },
      );
    } catch (e) {
      debugPrint('Consent: request threw ($e)');
      return;
    }
    final ok = await updated.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );
    if (!ok) return;
    try {
      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) debugPrint('Consent: form error (${error.message})');
      });
    } catch (e) {
      debugPrint('Consent: form threw ($e)');
    }
  }

  Future<bool> _canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  /// Whether Settings should offer a "Privacy options" entry (UMP requires it
  /// in regulated regions so the user can change their choice).
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptionsForm() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) debugPrint('Consent: privacy form error (${error.message})');
      });
    } catch (e) {
      debugPrint('Consent: privacy form threw ($e)');
    }
  }

  Future<void> _load() async {
    if (!_ready || _disposed || _loading || _ad != null) return;
    _loading = true;
    _pendingLoad ??= Completer<void>();
    try {
      await InterstitialAd.load(
        adUnitId: AdConfig.interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loading = false;
            _retry = _minRetry;
            if (_disposed) {
              ad.dispose();
              return;
            }
            _ad = ad;
            _completeLoad();
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdService: load failed (${error.code} ${error.message})');
            _loading = false;
            _completeLoad();
            _scheduleRetry();
          },
        ),
      );
    } catch (e) {
      debugPrint('AdService: load threw ($e)');
      _loading = false;
      _completeLoad();
      _scheduleRetry();
    }
  }

  void _completeLoad() {
    final pending = _pendingLoad;
    _pendingLoad = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  void _scheduleRetry() {
    if (_disposed || !_ready) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retry, () {
      _retry = _retry * 2 > _maxRetry ? _maxRetry : _retry * 2;
      unawaited(_load());
    });
  }

  /// Shows an interstitial if one is ready, waiting at most [loadWait] for a
  /// load already in flight. Returns when the ad is dismissed, or right away
  /// when there is nothing to show.
  Future<void> showInterstitial() async {
    if (!_platformSupported || _disposed || _showing) return;
    if (!_ready) {
      // Init may still be running on a cold start; don't hold the player up.
      return;
    }
    if (_ad == null) {
      final pending = _pendingLoad;
      if (pending == null) {
        unawaited(_load());
        await (_pendingLoad?.future ?? Future<void>.value()).timeout(
          loadWait,
          onTimeout: () {},
        );
      } else {
        await pending.future.timeout(loadWait, onTimeout: () {});
      }
    }
    final ad = _ad;
    if (ad == null || _disposed) return;
    _ad = null;
    final closed = Completer<void>();
    void finish() {
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        ad.dispose();
        finish();
        unawaited(_load());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdService: show failed (${error.message})');
        _showing = false;
        ad.dispose();
        finish();
        unawaited(_load());
      },
    );
    _showing = true;
    try {
      await ad.show();
    } catch (e) {
      debugPrint('AdService: show threw ($e)');
      _showing = false;
      finish();
    }
    // Safety net: never block the result screen if a callback goes missing.
    await closed.future.timeout(const Duration(seconds: 30), onTimeout: () {});
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _ad?.dispose();
    _ad = null;
  }
}
