class OfficerApplicationItem {
  const OfficerApplicationItem({
    required this.id,
    required this.citizenName,
    required this.serviceType,
    required this.submissionDate,
    required this.status,
    required this.priority,
  });

  final String id;
  final String citizenName;
  final String serviceType;
  final String submissionDate;
  final String status;
  final String priority;
}

class OfficerComplaintItem {
  OfficerComplaintItem({
    required this.id,
    required this.citizenName,
    required this.description,
    required this.location,
    required this.date,
    required this.status,
  });

  final String id;
  final String citizenName;
  final String description;
  final String location;
  final String date;
  String status;
}

class OfficerCitizenItem {
  const OfficerCitizenItem({
    required this.id,
    required this.name,
    required this.nic,
    required this.phone,
    required this.address,
    required this.registeredDate,
  });

  final String id;
  final String name;
  final String nic;
  final String phone;
  final String address;
  final String registeredDate;
}
