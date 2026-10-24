import 'package:flutter/material.dart';
import '../../domain/entities/cow.dart';
import '../../domain/repositories/cow_repository.dart';

/// ChangeNotifier that manages the full cattle list and cow-name editing.
class CowController extends ChangeNotifier {
  final CowRepository _repository;

  CowController({required CowRepository repository}) : _repository = repository;

  List<Cow> _cows = [];
  bool _isLoading = false;
  String? _error;

  List<Cow> get cows => List.unmodifiable(_cows);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<void> loadCows() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _cows = await _repository.getAllCows();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Add cow ───────────────────────────────────────────────────────────────

  /// Add a brand-new user-defined cow.  Returns an error message on failure.
  Future<String?> addCow({
    required String id,
    required String tagNumber,
    required String breed,
    required int ageYears,
    required String lactationStage,
    String status = 'Ready for Test',
    String? name,
  }) async {
    final trimmedId = id.trim().toUpperCase();
    if (trimmedId.isEmpty) return 'Cow ID is required';
    if (_cows.any((c) => c.id.toUpperCase() == trimmedId)) {
      return 'A cow with ID "$trimmedId" already exists';
    }
    final cow = Cow(
      id: trimmedId,
      tagNumber: tagNumber.trim().isEmpty ? trimmedId : tagNumber.trim(),
      breed: breed.trim().isEmpty ? 'Indigenous' : breed.trim(),
      ageYears: ageYears,
      lactationStage: lactationStage.trim().isEmpty ? 'Lactating' : lactationStage.trim(),
      status: status,
      name: name?.trim().isEmpty == true ? null : name?.trim(),
    );
    try {
      await _repository.saveCow(cow);
      await loadCows();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Edit name ─────────────────────────────────────────────────────────────

  /// Update (or clear) the farmer-assigned name for an existing cow.
  Future<String?> updateCowName(String cowId, String? name) async {
    try {
      await _repository.updateCowName(cowId, name);
      await loadCows();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<bool> deleteCow(String cowId) async {
    final deleted = await _repository.deleteCow(cowId);
    if (deleted) await loadCows();
    return deleted;
  }
}
