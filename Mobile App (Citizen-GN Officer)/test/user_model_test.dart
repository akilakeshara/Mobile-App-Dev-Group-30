import 'package:flutter_test/flutter_test.dart';
import 'package:govease/models/user_model.dart';

void main() {
  group('UserModel Serialization/Deserialization Tests', () {
    test('Correctly maps from Map with standard string date', () {
      final map = {
        'name': 'Akil',
        'nic': '199512345678',
        'phone': '0771234567',
        'role': 'citizen',
        'createdAt': '2026-04-05T01:23:45.000Z',
      };
      
      final user = UserModel.fromMap(map, 'doc_123');
      
      expect(user.id, 'doc_123');
      expect(user.name, 'Akil');
      expect(user.role, 'citizen');
      expect(user.createdAt.year, 2026);
    });

    test('Gracefully handles missing or null fields', () {
      final map = {
        'nic': '912345678V',
      };
      
      final user = UserModel.fromMap(map, 'doc_456');
      
      expect(user.id, 'doc_456');
      expect(user.name, 'Unknown User'); // fallback
      expect(user.role, 'citizen'); // fallback
      expect(user.createdAt.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue); // fallback to now
    });
  });
}
