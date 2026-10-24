import 'dart:async';
import '../../domain/entities/milk_measurement.dart';
import '../../domain/repositories/milk_data_provider.dart';
import '../services/arduino_data_parser.dart';
import '../services/native_bluetooth_service.dart';

/// Concrete [MilkDataProvider] implementation interfacing with physical Arduino HC-05 hardware
class HardwareMilkTester implements MilkDataProvider {
  final NativeBluetoothService _bluetoothService;
  final ArduinoDataParser _parser;
  String? _customStreamPacket;

  MilkTestingState _state = MilkTestingState.disconnected;
  final StreamController<MilkTestingState> _stateController =
      StreamController<MilkTestingState>.broadcast();

  ArduinoHardwareMetadata _latestMetadata = const ArduinoHardwareMetadata();

  final Duration connectionDelay;
  final Duration measurementDelay;

  HardwareMilkTester({
    NativeBluetoothService? bluetoothService,
    ArduinoDataParser? parser,
    this.connectionDelay = const Duration(milliseconds: 10),
    this.measurementDelay = const Duration(milliseconds: 10),
  }) : _bluetoothService = bluetoothService ?? const NativeBluetoothService(),
       _parser = parser ?? const ArduinoDataParser();

  @override
  MilkTestingState get state => _state;

  @override
  Stream<MilkTestingState> get stateStream => _stateController.stream;

  ArduinoHardwareMetadata get latestMetadata => _latestMetadata;

  /// Injects a custom stream packet (used during testing or debugging)
  void setStreamPacket(String packet) {
    _customStreamPacket = packet;
  }

  void _setState(MilkTestingState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  @override
  Future<MilkMeasurement> getMeasurement({required String cowId}) async {
    try {
      // If a custom debug packet is injected (e.g., during tests), parse it directly
      if (_customStreamPacket != null) {
        _setState(MilkTestingState.searching);
        await Future.delayed(const Duration(milliseconds: 10));
        _setState(MilkTestingState.connecting);
        await Future.delayed(const Duration(milliseconds: 10));
        _setState(MilkTestingState.connected);
        _setState(MilkTestingState.measuring);
        await Future.delayed(const Duration(milliseconds: 10));

        final parsed = _parser.parse(
          rawData: _customStreamPacket!,
          cowId: cowId,
        );
        _latestMetadata = parsed.metadata;
        _setState(MilkTestingState.completed);
        return parsed.measurement;
      }

      // Check if already connected to HC-05
      final isAlreadyConnected = await _bluetoothService.isConnected();

      if (!isAlreadyConnected) {
        // 1. Scan phone's paired devices for HC-05 / HC-06
        _setState(MilkTestingState.searching);
        final pairedDevices = await _bluetoothService.getPairedDevices();

        if (pairedDevices.isEmpty) {
          throw Exception(
            'No paired Bluetooth devices found on this phone. Please pair your HC-05 module in Android Settings -> Bluetooth (PIN: 1234), or switch to Demo Simulation.',
          );
        }

        // Match device named HC-05, HC-06, BT-05, Arduino, or Bluetooth
        final hc05 = pairedDevices.firstWhere(
          (d) {
            final name = (d['name'] ?? '').toUpperCase();
            return name.contains('HC-05') ||
                name.contains('HC-06') ||
                name.contains('BT-') ||
                name.contains('BLUETOOTH') ||
                name.contains('GAU') ||
                name.contains('ARDUINO');
          },
          orElse: () => pairedDevices
              .first, // fallback to first paired device if name differs
        );

        final address = hc05['address'] ?? '';
        if (address.isEmpty) {
          throw Exception(
            'Invalid Bluetooth address for device: ${hc05['name']}',
          );
        }

        // 2. Connect RFCOMM Socket to HC-05
        _setState(MilkTestingState.connecting);
        final connected = await _bluetoothService.connect(address);
        if (!connected) {
          throw Exception(
            'Failed to connect to ${hc05['name']} ($address). Please ensure HC-05 is not connected to any other app (e.g. Serial Terminal) and is powered ON.',
          );
        }
      }

      _setState(MilkTestingState.connected);

      // 3. Read live, real-time physical telemetry stream from Arduino (buffer is automatically flushed)
      _setState(MilkTestingState.measuring);
      final rawPacket = await _bluetoothService.readPacket();

      // 4. Parse physical hardware readings
      final parsed = _parser.parse(rawData: rawPacket, cowId: cowId);
      _latestMetadata = parsed.metadata;

      _setState(MilkTestingState.completed);
      return parsed.measurement;
    } catch (e) {
      _setState(MilkTestingState.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _bluetoothService.disconnect();
    _setState(MilkTestingState.disconnected);
    _latestMetadata = const ArduinoHardwareMetadata();
  }

  void dispose() {
    _stateController.close();
  }
}
