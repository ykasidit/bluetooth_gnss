import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pref/pref.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screen_settings.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const methodChannel =
      MethodChannel("com.clearevo.bluetooth_gnss/engine");
const eventChannel =
      EventChannel("com.clearevo.bluetooth_gnss/engine_events");
const settingsEventChannel = EventChannel("com.clearevo.bluetooth_gnss/settings_events");

void initEventChannels() {
    eventChannel.receiveBroadcastStream().listen((dynamic event) {
      Map<dynamic, dynamic> paramMap = event as Map<dynamic, dynamic>? ?? {};
      if (paramMap.containsKey("is_dev_msg_map")) {
        developer.log("got event is_dev_msg_parse");
        try {
          Message msg = Message.fromMap(paramMap);
          if (!uniqueNames.contains(msg.name)) {
            uniqueNames.add(msg.name);
          }
          msgList.add(msg);
          if (msgList.length > maxMsgListSize) {
            msgList.removeAt(0);
          }
          if (filteredMessages.length > maxMsgListSize) {
            filteredMessages.removeAt(0);
          }
          if (isMessageInFilter(msg)) {
            setState(() {
              filteredMessages.add(msg);
            });
          }
        } catch (e) {
          developer.log('parse msg exception: $e');
        }
        return; //update messages only
      } else {
        developer.log("got event pos update");
        setState(() {
          _paramMap = paramMap;
        });
        // 660296614
        if (paramMap.containsKey('mock_location_set_ts')) {
          try {
            _mockLocationSetTs = (paramMap['mock_location_set_ts'] ?? 0) as int? ?? 0;
          } catch (e) {
            developer.log('get parsed param exception: $e');
          }
        }
      }
    }, onError: (dynamic error) {
      developer.log('Received error: ${error.message}');
    });
}

Future<String> getSelectedBdname(BasePrefService prefService) async {
  String bdaddr = getSelectedBdaddr(prefService);
  //developer.log("get_selected_bdname: bdaddr: $bdaddr");
  Map<dynamic, dynamic> bdMap = await getBdMap();
  if (!(bdMap.containsKey(bdaddr))) {
    return "";
  }
  return (bdMap[bdaddr] ?? "").toString();
}

Future<String> getSelectedBdSummary(BasePrefService prefService) async {
  //developer.log("get_selected_bd_summary 0");
  String ret = '';
  String bdaddr = getSelectedBdaddr(prefService);
  //developer.log("get_selected_bd_summary selected bdaddr: $bdaddr");
  String bdname = await getSelectedBdname(prefService);
  if (bdname.startsWith("QSTARZ")) {
    isQstarz = true;
  } else {
    isQstarz = false;
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

Future<Map<dynamic, dynamic>> getBdMap() async {
  Map<dynamic, dynamic>? ret;
  try {
    ret =
    await methodChannel.invokeMethod<Map<dynamic, dynamic>>('get_bd_map');
    //developer.log("got bt_map: $ret");
  } on PlatformException catch (e) {
    String status = "warning: get_bd_map exception: '${e.message}'.";
    developer.log(status);
  }
  return ret ?? {};
}

Future<bool> isBluetoothOn() async {
  bool? ret = false;
  try {
    ret = await methodChannel.invokeMethod<bool>('is_bluetooth_on');
  } on PlatformException catch (e) {
    String status = "is_bluetooth_on error: '${e.message}'.";
    developer.log(status);
  }
  return ret!;
}

Future<List<String>> checkPermissions() async {
  List<String> ret = ['failed_to_list_ungranted_permissions'];
  try {
    List<Object?>? ret0 = await methodChannel
        .invokeMethod<List<Object?>>('check_permissions_not_granted');
    ret.clear();
    for (Object? o in ret0 ?? []) {
      ret.add((o ?? "").toString());
    }
  } on PlatformException catch (e) {
    String status = "check_permissions_not_granted error: '${e.message}'.";
    (status);
  }
  return ret;
}

Future<bool> isLocationEnabled() async {
  bool? ret = false;
  try {
    //developer.log("is_location_enabled try0");
    ret = await methodChannel.invokeMethod<bool>('is_location_enabled');
    //developer.log("is_location_enabled got ret: $ret");
  } on PlatformException catch (e) {
    String status = "is_location_enabled exception: '${e.message}'.";
    developer.log(status);
  }
  return ret!;
}

Future<bool> isCoarseLocationEnabled() async {
  bool? ret = false;
  try {
    //developer.log("is_coarse_location_enabled try0");
    ret =
    await methodChannel.invokeMethod<bool>('is_coarse_location_enabled');
    //developer.log("is_coarse_location_enabled got ret: $ret");
  } on PlatformException catch (e) {
    String status = "is_coarse_location_enabled exception: '${e.message}'.";
    developer.log(status);
  }
  return ret!;
}

Future<bool> isMockLocationEnabled() async {
  bool? ret = false;
  try {
    //developer.log("is_mock_location_enabled try0");
    ret = await methodChannel.invokeMethod<bool>('is_mock_location_enabled');
    //developer.log("is_mock_location_enabled got ret $ret");
  } on PlatformException catch (e) {
    String status = "is_mock_location_enabled exception: '${e.message}'.";
    developer.log(status);
  }
  return ret!;
}


  