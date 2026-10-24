import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/hardware_milk_tester.dart';
import '../../data/repositories/mock_milk_tester.dart';
import '../../data/services/arduino_data_parser.dart';
import '../../domain/entities/milk_measurement.dart';
import '../../domain/repositories/milk_data_provider.dart';

/// Connection mode for the handheld milk tester
enum TesterMode {
  hardware, // Live Arduino Bluetooth (HC-05)
  simulation, // Demo Simulation (Healthy/Clinical presets)
}

/// Controller managing milk tester UI state and measurement streams.
class MilkTesterController extends ChangeNotifier {
  MilkDataProvider _provider;
  StreamSubscription<MilkTestingState>? _subscription;

  TesterMode _mode = TesterMode.hardware;
  MilkTestingState _state = MilkTestingState.disconnected;
  MilkMeasurement? _measurement;
  ArduinoHardwareMetadata _hardwareMetadata = const ArduinoHardwareMetadata();
  String? _errorMessage;

  MilkTesterController({MilkDataProvider? provider})
      : _provider = provider ?? MockMilkTester() {
    _mode = _provider is HardwareMilkTester
        ? TesterMode.hardware
        : TesterMode.simulation;
    _state = _provider.state;
    _listenToProvider();
  }

  void _listenToProvider() {
    _subscription?.cancel();
    _subscription = _provider.stateStream.listen((state) {
      _state = state;
      if (_provider is HardwareMilkTester) {
        _hardwareMetadata = (_provider as HardwareMilkTester).latestMetadata;
      }
      notifyListeners();
    });
  }

  TesterMode get mode => _mode;
  bool get isHardwareMode => _mode == TesterMode.hardware;
  MilkTestingState get state => _state;
  MilkMeasurement? get measurement => _measurement;
  ArduinoHardwareMetadata get hardwareMetadata => _hardwareMetadata;
  String? get errorMessage => _errorMessage;
  MilkDataProvider get provider => _provider;

  bool get isBusy =>
      _state == MilkTestingState.searching ||
      _state == MilkTestingState.connecting ||
      _state == MilkTestingState.measuring;

  bool get hasMeasurement => _measurement != null;

  bool _isContinuousStreamActive = false;
  Timer? _streamTimer;

  bool get isContinuousStreamActive => _isContinuousStreamActive;

  /// Starts or stops continuous real-time live sensor streaming
  void toggleContinuousStream(String cowId) {
    if (_isContinuousStreamActive) {
      stopContinuousStream();
    } else {
      _isContinuousStreamActive = true;
      notifyListeners();
      takeMeasurement(cowId);
      _streamTimer?.cancel();
      _streamTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
        if (!_isContinuousStreamActive || isBusy) return;
        try {
          final result = await _provider.getMeasurement(cowId: cowId);
          _measurement = result;
          if (_provider is HardwareMilkTester) {
            _hardwareMetadata = (_provider as HardwareMilkTester).latestMetadata;
          }
          notifyListeners();
        } catch (_) {
          stopContinuousStream();
        }
      });
    }
  }

  void stopContinuousStream() {
    _streamTimer?.cancel();
    _streamTimer = null;
    _isContinuousStreamActive = false;
    notifyListeners();
  }

  /// Switch between Live Arduino Hardware and Demo Simulation mode
  void setMode(TesterMode newMode) {
    if (_mode == newMode) return;
    stopContinuousStream();
    _mode = newMode;
    _measurement = null;
    _errorMessage = null;
    _provider.disconnect();

    if (_mode == TesterMode.hardware) {
      _provider = HardwareMilkTester();
    } else {
      _provider = MockMilkTester();
    }
    _state = _provider.state;
    _listenToProvider();
    notifyListeners();
  }

  /// Trigger a milk measurement for the specified cow
  Future<void> takeMeasurement(String cowId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _provider.getMeasurement(cowId: cowId);
      _measurement = result;
      _state = _provider.state;
      if (_provider is HardwareMilkTester) {
        _hardwareMetadata = (_provider as HardwareMilkTester).latestMetadata;
      }
      _errorMessage = null;
    } catch (e) {
      if (e is PlatformException) {
        _errorMessage = e.message ?? e.code;
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      _state = MilkTestingState.error;
    } finally {
      notifyListeners();
    }
  }

  /// Change preset if provider is MockMilkTester
  void setPreset(MockSamplePreset preset) {
    if (_provider is MockMilkTester) {
      (_provider as MockMilkTester).activePreset = preset;
      notifyListeners();
    }
  }

  MockSamplePreset? get activePreset {
    if (_provider is MockMilkTester) {
      return (_provider as MockMilkTester).activePreset;
    }
    return null;
  }

  void reset() {
    stopContinuousStream();
    _measurement = null;
    _errorMessage = null;
    _hardwareMetadata = const ArduinoHardwareMetadata();
    _provider.disconnect();
    _state = _provider.state;
    notifyListeners();
  }

  @override
  void dispose() {
    stopContinuousStream();
    _subscription?.cancel();
    super.dispose();
  }
}
