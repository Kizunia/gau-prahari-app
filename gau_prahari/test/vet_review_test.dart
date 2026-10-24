import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_result.dart';
import 'package:gau_prahari/features/auth/domain/entities/user.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';
import 'package:gau_prahari/features/vet_review/data/repositories/local_draft_repository.dart';
import 'package:gau_prahari/features/vet_review/domain/entities/review_draft.dart';
import 'package:gau_prahari/features/vet_review/domain/entities/review_message.dart';
import 'package:gau_prahari/features/vet_review/domain/entities/review_request.dart';
import 'package:gau_prahari/features/vet_review/domain/entities/review_status.dart';

void main() {
  group('ReviewStatus Lifecycle Tests (SRS 4.6)', () {
    test('Correct enum parsing and fallbacks', () {
      expect(ReviewStatus.fromString('pending'), ReviewStatus.pending);
      expect(ReviewStatus.fromString('inReview'), ReviewStatus.inReview);
      expect(ReviewStatus.fromString('in_review'), ReviewStatus.inReview);
      expect(ReviewStatus.fromString('responded'), ReviewStatus.responded);
      expect(ReviewStatus.fromString('closed'), ReviewStatus.closed);
      expect(ReviewStatus.fromString(null), ReviewStatus.pending);
      expect(ReviewStatus.fromString('unknown'), ReviewStatus.pending);
    });

    test('Open and Closed status query flags', () {
      expect(ReviewStatus.pending.isOpen, isTrue);
      expect(ReviewStatus.pending.isClosed, isFalse);
      expect(ReviewStatus.inReview.isOpen, isTrue);
      expect(ReviewStatus.responded.isOpen, isTrue);
      expect(ReviewStatus.closed.isOpen, isFalse);
      expect(ReviewStatus.closed.isClosed, isTrue);
    });
  });

  group('Clinical Snapshot Creation & Immutability Tests (SRS 4.2)', () {
    late Cow originalCow;
    late AnalysisResult originalResult;
    late MilkMeasurement originalMilk;
    late CollarHistory originalCollar;

    setUp(() {
      originalCow = const Cow(
        id: 'COW-104',
        tagNumber: 'TAG-104-IND',
        name: 'Ganga',
        breed: 'Gir',
        ageYears: 4,
        lactationStage: 'Early Lactation',
        status: 'Active',
      );

      originalResult = AnalysisResult(
        cowId: 'COW-104',
        prediction: 1,
        probability: 0.88,
        riskLevel: 'HIGH',
        factors: ['Elevated SCC (>500k)', 'Conductivity >6.2 mS/cm'],
        recommendedAction: 'Quarantine quarter and administer intramammary treatment.',
        timestamp: DateTime(2026, 10, 25, 10, 30),
      );

      originalMilk = MilkMeasurement(
        cowId: 'COW-104',
        milkTemperature: 38.4,
        ph: 7.15,
        conductivity: 6.45,
        scc: 540000,
        fat: 3.2,
        snf: 7.9,
        timestamp: DateTime(2026, 10, 25, 10, 25),
      );

      originalCollar = CollarHistory(
        cowId: 'COW-104',
        records: [
          CollarTelemetry(
            timestamp: DateTime(2026, 10, 24, 8, 0),
            activity: 45.0,
            skinTemperature: 38.1,
            ambientTemperature: 28.5,
            humidity: 62.0,
            thi: 74.2,
          ),
          CollarTelemetry(
            timestamp: DateTime(2026, 10, 25, 8, 0),
            activity: 35.0,
            skinTemperature: 38.6,
            ambientTemperature: 29.0,
            humidity: 64.0,
            thi: 75.8,
          ),
        ],
      );
    });

    test('Builds comprehensive snapshot preserving exact measurements and units', () {
      final snapshot = ReviewRequest.buildSnapshot(
        cow: originalCow,
        result: originalResult,
        milkMeasurement: originalMilk,
        collarHistory: originalCollar,
      );

      expect(snapshot['cow']['id'], 'COW-104');
      expect(snapshot['cow']['name'], 'Ganga');
      expect(snapshot['cow']['breed'], 'Gir');

      expect(snapshot['prediction']['prediction'], 1);
      expect(snapshot['prediction']['probability'], 0.88);
      expect(snapshot['prediction']['risk_level'], 'HIGH');
      expect(snapshot['prediction']['factors'], hasLength(2));

      expect(snapshot['milkMeasurement']['milk_temperature'], 38.4);
      expect(snapshot['milkMeasurement']['ph'], 7.15);
      expect(snapshot['milkMeasurement']['conductivity'], 6.45);
      expect(snapshot['milkMeasurement']['scc'], 540000);

      expect(snapshot['collarHistory']['summary']['record_count'], 2);
      expect(snapshot['collarHistory']['records'], hasLength(2));
    });

    test('Snapshot remains immutable when source entities are modified or copied', () {
      final snapshot = ReviewRequest.buildSnapshot(
        cow: originalCow,
        result: originalResult,
        milkMeasurement: originalMilk,
        collarHistory: originalCollar,
      );

      // Modify / reassign local cow profile
      final modifiedCow = originalCow.copyWith(
        name: 'Ganga 2.0 (Renamed)',
        breed: 'Murrah',
        ageYears: 7,
      );

      expect(snapshot['cow']['name'], 'Ganga');
      expect(snapshot['cow']['breed'], 'Gir');
      expect(snapshot['cow']['age_years'], 4);
      expect(modifiedCow.name, 'Ganga 2.0 (Renamed)');
    });

    test('Unpacks snapshot accessors accurately into strongly-typed domain entities', () {
      final snapshot = ReviewRequest.buildSnapshot(
        cow: originalCow,
        result: originalResult,
        milkMeasurement: originalMilk,
        collarHistory: originalCollar,
      );

      final request = ReviewRequest(
        id: 'REQ-999',
        farmerUid: 'farmer_123',
        farmerNameSnapshot: 'Ramesh Patel',
        veterinarianUid: 'vet_456',
        veterinarianNameSnapshot: 'Dr. Suresh Rao',
        cowId: 'COW-104',
        cowTagNumber: 'TAG-104-IND',
        predictionLabel: 'High Mastitis Risk',
        riskLevel: 'HIGH',
        status: ReviewStatus.pending,
        snapshot: snapshot,
        createdAt: DateTime(2026, 10, 25, 11, 0),
        updatedAt: DateTime(2026, 10, 25, 11, 0),
      );

      final unpackedCow = request.cowSnapshot;
      expect(unpackedCow, isNotNull);
      expect(unpackedCow!.id, 'COW-104');
      expect(unpackedCow.displayName, 'Ganga');

      final unpackedPrediction = request.predictionSnapshot;
      expect(unpackedPrediction, isNotNull);
      expect(unpackedPrediction!.isHighRisk, isTrue);
      expect(unpackedPrediction.probability, 0.88);

      final unpackedMilk = request.milkSnapshot;
      expect(unpackedMilk, isNotNull);
      expect(unpackedMilk!.scc, 540000);
      expect(unpackedMilk.isSccElevated, isTrue);

      final unpackedCollar = request.collarSnapshot;
      expect(unpackedCollar, isNotNull);
      expect(unpackedCollar!.recordCount, 2);
    });
  });

  group('ReviewMessage Model & Validation Tests (SRS 4.7)', () {
    test('Constructs and parses message accurately', () {
      final now = DateTime.now();
      final message = ReviewMessage(
        id: 'MSG-001',
        senderUid: 'vet_456',
        senderRole: 'veterinarian',
        text: 'Please isolate the cow immediately and check quarter temperature.',
        createdAt: now,
      );

      expect(message.isVeterinarian, isTrue);
      expect(message.isFarmer, isFalse);

      final map = message.toMap();
      final reconstructed = ReviewMessage.fromMap({
        'senderUid': map['senderUid'],
        'senderRole': map['senderRole'],
        'text': map['text'],
        'createdAt': now.toIso8601String(),
      }, 'MSG-001');

      expect(reconstructed.id, 'MSG-001');
      expect(reconstructed.senderRole, 'veterinarian');
      expect(reconstructed.text, contains('isolate the cow'));
    });
  });

  group('Local Draft Persistence Tests (SRS 4.3)', () {
    test('Draft saving, retrieval by farmerUid, and deletion', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalDraftRepository();

      const farmerUid = 'farmer_abc_123';
      final draft = ReviewDraft(
        id: 'draft_001',
        farmerUid: farmerUid,
        cowId: 'COW-104',
        cowTagNumber: 'TAG-104',
        predictionLabel: 'High Risk',
        riskLevel: 'HIGH',
        snapshot: {'cow': {'id': 'COW-104'}},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Initially empty
      final emptyList = await repo.getDrafts(farmerUid);
      expect(emptyList, isEmpty);

      // Save draft
      await repo.saveDraft(draft);

      final drafts = await repo.getDrafts(farmerUid);
      expect(drafts, hasLength(1));
      expect(drafts.first.cowId, 'COW-104');

      // Isolated: different farmer has no drafts
      final otherFarmerDrafts = await repo.getDrafts('farmer_xyz_999');
      expect(otherFarmerDrafts, isEmpty);

      // Delete draft
      await repo.deleteDraft(farmerUid, 'draft_001');
      final afterDelete = await repo.getDrafts(farmerUid);
      expect(afterDelete, isEmpty);
    });
  });

  group('User Role & Routing Logic Tests (SRS 3.1 & 3.2)', () {
    test('Farmer role detection', () {
      const farmer = User(
        id: 'u1',
        name: 'Kisan',
        identifier: 'kisan@example.com',
        role: 'farmer',
      );
      expect(farmer.isFarmer, isTrue);
      expect(farmer.isVeterinarian, isFalse);
    });

    test('Veterinarian role detection', () {
      const vet = User(
        id: 'u2',
        name: 'Dr. Deshmukh',
        identifier: 'vet@example.com',
        role: 'veterinarian',
      );
      expect(vet.isVeterinarian, isTrue);
      expect(vet.isFarmer, isFalse);
    });

    test('Demo session isolation flag', () {
      const demoUser = User(
        id: 'u3',
        name: 'Demo Farmer',
        identifier: 'farmer@gauprahari.org',
        role: 'farmer',
        isDemo: true,
      );
      expect(demoUser.isDemo, isTrue);
    });
  });
}
