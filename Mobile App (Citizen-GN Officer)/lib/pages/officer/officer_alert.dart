import 'package:cloud_firestore/cloud_firestore.dart';

class OfficerAlert {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool isHighPriority;

  OfficerAlert({
    required this.id,
    required this.text,
    required this.createdAt,
    this.isHighPriority = false,
  });

  factory OfficerAlert.fromMap(Map<String, dynamic> map, String id) {
    return OfficerAlert(
      id: id,
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isHighPriority: map['isHighPriority'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'isHighPriority': isHighPriority,
    };
  }
}
