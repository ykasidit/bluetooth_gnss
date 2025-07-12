import 'package:bluetooth_gnss/main.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'native_channels.dart';

import 'const.dart';

ValueNotifier<String> connectStatus = ValueNotifier("Loading status...");
ValueNotifier<String> connectSelectedDevice = ValueNotifier("Loading selected device...");
ValueNotifier<bool> isBtConnected = ValueNotifier(false);
ValueNotifier<bool> isQstarz = ValueNotifier(false);
ValueNotifier<bool> isBtConnThreadConnecting = ValueNotifier(false);
ValueNotifier<int> mockLocationSetTs = ValueNotifier(0);
ValueNotifier<String> mockLocationSetStatus = ValueNotifier(waitingDev);
ValueNotifier<bool> isNtripConnected = ValueNotifier(false);
ValueNotifier<int> ntripPacketsCount = ValueNotifier(0);



Future<void> disconnect() async {
  try {
    //call it in any case just to be sure service it is stopped (.close()) method called
    await methodChannel.invokeMethod('disconnect');
  } on Exception catch (e, trace) {
    developer.log("WARNING: disconnect failed exception: $e $trace");
  }
}

Future<void> connect() async {
  developer.log("main.dart connect() start");
  String log_bt_rx_log_uri = prefService.get('log_bt_rx_log_uri') ?? "";
  bool autostart = prefService.get('autostart') ?? false;
  bool gapMode = prefService.get('ble_gap_scan_mode') ?? false;
  String log_uri = prefService.get('log_bt_rx_log_uri') as String? ?? "";
  if (log_bt_rx_log_uri.isNotEmpty) {
    bool writeEnabled = false;
    writeEnabled =
          (await methodChannel.invokeMethod('is_write_enabled')) as bool? ??
              false;
    if (writeEnabled == false) {
      throw "Write external storage permission required for data loggging...";
    }
    bool canCreateFile = false;
    canCreateFile = (await methodChannel.invokeMethod(
        'test_can_create_file_in_chosen_folder',
        {"log_bt_rx_log_uri": log_uri})) as bool? ??
        false;
    if (canCreateFile == false) {
      throw "Please go to Settings > re-tick 'Enable logging' (failed to access chosen log folder)";
    }
  }
  if (gapMode) {
    bool coarseLocationEnabled = await isCoarseLocationEnabled();
    if (coarseLocationEnabled == false) {
      throw "Coarse Locaiton permission required for BLE GAP mode...";
    }
  }

  if (isBtConnected.value) {
    throw "Already connected...";
  }

  if (isBtConnThreadConnecting.value) {
    throw "Already connecting, please wait...";
  }

  bool connecting = false;
  connecting =
        (await methodChannel.invokeMethod('is_conn_thread_alive')) as bool? ??
            false;  
  if (connecting) {
    throw "Already connecting, please wait...";
  }

  String bdaddr = prefService.get("target_bdaddr") as String? ?? "";
  if (bdaddr.isEmpty) {    
    throw "No bluetooth device selected in settings";
  }
  developer.log("main.dart connect() start1");
  paramMap.clear();
  
  String status = "unknown";
  try {
    developer.log("main.dart connect() start connect start");
    final bool ret = (await methodChannel.invokeMethod('connect', {
          "bdaddr": bdaddr,
          'secure': prefService.get('secure') ?? true,
          'reconnect': prefService.get('reconnect') ?? false,
          'ble_gap_scan_mode': gapMode,
          'log_bt_rx_log_uri': log_bt_rx_log_uri,
          'disable_ntrip': prefService.get('disable_ntrip') ?? false,
          'ntrip_host': prefService.get('ntrip_host'),
          'ntrip_port': prefService.get('ntrip_port'),
          'ntrip_mountpoint': prefService.get('ntrip_mountpoint'),
          'ntrip_user': prefService.get('ntrip_user'),
          'ntrip_pass': prefService.get('ntrip_pass'),
          'autostart': autostart,
        })) as bool? ??
        false;
    developer.log("main.dart connect() start connect done");
    if (ret) {
      status = "Connecting - please wait ...";
    } else {
      status = "Failed to connect...";
    }
    developer.log("main.dart connect() start2");
  } on PlatformException catch (e) {
    status = "Failed to start connection: '${e.message}'.";
    developer.log(status);
  }

  developer.log("main.dart connect() start3");

  connectStatus.value = status;

  developer.log("main.dart connect() start4");

  developer.log("marin.dart connect() done");
}

Map<String, String> QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP = {
  'B': "POI",
  'T': "time",
  'D': 'distance',
  'S': 'speed'
};

String getQstarzRCRLogType(int? asciiCode) {
  if (asciiCode == null) {
    return "";
  }
  String character = String.fromCharCode(asciiCode);
  String? lt = QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP[character];
  return "$character${lt == null ? '' : ' ($lt)'}";
}

String getgetQstarzDateime(int? timestampS, int? millisecond) {
  if (timestampS == null || millisecond == null) {
    return "";
  }
  DateTime dateTime =
  DateTime.fromMillisecondsSinceEpoch(timestampS * 1000 + millisecond);
  return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
      "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}.${millisecond.toString().padLeft(3, '0')}";
}

