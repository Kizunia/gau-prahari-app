import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/cow_selection/data/repositories/cow_repository_impl.dart';
import 'package:gau_prahari/features/cow_selection/presentation/controllers/cow_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Cow Entity Name Tests', () {
    test('displayName returns name when present, else id', () {
      const nameless = Cow(
        id: 'COW-104',
        tagNumber: 'RFID-9821',
        breed: 'Gir',
        ageYears: 4,
        lactationStage: 'Early',
      );
      expect(nameless.displayName, 'COW-104');

      final named = nameless.copyWith(name: 'Ganga');
      expect(named.displayName, 'Ganga');
      expect(named.name, 'Ganga');
      expect(named.id, 'COW-104');
    });

    test('toJson and fromJson serialize name correctly', () {
      const cow = Cow(
        id: 'COW-201',
        tagNumber: 'RFID-201',
        breed: 'Sahiwal',
        ageYears: 3,
        lactationStage: 'Mid',
        name: 'Nandini',
      );
      final json = cow.toJson();
      expect(json['name'], 'Nandini');

      final parsed = Cow.fromJson(json);
      expect(parsed.name, 'Nandini');
      expect(parsed.displayName, 'Nandini');
      expect(parsed.id, 'COW-201');
    });
  });

  group('CowRepository & CowController Tests', () {
    test('Can assign and edit name of existing catalog cow', () async {
      final repo = CowRepositoryImpl();
      final controller = CowController(repository: repo);

      await controller.loadCows();
      expect(controller.cows.any((c) => c.id == 'COW-104'), isTrue);

      // 1. Give cow a name
      final err = await controller.updateCowName('COW-104', 'Kamadhenu');
      expect(err, isNull);

      final cow = controller.cows.firstWhere((c) => c.id == 'COW-104');
      expect(cow.name, 'Kamadhenu');
      expect(cow.displayName, 'Kamadhenu');

      // 2. Edit cow name
      final err2 = await controller.updateCowName('COW-104', 'Ganga');
      expect(err2, isNull);

      final updatedCow = controller.cows.firstWhere((c) => c.id == 'COW-104');
      expect(updatedCow.name, 'Ganga');
      expect(updatedCow.displayName, 'Ganga');
    });

    test('Can add a new cow with name and custom fields', () async {
      final repo = CowRepositoryImpl();
      final controller = CowController(repository: repo);

      await controller.loadCows();
      final initialCount = controller.cows.length;

      // Add new cow
      final err = await controller.addCow(
        id: 'COW-999',
        tagNumber: 'RFID-9999',
        breed: 'Red Sindhi',
        ageYears: 5,
        lactationStage: 'Late Lactation',
        name: 'Gauri',
      );
      expect(err, isNull);
      expect(controller.cows.length, initialCount + 1);

      final added = controller.cows.firstWhere((c) => c.id == 'COW-999');
      expect(added.name, 'Gauri');
      expect(added.displayName, 'Gauri');
      expect(added.breed, 'Red Sindhi');
      expect(added.ageYears, 5);
    });

    test('Prevents duplicate Cow ID', () async {
      final repo = CowRepositoryImpl();
      final controller = CowController(repository: repo);
      await controller.loadCows();

      final err = await controller.addCow(
        id: 'COW-104', // already in catalog
        tagNumber: 'RFID-DUPE',
        breed: 'Gir',
        ageYears: 4,
        lactationStage: 'Early',
      );
      expect(err, contains('already exists'));
    });

    test('Persists name overrides across fresh repository instances', () async {
      final repo1 = CowRepositoryImpl();
      await repo1.updateCowName('COW-101', 'Sundari');

      // Fresh repository loading from SharedPreferences
      final repo2 = CowRepositoryImpl();
      final cow = await repo2.getCowById('COW-101');
      expect(cow, isNotNull);
      expect(cow!.name, 'Sundari');
      expect(cow.displayName, 'Sundari');
    });
  });
}
