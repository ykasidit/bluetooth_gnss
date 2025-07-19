import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';


Future<void> wakelockEnable() async {
  if (await WakelockPlus.enabled == false) {
    await WakelockPlus
        .enable(); //keep screen on for users to continuously monitor connection state
  }
}

Future<void> wakelockDisable() async {
  if (await WakelockPlus.enabled == true) {
    await WakelockPlus
        .disable(); //keep screen on for users to continuously monitor connection state
  }
}

void notifyIfMapChanged(ValueNotifier<Map<dynamic, dynamic>> vn, Map<dynamic, dynamic> v)
{
  if (!mapEquals(vn.value, v)) {
    vn.value = v;
  }
}