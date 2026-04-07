import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';
import '../models/gn_appointment.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_page_app_bar.dart';

class GnAppointmentPage extends StatefulWidget {
  final bool showUpcomingFirst;

  const GnAppointmentPage({super.key, this.showUpcomingFirst = false});

  @override
  State<GnAppointmentPage> createState() => _GnAppointmentPageState();
}

class _GnAppointmentPageState extends State<GnAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedSubject = 'general';
  String _selectedTimeSlot = 'morning';
  String _selectedMode = 'in_person';
  bool _isUrgent = false;
  bool _isSubmitting = false;
  String? _successReference;

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: context.tr('selectAppointmentDate'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitAppointment(UserModel user) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _successReference = null;
    });

    try {
      final now = DateTime.now();
      final referenceNumber =
          'GNAPT-${DateFormat('yyyyMMdd').format(now)}-${Random().nextInt(9000) + 1000}';
      final id = 'gnappt_${now.microsecondsSinceEpoch}';

      final appointment = GnAppointment(
        id: id,
        referenceNumber: referenceNumber,
        userId: user.id,
        citizenName: user.name,
        nic: user.nic,
        phone: user.phone,
        province: user.province,
        district: user.district,
        pradeshiyaSabha: user.pradeshiyaSabha,
        gramasewaWasama: user.gramasewaWasama,
        subject: _subjectLabel(_selectedSubject),
        reason: _reasonController.text.trim(),
        preferredDate: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ),
        preferredTimeSlot: _timeSlotLabel(_selectedTimeSlot),
        meetingMode: _modeLabel(_selectedMode),
        isUrgent: _isUrgent,
        status: 'Requested',
        notes: _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await firestoreService.addGnAppointment(appointment);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _successReference = appointment.referenceNumber;
        _reasonController.clear();
        _notesController.clear();
        _selectedDate = DateTime.now().add(const Duration(days: 1));
        _selectedSubject = 'general';
        _selectedTimeSlot = 'morning';
        _selectedMode = 'in_person';
        _isUrgent = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('appointmentSubmittedMessage')} ${appointment.referenceNumber}',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('appointmentSubmitFailed')}: $e')),
      );
    }
  }

  String _subjectLabel(String code) {
    switch (code) {
      case 'document_verification':
        return context.tr('appointmentSubjectDocument');
      case 'land_issue':
        return context.tr('appointmentSubjectLand');
      case 'complaint_follow_up':
        return context.tr('appointmentSubjectComplaint');
      case 'certificate_support':
        return context.tr('appointmentSubjectCertificate');
      default:
        return context.tr('appointmentSubjectGeneral');
    }
  }

  String _timeSlotLabel(String code) {
    switch (code) {
      case 'afternoon':
        return context.tr('appointmentSlotAfternoon');
      case 'evening':
        return context.tr('appointmentSlotEvening');
      default:
        return context.tr('appointmentSlotMorning');
    }
  }

  String _modeLabel(String code) {
    switch (code) {
      case 'phone_call':
        return context.tr('appointmentModePhone');
      default:
        return context.tr('appointmentModeInPerson');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = firestoreService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: context.tr('appointmentTitle'),
        subtitle: context.tr('appointmentSubtitle'),
      ),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(uid),
        builder: (context, userSnapshot) {
          final user = userSnapshot.data;

          if (user == null) {
            return _buildSignInPrompt(context);
          }

          return StreamBuilder<List<GnAppointment>>(
            stream: firestoreService.getUserGnAppointments(),
            builder: (context, appointmentSnapshot) {
              final appointments = List<GnAppointment>.from(
                appointmentSnapshot.data ?? const [],
              );
              appointments.sort(
                (a, b) => a.preferredDate.compareTo(b.preferredDate),
              );
              final upcomingAppointments = appointments
                  .where(
                    (appointment) =>
                        appointment.status.toLowerCase() != 'cancelled' &&
                        appointment.status.toLowerCase() != 'canceled' &&
                        appointment.status.toLowerCase() != 'completed',
                  )
                  .toList();

              final pastAppointments = appointments
                  .where((a) => a.status.toLowerCase() == 'completed')
                  .toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 450),
                        child: _buildHeroCard(
                          context,
                          user,
                          upcomingAppointments,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.showUpcomingFirst) ...[
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          child: _buildUpcomingAppointmentsSection(
                            context,
                            upcomingAppointments,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: _buildCitizenSummary(context, user),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: _buildBookingForm(context, user),
                      ),
                      const SizedBox(height: 16),
                      if (_successReference != null) ...[
                        FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          child: _buildSuccessCard(context, _successReference!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!widget.showUpcomingFirst) ...[
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          child: _buildUpcomingAppointmentsSection(
                            context,
                            upcomingAppointments,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 16),
                      if (pastAppointments.isNotEmpty) ...[
                        FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          child: _buildPastAppointmentsSection(
                            context,
                            pastAppointments,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        context.tr('appointmentHelpText'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('appointmentRequiresSignIn'),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('appointmentSignInMessage'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedForeground,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/login'),
              child: Text(context.tr('signIn')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    UserModel user,
    List<GnAppointment> upcomingAppointments,
  ) {
    final nextAppointment = upcomingAppointments.isNotEmpty
        ? upcomingAppointments.first
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withAlpha(32),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.meeting_room_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('bookGnAppointment'),
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('appointmentHeroSubtitle'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withAlpha(220),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildHeroPill(
            icon: Icons.location_on_outlined,
            label: [
              user.pradeshiyaSabha,
              user.district,
              user.province,
            ].where((item) => item.isNotEmpty).join(', '),
            fallback: context.tr('appointmentAreaUnknown'),
          ),
          const SizedBox(height: 10),
          _buildHeroPill(
            icon: Icons.event_available_rounded,
            label: nextAppointment == null
                ? context.tr('noAppointmentsYet')
                : '${nextAppointment.referenceNumber} • ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(nextAppointment.preferredDate)}',
            fallback: context.tr('noAppointmentsYet'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill({
    required IconData icon,
    required String label,
    required String fallback,
  }) {
    final display = label.trim().isEmpty ? fallback : label;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              display,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitizenSummary(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.nic} • ${user.phone}',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  [
                    user.pradeshiyaSabha,
                    user.gramasewaWasama,
                  ].where((value) => value.isNotEmpty).join(' • '),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingForm(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('appointmentFormTitle'),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('appointmentFormSubtitle'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedSubject,
            decoration: _inputDecoration(context.tr('appointmentSubjectLabel')),
            items: [
              DropdownMenuItem(
                value: 'general',
                child: Text(context.tr('appointmentSubjectGeneral')),
              ),
              DropdownMenuItem(
                value: 'document_verification',
                child: Text(context.tr('appointmentSubjectDocument')),
              ),
              DropdownMenuItem(
                value: 'land_issue',
                child: Text(context.tr('appointmentSubjectLand')),
              ),
              DropdownMenuItem(
                value: 'complaint_follow_up',
                child: Text(context.tr('appointmentSubjectComplaint')),
              ),
              DropdownMenuItem(
                value: 'certificate_support',
                child: Text(context.tr('appointmentSubjectCertificate')),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedSubject = value);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _reasonController,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: _inputDecoration(
              context.tr('appointmentReasonLabel'),
            ).copyWith(hintText: context.tr('appointmentReasonHint')),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.tr('pleaseFillAllFields');
              }
              if (value.trim().length < 15) {
                return context.tr('appointmentReasonTooShort');
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(18),
            child: InputDecorator(
              decoration: _inputDecoration(context.tr('preferredDate')),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat.yMMMMEEEEd(
                      Localizations.localeOf(context).toLanguageTag(),
                    ).format(_selectedDate),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(context.tr('change')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('preferredTimeSlot'),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildChip(
                label: context.tr('appointmentSlotMorning'),
                selected: _selectedTimeSlot == 'morning',
                onTap: () => setState(() => _selectedTimeSlot = 'morning'),
              ),
              _buildChip(
                label: context.tr('appointmentSlotAfternoon'),
                selected: _selectedTimeSlot == 'afternoon',
                onTap: () => setState(() => _selectedTimeSlot = 'afternoon'),
              ),
              _buildChip(
                label: context.tr('appointmentSlotEvening'),
                selected: _selectedTimeSlot == 'evening',
                onTap: () => setState(() => _selectedTimeSlot = 'evening'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('appointmentMode'),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildChip(
                label: context.tr('appointmentModeInPerson'),
                selected: _selectedMode == 'in_person',
                onTap: () => setState(() => _selectedMode = 'in_person'),
              ),
              _buildChip(
                label: context.tr('appointmentModePhone'),
                selected: _selectedMode == 'phone_call',
                onTap: () => setState(() => _selectedMode = 'phone_call'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isUrgent,
            onChanged: (value) => setState(() => _isUrgent = value),
            title: Text(
              context.tr('urgentRequest'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            subtitle: Text(
              context.tr('urgentRequestSubtitle'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration(context.tr('additionalNotes')),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : () => _submitAppointment(user),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(context.tr('submitAppointment')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: GoogleFonts.inter(
        color: selected ? Colors.white : AppColors.foreground,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buildSuccessCard(BuildContext context, String reference) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withAlpha(18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('appointmentSubmitted'),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${context.tr('appointmentSubmittedMessage')} $reference',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.foreground,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointmentsSection(
    BuildContext context,
    List<GnAppointment> appointments,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('upcomingAppointments'),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointments.isEmpty
                          ? context.tr('noAppointmentsYet')
                          : '${appointments.length} ${context.tr('plannedAppointments')}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (appointments.isEmpty)
            _buildEmptyAppointmentsState(context)
          else
            ...appointments.map(
              (appointment) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAppointmentCard(context, appointment),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyAppointmentsState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('noAppointmentsYet'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('appointmentEmptyStateMessage'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.mutedForeground,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    GnAppointment appointment,
  ) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final displayDate = DateFormat.yMMMMEEEEd(
      localeTag,
    ).format(appointment.preferredDate);
    final statusColor = _statusColor(appointment.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.meeting_room_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appointment.referenceNumber,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            appointment.status,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.subject,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.calendar_month_rounded, displayDate),
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.schedule_rounded,
            '${appointment.preferredTimeSlot} • ${appointment.meetingMode}',
          ),
          if (appointment.scheduledDate != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.event_repeat_rounded,
              '${context.tr('scheduledFor')} ${DateFormat.yMMMMEEEEd(localeTag).format(appointment.scheduledDate!)}',
            ),
          ],
          if (appointment.isUrgent) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.priority_high_rounded,
              context.tr('urgentRequest'),
            ),
          ],
          if (appointment.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              appointment.reason,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppColors.foreground,
                height: 1.45,
              ),
            ),
          ],
          if (appointment.officerNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${context.tr('officerNote')}: ${appointment.officerNotes}',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.foreground,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (_canCancelAppointment(appointment.status)) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final shouldCancel = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(context.tr('cancelAppointment')),
                      content: Text('Do you want to cancel this appointment?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('No'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Yes, Cancel'),
                        ),
                      ],
                    ),
                  );

                  if (shouldCancel != true) {
                    return;
                  }

                  await firestoreService.cancelGnAppointment(appointment.id);
                },
                icon: const Icon(Icons.cancel_outlined),
                label: Text(context.tr('cancelAppointment')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _canCancelAppointment(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'requested' ||
        normalized == 'approved' ||
        normalized == 'rescheduled';
  }

  Widget _buildDetailRow(IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.foreground,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'completed':
        return const Color(0xFF0F766E);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFDC2626);
      case 'rejected':
        return const Color(0xFFB45309);
      default:
        return AppColors.primary;
    }
  }

  Widget _buildPastAppointmentsSection(
    BuildContext context,
    List<GnAppointment> appointments,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Past Appointments',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 16),
          ...appointments.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPastAppointmentCard(context, a),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastAppointmentCard(
    BuildContext context,
    GnAppointment appointment,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appointment.referenceNumber,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appointment.subject,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showRatingDialog(context, appointment),
              child: const Text('Rate your experience'),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, GnAppointment appointment) {
    int rating = 5;
    String feedback = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate GN Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setState(() => rating = index + 1),
                  ),
                ),
              ),
              TextField(
                decoration: const InputDecoration(hintText: 'Any feedback?'),
                onChanged: (val) => feedback = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await firestoreService.rateGNAppointment(
                  appointment.id,
                  rating,
                  feedback,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for your feedback!'),
                    ),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
