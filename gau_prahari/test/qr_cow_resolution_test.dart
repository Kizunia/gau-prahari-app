import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/cow_selection/data/repositories/cow_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('CowRepositoryImpl QR Code resolution', () {
    final repo = CowRepositoryImpl();

    test('fetches COW-104 by plain cow ID', () async {
      final cow = await repo.getCowById('COW-104');
      expect(cow, isNotNull);
      expect(cow!.id, 'COW-104');
      expect(cow.tagNumber, 'RFID-9821');
      expect(cow.breed, 'Gir / Sahiwal Cross');
    });

    test('fetches COW-104 by tag number RFID-9821', () async {
      final cow = await repo.getCowById('RFID-9821');
      expect(cow, isNotNull);
      expect(cow!.id, 'COW-104');
    });

    test('fetches COW-104 by JSON payload in QR code', () async {
      const jsonPayload = '{"cow_id": "COW-104", "tag_number": "RFID-9821", "breed": "Gir / Sahiwal Cross", "app": "Gau-Prahari"}';
      final cow = await repo.getCowById(jsonPayload);
      expect(cow, isNotNull);
      expect(cow!.id, 'COW-104');
      expect(cow.tagNumber, 'RFID-9821');
    });

    test('fetches COW-101 and COW-102 correctly', () async {
      final cow101 = await repo.getCowById('COW-101');
      expect(cow101, isNotNull);
      expect(cow101!.id, 'COW-101');

      final cow102 = await repo.getCowById('COW-102');
      expect(cow102, isNotNull);
      expect(cow102!.id, 'COW-102');
    });

    test('returns null for unknown QR code', () async {
      final cow = await repo.getCowById('UNKNOWN-CODE-999');
      expect(cow, isNull);
    });
  });
}
