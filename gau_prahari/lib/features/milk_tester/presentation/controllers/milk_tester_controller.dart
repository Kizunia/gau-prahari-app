import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/mock_milk_tester.dart';
import '../../domain/entities/milk_measurement.dart';
import '../../domain/repositories/milk_data_provider.dart';

/// Controller managing milk tester UI state and measurement streams.
class MilkTesterController extends ChangeNotifier {
  final MilkDataProvider _provider;
  StreamSubscription<MilkTestingState>? _subscription;

  MilkTestingState _state = MilkTestingState.disconnected;
  MilkMeasurement? _measurement;
  String? _errorMessage;

  MilkTesterController({required MilkDataProvider provider})
      : _provider = provider {
    _state = _provider.state;
    _subscription = _provider.stateStream.listen((state) {
      _state = state;
      notifyListeners();
    });
  }

  MilkTestingState get state => _state;
  MilkMeasurement? get measurement => _measurement;
  String? get errorMessage => _errorMessage;
  MilkDataProvider get provider => _provider;

  bool get isBusy =>
      _state == MilkTestingState.searching ||
      _state == MilkTestingState.connecting ||
      _state == MilkTestingState.measuring;

  bool get hasMeasurement => _measurement != null;

  /// Trigger a milk measurement for the specified cow
  Future<void> takeMeasurement(String cowId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _provider.getMeasurement(cowId: cowId);
      _measurement = result;
      _state = _provider.state;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = MilkTestingState.error;
    } finally {
      notifyListeners();
    }
  }

  /// Change preset if provider is MockMilkTester
  void setPreset(MockSamplePreset preset) {
    if (_provider is MockMilkTester) {
      _provider.activePreset = preset;
      notifyListeners();
    }
  }

  MockSamplePreset? get activePreset {
    if (_provider is MockMilkTester) {
      return _provider.activePreset;
    }
    return null;
  }

  void reset() {
    _measurement = null;
    _errorMessage = null;
    _provider.disconnect();
    _state = _provider.state;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
