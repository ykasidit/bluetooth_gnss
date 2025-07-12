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
