import '../utils/encryption_util.dart';

class UserModel {
  final String id;
  final String name;
  final String nic;
  final String phone;
  final String role;
  final String division;
  final String province;
  final String district;
  final String pradeshiyaSabha;
  final String gramasewaWasama;
  final String preferredLanguage;
  final String profileImageUrl;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.nic,
    required this.phone,
    required this.role,
    this.division = '',
    this.province = '',
    this.district = '',
    this.pradeshiyaSabha = '',
    this.gramasewaWasama = '',
    this.preferredLanguage = 'en',
    this.profileImageUrl = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nic': EncryptionUtil.encrypt(nic),
      'phone': phone, // Keep phone plaintext mostly unless explicitly requested, often used for queries
      'role': role,
      'division': EncryptionUtil.encrypt(division),
      'province': EncryptionUtil.encrypt(province),
      'district': EncryptionUtil.encrypt(district),
      'pradeshiyaSabha': EncryptionUtil.encrypt(pradeshiyaSabha),
      'gramasewaWasama': EncryptionUtil.encrypt(gramasewaWasama),
      'preferredLanguage': preferredLanguage,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      name: map['name'] ?? 'Unknown User',
      nic: EncryptionUtil.decrypt(map['nic'] ?? ''),
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'citizen',
      division: EncryptionUtil.decrypt((map['division'] ?? map['gramasewaWasama'] ?? '').toString()),
      province: EncryptionUtil.decrypt(map['province'] ?? ''),
      district: EncryptionUtil.decrypt(map['district'] ?? ''),
      pradeshiyaSabha: EncryptionUtil.decrypt(map['pradeshiyaSabha'] ?? ''),
      gramasewaWasama: EncryptionUtil.decrypt((map['gramasewaWasama'] ?? map['division'] ?? '').toString()),
      preferredLanguage: map['preferredLanguage'] ?? 'en',
      profileImageUrl: map['profileImageUrl'] ?? '',
      createdAt: () {
        var val = map['createdAt'];
        if (val == null) return DateTime.now();
        if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
        try {
          if (val.runtimeType.toString() == 'Timestamp') {
            return DateTime.fromMillisecondsSinceEpoch(val.millisecondsSinceEpoch);
          }
        } catch (_) {}
        try {
          return val.toDate() as DateTime;
        } catch (_) {}
        return DateTime.now();
      }(),
    );
  }
}
