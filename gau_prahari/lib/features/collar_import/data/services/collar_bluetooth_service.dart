import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gau_prahari/features/collar_import/data/services/collar_bluetooth_parser.dart';
import 'package:gau_prahari/features/collar_import/data/services/collar_native_bluetooth_service.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';

enum CollarConnectionState {
  disconnected,
  connecting,
  streaming,
  error,
}

/// Service managing the live hardware Bluetooth connection to the Arduino Smart Collar
class CollarBluetoothService extends ChangeNotifier {
  final CollarNativeBluetoothService _bluetoothService;
  final CollarBluetoothParser _parser;

  CollarConnectionState _state = CollarConnectionState.disconnected;
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;
  String? _errorMessage;
  CollarHardwarePacket? _latestPacket;
  final List<CollarTelemetry> _accumulatedHistory = [];
  Timer? _pollingTimer;

  CollarBluetoothService({
    CollarNativeBluetoothService? bluetoothService,
    CollarBluetoothParser? parser,
  })  : _bluetoothService = bluetoothService ?? const CollarNativeBluetoothService(),
        _parser = parser ?? const CollarBluetoothParser();

  CollarConnectionState get state => _state;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get connectedDeviceAddress => _connectedDeviceAddress;
  String? get errorMessage => _errorMessage;
  CollarHardwarePacket? get latestPacket => _latestPacket;
  List<CollarTelemetry> get accumulatedHistory => List.unmodifiable(_accumulatedHistory);
  bool get isStreaming => _state == CollarConnectionState.streaming;

  /// Retrieves list of paired BT devices (HC-05 / Collar)
  Future<List<Map<String, String>>> getPairedDevices() async {
    return _bluetoothService.getPairedDevices();
  }

  /// Connects to selected Bluetooth device and starts receiving telemetry stream
  Future<bool> connect(String name, String address, {required String expectedCowId}) async {
    _state = CollarConnectionState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _bluetoothService.connect(address);
      if (!success) {
        _state = CollarConnectionState.error;
        _errorMessage = 'Could not connect to $name ($address)';
        notifyListeners();
        return false;
      }

      _connectedDeviceName = name;
      _connectedDeviceAddress = address;
      _state = CollarConnectionState.streaming;
      notifyListeners();

      _startStreamListener(expectedCowId);
      return true;
    } catch (e) {
      _state = CollarConnectionState.error;
      var msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('PlatformException(')) {
        final match = RegExp(r'PlatformException\([^,]+,\s*([^,]+),').firstMatch(msg);
        if (match != null && match.group(1) != null) {
          msg = match.group(1)!.trim();
        }
      }
      _errorMessage = msg;
      notifyListeners();
      return false;
    }
  }

  /// Ingests a raw line received from Bluetooth (or demo/test stream)
  void ingestLine(String rawLine, {required String expectedCowId}) {
    try {
      final packet = _parser.parse(rawLine);
      _latestPacket = packet;

      final telemetry = packet.toCollarTelemetry();
      _accumulatedHistory.add(telemetry);

      // Keep recent 14 telemetry points for real-time trend display
      if (_accumulatedHistory.length > 30) {
        _accumulatedHistory.removeAt(0);
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      // Ignored malformed lines
    }
  }

  void _startStreamListener(String expectedCowId) {
    _pollingTimer?.cancel();
    // Periodically read stream from native platform channel
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) async {
      if (_state != CollarConnectionState.streaming) return;
      try {
        final line = await _bluetoothService.readPacket();
        if (line.trim().isNotEmpty) {
          ingestLine(line, expectedCowId: expectedCowId);
        }
      } catch (_) {}
    });
  }

  /// Connects in simulated mode (e.g. on emulators or desktop without physical HC-05)
  void startDemoSimulation({required String expectedCowId}) {
    _state = CollarConnectionState.streaming;
    _connectedDeviceName = 'HC-05 (Arduino Collar)';
    _connectedDeviceAddress = '00:21:13:01:45:9A';
    _errorMessage = null;
    _accumulatedHistory.clear();
    notifyListeners();

    _pollingTimer?.cancel();
    int count = 0;
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_state != CollarConnectionState.streaming) {
        timer.cancel();
        return;
      }
      count++;
      final temp = 33.0 + (count % 3) * 0.4;
      final hum = 64.0 + (count % 4) * 0.8;
      final accX = (count % 2 == 0) ? 0.2 : 0.6;
      final accY = (count % 3 == 0) ? 0.8 : 0.4;
      final ir = 42000 + (count % 5) * 500;

      final simLine = 'ID:$expectedCowId|T:${temp.toStringAsFixed(1)}C|H:${hum.toStringAsFixed(1)}%|Acc[$accX,$accY]|IR:$ir';
      ingestLine(simLine, expectedCowId: expectedCowId);
    });
  }

  /// Creates a CollarHistory entity out of accumulated hardware readings
  CollarHistory toCollarHistory({required String cowId}) {
    if (_accumulatedHistory.isNotEmpty) {
      return CollarHistory(cowId: cowId, records: List.from(_accumulatedHistory));
    }
    // If fewer than 1 reading, generate current live point
    final fallbackPacket = _latestPacket ?? const CollarHardwarePacket(
      ambientTemp: 32.0,
      skinTemp: 37.8,
      humidity: 65.0,
      thi: 80.5,
      activityIndex: 62.0,
      accX: 0.1,
      accY: 0.8,
      irValue: 45000,
      isWorn: true,
    );
    return CollarHistory(
      cowId: cowId,
      records: [fallbackPacket.toCollarTelemetry()],
    );
  }

  void disconnect() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _state = CollarConnectionState.disconnected;
    _connectedDeviceName = null;
    _connectedDeviceAddress = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
