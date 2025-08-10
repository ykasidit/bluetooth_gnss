import 'dart:developer' as developer;

import 'package:bluetooth_gnss/main.dart';
import 'package:bluetooth_gnss/utils.dart';
import 'package:bluetooth_gnss/utils_ui.dart';
import 'package:flutter/material.dart';
import 'package:pref/pref.dart';

import 'channels.dart';
import 'const.dart';
import 'home.dart';

enum ConnectState {
  Loading,
  PendingRequirements,
  ReadyToConnect,
  Connecting,
  Connected
}

ValueNotifier<ConnectState> connectState = ValueNotifier(ConnectState.Loading);
ValueNotifier<String> connectStatus = ValueNotifier("Loading status...");
ValueNotifier<String> connectSelectedDevice =
    ValueNotifier("Loading selected device...");
ValueNotifier<bool> isBtConnected = ValueNotifier(false);
ValueNotifier<DateTime> setLiveArgsTs = ValueNotifier(DateTime.now());
ValueNotifier<bool> isQstarz = ValueNotifier(false);
ValueNotifier<bool> isBtConnThreadConnecting = ValueNotifier(false);
ValueNotifier<int> mockLocationSetTs = ValueNotifier(0);
ValueNotifier<String> mockLocationSetStatus = ValueNotifier(waitingDev);
ValueNotifier<bool> isNtripConnected = ValueNotifier(false);
ValueNotifier<int> ntripPacketsCount = ValueNotifier(0);
final ValueNotifier<Map<String, Icon>> checkStateMapIcon = ValueNotifier({});
final ValueNotifier<Map<String, String>> bdMapNotifier = ValueNotifier({});

void paramMapSubscribe(String param)
{
  if (!paramMap.containsKey(param)) {
    paramMap[param] = ValueNotifier<dynamic>('');
  }
}

(String, String) getLatLon()
{
  var lat = paramMap['lat']?.value;
  var lon = paramMap['lon']?.value;
  if (lat != null && lon != null) {
    if (lat is double && lon is double) {
      String lats = lat.toStringAsFixed(POS_FRACTION_DIGITS);
      String lons = lon.toStringAsFixed(POS_FRACTION_DIGITS);
      return (lats, lons);
    }
  }
  return ("", "");
}

String getLatLonCsv()
{
  var (lat, lon) = getLatLon();
  if (lat.isEmpty || lon.isEmpty) {
    return "";
  }
  return "$lat,$lon"; //for share gmaps - no space after comma
}

Future<void> onFloatingButtonTap() async {
  ConnectState state = connectState.value;
  switch (state) {
    case ConnectState.Loading:
    case ConnectState.PendingRequirements:
      await toast("Not Ready: ${connectStatus.value}");
    case ConnectState.ReadyToConnect:
      await connect();
    case ConnectState.Connecting:
      await toast("Connecting, Please wait...");
    case ConnectState.Connected:
      await disconnect();
  }
}

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
          'reconnect': false, //TODO: retest/recode this feature - not well tested - users say no way to stop/disconnect when fail - prefService.get('reconnect') ?? false,
          'ble_gap_scan_mode': gapMode,
          'log_bt_rx_log_uri': log_bt_rx_log_uri,
          'disable_ntrip': prefService.get('disable_ntrip') ?? false,
          'ntrip_host': prefService.get('ntrip_host'),
          'ntrip_port': prefService.get('ntrip_port'),
          'ntrip_mountpoint': prefService.get('ntrip_mountpoint'),
          'ntrip_user': prefService.get('ntrip_user'),
          'ntrip_pass': prefService.get('ntrip_pass'),
          'autostart': autostart,

      'mock_timestamp_use_system_time': true,
      'mock_timestamp_offset_secs': double.parse(prefService.get('mock_timestamp_offset_secs') ?? "0.0"),
      'mock_lat_offset_meters': double.parse(prefService.get('mock_lat_offset_meters') ?? "0.0"),
      'mock_lon_offset_meters': double.parse(prefService.get('mock_lon_offset_meters') ?? "0.0"),
      'mock_alt_offset_meters': double.parse(prefService.get('mock_alt_offset_meters') ?? "0.0"),

        })) as bool? ??
        false;
    developer.log("main.dart connect() start connect done");
    if (ret) {
      status = "Connecting - please wait ...";
    } else {
      status = "Failed to connect...";
    }
    developer.log("main.dart connect() start2");
  } catch (e, t) {
    status = "Failed to start connection: '${e}'";
    developer.log(status+"$t");
  }

  developer.log("main.dart connect() start3");

  connectStatus.value = status;

  developer.log("main.dart connect() start4");

  developer.log("marin.dart connect() done");
}

