class Application {
  final String id;
  final String serviceType;
  final String status; // 'Submitted', 'Processing', 'Verified', 'Completed'
  final DateTime createdAt;
  final String userId;
  final int currentStep;
  final Map<String, String>
  documentUrls; // {'doc_0': 'https://...', 'doc_1': 'https://...'}
  final Map<String, String>
  formData; // {'fullName': 'John Doe', 'dateOfBirth': '2000-01-01'}
  final double fee;
  final String processingTime;
  final String officerRemarks;
  final bool certificateGenerated;
  final String certificateDownloadUrl;
  final DateTime? certificateIssuedAt;
  final String certificateReference;
  final String certificateIntegrityHash;
  final String gnDivision;

  Application({
    required this.id,
    required this.serviceType,
    required this.status,
    required this.createdAt,
    required this.userId,
    required this.currentStep,
    this.documentUrls = const {},
    this.formData = const {},
    this.fee = 0.0,
    this.processingTime = '',
    this.officerRemarks = '',
    this.certificateGenerated = false,
    this.certificateDownloadUrl = '',
    this.certificateIssuedAt,
    this.certificateReference = '',
    this.certificateIntegrityHash = '',
    this.gnDivision = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'serviceType': serviceType,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'currentStep': currentStep,
      'documentUrls': documentUrls,
      'formData': formData,
      'fee': fee,
      'processingTime': processingTime,
      'officerRemarks': officerRemarks,
      'certificateGenerated': certificateGenerated,
      'certificateDownloadUrl': certificateDownloadUrl,
      'certificateIssuedAt': certificateIssuedAt?.toIso8601String(),
      'certificateReference': certificateReference,
      'certificateIntegrityHash': certificateIntegrityHash,
      'gnDivision': gnDivision,
    };
  }

  factory Application.fromMap(Map<String, dynamic> map, String documentId) {
    return Application(
      id: documentId,
      serviceType: map['serviceType'] ?? '',
      status: map['status'] ?? 'Submitted',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      userId: map['userId'] ?? '',
      currentStep: _maxStep(
          map['currentStep']?.toInt() ?? 1,
          _resolveStepFromStatus(map['status'] ?? 'Submitted')),
      documentUrls: Map<String, String>.from(map['documentUrls'] ?? {}),
      formData: Map<String, String>.from(map['formData'] ?? {}),
      fee: (map['fee'] ?? 0.0).toDouble(),
      processingTime: map['processingTime'] ?? '',
      officerRemarks: map['officerRemarks'] ?? '',
      certificateGenerated: map['certificateGenerated'] == true,
      certificateDownloadUrl: map['certificateDownloadUrl'] ?? '',
      certificateIssuedAt: map['certificateIssuedAt'] != null
          ? DateTime.tryParse(map['certificateIssuedAt'])
          : null,
      certificateReference: map['certificateReference'] ?? '',
      certificateIntegrityHash: map['certificateIntegrityHash'] ?? '',
      gnDivision: map['gnDivision'] ?? '',
    );
  }

  static int _maxStep(int a, int b) => a > b ? a : b;

  static int _resolveStepFromStatus(String status) {
    switch (status) {
      case 'Submitted':
        return 1;
      case 'Verified':
        return 2;
      case 'Processing':
        return 3;
      case 'Completed':
        return 4;
      default:
        return 1;
    }
  }
}
