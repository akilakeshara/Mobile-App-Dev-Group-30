import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../widgets/gradient_page_app_bar.dart';
import '../models/service_type.dart';
import '../localization/app_localizations.dart';

class ServiceApplicationPage extends StatefulWidget {
  const ServiceApplicationPage({super.key});

  @override
  State<ServiceApplicationPage> createState() => _ServiceApplicationPageState();
}

class _ServiceApplicationPageState extends State<ServiceApplicationPage> {
  int _currentStep = 0;
  String? _selectedService;
  double _selectedServiceFee = 250.0;
  bool _isSubmitting = false;

  // Storage state
  final Map<String, String> _uploadedDocumentUrls = {};
  final Map<String, double> _uploadProgress = {};
  final Map<String, String> _selectedFileNames = {};
  final String _applicationId =
      'APP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

  // Form data for service-specific fields
  final Map<String, String> _formData = {};

  String? _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_selectedService == null) {
        return context.tr('pleaseSelectService');
      }
    } else if (_currentStep == 1) {
      final serviceType = getServiceType(_selectedService ?? '');
      if (serviceType == null) {
        return context.tr('serviceNotFound');
      }

      // Check required form fields
      for (final field in serviceType.formFields) {
        if (field.required && (_formData[field.id]?.isEmpty ?? true)) {
          return '${context.tr('pleaseFillIn')}: ${field.label}';
        }
      }

      // Check required documents
      for (int i = 0; i < serviceType.requiredDocuments.length; i++) {
        final docKey = 'doc_$i';
        if (!_uploadedDocumentUrls.containsKey(docKey)) {
          return '${context.tr('pleaseUpload')}: ${serviceType.requiredDocuments[i]}';
        }
      }
    }
    return null;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _nextStep() async {
    if (_currentStep < 2) {
      final error = _validateCurrentStep();
      if (error != null) {
        _showValidationError(error);
        return;
      }
      setState(() => _currentStep++);
    } else {
      if (_isSubmitting) return;
      setState(() => _isSubmitting = true);

      try {
        final id = _applicationId;
        if (!mounted) return;

        await context.push(
          '/payment/checkout',
          extra: {
            'serviceName': _selectedService,
            'amount': _selectedServiceFee,
            'applicationId': id,
            'pendingApplication': {
              'serviceType': _selectedService,
              'status': 'Submitted',
              'currentStep': 1,
              'documentUrls': _uploadedDocumentUrls,
              'formData': _formData, // Include the citizen's form input!
            },
          },
        );
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
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: context.tr('serviceApplicationTitle'),
        subtitle: context.tr('serviceApplicationSubtitle'),
        onBack: _previousStep,
      ),
      body: Column(
        children: [
          _buildProgressHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildCurrentStep(),
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    final progress = (_currentStep + 1) / 3;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2E8F), Color(0xFF3558E1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fact_check_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${context.tr('step')} ${_currentStep + 1} ${context.tr('of')} 3',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withAlpha(50),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildServiceSelection();
      case 1:
        return _buildRequirements();
      case 2:
        return _buildReview();
      default:
        return const SizedBox();
    }
  }

  Widget _buildServiceSelection() {
    final allServices = getAllServiceTypes();

    return Column(
      key: const ValueKey('serv1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('selectGovernmentService'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('serviceSelectionSubtitle'),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 24),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allServices.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final service = allServices[index];
            final isSelected = _selectedService == service.name;

            return GestureDetector(
              onTap: () => setState(() {
                _selectedService = service.name;
                _selectedServiceFee = service.fee;
                _formData.clear();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withAlpha(15)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.border.withAlpha(100),
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(30),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha(3),
                            blurRadius: 8,
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withAlpha(30)
                                : AppColors.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              service.icon,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.foreground,
                                ),
                              ),
                              Text(
                                service.description,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Rs. ${service.fee.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          service.processingTime,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequirements() {
    final serviceType = getServiceType(_selectedService ?? '');
    if (serviceType == null) {
      return Center(child: Text(context.tr('serviceTypeNotFound')));
    }

    return Column(
      key: const ValueKey('serv2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('serviceDetails'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 24),
        // Service-specific form fields
        ...serviceType.formFields.map((field) {
          if (field.type == 'text') {
            return _buildTextFormField(field);
          } else if (field.type == 'date') {
            return _buildDateFormField(field);
          } else if (field.type == 'dropdown') {
            return _buildDropdownFormField(field);
          }
          return const SizedBox();
        }),
        const SizedBox(height: 32),
        Text(
          context.tr('requiredDocuments'),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('uploadRequiredDocumentsNote'),
          style: GoogleFonts.inter(
            color: AppColors.mutedForeground,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        ...serviceType.requiredDocuments.asMap().entries.map((entry) {
          final index = entry.key;
          final docType = entry.value;
          final doc = 'doc_$index';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildUploadField(
              doc,
              docType,
              '${context.tr('upload')} $docType',
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTextFormField(ServiceFormField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (value) => _formData[field.id] = value,
            decoration: InputDecoration(
              hintText: field.hint,
              hintStyle: GoogleFonts.inter(
                color: AppColors.mutedForeground,
                fontSize: 13,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.border.withAlpha(100),
                  width: 1,
                ),
              ),
            ),
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.foreground),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFormField(ServiceFormField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(
                  () => _formData[field.id] = picked.toString().split(' ')[0],
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border.withAlpha(100),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formData[field.id] ?? field.hint,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _formData[field.id] != null
                            ? AppColors.foreground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFormField(ServiceFormField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border.withAlpha(100),
                width: 1,
              ),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              underline: const SizedBox(),
              hint: Text(
                field.hint,
                style: GoogleFonts.inter(
                  color: AppColors.mutedForeground,
                  fontSize: 13,
                ),
              ),
              value: _formData[field.id],
              onChanged: (value) =>
                  setState(() => _formData[field.id] = value ?? ''),
              items: (field.options ?? [])
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(
                        option,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(String docType) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;

      setState(() {
        _selectedFileNames[docType] = fileName;
        _uploadProgress[docType] = 0.1; // Start progress
      });

      try {
        final url = await storageService.uploadDocument(
          file: file,
          applicationId: _applicationId,
          documentType: docType,
          onProgress: (p) {
            setState(() => _uploadProgress[docType] = p);
          },
        );

        setState(() {
          _uploadedDocumentUrls[docType] = url;
          _uploadProgress[docType] = 1.0;
        });
      } catch (e) {
        setState(() {
          _uploadProgress.remove(docType);
          _selectedFileNames.remove(docType);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.tr('uploadFailed')}: $e')),
          );
        }
      }
    }
  }

  Widget _buildUploadField(String docType, String label, String sub) {
    bool isUploaded = _uploadedDocumentUrls.containsKey(docType);
    double? progress = _uploadProgress[docType];
    bool isUploading = progress != null && progress < 1.0;
    String? fileName = _selectedFileNames[docType];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isUploaded
              ? Colors.green
              : (isUploading
                    ? AppColors.primary
                    : AppColors.border.withAlpha(150)),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isUploaded
                ? Colors.green.withAlpha(15)
                : isUploading
                ? AppColors.primary.withAlpha(15)
                : Colors.black.withAlpha(5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isUploaded
                ? Icons.check_circle_rounded
                : Icons.cloud_upload_outlined,
            color: isUploaded ? Colors.green : AppColors.primary,
            size: 40,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isUploaded ? Colors.green : AppColors.foreground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUploaded ? context.tr('uploaded') : sub,
                      style: GoogleFonts.inter(
                        color: isUploaded
                            ? Colors.green
                            : AppColors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (fileName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isUploaded
                    ? Colors.green.withAlpha(20)
                    : AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                fileName,
                style: GoogleFonts.inter(
                  color: isUploaded ? Colors.green : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (isUploading)
            Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.border.withAlpha(100),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  minHeight: 6,
                ),
                const SizedBox(height: 10),
                Text(
                  '${(progress * 100).toInt()}% ${context.tr('uploading')}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: () => _pickAndUpload(docType),
              style: ElevatedButton.styleFrom(
                backgroundColor: isUploaded
                    ? Colors.green.withAlpha(20)
                    : AppColors.primary.withAlpha(20),
                foregroundColor: isUploaded ? Colors.green : AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isUploaded
                    ? context.tr('changeFile')
                    : context.tr('browseFiles'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    final serviceType = getServiceType(_selectedService ?? '');

    return Column(
      key: const ValueKey('serv3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('reviewAndConfirm'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 24),
        // Service Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B2E8F), Color(0xFF3558E1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    serviceType?.icon ?? '📋',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedService ?? context.tr('service'),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          serviceType?.description ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withAlpha(200),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Colors.white.withAlpha(200),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    serviceType?.processingTime ?? '3-5 Days',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Rs. ${_selectedServiceFee.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          context.tr('submittedInformation'),
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 14),
        ..._formData.entries.map((entry) {
          final field = serviceType?.formFields
              .where((f) => f.id == entry.key)
              .firstOrNull;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    field?.label ?? entry.key,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.orangeAccent.withAlpha(50),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('applicationSubmittedAfterPayment'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orangeAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final validationError = _validateCurrentStep();
    final isValid = validationError == null;
    final canProceed = !_isSubmitting && isValid;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white),
      child: Tooltip(
        message: validationError ?? '',
        child: ElevatedButton(
          onPressed: canProceed ? _nextStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canProceed ? AppColors.primary : Colors.grey[300],
            foregroundColor: canProceed ? Colors.white : Colors.grey[600],
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: canProceed ? 4 : 0,
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
                  _currentStep == 2
                      ? context.tr('proceedToPayment')
                      : context.tr('continue'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}
