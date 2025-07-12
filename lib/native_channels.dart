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

void initEventChannel() {
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