Future<String> getSelectedBdSummary(BasePrefService prefService) async {
  //developer.log("get_selected_bd_summary 0");
  String ret = '';
  String bdaddr = getSelectedBdaddr(prefService);
  //developer.log("get_selected_bd_summary selected bdaddr: $bdaddr");
  String bdname = await getSelectedBdname(prefService);
  if (bdname.startsWith("QSTARZ")) {
    isQstarz.value = true;
  } else {
    isQstarz.value = false;
  }
  if (bdaddr.isEmpty) {
    ret += "No device selected";
  } else {
    ret += bdname;
    ret += " ($bdaddr)";
  }
  //developer.log("get_selected_bd_summary ret $ret");
  return ret;
}

Future<void> checkConnectState() async {
  Map<String, Icon> new_icon_map = {};
  ConnectState state = await _checkUpdateSelectedDev(new_icon_map);
  if (state.index <= ConnectState.ReadyToConnect.index) {
    notifyIfMapChanged(checkStateMapIcon, new_icon_map);
  }
  switch (state) {
    case ConnectState.Loading:
      floatingButtonIcon.value = Icons.access_time_rounded;
    case ConnectState.PendingRequirements:
      floatingButtonIcon.value = Icons.error_rounded;
    case ConnectState.ReadyToConnect:
      floatingButtonIcon.value = Icons.bluetooth_connected_rounded;
    case ConnectState.Connecting:
      floatingButtonIcon.value = Icons.access_time_rounded;
    case ConnectState.Connected:
      floatingButtonIcon.value = Icons.bluetooth_disabled_rounded;
  }
  connectState.value = state;
}

