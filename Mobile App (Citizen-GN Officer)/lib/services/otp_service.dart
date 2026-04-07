import 'package:cloud_functions/cloud_functions.dart';
import '../utils/logger.dart';

class OtpService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Cloud Function එක call කරලා OTP එකක් phone number එකට යවනවා
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('sendOTP');
      final result = await callable.call({
        'phoneNumber': phoneNumber,
      });

      if (result.data != null && result.data['success'] == true) {
        appLogger.i('OTP sent successfully to $phoneNumber');
        return true;
      }
      return false;
    } on FirebaseFunctionsException catch (e) {
      appLogger.e('FirebaseFunctionsException [${e.code}]: ${e.message}', error: e);
      return false;
    } catch (e) {
      appLogger.e('Unexpected error calling sendOTP function', error: e);
      return false;
    }
  }

  /// User ඇතුල් කරපු OTP එක verify කරනවා
  /// Returns Custom Token string if successful, null otherwise
  Future<String?> verifyOtp(String phoneNumber, String code) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('verifyOTP');
      final result = await callable.call({
        'phoneNumber': phoneNumber,
        'code': code.trim(),
      });

      if (result.data != null && result.data['success'] == true) {
        appLogger.i('OTP verified successfully for $phoneNumber');
        return result.data['token'] as String?;
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      appLogger.e('FirebaseFunctionsException [${e.code}]: ${e.message}', error: e);
      return null;
    } catch (e) {
      appLogger.e('Unexpected error calling verifyOTP function', error: e);
      return null;
    }
  }
}

final otpService = OtpService();
