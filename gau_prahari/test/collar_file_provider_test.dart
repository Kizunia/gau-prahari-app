import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/collar_import/data/repositories/file_collar_data_provider.dart';
import 'package:gau_prahari/features/collar_import/presentation/controllers/collar_import_controller.dart';

void main() {
  group('Phase 3 FileCollarDataProvider Tests', () {
    late FileCollarDataProvider provider;
    late CollarImportController controller;

    setUp(() {
      provider = FileCollarDataProvider();
      controller = CollarImportController(provider: provider);
    });

    const validCsv = '''
cow_id,timestamp,activity,skin_temperature,ambient_temperature,humidity,thi
COW-104,2026-09-01T08:00:00,75.5,37.1,29.5,62.0,77.3
COW-104,2026-09-02T08:00:00,72.0,37.3,30.0,65.0,78.2
''';

    const validJson = '''
{
  "cow_id": "COW-104",
  "records": [
    {
      "timestamp": "2026-09-01T08:00:00",
      "activity": 75.5,
      "skin_temperature": 37.1,
      "ambient_temperature": 29.5,
      "humidity": 62.0,
      "thi": 77.3
    }
  ]
}
''';

    test('Parses valid CSV into CollarHistory with correct metrics', () async {
      final history = await provider.parseData(validCsv, expectedCowId: 'COW-104');

      expect(history.cowId, 'COW-104');
      expect(history.recordCount, 2);
      expect(history.meanActivity, closeTo(73.75, 0.01));
      expect(history.meanSkinTemperature, closeTo(37.2, 0.01));
      expect(history.records[0].thi, 77.3);
    });

    test('Parses valid JSON into CollarHistory', () async {
      final history = await provider.parseData(validJson, expectedCowId: 'COW-104');

      expect(history.cowId, 'COW-104');
      expect(history.recordCount, 1);
      expect(history.records[0].activity, 75.5);
    });

    test('Rejects CSV when Cow ID does not match selected animal', () async {
      expect(
        () => provider.parseData(validCsv, expectedCowId: 'COW-999'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Cow ID mismatch'),
        )),
      );
    });

    test('Rejects JSON when Cow ID does not match selected animal', () async {
      expect(
        () => provider.parseData(validJson, expectedCowId: 'COW-999'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Cow ID mismatch'),
        )),
      );
    });

    test('Rejects CSV with missing required columns', () async {
      const incompleteCsv = '''
cow_id,timestamp,activity,skin_temperature
COW-104,2026-09-01T08:00:00,75.5,37.1
''';
      expect(
        () => provider.parseData(incompleteCsv, expectedCowId: 'COW-104'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Missing required CSV header column'),
        )),
      );
    });

    test('Rejects empty file content', () async {
      expect(
        () => provider.parseData('   ', expectedCowId: 'COW-104'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('empty'),
        )),
      );
    });

    test('CollarImportController manages state and error transitions', () async {
      final success = await controller.loadFromString(
        validCsv,
        expectedCowId: 'COW-104',
        sourceName: 'test.csv',
      );

      expect(success, true);
      expect(controller.hasData, true);
      expect(controller.history?.recordCount, 2);
      expect(controller.sourceName, 'test.csv');
      expect(controller.errorMessage, isNull);

      // Fail with wrong cow
      final failed = await controller.loadFromString(
        validCsv,
        expectedCowId: 'COW-OTHER',
        sourceName: 'test.csv',
      );

      expect(failed, false);
      expect(controller.hasData, false);
      expect(controller.errorMessage, contains('Cow ID mismatch'));
    });
  });
}
