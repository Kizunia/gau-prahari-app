import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gau_prahari/core/localization/app_localizations.dart';
import 'package:gau_prahari/core/localization/locale_controller.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_result.dart';
import 'package:gau_prahari/features/analysis/services/report_export_service.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocaleController Language Change Tests', () {
    test('Default locale is English', () {
      final controller = LocaleController();
      expect(controller.locale.languageCode, 'en');
    });

    test('Switching locale notifies listeners and updates code', () async {
      final controller = LocaleController();
      bool notified = false;
      controller.addListener(() => notified = true);

      // Switch to Hindi
      await controller.setLocale(const Locale('hi'));
      expect(controller.locale.languageCode, 'hi');
      expect(notified, isTrue);

      // Switch to Marathi
      notified = false;
      await controller.setLocale(const Locale('mr'));
      expect(controller.locale.languageCode, 'mr');
      expect(notified, isTrue);

      // Persistence check
      final controller2 = LocaleController();
      await controller2.loadSavedLocale();
      expect(controller2.locale.languageCode, 'mr');
    });
  });

  group('Multilingual JSON Asset Parity Tests', () {
    test('All keys in app_en.json exist in app_hi.json and app_mr.json', () {
      final en = json.decode(File('assets/lang/app_en.json').readAsStringSync()) as Map<String, dynamic>;
      final hi = json.decode(File('assets/lang/app_hi.json').readAsStringSync()) as Map<String, dynamic>;
      final mr = json.decode(File('assets/lang/app_mr.json').readAsStringSync()) as Map<String, dynamic>;

      expect(hi.keys.toSet(), equals(en.keys.toSet()), reason: 'Hindi keys should match English keys');
      expect(mr.keys.toSet(), equals(en.keys.toSet()), reason: 'Marathi keys should match English keys');
    });
  });

  group('AppLocalizations Dynamic Helper Translations', () {
    late AppLocalizations locEn;
    late AppLocalizations locHi;
    late AppLocalizations locMr;

    setUpAll(() {
      final enMap = (json.decode(File('assets/lang/app_en.json').readAsStringSync()) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
      final hiMap = (json.decode(File('assets/lang/app_hi.json').readAsStringSync()) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
      final mrMap = (json.decode(File('assets/lang/app_mr.json').readAsStringSync()) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));

      locEn = AppLocalizations.fromMap(const Locale('en'), enMap);
      locHi = AppLocalizations.fromMap(const Locale('hi'), hiMap);
      locMr = AppLocalizations.fromMap(const Locale('mr'), mrMap);
    });

    test('Translates cow status across languages', () {
      expect(locEn.translateStatus('Ready for Test'), 'Ready for Test');
      expect(locHi.translateStatus('Ready for Test'), 'परीक्षण के लिए तैयार');
      expect(locMr.translateStatus('Ready for Test'), 'चाचणीसाठी तयार');

      expect(locHi.translateStatus('Collar History Available'), 'कॉलर इतिहास उपलब्ध');
      expect(locMr.translateStatus('Needs Milk Test'), 'दूध चाचणी आवश्यक');
    });

    test('Translates cow breed across languages', () {
      expect(locEn.translateBreed('Murrah Buffalo'), 'Murrah Buffalo');
      expect(locHi.translateBreed('Murrah Buffalo'), 'मुर्रा भैंस');
      expect(locMr.translateBreed('Murrah Buffalo'), 'मुऱ्हा म्हैस');

      expect(locHi.translateBreed('Gir / Sahiwal Cross'), 'गीर / साहीवाल संकर');
      expect(locMr.translateBreed('Tharparkar'), 'थारपारकर');
    });

    test('Translates lactation stages across languages', () {
      expect(locEn.translateLactation('Early Lactation (Day 42)'), 'Early Lactation (Day 42)');
      expect(locHi.translateLactation('Early Lactation (Day 42)'), 'प्रारंभिक दुग्ध अवस्था (दिन 42)');
      expect(locMr.translateLactation('Early Lactation (Day 42)'), 'प्रारंभिक दुग्ध अवस्था (दिवस 42)');
    });

    test('Translates user roles across languages', () {
      expect(locEn.translateRole('Field Veterinarian'), 'Field Veterinarian');
      expect(locHi.translateRole('Field Veterinarian'), 'क्षेत्र पशुचिकित्सक');
      expect(locMr.translateRole('Field Veterinarian'), 'क्षेत्र पशुवैद्य');
    });

    test('Translates diagnostic factors and recommendations across languages', () {
      const factor = 'Elevated Somatic Cell Count (580,000 cells/mL > 250,000 threshold)';
      expect(locHi.translateFactor(factor), contains('बढ़ी हुई दैहिक कोशिका गणना'));
      expect(locMr.translateFactor(factor), contains('वाढलेली दैहिक पेशी गणना'));

      expect(locHi.translateRecommendation('Isolate animal immediately', 'HIGH'), contains('पशु को तुरंत अलग करें'));
      expect(locMr.translateRecommendation('Isolate animal immediately', 'HIGH'), contains('जनावराला त्वरित वेगळे करा'));
    });

    test('ReportExportService generates localized summaries', () {
      const cow = Cow(
        id: 'COW-104',
        name: 'Ganga',
        tagNumber: 'RFID-9821',
        breed: 'Gir / Sahiwal Cross',
        ageYears: 4,
        lactationStage: 'Early Lactation (Day 42)',
      );

      final milk = MilkMeasurement(
        cowId: 'COW-104',
        timestamp: DateTime.now(),
        milkTemperature: 38.5,
        ph: 6.9,
        conductivity: 6.2,
        scc: 650000,
        fat: 4.0,
        snf: 8.5,
      );

      final result = AnalysisResult(
        cowId: 'COW-104',
        prediction: 1,
        riskLevel: 'HIGH',
        probability: 0.88,
        factors: ['Elevated Somatic Cell Count (650,000 cells/mL > 250,000 threshold)'],
        recommendedAction: 'Isolate animal immediately.',
      );

      const service = ReportExportService();
      final reportHi = service.generateClinicalSummary(
        cow: cow,
        milkMeasurement: milk,
        result: result,
        localizations: locHi,
      );

      expect(reportHi, contains('गौ-प्रहरी नैदानिक मास्टिटिस रिपोर्ट'));
      expect(reportHi, contains('मास्टिटिस जोखिम स्तर'));
      expect(reportHi, contains('पशु को तुरंत अलग करें'));

      final reportMr = service.generateClinicalSummary(
        cow: cow,
        milkMeasurement: milk,
        result: result,
        localizations: locMr,
      );

      expect(reportMr, contains('गौ-प्रहरी नैदानिक मास्टिटिस अहवाल'));
      expect(reportMr, contains('मास्टिटिस धोका पातळी'));
      expect(reportMr, contains('जनावराला त्वरित वेगळे करा'));
    });
  });
}
