import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pref/pref.dart';

const methodChannel =
      MethodChannel("com.clearevo.bluetooth_gnss/engine");
const eventChannel =
      EventChannel("com.clearevo.bluetooth_gnss/engine_events");
const settingsEventChannel = EventChannel("com.clearevo.bluetooth_gnss/settings_events");

Map<String, ValueNotifier<Map<DateTime, dynamic>>> paramMap = {};

class Message {
    final bool tx;
    final String name;
    final String contents;
    Message({required this.tx, required this.name, required this.contents});
    // Factory constructor to create a Message from a Map<String, Object>
    factory Message.fromMap(Map<dynamic, dynamic> map) {
      developer.log("got Message map: $map");
      return Message(
        tx: map['tx'] as bool? ?? false,
        name: map['name'] as String? ?? "",
        contents: map['contents'] as String? ?? "",
      );
    }
}

List<String> MESSAGE_NAMES_CACHE = [];
List<Message> MESSAGE_LIST_CACHE = [];
const maxMsgListSize = 1000;

void initEventChannels() {
    eventChannel.receiveBroadcastStream().listen((dynamic event) {
      Map<String, Map<DateTime, dynamic>> channel_paramMap = event as Map<String, Map<DateTime, dynamic>>? ?? {};
      if (channel_paramMap.containsKey("is_dev_msg_map")) {
        try {
          Message msg = Message.fromMap(channel_paramMap);
          if (!MESSAGE_NAMES_CACHE.contains(msg.name)) {
            MESSAGE_NAMES_CACHE.add(msg.name);
          }
          MESSAGE_LIST_CACHE.add(msg);
          if (MESSAGE_LIST_CACHE.length > maxMsgListSize) {
            MESSAGE_LIST_CACHE.removeAt(0);
          }
        } catch (e) {
          developer.log('parse msg exception: $e');
        }
        return; //update messages only
      } else {
        for (MapEntry<String, Map<DateTime, dynamic>> entry in channel_paramMap.entries) {
          String k = entry.key;
          Map<DateTime, dynamic> v = entry.value;
          if (!paramMap.containsKey(k)) {
            paramMap[k] = ValueNotifier(v);
          } else {
            paramMap[k]!.value  = entry.value;
          }
        }
      }
    }, onError: (dynamic error) {
      developer.log('Received error: ${error.message}');
    });
}

String getSelectedBdaddr(BasePrefService prefService) {
  return prefService.get("target_bdaddr") ?? "";
}

Future<String> getSelectedBdname(BasePrefService prefService) async {
  String bdaddr = getSelectedBdaddr(prefService);
  Map<dynamic, dynamic> bdMap = await getBdMap();
  if (!(bdMap.containsKey(bdaddr))) {
    return "";
  }
  return (bdMap[bdaddr] ?? "").toString();
}



Future<Map<dynamic, dynamic>> getBdMap() async {
  Map<String, String> ret = {};
  try {
    ret = (await methodChannel.invokeMethod<Map<String, String>>('get_bd_map')) ?? {};
  } on PlatformException catch (e) {
    String status = "warning: get_bd_map exception: '${e.message}'.";
    developer.log(status);
  }
  return ret;
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


  