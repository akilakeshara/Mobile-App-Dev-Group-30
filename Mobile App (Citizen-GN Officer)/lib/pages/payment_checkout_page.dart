import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/gradient_page_app_bar.dart';
import '../localization/app_localizations.dart';

class PaymentCheckoutPage extends StatefulWidget {
  final String serviceName;
  final double amount;
  final String applicationId;
  final Map<String, dynamic>? pendingApplicationData;

  const PaymentCheckoutPage({
    super.key,
    required this.serviceName,
    required this.amount,
    required this.applicationId,
    this.pendingApplicationData,
  });

  @override
  State<PaymentCheckoutPage> createState() => _PaymentCheckoutPageState();
}

class _PaymentCheckoutPageState extends State<PaymentCheckoutPage> {
  bool _isLoading = false;
  String _selectedMethod = 'card'; // 'card' or 'wallet'

  Future<Map<String, String>> _buildPaymentUserInfo() async {
    final fallbackName = 'Citizen User';
    final fallback = <String, String>{
      'firstName': 'Citizen',
      'lastName': 'User',
      'email': 'no-email@govease.app',
      'phone': '0770000000',
      'address': 'No 1, Main Street',
      'city': 'Colombo',
    };

    final uid = authService.currentUid;
    if (uid == null) return fallback;

    final profile = await authService.getUserById(uid);
    final fullName = (profile?.name.trim().isNotEmpty == true)
        ? profile!.name.trim()
        : fallbackName;

    final parts = fullName.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : 'Citizen';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : 'User';

    return <String, String>{
      'firstName': firstName,
      'lastName': lastName,
      'email': FirebaseAuth.instance.currentUser?.email ?? fallback['email']!,
      'phone': (profile?.phone.isNotEmpty == true)
          ? profile!.phone
          : fallback['phone']!,
      'address': fallback['address']!,
      'city': fallback['city']!,
    };
  }

  void _processPayment() async {
    setState(() => _isLoading = true);

    final userInfo = await _buildPaymentUserInfo();

    if (!mounted) return;

    await paymentService.startPayment(
      context: context,
      orderId: widget.applicationId,
      amount: widget.amount,
      itemName: "GovEase Fee: ${widget.serviceName}",
      userInfo: userInfo,
      onSuccess: (id) async {
        try {
          await firestoreService.recordPaymentSuccess(
            applicationId: widget.applicationId,
            paymentId: id,
            amount: widget.amount,
            serviceName: widget.serviceName,
            pendingApplicationData: widget.pendingApplicationData,
          );
          if (mounted) {
            setState(() => _isLoading = false);
            _showSuccessDialog(id);
          }
        } catch (e) {
          debugPrint('CRITICAL: Failed to persist payment success: $e');
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Critical Error: Payment was successful but application data could not be saved. Please contact support with ID: $id',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 10),
              ),
            );
          }
        }
      },
      onDismissed: (msg) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('paymentCancelled'))));
      },
      onError: (err) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('paymentError')}: $err')),
        );
      },
    );
  }

  void _showSuccessDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ZoomIn(
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 72,
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('paymentSuccessful'),
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${context.tr('paymentSuccessMessagePrefix')} ${widget.serviceName}. ${context.tr('transactionId')}: $paymentId',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/'); // Back to home
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.tr('goToHome'),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: context.tr('checkout'),
        subtitle: context.tr('securePaymentViaPayHere'),
        onBack: () => context.pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!paymentService.isConfigured) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withAlpha(90)),
                ),
                child: Text(
                  '${context.tr('paymentSetupMissing')}: ${paymentService.missingConfigKeys.join(', ')}. '
                  'Run the app with the PayHere dart-defines for MERCHANT_ID, MERCHANT_SECRET and NOTIFY_URL.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            FadeInDown(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Amount',
                      style: GoogleFonts.inter(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs. ${widget.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildDetailRow('Service', widget.serviceName),
                    _buildDetailRow('Application ID', widget.applicationId),
                    _buildDetailRow('Payment Vendor', 'PayHere LKR'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  _buildPaymentMethodTile(
                    Icons.credit_card_rounded,
                    'Visa / Master',
                    'Secure Card Payment',
                    'card',
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentMethodTile(
                    Icons.account_balance_wallet_rounded,
                    'Mobile Wallets',
                    'HelaPay, Genie, eZ Cash',
                    'wallet',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: ElevatedButton(
                onPressed: _isLoading || !paymentService.isConfigured
                    ? null
                    : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                  shadowColor: AppColors.primary.withAlpha(100),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Pay Now',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.mutedForeground,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile(
    IconData icon,
    String title,
    String sub,
    String value,
  ) {
    final isSelected = _selectedMethod == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withAlpha(150),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.inter(
                      color: AppColors.mutedForeground,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              FadeIn(
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
