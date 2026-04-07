class Complaint {
  final String id;
  final String title;
  final String category;
  final String description;
  final String location;
  final String landmark;
  final String priority;
  final DateTime? incidentDateTime;
  final bool isSafetyRisk;
  final bool isAnonymous;
  final bool allowFollowUp;
  final String preferredContactMethod;
  final String contactPhone;
  final String contactEmail;
  final int? affectedPeople;
  final String additionalDetails;
  final String status; // 'Open', 'In Progress', 'Closed'
  final DateTime createdAt;
  final String userId;
  final String gnDivision;

  Complaint({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    this.landmark = '',
    this.priority = 'Medium',
    this.incidentDateTime,
    this.isSafetyRisk = false,
    this.isAnonymous = false,
    this.allowFollowUp = true,
    this.preferredContactMethod = 'Phone',
    this.contactPhone = '',
    this.contactEmail = '',
    this.affectedPeople,
    this.additionalDetails = '',
    required this.status,
    required this.createdAt,
    required this.userId,
    this.gnDivision = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'description': description,
      'location': location,
      'landmark': landmark,
      'priority': priority,
      'incidentDateTime': incidentDateTime?.toIso8601String(),
      'isSafetyRisk': isSafetyRisk,
      'isAnonymous': isAnonymous,
      'allowFollowUp': allowFollowUp,
      'preferredContactMethod': preferredContactMethod,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'affectedPeople': affectedPeople,
      'additionalDetails': additionalDetails,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'gnDivision': gnDivision,
    };
  }

  factory Complaint.fromMap(Map<String, dynamic> map, String documentId) {
    return Complaint(
      id: documentId,
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      landmark: map['landmark'] ?? '',
      priority: map['priority'] ?? 'Medium',
      incidentDateTime: map['incidentDateTime'] != null
          ? DateTime.tryParse(map['incidentDateTime'])
          : null,
      isSafetyRisk: map['isSafetyRisk'] == true,
      isAnonymous: map['isAnonymous'] == true,
      allowFollowUp: map['allowFollowUp'] != false,
      preferredContactMethod: map['preferredContactMethod'] ?? 'Phone',
      contactPhone: map['contactPhone'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      affectedPeople: map['affectedPeople'] is int
          ? map['affectedPeople']
          : int.tryParse('${map['affectedPeople'] ?? ''}'),
      additionalDetails: map['additionalDetails'] ?? '',
      status: map['status'] ?? 'Open',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      userId: map['userId'] ?? '',
      gnDivision: map['gnDivision'] ?? '',
    );
  }
}
