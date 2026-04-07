import 'package:flutter/services.dart';

class InputValidators {
  static final RegExp _oldNicRegex = RegExp(r'^\d{9}[VX]$');
  static final RegExp _newNicRegex = RegExp(r'^\d{12}$');
  static final RegExp _localSriLankanPhoneRegex = RegExp(r'^0\d{9}$');

  static String normalizeNic(String rawNic) {
    return rawNic.trim().toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
  }

  static String normalizeOfficerId(String rawOfficerId) {
    return rawOfficerId.trim().toUpperCase();
  }

  static String normalizePhoneToLocal(String rawPhone) {
    final digitsOnly = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (digitsOnly.startsWith('+94')) {
      final rest = digitsOnly.substring(3);
      return rest.isEmpty ? '' : '0$rest';
    }

    if (digitsOnly.startsWith('94')) {
      final rest = digitsOnly.substring(2);
      return rest.isEmpty ? '' : '0$rest';
    }

    return digitsOnly;
  }

  static String toE164SriLankanPhone(String rawPhone) {
    final local = normalizePhoneToLocal(rawPhone);
    if (local.startsWith('0') && local.length == 10) {
      return '+94${local.substring(1)}';
    }
    if (local.startsWith('7') && local.length == 9) {
      return '+94$local';
    }
    return rawPhone.trim();
  }

  static bool isValidSriLankanPhone(String rawPhone) {
    final local = normalizePhoneToLocal(rawPhone);
    return _localSriLankanPhoneRegex.hasMatch(local);
  }

  static bool isValidNic(String nicRaw) {
    final nic = normalizeNic(nicRaw);
    return _oldNicRegex.hasMatch(nic) || _newNicRegex.hasMatch(nic);
  }

  static List<TextInputFormatter> nicFormatters() {
    return <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9vVxX]')),
      LengthLimitingTextInputFormatter(12),
    ];
  }

  static List<TextInputFormatter> sriLankanPhoneFormatters() {
    return <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(10),
    ];
  }

  static List<TextInputFormatter> otpFormatters() {
    return <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ];
  }
}
