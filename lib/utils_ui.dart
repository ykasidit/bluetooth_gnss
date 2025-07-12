import 'package:flutter/material.dart';

import 'native_channels.dart';


Future<void> toast(String msg) async {
  try {
    print("toast start");
    await methodChannel.invokeMethod("toast", {"msg": msg});
    print("toast done");
  } catch (e) {
    print("WARNING: toast failed exception: $e");
  }
}

void snackbar(BuildContext context, String msg) {
  try {
    final snackBar = SnackBar(content: Text(msg));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } catch (e) {
    print("WARNING: snackbar failed exception: $e");
  }
}
