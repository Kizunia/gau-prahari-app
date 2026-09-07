import 'package:flutter/services.dart';

/// Native platform channel client communicating with Android Bluetooth RFCOMM (HC-05 / HC-06)
class NativeBluetoothService {
  static const MethodChannel _channel = MethodChannel('gau_prahari/bluetooth');

  const NativeBluetoothService();

  /// Requests Bluetooth / Nearby Devices runtime permissions
  Future<bool> requestPermissions() async {
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Retrieves list of paired Bluetooth devices on the Android phone
  Future<List<Map<String, String>>> getPairedDevices() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>('getPairedDevices');
      if (rawList == null) return [];

      return rawList.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return {
          'name': map['name']?.toString() ?? 'Unknown Device',
          'address': map['address']?.toString() ?? '',
        };
      }).toList();
    } on PlatformException catch (e) {
      if (e.code == 'BLUETOOTH_DISABLED') {
        throw Exception('Bluetooth is turned OFF. Please turn ON Bluetooth in Android Settings.');
      } else if (e.code == 'PERMISSION_DENIED') {
        throw Exception('Nearby devices / Bluetooth permission is required to connect to HC-05.');
      }
      return [];
    } on MissingPluginException {
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Connects to the HC-05 module by MAC address
  Future<bool> connect(String address) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('connect', {
        'address': address,
      });
      return success ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      rethrow;
    }
  }

  /// Checks whether the RFCOMM socket is currently open and connected
  Future<bool> isConnected() async {
    try {
      final bool? connected = await _channel.invokeMethod<bool>('isConnected');
      return connected ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Reads a single real-time line emitted by Arduino Serial over Bluetooth
  Future<String> readPacket() async {
    try {
      final String? packet = await _channel.invokeMethod<String>('readPacket');
      if (packet == null || packet.isEmpty) {
        throw Exception('Empty packet received from HC-05');
      }
      return packet;
    } on MissingPluginException {
      throw Exception('Platform Bluetooth channel not available');
    } catch (e) {
      rethrow;
    }
  }

  /// Closes the active Bluetooth socket
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (_) {}
  }
}
