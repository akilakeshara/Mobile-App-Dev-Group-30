import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../models/complaint.dart';
import '../services/firestore_service.dart';
import '../widgets/gradient_page_app_bar.dart';
import '../localization/app_localizations.dart';

class NewComplaintPage extends StatefulWidget {
  const NewComplaintPage({super.key});

  @override
  State<NewComplaintPage> createState() => _NewComplaintPageState();
}

class _NewComplaintPageState extends State<NewComplaintPage> {
  int _currentStep = 0;
  String? _selectedCategory;
  String _selectedPriority = 'Medium';
  String _preferredContactMethod = 'Phone';
  bool _isSafetyRisk = false;
  bool _isAnonymous = false;
  bool _allowFollowUp = true;
  DateTime? _incidentDate;
  TimeOfDay? _incidentTime;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _affectedPeopleController = TextEditingController();
  final _additionalDetailsController = TextEditingController();

  bool _isSubmitting = false;
  StreamSubscription<List<String>>? _categoriesSub;

  List<String> _categories = const [
    'Infrastructure',
    'Electricity',
    'Water Supply',
    'Waste Management',
    'Public Health',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _incidentDate = DateTime.now();
    _incidentTime = TimeOfDay.now();

    _categoriesSub = firestoreService.getComplaintCategories().listen((
      categories,
    ) {
      if (!mounted || categories.isEmpty) return;
      setState(() {
        _categories = categories;
        if (_selectedCategory != null &&
            !_categories.contains(_selectedCategory)) {
          _selectedCategory = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _landmarkController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _affectedPeopleController.dispose();
    _additionalDetailsController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_selectedCategory == null ||
          _titleController.text.trim().length < 6) {
        _showError('Select a category and enter a clear title (min 6 chars).');
        return false;
      }
      return true;
    }

    if (_currentStep == 1) {
      if (_descriptionController.text.trim().length < 20 ||
          _locationController.text.trim().isEmpty ||
          _incidentDate == null) {
        _showError(
          'Add full incident details: description, location, and date.',
        );
        return false;
      }
      return true;
    }

    if (_currentStep == 2) {
      final affectedRaw = _affectedPeopleController.text.trim();
      if (affectedRaw.isNotEmpty && int.tryParse(affectedRaw) == null) {
        _showError('Affected people count must be a valid number.');
        return false;
      }

      if (!_isAnonymous) {
        final hasPhone = _contactPhoneController.text.trim().isNotEmpty;
        final hasEmail = _contactEmailController.text.trim().isNotEmpty;
        if (!hasPhone && !hasEmail) {
          _showError('Provide at least one contact method (phone or email).');
          return false;
        }
      }
      return true;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _nextStep() async {
    if (_currentStep < 3) {
      if (!_validateCurrentStep()) return;
      setState(() => _currentStep++);
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final id =
          'CP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      DateTime? incidentDateTime;
      if (_incidentDate != null) {
        final t = _incidentTime ?? const TimeOfDay(hour: 0, minute: 0);
        incidentDateTime = DateTime(
          _incidentDate!.year,
          _incidentDate!.month,
          _incidentDate!.day,
          t.hour,
          t.minute,
        );
      }

      final complaint = Complaint(
        id: id,
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        landmark: _landmarkController.text.trim(),
        priority: _selectedPriority,
        incidentDateTime: incidentDateTime,
        isSafetyRisk: _isSafetyRisk,
        isAnonymous: _isAnonymous,
        allowFollowUp: _allowFollowUp,
        preferredContactMethod: _preferredContactMethod,
        contactPhone: _contactPhoneController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        affectedPeople: int.tryParse(_affectedPeopleController.text.trim()),
        additionalDetails: _additionalDetailsController.text.trim(),
        status: 'Open',
        createdAt: DateTime.now(),
        userId: firestoreService.currentUserId,
      );

      await firestoreService.addComplaint(complaint);
      if (mounted) _showSuccessDialog(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.tr('error')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _pickIncidentDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _incidentDate = picked);
    }
  }

  Future<void> _pickIncidentTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _incidentTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _incidentTime = picked);
    }
  }

  void _showSuccessDialog(String referenceId) {
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF28A745),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('submittedSuccessTitle'),
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${context.tr('complaintSubmittedMessage')} $referenceId',
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
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.tr('backToHome'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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
        title: context.tr('newComplaintTitle'),
        subtitle: 'Complete incident intake with full details',
        onBack: _previousStep,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _buildCurrentStep(),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? AppColors.primary : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.outfit(
                        color: isActive
                            ? Colors.white
                            : AppColors.mutedForeground,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (index < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < _currentStep
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStepOne();
      case 1:
        return _buildStepTwo();
      case 2:
        return _buildStepThree();
      case 3:
        return _buildStepFour();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepOne() {
    return Column(
      key: const ValueKey('complaint-step-1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Issue Classification'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = cat),
              selectedColor: AppColors.primary,
              labelStyle: GoogleFonts.inter(
                color: isSelected ? Colors.white : AppColors.foreground,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Complaint Title'),
        const SizedBox(height: 10),
        TextField(
          controller: _titleController,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Short, clear summary of the issue',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Priority Level'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Low', 'Medium', 'High', 'Critical'].map((level) {
            final selected = _selectedPriority == level;
            return ChoiceChip(
              label: Text(level),
              selected: selected,
              onSelected: (_) => setState(() => _selectedPriority = level),
              selectedColor: AppColors.secondary,
              labelStyle: GoogleFonts.inter(
                color: selected ? Colors.white : AppColors.foreground,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Immediate safety risk',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Mark this if people/property are in immediate danger.',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          value: _isSafetyRisk,
          onChanged: (v) => setState(() => _isSafetyRisk = v),
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      key: const ValueKey('complaint-step-2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Incident Details'),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          maxLines: 6,
          minLines: 4,
          decoration: const InputDecoration(
            hintText:
                'Describe what happened, when it started, and current impact...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            hintText: 'Exact location (street, number, area)',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _landmarkController,
          decoration: const InputDecoration(
            hintText: 'Nearby landmark (optional)',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickIncidentDate,
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(
                  _incidentDate == null
                      ? 'Pick date'
                      : '${_incidentDate!.day}/${_incidentDate!.month}/${_incidentDate!.year}',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickIncidentTime,
                icon: const Icon(Icons.access_time_rounded),
                label: Text(
                  _incidentTime == null
                      ? 'Pick time'
                      : _incidentTime!.format(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepThree() {
    return Column(
      key: const ValueKey('complaint-step-3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Reporter & Impact Information'),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Submit anonymously',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          value: _isAnonymous,
          onChanged: (v) => setState(() => _isAnonymous = v),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Allow officer follow-up',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          value: _allowFollowUp,
          onChanged: (v) => setState(() => _allowFollowUp = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _preferredContactMethod,
          decoration: const InputDecoration(
            labelText: 'Preferred contact method',
          ),
          items: const [
            DropdownMenuItem(value: 'Phone', child: Text('Phone')),
            DropdownMenuItem(value: 'Email', child: Text('Email')),
            DropdownMenuItem(value: 'SMS', child: Text('SMS')),
            DropdownMenuItem(
              value: 'No Contact Needed',
              child: Text('No Contact Needed'),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _preferredContactMethod = v);
          },
        ),
        const SizedBox(height: 12),
        if (!_isAnonymous) ...[
          TextField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Contact phone (optional if email provided)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Contact email (optional if phone provided)',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _affectedPeopleController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Estimated number of affected people (optional)',
            prefixIcon: Icon(Icons.groups_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _additionalDetailsController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Additional evidence/details (optional)',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStepFour() {
    return Column(
      key: const ValueKey('complaint-step-4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Review Submission'),
        const SizedBox(height: 18),
        _buildReviewRow('Category', _selectedCategory ?? '-'),
        _buildReviewRow('Title', _titleController.text.trim()),
        _buildReviewRow('Priority', _selectedPriority),
        _buildReviewRow('Safety Risk', _isSafetyRisk ? 'Yes' : 'No'),
        _buildReviewRow('Location', _locationController.text.trim()),
        _buildReviewRow(
          'Landmark',
          _landmarkController.text.trim().isEmpty
              ? '-'
              : _landmarkController.text.trim(),
        ),
        _buildReviewRow(
          'Incident Date/Time',
          '${_incidentDate == null ? '-' : '${_incidentDate!.day}/${_incidentDate!.month}/${_incidentDate!.year}'} ${_incidentTime == null ? '' : _incidentTime!.format(context)}',
        ),
        _buildReviewRow('Anonymous', _isAnonymous ? 'Yes' : 'No'),
        _buildReviewRow('Follow-up Allowed', _allowFollowUp ? 'Yes' : 'No'),
        _buildReviewRow('Preferred Contact', _preferredContactMethod),
        _buildReviewRow(
          'Affected People',
          _affectedPeopleController.text.trim().isEmpty
              ? '-'
              : _affectedPeopleController.text.trim(),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondary.withAlpha(20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.secondary.withAlpha(70)),
          ),
          child: Text(
            'Ensure all details are accurate. Incomplete or misleading complaints may delay resolution.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Text(
                  context.tr('previous'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep == 3
                          ? context.tr('submitComplaint')
                          : context.tr('continue'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
