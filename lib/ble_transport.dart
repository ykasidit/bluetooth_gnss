import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// Nordic UART Service UUIDs
const nordicUartServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const nordicUartTxCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
const nordicUartRxCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

/// Qstarz BLE UUIDs
const qstarzServiceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
const qstarzTxCharUuid = '0000fff1-0000-1000-8000-00805f9b34fb';

/// BLE transport that connects to a GNSS device and streams received bytes.
/// Supports Nordic UART Service (NMEA) and Qstarz BLE (proprietary binary).
class BleTransport {
  final _dataController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  String? _deviceId;
  bool _connected = false;

  /// 0 = NMEA/UBX (Nordic UART), 1 = Qstarz BLE chunk
  int protocolHint = 0;

  Stream<Uint8List> get dataStream => _dataController.stream;
  Stream<String> get statusStream => _statusController.stream;
  bool get isConnected => _connected;

  /// Start scanning for BLE GNSS devices.
  /// Returns a stream of discovered devices.
  Stream<BleDevice> startScan() {
    final controller = StreamController<BleDevice>();
    UniversalBle.onScanResult = (device) {
      controller.add(device);
    };
    // On web, scanning with service filters triggers the browser's device chooser.
    // Use service filters so the browser knows which services we need access to.
    UniversalBle.startScan(
      scanFilter: ScanFilter(
        withServices: [nordicUartServiceUuid, qstarzServiceUuid],
      ),
    ).catchError((e) {
      _statusController.add('BLE scan error: $e');
    });
    return controller.stream;
  }

  void stopScan() {
    UniversalBle.stopScan();
  }

  /// Connect to a BLE device and subscribe to GNSS data notifications.
  Future<void> connect(String deviceId) async {
    _deviceId = deviceId;
    _statusController.add('Connecting to $deviceId...');

    UniversalBle.onConnectionChange = (id, isConnected, error) {
      if (id != _deviceId) return;
      _connected = isConnected;
      if (isConnected) {
        _statusController.add('Connected');
        _discoverAndSubscribe(id);
      } else {
        _statusController.add('Disconnected${error != null ? ": $error" : ""}');
      }
    };

    UniversalBle.onValueChange = (id, charId, value) {
      if (id != _deviceId) return;
      _dataController.add(value);
    };

    await UniversalBle.connect(deviceId);
  }

  Future<void> _discoverAndSubscribe(String deviceId) async {
    try {
      List<BleService> services = await UniversalBle.discoverServices(deviceId);

      // Try Qstarz first
      for (var svc in services) {
        if (_uuidMatch(svc.uuid, qstarzServiceUuid)) {
          for (var ch in svc.characteristics) {
            if (_uuidMatch(ch.uuid, qstarzTxCharUuid)) {
              protocolHint = 1; // Qstarz BLE chunk
              _statusController.add('Found Qstarz BLE service');
              await UniversalBle.setNotifiable(deviceId, svc.uuid, ch.uuid, BleInputProperty.notification);
              return;
            }
          }
        }
      }

      // Try Nordic UART
      for (var svc in services) {
        if (_uuidMatch(svc.uuid, nordicUartServiceUuid)) {
          for (var ch in svc.characteristics) {
            if (_uuidMatch(ch.uuid, nordicUartTxCharUuid)) {
              protocolHint = 0; // NMEA/UBX stream
              _statusController.add('Found Nordic UART service');
              await UniversalBle.setNotifiable(deviceId, svc.uuid, ch.uuid, BleInputProperty.notification);
              return;
            }
          }
        }
      }

      _statusController.add('No supported GNSS service found');
    } catch (e) {
      _statusController.add('Service discovery failed: $e');
    }
  }

  Future<void> disconnect() async {
    if (_deviceId != null) {
      await UniversalBle.disconnect(_deviceId!);
    }
    _connected = false;
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _statusController.close();
  }

  bool _uuidMatch(String a, String b) {
    return a.toLowerCase() == b.toLowerCase();
  }
}
