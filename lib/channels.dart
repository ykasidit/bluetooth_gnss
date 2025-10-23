import 'dart:async';
import 'dart:developer' as developer;

import 'package:bluetooth_gnss/connect.dart';
import 'package:bluetooth_gnss/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:pref/pref.dart';

import 'const.dart';

const methodChannel = MethodChannel("com.clearevo.bluetooth_gnss/engine");
const _eventChannel = EventChannel("com.clearevo.bluetooth_gnss/engine_events");

Map<String, ValueNotifier<dynamic>> paramMap = {};

class Message {
  final bool tx;
  final String name;
  final String contents;
  Message({required this.tx, required this.name, required this.contents});
  // Factory constructor to create a Message from a Map<String, Object>
  factory Message.fromMap(Map<dynamic, dynamic> map) {
    //developer.log("got Message map: $map");
    return Message(
      tx: map['tx'] as bool? ?? false,
      name: map['name'] as String? ?? "",
      contents: map['contents'] as String? ?? "",
    );
  }
}

List<String> MESSAGE_NAMES_CACHE = [];
List<Message> MESSAGE_LIST_CACHE = [];
const maxMsgListSize = 100;

StreamSubscription<dynamic> initEventChannels() {
  developer.log("initEventChannels()");
  return _eventChannel.receiveBroadcastStream().listen((dynamic event) {
    //developer.log("eventChannel got: $event");
    final channel_paramMap =
        (event as Map<Object?, Object?>).cast<String, dynamic>();

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
      dynamic mock_lat = channel_paramMap["mock_location_set_ts"];
      if (mock_lat != null && mock_lat is int) {
        mockLocationSetTs.value = mock_lat;
        try {
          int mockSetMillisAgo;
          DateTime now = DateTime.now();
          int nowts = now.millisecondsSinceEpoch;
          mockLocationSetStatus.value = "";
          mockSetMillisAgo = nowts - mockLocationSetTs.value;
          developer.log("mockSetMillisAgo: $mockSetMillisAgo");
          double secsAgo = mockSetMillisAgo / 1000.0;
          String state = 'NO valid location sent to other apps';
          bool ok = false;
          location_status_update_spinner_count += 1;
          String update_suffix = flashFrames[location_status_update_spinner_count%flashFrames.length];
          if (mockLocationSetTs.value == 0) {
          } else {
            state = "Location sent ${secsAgo.toStringAsFixed(3)} seconds ago";
            if (secsAgo < 3.0) {
              ok = true;
            } else {
              state += " (expired)";
            }
          }
          mockLocationSetStatus.value = (ok?okEmoji:errorEmoji)+" "+state + " " + update_suffix;
        } catch (e, trace) {
          developer.log('get parsed param exception: $e $trace');
        }
      }
      if (channel_paramMap["lat"] != null &&
          channel_paramMap["lat"] is double) {
        try {
          var pos = LatLng(channel_paramMap["lat"] as double,
              channel_paramMap["lon"] as double);
          mapExternalDevPos.value = pos;

          var pos_ori = LatLng(
              channel_paramMap["mock_location_base_lat"] as double,
              channel_paramMap["mock_location_base_lon"] as double);
          mapExternalDevPosOri.value = pos_ori;
        } catch (e, t) {
          developer.log("set mapExternalDevPos failed: $e: $t");
        }
      }
      for (MapEntry<String, dynamic> entry in channel_paramMap.entries) {
        String k = entry.key;
        if (!paramMap.containsKey(k)) {
          //not subscribed
        } else {
          paramMap[k]!.value = entry.value;
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
  Map<String, String> bdMap = await getBdMap();
  if (!(bdMap.containsKey(bdaddr))) {
    return "";
  }
  return (bdMap[bdaddr] ?? "").toString();
}

Future<Map<String, String>> getBdMap() async {
  Map<String, String> ret = {};
  try {
    var oret =
        await methodChannel.invokeMethod<Map<dynamic, dynamic>>('get_bd_map');
    ret = Map<String, String>.from(oret!);
  } catch (e, trace) {
    String status = "warning: get_bd_map exception: $e trace: $trace";
    developer.log(status);
  }
  return ret;
}

Future<bool> isBluetoothOn() async {
  bool? ret = false;
  try {
    ret = await methodChannel.invokeMethod<bool>('is_bluetooth_on');
  } catch (e, trace) {
    String status = "is_bluetooth_on error: '${e}': $trace";
    developer.log(status);
  }
  return ret!;
}

Future<List<String>> checkPermissions() async {
  List<String> ret = ['failed_to_list_ungranted_permissions'];
  try {
    var ret0 = await methodChannel
        .invokeMethod<List<dynamic>>('check_permissions_not_granted');
    ret = List<String>.from(ret0!);
  } catch (e, trace) {
    String status = "check_permissions_not_granted error: '${e}': $trace";
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
  } catch (e, trace) {
    String status = "is_location_enabled exception: '${e}': $trace";
    developer.log(status);
  }
  return ret!;
}

Future<bool> isCoarseLocationEnabled() async {
  bool? ret = false;
  try {
    //developer.log("is_coarse_location_enabled try0");
    ret = await methodChannel.invokeMethod<bool>('is_coarse_location_enabled');
    //developer.log("is_coarse_location_enabled got ret: $ret");
  } catch (e, trace) {
    String status = "is_coarse_location_enabled exception: '${e}': $trace";
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
  } catch (e, trace) {
    String status = "is_mock_location_enabled exception: '${e}': $trace";
    developer.log(status);
  }
  return ret!;
}
