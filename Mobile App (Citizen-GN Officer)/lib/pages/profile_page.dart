import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/language_service.dart';
import '../services/storage_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/gradient_page_app_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditMode = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  double? _photoUploadProgress;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _nameController.clear();
      _phoneController.clear();
    });
  }

  Future<void> _saveProfile(String userId, UserModel currentUser) async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pleaseFillAllFields'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update user in Firestore
      final updatedUser = UserModel(
        id: currentUser.id,
        name: _nameController.text.trim(),
        nic: currentUser.nic,
        phone: _phoneController.text.trim(),
        role: currentUser.role,
        division: currentUser.division,
        province: currentUser.province,
        district: currentUser.district,
        pradeshiyaSabha: currentUser.pradeshiyaSabha,
        gramasewaWasama: currentUser.gramasewaWasama,
        preferredLanguage: currentUser.preferredLanguage,
        profileImageUrl: currentUser.profileImageUrl,
        createdAt: currentUser.createdAt,
      );

      await firestoreService.updateUser(updatedUser);

      if (mounted) {
        setState(() {
          _isEditMode = false;
          _isSaving = false;
          _nameController.clear();
          _phoneController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('profileUpdated')),
            backgroundColor: const Color(0xFF28A745),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('errorUpdatingProfile')}: $e')),
        );
      }
    }
  }

  Future<void> _changeLanguage(
    UserModel currentUser,
    String languageCode,
  ) async {
    try {
      await languageService.setLanguage(languageCode);

      if (currentUser.preferredLanguage != languageCode) {
        final updatedUser = UserModel(
          id: currentUser.id,
          name: currentUser.name,
          nic: currentUser.nic,
          phone: currentUser.phone,
          role: currentUser.role,
          division: currentUser.division,
          province: currentUser.province,
          district: currentUser.district,
          pradeshiyaSabha: currentUser.pradeshiyaSabha,
          gramasewaWasama: currentUser.gramasewaWasama,
          preferredLanguage: languageCode,
          profileImageUrl: currentUser.profileImageUrl,
          createdAt: currentUser.createdAt,
        );
        await firestoreService.updateUser(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('languageSaved'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('failedToUpdateLanguage')}: $e'),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadProfilePhoto(UserModel currentUser) async {
    if (_isUploadingPhoto) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _isUploadingPhoto = true;
      _photoUploadProgress = 0;
    });

    try {
      final file = File(result.files.single.path!);
      final imageUrl = await storageService.uploadProfilePhoto(
        file: file,
        userId: currentUser.id,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _photoUploadProgress = progress);
        },
      );

      await firestoreService.updateUserProfilePhoto(currentUser.id, imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('profilePhotoUpdated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('failedToUploadPhoto')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          _photoUploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = firestoreService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: _isEditMode
            ? context.tr('editProfile')
            : context.tr('myProfile'),
        subtitle: _isEditMode
            ? context.tr('updateYourInformation')
            : context.tr('viewAndManageAccount'),
      ),
      body: SingleChildScrollView(
        child: StreamBuilder<UserModel?>(
          stream: firestoreService.getUserStream(userId),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null && _isEditMode) {
              if (_nameController.text.isEmpty) {
                _nameController.text = snapshot.data!.name;
                _phoneController.text = snapshot.data!.phone;
              }
            }

            return Column(
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: _buildProfileHeader(userId),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      if (_isEditMode)
                        FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 100),
                          child: _buildEditSection(snapshot.data),
                        )
                      else
                        FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 100),
                          child: _buildUserDetailsSection(userId),
                        ),
                      const SizedBox(height: 24),
                      if (!_isEditMode) ...[
                        FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 200),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  setState(() => _isEditMode = true),
                              icon: const Icon(Icons.edit_rounded),
                              label: Text(
                                context.tr('editProfile'),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_isEditMode) ...[
                        FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 200),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isSaving ? null : _cancelEdit,
                                  icon: const Icon(Icons.close_rounded),
                                  label: Text(
                                    context.tr('cancel'),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.grey,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isSaving
                                      ? null
                                      : () => _saveProfile(
                                          userId,
                                          snapshot.data!,
                                        ),
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded),
                                  label: Text(
                                    _isSaving
                                        ? context.tr('saving')
                                        : context.tr('save'),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (!_isEditMode) ...[
                        if (snapshot.data != null)
                          FadeInUp(
                            duration: const Duration(milliseconds: 600),
                            delay: const Duration(milliseconds: 250),
                            child: _buildLanguageSection(snapshot.data!),
                          ),
                        if (snapshot.data != null) const SizedBox(height: 24),
                        FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 300),
                          child: _buildMenuSection(context.tr('support'), [
                            _buildMenuItem(
                              Icons.help_outline_rounded,
                              context.tr('helpCenter'),
                              context.tr('faqsAndSupportGuides'),
                            ),
                            _buildMenuItem(
                              Icons.feedback_outlined,
                              context.tr('sendFeedback'),
                              context.tr('helpUsImprove'),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 32),
                      ],
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: Duration(milliseconds: _isEditMode ? 300 : 400),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/welcome'),
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Colors.redAccent,
                            ),
                            label: Text(
                              context.tr('signOut'),
                              style: GoogleFonts.inter(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                color: Colors.redAccent,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String userId) {
    return StreamBuilder<UserModel?>(
      stream: firestoreService.getUserStream(userId),
      builder: (context, snapshot) {
        String name = context.tr('userName');
        String nic = context.tr('nicId');
        String role = context.tr('citizen');
        String profileImageUrl = '';
        UserModel? currentUser;

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          currentUser = user;
          name = user.name;
          nic = user.nic;
          profileImageUrl = user.profileImageUrl;
          role = user.role == 'officer'
              ? context.tr('governmentOfficer')
              : context.tr('citizen');
        }

        final displayInitial = name.trim().isNotEmpty
            ? name.trim()[0].toUpperCase()
            : 'U';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B2E8F), Color(0xFF3558E1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(55),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profileImageUrl.isNotEmpty
                          ? Image.network(
                              profileImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white.withAlpha(179),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: AppColors.primary,
                                    size: 50,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.white,
                              alignment: Alignment.center,
                              child: Text(
                                displayInitial,
                                style: GoogleFonts.inter(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                    ),
                  ),
                  GestureDetector(
                    onTap: (currentUser == null || _isUploadingPhoto)
                        ? null
                        : () => _pickAndUploadProfilePhoto(currentUser!),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _isUploadingPhoto
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: _photoUploadProgress,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
              if (_isUploadingPhoto) ...[
                const SizedBox(height: 10),
                Text(
                  '${context.tr('uploadingPhoto')} ${((_photoUploadProgress ?? 0) * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(210),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                role,
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(210),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha(50),
                    width: 1,
                  ),
                ),
                child: Text(
                  nic,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditSection(UserModel? currentUser) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('editProfile'),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('fullName'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: context.tr('enterYourFullName'),
              hintStyle: GoogleFonts.inter(color: AppColors.mutedForeground),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('phoneNumber'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: context.tr('enterYourPhoneNumber'),
              hintStyle: GoogleFonts.inter(color: AppColors.mutedForeground),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🆔 ${context.tr('nicNumber')}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  currentUser?.nic ?? '--',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '(${context.tr('nicCannotBeChanged')})',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.mutedForeground,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailsSection(String userId) {
    return StreamBuilder<UserModel?>(
      stream: firestoreService.getUserStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              context.tr('loadingUserInformation'),
              style: GoogleFonts.inter(color: AppColors.mutedForeground),
            ),
          );
        }

        final user = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('accountInformation'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow('👤 ${context.tr('fullName')}', user.name),
              const SizedBox(height: 16),
              _buildDetailRow('🆔 ${context.tr('nicId')}', user.nic),
              const SizedBox(height: 16),
              _buildDetailRow('📱 ${context.tr('phoneNumber')}', user.phone),
              const SizedBox(height: 16),
              _buildDetailRow(
                '👨‍💼 ${context.tr('role')}',
                user.role == 'officer'
                    ? context.tr('governmentOfficer')
                    : context.tr('citizen'),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                '📅 ${context.tr('memberSince')}',
                _formatDate(user.createdAt),
              ),
              if (user.province.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailRow('🗺️ ${context.tr('province')}', user.province),
              ],
              if (user.district.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailRow('📍 ${context.tr('district')}', user.district),
              ],
              if (user.pradeshiyaSabha.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailRow(
                  '🏛️ ${context.tr('pradeshiyaSabha')}',
                  user.pradeshiyaSabha,
                ),
              ],
              if (user.gramasewaWasama.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailRow(
                  '🏘️ ${context.tr('gramasewaWasama')}',
                  user.gramasewaWasama,
                ),
              ],
              if (user.division.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailRow('🏢 ${context.tr('division')}', user.division),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildLanguageSection(UserModel user) {
    final selected = user.preferredLanguage.isEmpty
        ? languageService.currentLanguageCode
        : user.preferredLanguage;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('changeLanguage'),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.language_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: [
              DropdownMenuItem(value: 'en', child: Text(context.tr('english'))),
              DropdownMenuItem(value: 'si', child: Text(context.tr('sinhala'))),
              DropdownMenuItem(value: 'ta', child: Text(context.tr('tamil'))),
            ],
            onChanged: (value) {
              if (value == null) return;
              _changeLanguage(user, value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.border,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
