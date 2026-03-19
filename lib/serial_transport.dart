import 'dart:async' show StreamController, unawaited;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// JS interop bindings for Web Serial API (not yet in the `web` package).
@JS('navigator.serial')
external JSObject? get _serialApi;

/// WebSerial transport for connecting to USB/serial GNSS receivers in the browser.
class SerialTransport {
  final _dataController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  JSObject? _port;
  JSObject? _reader;
  bool _connected = false;
  bool _reading = false;

  Stream<Uint8List> get dataStream => _dataController.stream;
  Stream<String> get statusStream => _statusController.stream;
  bool get isConnected => _connected;

  /// Check if Web Serial API is available in this browser.
  static bool get isSupported {
    try {
      return _serialApi != null;
    } catch (_) {
      return false;
    }
  }

  /// Request a serial port from the user (browser picker dialog) and connect.
  Future<void> requestAndConnect({int baudRate = 115200}) async {
    if (!isSupported) {
      _statusController.add('Web Serial API not supported in this browser');
      return;
    }
    try {
      _statusController.add('Requesting serial port...');

      // navigator.serial.requestPort()
      final serial = _serialApi!;
      final portPromise = serial.callMethod<JSPromise>('requestPort'.toJS);
      final port = await portPromise.toDart;
      _port = port as JSObject;

      // port.open({baudRate: baudRate})
      final options = JSObject();
      options['baudRate'] = baudRate.toJS;
      final openPromise = _port!.callMethod<JSPromise>('open'.toJS, options);
      await openPromise.toDart;

      _connected = true;
      _statusController.add('Serial connected at $baudRate baud');
      unawaited(_startReading());
    } catch (e) {
      _statusController.add('Serial connection failed: $e');
      _connected = false;
    }
  }

  Future<void> _startReading() async {
    if (_port == null || _reading) return;
    _reading = true;

    try {
      // port.readable.getReader()
      final readable = _port!['readable'] as JSObject;
      _reader = readable.callMethod<JSObject>('getReader'.toJS);

      while (_connected) {
        // reader.read() returns {done: bool, value: Uint8Array}
        final resultPromise = _reader!.callMethod<JSPromise>('read'.toJS);
        final result = await resultPromise.toDart as JSObject;

        final done = (result['done'] as JSBoolean).toDart;
        if (done) break;

        final value = result['value'];
        if (value != null) {
          final jsArray = value as JSUint8Array;
          _dataController.add(jsArray.toDart);
        }
      }
    } catch (e) {
      if (_connected) {
        _statusController.add('Serial read error: $e');
      }
    } finally {
      _reading = false;
      // Release reader lock
      try {
        _reader?.callMethod<JSAny?>('releaseLock'.toJS);
      } catch (_) {}
      _reader = null;
    }
  }

  Future<void> disconnect() async {
    _connected = false;

    // Cancel the reader first to unblock the read loop
    try {
      if (_reader != null) {
        final cancelPromise = _reader!.callMethod<JSPromise>('cancel'.toJS);
        await cancelPromise.toDart;
        _reader!.callMethod<JSAny?>('releaseLock'.toJS);
        _reader = null;
      }
    } catch (_) {}

    // Wait for reading loop to finish
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Close the port
    try {
      if (_port != null) {
        final closePromise = _port!.callMethod<JSPromise>('close'.toJS);
        await closePromise.toDart;
      }
    } catch (_) {}
    _port = null;
    _statusController.add('Serial disconnected');
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _statusController.close();
  }
}
