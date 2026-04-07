import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/otp_service.dart';
import '../services/language_service.dart';
import '../utils/input_validators.dart';
import '../localization/app_localizations.dart';
import 'dart:async';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final _nameController = TextEditingController();
  final _nicController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _manualPradeshiyaSabhaController = TextEditingController();
  final _manualGramasewaWasamaController = TextEditingController();

  bool _isSubmitting = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  String _selectedLanguage = 'en';
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedPradeshiyaSabha;
  String? _selectedGramasewaWasama;
  bool _isLoadingAdministrativeAreas = true;

  static const Map<String, Map<String, Map<String, List<String>>>>
  _defaultAdminHierarchy = {
    'Western': {
      'Colombo': {
        'Kolonnawa PS': ['Wellampitiya', 'Meethotamulla', 'Sedawatta'],
        'Homagama PS': ['Homagama', 'Pitipana', 'Godagama'],
      },
      'Gampaha': {
        'Ja-Ela PS': ['Ja-Ela South', 'Ekala', 'Kandana'],
        'Divulapitiya PS': ['Divulapitiya', 'Badalgama', 'Minsingama'],
      },
      'Kalutara': {
        'Bandaragama PS': ['Bandaragama', 'Waskaduwa', 'Raigama'],
        'Millaniya PS': ['Millaniya', 'Yatadolawatta', 'Halwatura'],
      },
    },
    'Central': {
      'Kandy': {
        'Akurana PS': ['Akurana', 'Bahirawakanda', 'Dunuwila'],
        'Pathadumbara PS': ['Katugastota', 'Poojapitiya', 'Wattegama'],
      },
      'Matale': {
        'Dambulla PS': ['Dambulla', 'Kandalama', 'Ibbankatuwa'],
        'Galewela PS': ['Galewela', 'Bambaragaswewa', 'Kalundewa'],
      },
      'Nuwara Eliya': {
        'Nuwara Eliya PS': ['Nuwara Eliya', 'Hawa Eliya', 'Blackpool'],
        'Ambagamuwa PS': ['Ginigathhena', 'Nallathanniya', 'Watawala'],
      },
    },
    'Southern': {
      'Galle': {
        'Bope Poddala PS': ['Poddala', 'Labuduwa', 'Yakkalamulla'],
        'Habaraduwa PS': ['Habaraduwa', 'Ahangama', 'Koggala'],
      },
      'Matara': {
        'Weligama PS': ['Weligama', 'Pelena', 'Denipitiya'],
        'Akuressa PS': ['Akuressa', 'Aparekka', 'Kamburupitiya'],
      },
      'Hambantota': {
        'Tissamaharama PS': ['Tissamaharama', 'Debarawewa', 'Yodakandiya'],
        'Tangalle PS': ['Tangalle', 'Kudawella', 'Netolpitiya'],
      },
    },
    'Northern': {
      'Jaffna': {
        'Nallur PS': ['Nallur', 'Kokuvil East', 'Kokuvil West'],
        'Chavakachcheri PS': ['Chavakachcheri', 'Kodikamam', 'Kachchai'],
      },
      'Kilinochchi': {
        'Karachchi PS': ['Kilinochchi', 'Kanakapuram', 'Paranthan'],
      },
      'Mannar': {
        'Mannar PS': ['Mannar Town', 'Pesalai', 'Thoddaveli'],
      },
      'Mullaitivu': {
        'Maritimepattu PS': ['Mullaitivu', 'Puthukudiyiruppu', 'Oddusuddan'],
      },
      'Vavuniya': {
        'Vavuniya PS': ['Vavuniya', 'Nedunkeni', 'Cheddikulam'],
      },
    },
    'Eastern': {
      'Trincomalee': {
        'Kinniya PS': ['Kinniya', 'Periyathottam', 'Kurinchakerny'],
        'Morawewa PS': ['Morawewa', 'Gomarankadawala', 'Pulmoddai'],
      },
      'Batticaloa': {
        'Kattankudy PS': ['Kattankudy', 'Navatkuda', 'Eravur'],
        'Kaluwanchikudy PS': ['Kaluwanchikudy', 'Cheddipalayam', 'Vellaveli'],
      },
      'Ampara': {
        'Sainthamaruthu PS': ['Sainthamaruthu', 'Sammanthurai', 'Nintavur'],
        'Akkaraipattu PS': ['Akkaraipattu', 'Alayadivembu', 'Karaitivu'],
      },
    },
    'North Western': {
      'Kurunegala': {
        'Kuliyapitiya PS': ['Kuliyapitiya', 'Wariyapola', 'Narammala'],
        'Pannala PS': ['Pannala', 'Makandura', 'Wenwita'],
      },
      'Puttalam': {
        'Wennappuwa PS': ['Wennappuwa', 'Lunuwila', 'Waikkal'],
        'Anamaduwa PS': ['Anamaduwa', 'Mahauswewa', 'Pahala Puliyankulama'],
      },
    },
    'North Central': {
      'Anuradhapura': {
        'Nuwaragam Palatha Central PS': [
          'Anuradhapura Town',
          'Mihintale',
          'Nachchaduwa',
        ],
        'Kekirawa PS': ['Kekirawa', 'Maradankadawala', 'Madatugama'],
      },
      'Polonnaruwa': {
        'Thamankaduwa PS': ['Polonnaruwa', 'Kaduruwela', 'Hingurakgoda'],
      },
    },
    'Uva': {
      'Badulla': {
        'Badulla PS': ['Badulla', 'Haliela', 'Passara'],
        'Bandarawela PS': ['Bandarawela', 'Diyatalawa', 'Ella'],
      },
      'Monaragala': {
        'Monaragala PS': ['Monaragala', 'Buttala', 'Wellawaya'],
      },
    },
    'Sabaragamuwa': {
      'Ratnapura': {
        'Ratnapura PS': ['Ratnapura', 'Kuruwita', 'Eheliyagoda'],
        'Pelmadulla PS': ['Pelmadulla', 'Balangoda', 'Godakawela'],
      },
      'Kegalle': {
        'Kegalle PS': ['Kegalle', 'Mawanella', 'Rambukkana'],
        'Warakapola PS': ['Warakapola', 'Galigamuwa', 'Yatiyantota'],
      },
    },
  };

  late AnimationController _bgController;
  late Animation<Alignment> _topAlignment;
  late Animation<Alignment> _bottomAlignment;

  late Map<String, Map<String, Map<String, List<String>>>> _adminHierarchy;

  List<String> get _provinces {
    final list = _adminHierarchy.keys.toList();
    list.sort();
    return list;
  }

  List<String> get _districts {
    if (_selectedProvince == null) return const [];
    final list = _adminHierarchy[_selectedProvince!]!.keys.toList();
    list.sort();
    return list;
  }

  List<String> get _pradeshiyaSabhas {
    if (_selectedProvince == null || _selectedDistrict == null) return const [];
    final list = _adminHierarchy[_selectedProvince!]![_selectedDistrict!]!.keys
        .toList();
    list.sort();
    return list;
  }

  List<String> get _gramasewaWasamas {
    if (_selectedProvince == null ||
        _selectedDistrict == null ||
        _selectedPradeshiyaSabha == null) {
      return const [];
    }
    final list = List<String>.from(
      _adminHierarchy[_selectedProvince!]![_selectedDistrict!]![_selectedPradeshiyaSabha!]!,
    );
    list.sort();
    return list;
  }

  String get _resolvedPradeshiyaSabha {
    final manual = _manualPradeshiyaSabhaController.text.trim();
    return _selectedPradeshiyaSabha ?? manual;
  }

  String get _resolvedGramasewaWasama {
    final manual = _manualGramasewaWasamaController.text.trim();
    return _selectedGramasewaWasama ?? manual;
  }

  @override
  void initState() {
    super.initState();
    _adminHierarchy = _defaultAdminHierarchy;
    _selectedLanguage = languageService.currentLanguageCode;
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _topAlignment = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.linear));
    _bottomAlignment = Tween<Alignment>(
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.linear));
    _loadAdministrativeAreas();
  }

  Future<void> _loadAdministrativeAreas() async {
    try {
      final remoteConfig = await firestoreService
          .getAdministrativeHierarchyConfig();
      if (!mounted) return;

      setState(() {
        if (remoteConfig.isNotEmpty) {
          _adminHierarchy = remoteConfig;
        }
        _normalizeAdministrativeSelection();
        _isLoadingAdministrativeAreas = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adminHierarchy = _defaultAdminHierarchy;
        _normalizeAdministrativeSelection();
        _isLoadingAdministrativeAreas = false;
      });
    }
  }

  void _normalizeAdministrativeSelection() {
    if (_selectedProvince == null ||
        !_adminHierarchy.containsKey(_selectedProvince)) {
      _selectedProvince = null;
      _selectedDistrict = null;
      _selectedPradeshiyaSabha = null;
      _selectedGramasewaWasama = null;
      return;
    }

    final districtMap = _adminHierarchy[_selectedProvince!]!;
    if (_selectedDistrict == null ||
        !districtMap.containsKey(_selectedDistrict)) {
      _selectedDistrict = null;
      _selectedPradeshiyaSabha = null;
      _selectedGramasewaWasama = null;
      return;
    }

    final sabhaMap = districtMap[_selectedDistrict!]!;
    if (_selectedPradeshiyaSabha == null ||
        !sabhaMap.containsKey(_selectedPradeshiyaSabha)) {
      _selectedPradeshiyaSabha = null;
      _selectedGramasewaWasama = null;
      return;
    }

    final wasamas = sabhaMap[_selectedPradeshiyaSabha!]!;
    if (_selectedGramasewaWasama == null ||
        !wasamas.contains(_selectedGramasewaWasama)) {
      _selectedGramasewaWasama = null;
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _nameController.dispose();
    _nicController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _manualPradeshiyaSabhaController.dispose();
    _manualGramasewaWasamaController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() {
      _resendCountdown = 60;
    });

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendCountdown--;
          if (_resendCountdown <= 0) {
            timer.cancel();
            _resendCountdown = 0;
          }
        });
      }
    });
  }

  Future<void> _handleLanguageSelection(String code) async {
    setState(() => _selectedLanguage = code);
    await languageService.setLanguage(code, syncRemote: false);
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;

    if (!InputValidators.isValidSriLankanPhone(_phoneController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('invalidPhone')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isResending = true);

    final phoneInput = InputValidators.toE164SriLankanPhone(
      _phoneController.text.trim(),
    );

    try {
      final success = await otpService.sendOtp(phoneInput);
      if (mounted) {
        if (success) {
          _startResendCooldown();
          setState(() => _isResending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('otpResentSuccess')),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          setState(() => _isResending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('failedToResendOtp')),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (_nameController.text.isEmpty ||
          _nicController.text.isEmpty ||
          _phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('pleaseFillAllFields'))),
        );
        return;
      }

      if (_selectedProvince == null ||
          _selectedDistrict == null ||
          _resolvedPradeshiyaSabha.isEmpty ||
          _resolvedGramasewaWasama.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('pleaseSelectAdministrativeArea'))),
        );
        return;
      }

      if (_isLoadingAdministrativeAreas) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('loadingAdministrativeAreas'))),
        );
        return;
      }

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

      final registrationCheck = await firestoreService.checkCitizenRegistration(
        nic: nic,
        phone: phoneRaw,
      );
      final nicExists = registrationCheck?['nicExists'] == true;
      final phoneExists = registrationCheck?['phoneExists'] == true;

      if (nicExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('thisNicAlreadyRegistered'))),
          );
        }
        return;
      }

      final phoneInput = InputValidators.toE164SriLankanPhone(phoneRaw);
      if (phoneExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('phoneAlreadyRegistered'))),
          );
        }
        return;
      }

      if (_isSubmitting) return;
      setState(() => _isSubmitting = true);

      try {
        final success = await otpService.sendOtp(phoneInput);
        if (mounted) {
          if (success) {
            _startResendCooldown();
            setState(() {
              _isSubmitting = false;
              _currentStep = 1;
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
      if (_otpController.text.length >= 6) {
        if (_isSubmitting) return;
        setState(() => _isSubmitting = true);

        final phoneInput = InputValidators.toE164SriLankanPhone(
          _phoneController.text.trim(),
        );

        try {
          final token = await otpService.verifyOtp(
            phoneInput,
            _otpController.text,
          );
          if (token != null) {
            await _signInWithToken(token);
          } else {
            if (mounted) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(context.tr('invalidOtp'))));
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${context.tr('verificationFailed')}: $e'),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _signInWithToken(String token) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCustomToken(
        token,
      );
      final user = userCredential.user;
      if (user != null) {
        final existingUser = await firestoreService.getUser(user.uid);
        final enteredNic = InputValidators.normalizeNic(_nicController.text);

        if (existingUser == null) {
          final newUser = UserModel(
            id: user.uid,
            name: _nameController.text.trim(),
            nic: _nicController.text.trim().toUpperCase(),
            phone:
                user.phoneNumber ??
                InputValidators.toE164SriLankanPhone(
                  _phoneController.text.trim(),
                ),
            role: 'citizen',
            division: _resolvedGramasewaWasama,
            province: _selectedProvince ?? '',
            district: _selectedDistrict ?? '',
            pradeshiyaSabha: _resolvedPradeshiyaSabha,
            gramasewaWasama: _resolvedGramasewaWasama,
            preferredLanguage: _selectedLanguage,
            createdAt: DateTime.now(),
          );
          await firestoreService.createUser(newUser);
          await languageService.setLanguage(
            _selectedLanguage,
            syncRemote: false,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('accountCreatedSuccessfully')),
                backgroundColor: const Color(0xFF28A745),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        } else {
          final existingNic = InputValidators.normalizeNic(existingUser.nic);
          if (existingNic.isNotEmpty && existingNic != enteredNic) {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('nicPhoneMismatch'))),
              );
            }
            return;
          }
        }
        if (mounted) context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('signInFailed')}: $e')),
        );
      }
    }
  }

  void _handleBack() {
    if (_currentStep != 0) {
      setState(() => _currentStep = 0);
      return;
    }

    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/welcome');
    }
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
                    AppColors.background,
                    AppColors.secondary.withAlpha(15),
                    AppColors.primary.withAlpha(20),
                  ],
                  begin: _topAlignment.value,
                  end: _bottomAlignment.value,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  FadeIn(
                    duration: const Duration(milliseconds: 600),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: _handleBack,
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
                  const SizedBox(height: 16),

                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    child: Text(
                      _currentStep == 0
                          ? context.tr('createAccount')
                          : context.tr('verifyIdentity'),
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      _currentStep == 0
                          ? context.tr('signupSubtitle')
                          : context.tr('otpEntrySubtitle'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Step indicator
                  FadeIn(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 200),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepNode(0, context.tr('info')),
                        Container(
                          width: 40,
                          height: 2,
                          color: _currentStep == 1
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        _buildStepNode(1, context.tr('verify')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  FadeInUp(
                    duration: const Duration(milliseconds: 1000),
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(217),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withAlpha(127),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _currentStep == 0
                            ? _buildRegistrationForm()
                            : _buildOtpForm(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  if (_currentStep == 0)
                    FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 400),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr('alreadyHaveAccount'),
                            style: GoogleFonts.inter(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Text(
                              context.tr('signIn'),
                              style: GoogleFonts.inter(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(int step, String label) {
    bool isCompleted = _currentStep > step;
    bool isActive = _currentStep == step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? AppColors.primary : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive
                  ? AppColors.primary
                  : AppColors.border,
              width: 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(76),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: GoogleFonts.outfit(
                      color: isActive
                          ? Colors.white
                          : AppColors.mutedForeground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.primary : AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      key: const ValueKey('reg_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context.tr('fullName')),
        const SizedBox(height: 8),
        _buildTextField(
          _nameController,
          context.tr('nameExample'),
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        _buildLabel(context.tr('administrativeArea')),
        const SizedBox(height: 8),
        if (_isLoadingAdministrativeAreas)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  context.tr('loadingAdministrativeAreas'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        _buildDropdownField(
          value: _selectedProvince,
          label: context.tr('province'),
          hint: context.tr('selectProvince'),
          items: _provinces,
          enabled: !_isLoadingAdministrativeAreas,
          onChanged: (value) {
            setState(() {
              _selectedProvince = value;
              _selectedDistrict = null;
              _selectedPradeshiyaSabha = null;
              _selectedGramasewaWasama = null;
              _manualPradeshiyaSabhaController.clear();
              _manualGramasewaWasamaController.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        _buildDropdownField(
          value: _selectedDistrict,
          label: context.tr('district'),
          hint: context.tr('selectDistrict'),
          items: _districts,
          enabled: !_isLoadingAdministrativeAreas && _selectedProvince != null,
          onChanged: (value) {
            setState(() {
              _selectedDistrict = value;
              _selectedPradeshiyaSabha = null;
              _selectedGramasewaWasama = null;
              _manualPradeshiyaSabhaController.clear();
              _manualGramasewaWasamaController.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        if (_pradeshiyaSabhas.isNotEmpty)
          _buildDropdownField(
            value: _selectedPradeshiyaSabha,
            label: context.tr('pradeshiyaSabha'),
            hint: context.tr('selectPradeshiyaSabha'),
            items: _pradeshiyaSabhas,
            enabled:
                !_isLoadingAdministrativeAreas && _selectedDistrict != null,
            onChanged: (value) {
              setState(() {
                _selectedPradeshiyaSabha = value;
                _selectedGramasewaWasama = null;
                _manualPradeshiyaSabhaController.clear();
                _manualGramasewaWasamaController.clear();
              });
            },
          )
        else
          _buildTextField(
            _manualPradeshiyaSabhaController,
            context.tr('enterPradeshiyaSabha'),
            icon: Icons.account_balance_outlined,
          ),
        const SizedBox(height: 12),
        if (_gramasewaWasamas.isNotEmpty)
          _buildDropdownField(
            value: _selectedGramasewaWasama,
            label: context.tr('gramasewaWasama'),
            hint: context.tr('selectGramasewaWasama'),
            items: _gramasewaWasamas,
            enabled:
                !_isLoadingAdministrativeAreas &&
                _resolvedPradeshiyaSabha.isNotEmpty,
            onChanged: (value) {
              setState(() {
                _selectedGramasewaWasama = value;
                _manualGramasewaWasamaController.clear();
              });
            },
          )
        else
          _buildTextField(
            _manualGramasewaWasamaController,
            context.tr('enterGramasewaWasama'),
            icon: Icons.location_city_outlined,
          ),
        const SizedBox(height: 16),
        _buildLabel(context.tr('selectLanguage')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedLanguage,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.language_rounded, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: [
            DropdownMenuItem(value: 'en', child: Text(context.tr('english'))),
            DropdownMenuItem(value: 'si', child: Text(context.tr('sinhala'))),
            DropdownMenuItem(value: 'ta', child: Text(context.tr('tamil'))),
          ],
          onChanged: (value) {
            if (value == null) return;
            _handleLanguageSelection(value);
          },
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          context.tr('createAccount'),
          _nextStep,
          icon: Icons.arrow_forward_rounded,
        ),
      ],
    );
  }

  Widget _buildOtpForm() {
    bool canResend = _resendCountdown == 0 && !_isResending;

    return Column(
      key: const ValueKey('otp_reg_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(13),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: AppColors.primary,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildLabel(context.tr('enterOtp')),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [...InputValidators.otpFormatters()],
          textAlign: TextAlign.center,
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
        const SizedBox(height: 32),
        _buildPrimaryButton(
          context.tr('verifyAndFinish'),
          _nextStep,
          icon: Icons.done_all_rounded,
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              if (_resendCountdown > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${context.tr('resendAvailableIn')} ${_resendCountdown}s',
                    style: GoogleFonts.inter(
                      color: AppColors.mutedForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              TextButton(
                onPressed: canResend ? _resendOtp : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isResending) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _isResending
                          ? context.tr('sending')
                          : context.tr('didntReceiveCodeResend'),
                      style: GoogleFonts.inter(
                        color: canResend
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        fontSize: 13,
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
      onChanged: controller == _nicController
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

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          hint: Text(hint),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ],
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
          minimumSize: const Size(double.infinity, 56),
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
