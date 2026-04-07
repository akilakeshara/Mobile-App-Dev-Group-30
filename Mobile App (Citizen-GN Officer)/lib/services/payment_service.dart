import 'package:flutter/material.dart';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentService {
  static String get _rawMerchantId => dotenv.env['PAYHERE_MERCHANT_ID'] ?? const String.fromEnvironment(
    'PAYHERE_MERCHANT_ID',
    defaultValue: '',
  );
  static String get _rawMerchantSecret => dotenv.env['PAYHERE_MERCHANT_SECRET'] ?? const String.fromEnvironment(
    'PAYHERE_MERCHANT_SECRET',
    defaultValue: '',
  );
  static String get _rawNotifyUrl => dotenv.env['PAYHERE_NOTIFY_URL'] ?? const String.fromEnvironment(
    'PAYHERE_NOTIFY_URL',
  );
  static String get _rawDomain => dotenv.env['PAYHERE_DOMAIN'] ?? const String.fromEnvironment(
    'PAYHERE_DOMAIN',
    defaultValue: 'com.govease',
  );
  static String get _rawAppPackage => dotenv.env['PAYHERE_APP_PACKAGE'] ?? const String.fromEnvironment(
    'PAYHERE_APP_PACKAGE',
    defaultValue: 'com.govease',
  );
  static String get _rawSandbox => dotenv.env['PAYHERE_SANDBOX'] ?? const String.fromEnvironment(
    'PAYHERE_SANDBOX',
    defaultValue: 'false',
  );

  String get _merchantId =>
      _resolveValue(raw: _rawMerchantId, fallback: '');

  String get _merchantSecret => _resolveValue(
    raw: _rawMerchantSecret,
    fallback: '',
  );

  String get _notifyUrl => _resolveValue(
    raw: _rawNotifyUrl,
    fallback:
        'https://unsmirking-kori-potbellied.ngrok-free.dev/payhere-notify',
  );

  String get _domain => _resolveValue(raw: _rawDomain, fallback: 'com.govease');

  String get _appPackage =>
      _resolveValue(raw: _rawAppPackage, fallback: 'com.govease');

  bool get _sandbox {
    final raw = _rawSandbox.trim().toLowerCase();
    if (raw.isEmpty || _isPlaceholder(raw)) return false;
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  String _resolveValue({required String raw, required String fallback}) {
    final trimmed = raw.trim();
    if (_isPlaceholder(trimmed)) return fallback;
    return trimmed;
  }

  bool _isPlaceholder(String value) {
    if (value.isEmpty) return true;
    final upper = value.toUpperCase();
    return upper.contains('YOUR_') ||
        upper.contains('YOUR-') ||
        upper.contains('YOUR.') ||
        upper.contains('YOURDOMAIN') ||
        upper.contains('YOUR-DOMAIN') ||
        upper.contains('EXAMPLE.COM') ||
        upper.contains('PLACEHOLDER') ||
        upper == 'CHANGE_ME';
  }

  bool get isConfigured =>
      _merchantId.isNotEmpty &&
      _merchantSecret.isNotEmpty &&
      _notifyUrl.isNotEmpty;

  bool get isSandbox => _sandbox;


  List<String> get missingConfigKeys {
    final missing = <String>[];
    if (_merchantId.isEmpty) missing.add('PAYHERE_MERCHANT_ID');
    if (_merchantSecret.isEmpty) missing.add('PAYHERE_MERCHANT_SECRET');
    if (_notifyUrl.isEmpty) missing.add('PAYHERE_NOTIFY_URL');
    return missing;
  }

  /// Payment එකක් ආරම්භ කරන ප්‍රධාන function එක
  Future<void> startPayment({
    required BuildContext context,
    required String orderId,
    required double amount,
    required String itemName,
    required Map<String, String> userInfo, // name, email, phone, address, city
    required Function(String) onSuccess,
    required Function(String) onDismissed,
    required Function(String) onError,
  }) async {
    if (!isConfigured) {
      onError('Payment configuration missing: ${missingConfigKeys.join(', ')}');
      return;
    }

    /*
    if (_sandbox && _isKnownLiveMerchant) {
      onError(
        'Invalid PayHere mode: sandbox=true with live merchant $_merchantId. Use --dart-define=PAYHERE_SANDBOX=false',
      );
      return;
    }
    */

    final Map<String, dynamic> paymentObject = {
      "sandbox": _sandbox,
      "merchant_id": _merchantId,
      "domain": _domain,
      "notify_url": _notifyUrl,
      "order_id": orderId,
      "items": itemName,
      "amount": amount.toStringAsFixed(2),
      "currency": "LKR",
      "first_name": userInfo['firstName'] ?? "Citizen",
      "last_name": userInfo['lastName'] ?? "User",
      "email": userInfo['email'] ?? "test@example.com",
      "phone": userInfo['phone'] ?? "0771234567",
      "address": userInfo['address'] ?? "No 1, Main Street",
      "city": userInfo['city'] ?? "Colombo",
      "country": "Sri Lanka",
      "delivery_address": userInfo['address'] ?? "No 1, Main Street",
      "delivery_city": userInfo['city'] ?? "Colombo",
      "delivery_country": "Sri Lanka",
      "custom_1": _appPackage,
      "custom_2": _domain,
    };

    final notifyHost = Uri.tryParse(_notifyUrl)?.host ?? _notifyUrl;
    debugPrint(
      'PayHere init => sandbox=$_sandbox, merchant_id=$_merchantId, domain=$_domain, appPackage=$_appPackage, notifyHost=$notifyHost',
    );

    PayHere.startPayment(
      paymentObject,
      (paymentId) {
        debugPrint("Payment Success! ID: $paymentId");
        onSuccess(paymentId);
      },
      (error) {
        debugPrint("Payment Error: $error");
        final err = error.toString();
        if (err.toLowerCase().contains('merchant id')) {
          onError(
            '$err. Check PayHere mode: currently sandbox=$_sandbox. If your merchant is LIVE, run with --dart-define=PAYHERE_SANDBOX=false',
          );
          return;
        }
        if (err.toLowerCase().contains('unauthorized domain')) {
          onError(
            '$err. Whitelist these in PayHere dashboard: app package=$_appPackage, domain=$_domain, notify host=$notifyHost',
          );
          return;
        }
        onError(err);
      },
      () {
        debugPrint("Payment Dismissed by user");
        onDismissed("Closed");
      },
    );
  }
}

final paymentService = PaymentService();