Future<ConnectState> _checkUpdateSelectedDev(
    Map<String, Icon> icon_map) async {
  try {
    isBtConnected.value =
        (await methodChannel.invokeMethod('is_bt_connected')) as bool? ?? false;
    isNtripConnected.value =
        (await methodChannel.invokeMethod('is_ntrip_connected')) as bool? ??
            false;
    ntripPacketsCount.value =
        (await methodChannel.invokeMethod('get_ntrip_cb_count')) as int? ?? 0;
    if (isBtConnected.value) {
      await wakelockEnable();
    } else {
      await wakelockDisable();
    }

    if (isBtConnected.value) {
      try {
        int mockSetMillisAgo;
        DateTime now = DateTime.now();
        int nowts = now.millisecondsSinceEpoch;
        mockLocationSetStatus.value = "";
        mockSetMillisAgo = nowts - mockLocationSetTs.value;
        //developer.log("mock_location_set_ts $mock_set_ts, nowts $nowts");

        double secsAgo = mockSetMillisAgo / 1000.0;

        if (mockLocationSetTs.value == 0) {
          mockLocationSetStatus.value = "Never";
        } else {
          mockLocationSetStatus.value =
              "${secsAgo.toStringAsFixed(3)} Seconds ago";
        }
      } catch (e, trace) {
        developer.log('get parsed param exception: $e $trace');
      }
      connectStatus.value = "Connected";
      return ConnectState.Connected;
    }
  } catch (e) {
    await toast("WARNING: check _is_bt_connected failed: $e");
    isBtConnected.value = false;
  }

  try {
    isBtConnThreadConnecting.value =
        await methodChannel.invokeMethod('is_conn_thread_alive') as bool? ??
            false;
    /*developer.log(
        "_is_bt_conn_thread_alive_likely_connecting: ${isBtConnThreadConnecting.value}");*/
    if (isBtConnThreadConnecting.value) {
      connectStatus.value = "Connecting...";
      return ConnectState.Connecting;
    }
  } catch (e) {
    await toast("WARNING: check _is_connecting failed: $e");
    isBtConnThreadConnecting.value = false;
  }

  ConnectState ret = ConnectState.PendingRequirements;

  List<String> notGrantedPermissions = await checkPermissions();
  if (notGrantedPermissions.isNotEmpty) {
    String msg =
        "Please allow required app permissions... Re-install app if declined earlier and not seeing permission request pop-up: $notGrantedPermissions";
    icon_map["App permissions"] = iconFail;
    connectStatus.value = msg;
    return ret;
  }

  icon_map["App permissions"] = iconOk;

  if (!(await isBluetoothOn())) {
    String msg = "Please turn ON Bluetooth...";
    icon_map["Bluetooth is OFF"] = iconFail;
    connectStatus.value = msg;
    return ret;
  }

  icon_map["Bluetooth powered ON"] = iconOk;
  //developer.log('check_and_update_selected_device5');

  Map<String, String> bdMap = await getBdMap();
  notifyIfMapChanged(bdMapNotifier, bdMap);
  bdMapNotifier.value;
  //developer.log('check_and_update_selected_device6 got bdMap: $bdMap');
  String selected_dev_sum = await getSelectedBdSummary(prefService);

  bool gapMode = prefService.get('ble_gap_scan_mode') ?? false;
  if (gapMode) {
    //bt ble gap broadcast mode
    icon_map["EcoDroidGPS-Broadcast device mode"] = iconOk;
  } else {
    //bt connect mode
    if (bdMap.isEmpty) {
      String msg =
          "Please pair your Bluetooth GPS/GNSS Receiver in phone Settings > Bluetooth first.\n\nClick floating button to go there...";
      icon_map["No paired Bluetooth devices"] = iconFail;
      connectStatus.value = msg;
      connectSelectedDevice.value = "No paired Bluetooth devices found...";
      return ret;
    }
    //developer.log('check_and_update_selected_device7');
    icon_map["Found paired Bluetooth devices"] = iconOk;

    //developer.log('check_and_update_selected_device8');

    //developer.log('check_and_update_selected_device9');

    if (getSelectedBdaddr(prefService).isEmpty ||
        (await getSelectedBdname(prefService)).isEmpty) {
      String msg =
          "Please select your Bluetooth GPS/GNSS Receiver in the Settings tab";
      /*Fluttertoast.showToast(
            msg: msg
        );*/

      icon_map["No device selected\n(select in settings tab)"] = iconFail;
      connectSelectedDevice.value = selected_dev_sum;
      connectStatus.value = msg;
      return ret;
    }
    icon_map["Target device selected:\n${connectSelectedDevice.value}"] =
        iconOk;
  }
  /* doesnt work in current targetsdk on some phones as in req emails, pixel 9?
  bool checkLocation = prefService.get('check_settings_location') ?? true;
  if (checkLocation) {
    if (!(await isLocationEnabled())) {
      String msg =
          "Location needs to be on and set to 'High Accuracy Mode' - Please go to phone Settings > Location to change this...";
      icon_map["Location must be ON and 'High Accuracy'"] = iconFail;
      connectStatus.value = msg;
      return ret;
    }
    //developer.log('check_and_update_selected_device13');
    icon_map["Location is on and 'High Accuracy'"] = iconOk;
  }*/

  if (!(await isMockLocationEnabled())) {
    String msg =
        "Please go to phone Settings > Developer Options > Under 'Debugging', set 'Mock Location app' to 'Bluetooth GNSS'...";
    icon_map["'Mock Location app' not 'Bluetooth GNSS'\n"] = iconFail;
    connectStatus.value = msg;
    return ret;
  }

  //ok - ready to connect
  icon_map["'Mock Location app' is 'Bluetooth GNSS'\nWARNING: If you want use internal GPS device again,\nSet 'Select mock location app' to 'Nothing'\n(in 'Developer Settings')."] = iconOk;
  connectStatus.value = "Please press the floating button to connect...";
  connectSelectedDevice.value = selected_dev_sum;

  return ConnectState.ReadyToConnect;
}

Future<void> setLiveArgs() async
{
  await methodChannel.invokeMethod('setLiveArgs', {
    'mock_timestamp_use_system_time': true,
    'mock_timestamp_offset_secs': double.parse(prefService.get('mock_timestamp_offset_secs') ?? "0.0"),
    'mock_lat_offset_meters': double.parse(prefService.get('mock_lat_offset_meters') ?? "0.0"),
    'mock_lon_offset_meters': double.parse(prefService.get('mock_lon_offset_meters') ?? "0.0"),
    'mock_alt_offset_meters': double.parse(prefService.get('mock_alt_offset_meters') ?? "0.0"),
  });
  developer.log("setLiveArgs setTs");
  setLiveArgsTs.value = DateTime.timestamp();
  developer.log("setLiveArgs setTs done: ${setLiveArgsTs.value}");
}