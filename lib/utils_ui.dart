import 'package:flutter/material.dart';

import 'native_channels.dart';

const double defaultChecklistIconSize = 35;
const double defaultConnectStateIconSize = 60;

const iconNotConnected = Icon(
  Icons.bluetooth_disabled,
  color: Colors.red,
  size: defaultConnectStateIconSize,
);
const iconBluetoothSettings = Icon(
  Icons.settings_bluetooth,
  color: Colors.white,
);
const iconConnect = Icon(
  Icons.bluetooth_connected,
  color: Colors.white,
);
const iconConnecting = Icon(
  Icons.bluetooth_connected,
  color: Colors.white,
);
const iconConnected = Icon(
  Icons.bluetooth_connected,
  color: Colors.blue,
  size: defaultConnectStateIconSize,
);
const iconLoading = Icon(
  Icons.access_time,
  color: Colors.grey,
  size: defaultConnectStateIconSize,
);
const iconOk = Icon(
  Icons.check_circle,
  color: Colors.lightBlueAccent,
  size: defaultChecklistIconSize,
);
const iconFail = Icon(
  Icons.cancel,
  color: Colors.blueGrey,
  size: defaultChecklistIconSize,
);

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

Row paramRow(BuildContext context, String param, {TextStyle? style}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Text('${param.toUpperCase()}:',
          style: Theme.of(context).textTheme.headlineSmall),
      ValueListenableBuilder<Map<DateTime, dynamic>>(
        valueListenable: paramMap[param] ?? ValueNotifier({}),
        builder: (context, value, child) => Text(
          '${value.values.first ?? ""} ',
          style: style,
        ),
      ),
    ],
  );
}

/// Builds a reactive [Text] widget from a [ValueNotifier<String>].
Widget reactiveText(
    ValueNotifier<dynamic> value, {
      TextStyle? style,
      TextAlign? textAlign,
      int? maxLines,
    }) {
  return ValueListenableBuilder<dynamic>(
    valueListenable: value,
    builder: (_, val, __) => Text(
      "$val",
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
    ),
  );
}

/// Builds a reactive [Icon] widget from a [ValueNotifier<IconData>].
Widget reactiveIcon(
    ValueNotifier<IconData> value, {
      double? size,
      Color? color,
    }) {
  return ValueListenableBuilder<IconData>(
    valueListenable: value,
    builder: (_, val, __) => Icon(val, size: size, color: color),
  );
}

/// Builds a reactive [Visibility] widget from a [ValueNotifier<bool>].
Widget reactiveVisibility(
    ValueNotifier<bool> value, {
      required Widget child,
    }) {
  return ValueListenableBuilder<bool>(
    valueListenable: value,
    builder: (_, visible, __) => Visibility(visible: visible, child: child),
  );
}

