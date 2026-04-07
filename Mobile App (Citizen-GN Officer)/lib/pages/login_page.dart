import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/otp_service.dart';
import '../services/firestore_service.dart';
import '../services/language_service.dart';
import '../models/user_model.dart';
import '../utils/input_validators.dart';
import '../localization/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  String _role = 'citizen';
  String _citizenStep = 'nic';
  bool _officerOtpSent = false;

  bool _isSubmitting = false;

  final _nicController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _officerIdController = TextEditingController();
  final _officerOtpController = TextEditingController();
  String? _pendingOfficerPhone;

  late AnimationController _bgController;
  late Animation<Alignment> _topAlignment;
  late Animation<Alignment> _bottomAlignment;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _topAlignment = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
    _bottomAlignment = Tween<Alignment>(
      begin: Alignment.bottomRight,
      end: Alignment.bottomLeft,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _nicController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _officerIdController.dispose();
    _officerOtpController.dispose();
    super.dispose();
  }

  void _handleSendOtp() async {
    final nic = _nicController.text.trim().toUpperCase();
    final phoneRaw = _phoneController.text.trim();

    if (nic.isNotEmpty && phoneRaw.isNotEmpty) {
      if (!InputValidators.isValidNic(nic)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('invalidNic'))));
        return;
      }

      if (!InputValidators.isValidSriLankanPhone(phoneRaw)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('invalidPhone'))));
        return;
      }

      final isIdentityValid = await _validateCitizenIdentity();
      if (!isIdentityValid) {
        return;
      }

      final phoneInput = InputValidators.toE164SriLankanPhone(phoneRaw);

      if (_isSubmitting) return;
      setState(() => _isSubmitting = true);

      try {
        final success = await otpService.sendOtp(phoneInput);

        if (mounted) {
          if (success) {
            setState(() {
              _isSubmitting = false;
              _citizenStep = 'otp';
            });
          } else {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('failedToSendOtp'))),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${context.tr('error')}: $e')));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pleaseFillAllFields'))),
      );
    }
  }

  void _handleVerify() async {
    debugPrint(
      'Verify button pressed. OTP length: ${_otpController.text.length}',
    );
    if (_otpController.text.length >= 6) {
      final nic = _nicController.text.trim().toUpperCase();
      final phoneRaw = _phoneController.text.trim();

      if (!InputValidators.isValidNic(nic)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('invalidNic'))));
        return;
      }

      if (!InputValidators.isValidSriLankanPhone(phoneRaw)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('invalidPhone'))));
        return;
      }

      final isIdentityValid = await _validateCitizenIdentity();
      if (!isIdentityValid) {
        return;
      }

      final phoneInput = InputValidators.toE164SriLankanPhone(phoneRaw);

      if (_isSubmitting) {
        debugPrint('Already submitting, ignoring click.');
        return;
      }
      setState(() => _isSubmitting = true);
      debugPrint('Verifying OTP for $phoneInput...');

      try {
        final token = await otpService.verifyOtp(
          phoneInput,
          _otpController.text,
        );
        debugPrint(
          'verifyOtp result: token=${token != null ? "RECEIVED" : "NULL"}',
        );

        if (token != null) {
          debugPrint('Attempting Firebase Sign In with Custom Token...');
          final userCredential = await FirebaseAuth.instance
              .signInWithCustomToken(token);
          debugPrint('Sign-in successful!');

          if (userCredential.user != null) {
            final user = userCredential.user!;
            final existingUser = await firestoreService.getUser(user.uid);

            // Only create user record if this is their first login
            if (existingUser == null) {
              final newUser = UserModel(
                id: user.uid,
                name: _nicController.text.trim(), // Use NIC as placeholder
                nic: _nicController.text.trim().toUpperCase(),
                phone:
                    user.phoneNumber ??
                    InputValidators.toE164SriLankanPhone(
                      _phoneController.text.trim(),
                    ),
                role: 'citizen',
                preferredLanguage: languageService.currentLanguageCode,
                createdAt: DateTime.now(),
              );
              await firestoreService.createUser(newUser);
              await languageService.setLanguage(
                newUser.preferredLanguage,
                syncRemote: false,
              );
              debugPrint('User data saved to database');
            } else {
              await languageService.setLanguage(
                existingUser.preferredLanguage,
                syncRemote: false,
              );
              debugPrint('User already exists in database');
            }
          }

          if (mounted) {
            debugPrint('Navigating to Home...');
            context.go('/');
          }
        } else {
          // Token is null, usually means server-side error caught by our catch block
          debugPrint('Verification failed: Token was null');
          if (mounted) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('verificationFailedMessage')),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } on FirebaseFunctionsException catch (e) {
        debugPrint('FirebaseFunctionsException in UI: ${e.message}');
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${context.tr('serverError')}: ${e.message}'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      } catch (e) {
        debugPrint('Unexpected exception in UI: $e');
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${context.tr('error')}: $e')));
        }
      }
    } else {
      debugPrint('OTP length is 0. Not calling verify.');
    }
  }

  Future<void> _handleOfficerSignIn() async {
    final officerId = InputValidators.normalizeOfficerId(
      _officerIdController.text,
    );
    if (officerId.isEmpty) {
      return;
    }

    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final officer = await firestoreService.lookupOfficerIdentity(officerId);
      if (officer == null) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Officer ID not found.')),
          );
        }
        return;
      }

      final officerLocalPhone = InputValidators.normalizePhoneToLocal(
        officer.phone,
      );
      final officerE164Phone = InputValidators.toE164SriLankanPhone(
        officer.phone,
      );

      if (!_officerOtpSent) {
        if (officerLocalPhone.isEmpty ||
            !InputValidators.isValidSriLankanPhone(officerLocalPhone)) {
          if (mounted) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Officer phone is not configured for OTP verification.',
                ),
              ),
            );
          }
          return;
        }

        final sent = await otpService.sendOtp(officerE164Phone);
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _officerOtpSent = sent;
            _pendingOfficerPhone = officerE164Phone;
          });
          if (!sent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('failedToSendOtp'))),
            );
          }
        }
        return;
      }

      if (_officerOtpController.text.length < 6) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.tr('invalidOtp'))));
        }
        return;
      }

      final phoneForOtp = _pendingOfficerPhone ?? officerE164Phone;
      if (phoneForOtp.isEmpty) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to verify officer OTP.')),
          );
        }
        return;
      }

      final token = await otpService.verifyOtp(
        phoneForOtp,
        _officerOtpController.text,
      );
      if (token == null) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.tr('invalidOtp'))));
        }
        return;
      }

      final credential = await FirebaseAuth.instance.signInWithCustomToken(
        token,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Officer verification failed.')),
          );
        }
        return;
      }

      final signedInOfficer = await firestoreService.getOfficerByUid(uid);
      if (signedInOfficer == null ||
          (signedInOfficer.role.toLowerCase() != 'officer' &&
              signedInOfficer.role.toLowerCase() != 'admin')) {
        final citizenForUid = await firestoreService.getCitizenByUid(uid);
        if (citizenForUid != null) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This phone number is linked to a citizen account. Use a dedicated officer phone number.',
                ),
              ),
            );
          }
          return;
        }

        final syncedOfficer = UserModel(
          id: uid,
          name: officer.name,
          nic: officer.nic,
          phone: officer.phone,
          role: officer.role,
          division: officer.division,
          province: officer.province,
          district: officer.district,
          pradeshiyaSabha: officer.pradeshiyaSabha,
          gramasewaWasama: officer.gramasewaWasama,
          preferredLanguage: officer.preferredLanguage,
          profileImageUrl: officer.profileImageUrl,
          createdAt: signedInOfficer?.createdAt ?? DateTime.now(),
        );
        await firestoreService.createUser(syncedOfficer);
        await firestoreService.updateUserPreferredLanguage(
          uid,
          syncedOfficer.preferredLanguage,
        );
        await firestoreService.updateUserProfilePhoto(
          uid,
          syncedOfficer.profileImageUrl,
        );

        await firestoreService.mergeOfficerFields(uid, {
          'officerId': officerId,
          'officerIdNormalized': InputValidators.normalizeOfficerId(officerId),
          'phoneNormalized': InputValidators.normalizePhoneToLocal(
            officer.phone,
          ),
        });

        // CRITICAL BUG FIX: Cleanup the temporary pre-registration document
        // created by the Admin Panel to prevent duplicate entries in the system.
        if (officer.id != uid) {
          await firestoreService.deleteUser(officer.id, 'officer');
          debugPrint('Cleaned up temporary pre-registration document: ${officer.id}');
        }
      }

      final refreshedOfficer = await firestoreService.getOfficerByUid(uid);
      final role = refreshedOfficer?.role.toLowerCase();
      if (role != 'officer' && role != 'admin') {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access denied for this account.')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _pendingOfficerPhone = null;
          _officerOtpSent = false;
        });
        context.go('/officer');
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('serverError')}: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.tr('error')}: $e')));
      }
    }
  }

  void _switchRole(String role) {
    if (_role == role) return;
    setState(() {
      _role = role;
      _citizenStep = 'nic';
      _officerOtpSent = false;
      _pendingOfficerPhone = null;
      _otpController.clear();
      _officerOtpController.clear();
    });
  }

  Future<bool> _validateCitizenIdentity() async {
    final nic = _nicController.text.trim().toUpperCase();
    final enteredLocalPhone = InputValidators.normalizePhoneToLocal(
      _phoneController.text.trim(),
    );

    final lookup = await firestoreService.lookupCitizenIdentity(
      nic: nic,
      phone: enteredLocalPhone,
    );
    if (lookup == null || lookup['found'] != true) {
      final reason = (lookup?['reason'] ?? '').toString();
      if (mounted) {
        final key = reason == 'phone_mismatch'
            ? 'nicPhoneMismatch'
            : 'nicNotFound';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr(key))));
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withAlpha(30),
                    AppColors.secondary.withAlpha(20),
                    AppColors.background,
                  ],
                  begin: _topAlignment.value,
                  end: _bottomAlignment.value,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FadeIn(
                    duration: const Duration(milliseconds: 600),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.go('/welcome'),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(200),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(45),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Image.asset(
                        'assets/images/GovEaseLoGo.png',
                        fit: BoxFit.contain,
                        height: 80,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      context.tr('signInToGovEase'),
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      context.tr('chooseAccessTypeSubtitle'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(200),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: ['citizen', 'officer'].map((role) {
                          final isActive = _role == role;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _switchRole(role),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.all(4),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      role == 'citizen'
                                          ? Icons.person_outline_rounded
                                          : Icons.shield_outlined,
                                      size: 18,
                                      color: isActive
                                          ? Colors.white
                                          : AppColors.mutedForeground,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      role == 'citizen'
                                          ? context.tr('citizen')
                                          : context.tr('officer'),
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: isActive
                                            ? Colors.white
                                            : AppColors.mutedForeground,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(209),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withAlpha(153),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _role == 'citizen'
                            ? (_citizenStep == 'nic'
                                  ? _buildCitizenNicForm()
                                  : _buildCitizenOtpForm())
                            : _buildOfficerForm(),
                      ),
                    ),
                  ),
                  if (_role == 'citizen') ...[
                    const SizedBox(height: 24),
                    FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 500),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr('dontHaveAccount'),
                            style: GoogleFonts.inter(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/signup'),
                            child: Text(
                              context.tr('signUp'),
                              style: GoogleFonts.inter(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitizenNicForm() {
    return Column(
      key: const ValueKey('nic_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context.tr('nicNumber')),
        const SizedBox(height: 8),
        _buildTextField(
          _nicController,
          context.tr('nicExampleLong'),
          icon: Icons.badge_outlined,
          inputFormatters: [...InputValidators.nicFormatters()],
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('nicFormatHint'),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel(context.tr('phoneNumber')),
        const SizedBox(height: 8),
        _buildTextField(
          _phoneController,
          context.tr('phoneExample'),
          icon: Icons.phone_android_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [...InputValidators.sriLankanPhoneFormatters()],
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('phoneFormatHint'),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          context.tr('sendOtp'),
          _handleSendOtp,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }

  Widget _buildCitizenOtpForm() {
    return Column(
      key: const ValueKey('otp_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.secondary.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.secondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${context.tr('codeSentTo')} ...${_phoneController.text.length > 4 ? _phoneController.text.substring(_phoneController.text.length - 4) : _phoneController.text}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildLabel(context.tr('enterOtp')),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [...InputValidators.otpFormatters()],
          textAlign: TextAlign.center,
          onChanged: (val) {
            if (val.length == 6) {
              _handleVerify();
            }
          },
          style: GoogleFonts.outfit(
            fontSize: 32,
            letterSpacing: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
            hintText: context.tr('otpPlaceholder'),
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          context.tr('verifyAndSignIn'),
          _handleVerify,
          icon: Icons.verified_rounded,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _citizenStep = 'nic'),
            child: Text(
              context.tr('changeNumber'),
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfficerForm() {
    return Column(
      key: const ValueKey('officer_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context.tr('officerId')),
        const SizedBox(height: 8),
        _buildTextField(
          _officerIdController,
          context.tr('officerIdExample'),
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 16),
        if (!_officerOtpSent)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              context.tr('tapSignInSendOfficerOtp'),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          )
        else
          TextField(
            controller: _officerOtpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [...InputValidators.otpFormatters()],
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 28,
              letterSpacing: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              hintText: context.tr('otpDigitsPlaceholder'),
              counterText: '',
            ),
          ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          !_officerOtpSent
              ? context.tr('sendOtpAndContinue')
              : context.tr('signInAsOfficer'),
          _handleOfficerSignIn,
          icon: Icons.login_rounded,
        ),
        if (_officerOtpSent) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _officerOtpSent = false;
                _officerOtpController.clear();
              }),
              child: Text(
                'Change ID / Resend OTP',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Center(
          child: Text(
            context.tr('authorizedOfficersNotice'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.foreground,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      onChanged:
          (controller == _nicController || controller == _officerIdController)
          ? (value) {
              final upper = value.toUpperCase();
              if (upper != value) {
                controller.value = controller.value.copyWith(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                  composing: TextRange.empty,
                );
              }
            }
          : null,
      style: GoogleFonts.inter(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      ),
    );
  }

  Widget _buildPrimaryButton(
    String label,
    VoidCallback onPressed, {
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(76),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isSubmitting ? null : onPressed,
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}
