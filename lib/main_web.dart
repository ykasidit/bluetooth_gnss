import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import 'package:bluetooth_gnss/src/rust/frb_generated.dart';
import 'ble_transport.dart';
import 'serial_transport.dart';
import 'gnss_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const WebApp());
}

class WebApp extends StatelessWidget {
  const WebApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth GNSS Web',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const WebHome(),
    );
  }
}

class WebHome extends StatefulWidget {
  const WebHome({super.key});
  @override
  State<WebHome> createState() => _WebHomeState();
}

enum TransportType { none, ble, serial }

class _WebHomeState extends State<WebHome> {
  final BleTransport _bleTransport = BleTransport();
  final SerialTransport _serialTransport = SerialTransport();
  final GnssEngine _engine = GnssEngine();

  final List<BleDevice> _devices = [];
  Map<String, dynamic> _liveParams = {};
  String _status = 'Ready';
  bool _scanning = false;
  bool _connected = false;
  TransportType _activeTransport = TransportType.none;

  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<Uint8List>? _dataSub;
  StreamSubscription<Map<String, dynamic>>? _posSub;
  StreamSubscription<String>? _transportStatusSub;

  @override
  void initState() {
    super.initState();
    _posSub = _engine.positionUpdates.listen((params) {
      setState(() => _liveParams = params);
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _dataSub?.cancel();
    _posSub?.cancel();
    _transportStatusSub?.cancel();
    _engine.dispose();
    _bleTransport.dispose();
    _serialTransport.dispose();
    super.dispose();
  }

  void _listenTransportStatus(Stream<String> statusStream) {
    _transportStatusSub?.cancel();
    _transportStatusSub = statusStream.listen((s) {
      setState(() => _status = s);
    });
  }

  // --- BLE ---

  Future<void> _startBleScan() async {
    setState(() {
      _devices.clear();
      _scanning = true;
      _status = 'Scanning for BLE devices...';
    });
    _listenTransportStatus(_bleTransport.statusStream);
    _scanSub = _bleTransport.startScan().listen((device) {
      setState(() {
        if (!_devices.any((d) => d.deviceId == device.deviceId)) {
          _devices.add(device);
        }
      });
    });
    Future<void>.delayed(const Duration(seconds: 10), () {
      if (_scanning) _stopBleScan();
    });
  }

  void _stopBleScan() {
    _bleTransport.stopScan();
    _scanSub?.cancel();
    setState(() {
      _scanning = false;
      _status = _devices.isEmpty ? 'No BLE devices found' : 'Select a device';
    });
  }

  Future<void> _connectBle(BleDevice device) async {
    _stopBleScan();
    setState(() => _status = 'Connecting to ${device.name ?? device.deviceId}...');

    _engine.start();
    _dataSub = _bleTransport.dataStream.listen((data) {
      _engine.feedBytes(data, protocolHint: _bleTransport.protocolHint);
    });

    await _bleTransport.connect(device.deviceId);
    setState(() {
      _connected = true;
      _activeTransport = TransportType.ble;
    });
  }

  // --- WebSerial ---

  Future<void> _connectSerial() async {
    _listenTransportStatus(_serialTransport.statusStream);

    _engine.start();
    _dataSub = _serialTransport.dataStream.listen((data) {
      _engine.feedBytes(data, protocolHint: 0); // NMEA/UBX stream
    });

    await _serialTransport.requestAndConnect(baudRate: 115200);
    if (_serialTransport.isConnected) {
      setState(() {
        _connected = true;
        _activeTransport = TransportType.serial;
      });
    }
  }

  // --- Disconnect ---

  Future<void> _disconnect() async {
    await _dataSub?.cancel();
    _engine.stop();
    if (_activeTransport == TransportType.ble) {
      await _bleTransport.disconnect();
    } else if (_activeTransport == TransportType.serial) {
      await _serialTransport.disconnect();
    }
    setState(() {
      _connected = false;
      _activeTransport = TransportType.none;
      _liveParams = {};
      _status = 'Disconnected';
    });
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth GNSS Web'),
        actions: [
          if (_connected)
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _connected ? _buildConnectedView() : _buildScanView(),
      ),
    );
  }

  Widget _buildScanView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_status, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),

        // Connection buttons
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _scanning ? _stopBleScan : _startBleScan,
              icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
              label: Text(_scanning ? 'Stop BLE Scan' : 'Scan BLE'),
            ),
            if (SerialTransport.isSupported)
              FilledButton.tonal(
                onPressed: _connectSerial,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.usb), SizedBox(width: 8), Text('Connect Serial')],
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),
        if (_scanning) const LinearProgressIndicator(),
        const SizedBox(height: 8),

        // BLE device list
        Expanded(
          child: _devices.isEmpty
              ? Center(
                  child: Text(
                    _scanning
                        ? 'Searching for BLE GNSS devices...'
                        : SerialTransport.isSupported
                            ? 'Scan BLE or connect a serial GNSS device'
                            : 'Press Scan BLE to find devices',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (ctx, i) {
                    final d = _devices[i];
                    return ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(d.name ?? 'Unknown'),
                      subtitle: Text(d.deviceId),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () { _connectBle(d); },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildConnectedView() {
    String transportLabel = _activeTransport == TransportType.ble
        ? 'BLE (${_bleTransport.protocolHint == 0 ? "NMEA/UBX" : "Qstarz"})'
        : 'Serial (NMEA)';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      _activeTransport == TransportType.ble
                          ? Icons.bluetooth_connected
                          : Icons.usb,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(_status, style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 8),
                  Text('Transport: $transportLabel',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildPositionCard(),
          const SizedBox(height: 16),
          _buildSatelliteCard(),
          const SizedBox(height: 16),
          _buildRawParamsCard(),
        ],
      ),
    );
  }

  Widget _buildPositionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Position', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _posRow('Latitude', _liveParams['lat']),
            _posRow('Longitude', _liveParams['lon']),
            _posRow('Altitude (m)', _liveParams['alt'] ?? _liveParams['ANY_alt']),
            _posRow('Speed (km/h)', _liveParams['speed_kmh']),
            _posRow('HDOP', _liveParams['hdop']),
            _posRow('VDOP', _liveParams['vdop']),
          ],
        ),
      ),
    );
  }

  Widget _buildSatelliteCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Satellites', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _posRow('Total in use', _liveParams['n_sats_used'] ?? _liveParams['n_sats']),
            _posRow('GPS', _liveParams['GP_n_sats_used']),
            _posRow('Galileo', _liveParams['GA_n_sats_used']),
            _posRow('GLONASS', _liveParams['GL_n_sats_used']),
            _posRow('BeiDou', _liveParams['GB_n_sats_used']),
          ],
        ),
      ),
    );
  }

  Widget _buildRawParamsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Raw params', style: Theme.of(context).textTheme.titleMedium),
                Text('${_liveParams.length} keys',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            ..._liveParams.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      child: Text(e.key,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text('${e.value}', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posRow(String label, dynamic value) {
    String display = '';
    if (value is double) {
      display = value.toStringAsFixed(6);
    } else if (value != null) {
      display = value.toString();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(display.isNotEmpty ? display : '--',
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

