import 'package:flutter/material.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/collar_import/domain/repositories/collar_data_provider.dart';

/// Controller managing collar history file importation, parsing, and telemetry state.
class CollarImportController extends ChangeNotifier {
  final CollarDataProvider _provider;

  CollarHistory? _history;
  bool _isLoading = false;
  String? _errorMessage;
  String? _sourceName;

  CollarImportController({required CollarDataProvider provider})
      : _provider = provider;

  CollarHistory? get history => _history;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get sourceName => _sourceName;
  bool get hasData => _history != null && _history!.isNotEmpty;

  /// Load from a bundled asset file (convenient for hackathon demos)
  Future<bool> loadFromAsset(
    String assetPath, {
    required String expectedCowId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _provider.loadFromAsset(
        assetPath,
        expectedCowId: expectedCowId,
      );
      _history = result;
      _sourceName = assetPath.split('/').last;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _history = null;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Parse from raw string (e.g. from file picker or pasted text)
  Future<bool> loadFromString(
    String rawContent, {
    required String expectedCowId,
    required String sourceName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _provider.parseData(
        rawContent,
        expectedCowId: expectedCowId,
      );
      _history = result;
      _sourceName = sourceName;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _history = null;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Directly set collar history (e.g. from live Bluetooth stream)
  void setCollarHistory(CollarHistory history, {required String sourceName}) {
    _history = history;
    _sourceName = sourceName;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _history = null;
    _errorMessage = null;
    _sourceName = null;
    notifyListeners();
  }
}
