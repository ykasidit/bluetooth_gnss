import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_gnss/src/rust/api/simple.dart';

/// Lightweight GNSS engine that feeds bytes from any transport into the Rust
/// parser via flutter_rust_bridge, then exposes parsed results as a stream.
class GnssEngine {
  final _positionController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  final Map<String, dynamic> params = {};
  bool _connected = false;

  Stream<Map<String, dynamic>> get positionUpdates => _positionController.stream;
  Stream<String> get statusUpdates => _statusController.stream;
  bool get isConnected => _connected;

  void start() {
    parserReset();
    params.clear();
    _connected = true;
    _statusController.add('Connected');
  }

  void stop() {
    _connected = false;
    _statusController.add('Disconnected');
  }

  /// Feed raw bytes from a BLE/serial transport into the Rust parser.
  /// [protocolHint] 0 = NMEA/UBX stream, 1 = Qstarz BLE chunk.
  void feedBytes(Uint8List data, {int protocolHint = 0}) {
    if (data.isEmpty) return;
    String jsonStr = parserFeed(data: data, protocolHint: protocolHint);
    if (jsonStr.isEmpty || jsonStr == '[]') return;

    try {
      List<dynamic> parsed = jsonDecode(jsonStr) as List<dynamic>;
      for (var obj in parsed) {
        if (obj is Map<String, dynamic>) {
          _mergeParams(obj);
          _positionController.add(Map.from(params));
        }
      }
    } catch (e) {
      _statusController.add('Parse error: $e');
    }
  }

  void _mergeParams(Map<String, dynamic> obj) {
    for (var entry in obj.entries) {
      params[entry.key] = entry.value;
    }
  }

  void dispose() {
    stop();
    _positionController.close();
    _statusController.close();
  }
}
