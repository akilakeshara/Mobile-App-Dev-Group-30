class GnAppointment {
  final String id;
  final String referenceNumber;
  final String userId;
  final String citizenName;
  final String nic;
  final String phone;
  final String province;
  final String district;
  final String pradeshiyaSabha;
  final String gramasewaWasama;
  final String subject;
  final String reason;
  final DateTime preferredDate;
  final String preferredTimeSlot;
  final String meetingMode;
  final bool isUrgent;
  final String status;
  final String notes;
  final String officerNotes;
  final String assignedOfficerId;
  final String assignedOfficerName;
  final DateTime? scheduledDate;
  final DateTime? responseAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  GnAppointment({
    required this.id,
    required this.referenceNumber,
    required this.userId,
    required this.citizenName,
    required this.nic,
    required this.phone,
    required this.province,
    required this.district,
    required this.pradeshiyaSabha,
    required this.gramasewaWasama,
    required this.subject,
    required this.reason,
    required this.preferredDate,
    required this.preferredTimeSlot,
    required this.meetingMode,
    required this.isUrgent,
    required this.status,
    this.notes = '',
    this.officerNotes = '',
    this.assignedOfficerId = '',
    this.assignedOfficerName = '',
    this.scheduledDate,
    this.responseAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'referenceNumber': referenceNumber,
      'userId': userId,
      'citizenName': citizenName,
      'nic': nic,
      'phone': phone,
      'province': province,
      'district': district,
      'pradeshiyaSabha': pradeshiyaSabha,
      'gramasewaWasama': gramasewaWasama,
      'subject': subject,
      'reason': reason,
      'preferredDate': preferredDate.toIso8601String(),
      'preferredTimeSlot': preferredTimeSlot,
      'meetingMode': meetingMode,
      'isUrgent': isUrgent,
      'status': status,
      'notes': notes,
      'officerNotes': officerNotes,
      'assignedOfficerId': assignedOfficerId,
      'assignedOfficerName': assignedOfficerName,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'responseAt': responseAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GnAppointment.fromMap(Map<String, dynamic> map, String documentId) {
    return GnAppointment(
      id: documentId,
      referenceNumber: map['referenceNumber'] ?? documentId,
      userId: map['userId'] ?? '',
      citizenName: map['citizenName'] ?? '',
      nic: map['nic'] ?? '',
      phone: map['phone'] ?? '',
      province: map['province'] ?? '',
      district: map['district'] ?? '',
      pradeshiyaSabha: map['pradeshiyaSabha'] ?? '',
      gramasewaWasama: map['gramasewaWasama'] ?? '',
      subject: map['subject'] ?? '',
      reason: map['reason'] ?? '',
      preferredDate: map['preferredDate'] != null
          ? DateTime.parse(map['preferredDate'])
          : DateTime.now(),
      preferredTimeSlot: map['preferredTimeSlot'] ?? '',
      meetingMode: map['meetingMode'] ?? 'In Person',
      isUrgent: map['isUrgent'] == true,
      status: map['status'] ?? 'Requested',
      notes: map['notes'] ?? '',
      officerNotes: map['officerNotes'] ?? '',
      assignedOfficerId: map['assignedOfficerId'] ?? '',
      assignedOfficerName: map['assignedOfficerName'] ?? '',
      scheduledDate: map['scheduledDate'] != null
          ? DateTime.tryParse(map['scheduledDate'])
          : null,
      responseAt: map['responseAt'] != null
          ? DateTime.tryParse(map['responseAt'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }
}
