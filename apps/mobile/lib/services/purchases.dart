// Buying «وحدات» and «نجوم» with real money through the phone's store (Google Play / App Store). The store takes
// the payment; the proof goes to the server (POST /purchases), which checks it with the store itself and credits
// the wallet once. Only then is the purchase finished here, so a purchase interrupted by a lost connection is
// sent again on the next launch (the store keeps reporting it until it is finished).
//
// Before going live, every product id in Store.unitPacks / Store.starPacks must exist as a consumable product
// in the Play Console and App Store Connect, and the server needs the store keys (apps/server/src/payments.ts).
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'account.dart';
import 'api.dart';
import 'error_text.dart';
import 'store.dart';

class Purchases extends ChangeNotifier {
  Purchases._();
  static final instance = Purchases._();

  bool available = false;
  bool loading = false;

  /// Local prices from the store, by product id.
  final Map<String, ProductDetails> products = {};

  /// The product being bought (its button shows a spinner).
  String? busy;

  /// Shown to the player: a result or a problem (the screen clears it once read).
  String? message;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _started = false;

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS) && !Platform.environment.containsKey('FLUTTER_TEST');

  /// Connects to the store once (the listener also picks up purchases left unfinished last time).
  Future<void> start() async {
    if (_started || !_supported) return;
    _started = true;
    final iap = InAppPurchase.instance;
    _sub = iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    try {
      available = await iap.isAvailable();
      if (!available) return notifyListeners();
      loading = true;
      notifyListeners();
      final r = await iap.queryProductDetails({for (final p in Store.allPacks) p.id});
      for (final p in r.productDetails) {
        products[p.id] = p;
      }
    } catch (_) {
      available = false;
    }
    loading = false;
    notifyListeners();
  }

  /// The price to show: the store's (in the player's currency) or the placeholder.
  String priceOf(CoinPack p) => products[p.id]?.price ?? p.price;

  /// What [p] would cost at full price when it is sold at [share] of it (in the store's currency when it has
  /// answered, else from [fallback]).
  String fullPriceOf(CoinPack p, double share, String fallback) {
    final d = products[p.id];
    if (d == null) return fallback;
    return '${d.currencySymbol}${(d.rawPrice / share).toStringAsFixed(2)}';
  }

  Future<void> buy(CoinPack pack) async {
    if (!_supported) {
      _say('الشراء متاح من تطبيق الهاتف فقط');
      return;
    }
    if (!_started) await start();
    final product = products[pack.id];
    if (!available || product == null) {
      _say('المتجر غير متاح الآن. تأكد من تسجيل دخولك في ${Platform.isIOS ? 'App Store' : 'Google Play'} وحاول لاحقاً');
      return;
    }
    busy = pack.id;
    notifyListeners();
    try {
      // the server consumes the purchase after crediting it (Android), so the app does not consume it itself
      await InAppPurchase.instance.buyConsumable(purchaseParam: PurchaseParam(productDetails: product), autoConsume: false);
    } catch (_) {
      busy = null;
      _say('تعذّر بدء عملية الشراء');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _say('عملية الشراء قيد المعالجة…');
        case PurchaseStatus.canceled:
          busy = null;
          notifyListeners();
          await _complete(p);
        case PurchaseStatus.error:
          busy = null;
          _say('لم تكتمل عملية الشراء');
          await _complete(p);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(p);
      }
    }
  }

  Future<void> _deliver(PurchaseDetails p) async {
    if (!Account.instance.signedIn) return; // delivered after sign-in: the store reports it again
    final android = Platform.isAndroid;
    final token = android ? p.verificationData.serverVerificationData : (p.purchaseID ?? '');
    try {
      final r = await Api.instance.post('/purchases', {'platform': android ? 'android' : 'ios', 'productId': p.productID, 'token': token}) as Map;
      Account.instance.apply(r['me']);
      final added = (r['added'] as num).toInt();
      if (added > 0) _say('تمت إضافة $added ${r['currency'] == 'stars' ? 'نجمة' : 'وحدة'} إلى محفظتك');
      await _complete(p);
    } on ApiError catch (e) {
      // a refusal that will not change: finish it so it does not come back for ever
      if (e.code == 'badPurchase' || e.code == 'purchaseUsed' || e.code == 'badProduct') {
        await _complete(p);
      }
      _say(errorText(e.code));
    }
    busy = null;
    notifyListeners();
  }

  Future<void> _complete(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await InAppPurchase.instance.completePurchase(p);
    } catch (_) {
      // already consumed by the server (Android): nothing left to finish
    }
  }

  void _say(String m) {
    message = m;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
