
import 'package:flutter/material.dart';
import 'package:pref/pref.dart';

import 'channels.dart';
import 'connect.dart';

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
const iconWarning = Icon(
  Icons.warning,
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
    await methodChannel.invokeMethod("toast", {"msg": msg});
    dlog("toast: $msg");
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

List<Widget> paramRowList(BuildContext context, List<List<String>> m) {
  return m.map((me) => paramRow(context, me[1], title: me[0])).toList()
      as List<Widget>;
}

DateTime tsToDateTime(int ts_millis) {
  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(ts_millis);
  return dateTime;
}

String tsToDateTimeStr(int ts_millis) {
  DateTime dateTime = tsToDateTime(ts_millis);
  return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
      "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}.${dateTime.millisecond.toString().padLeft(3, '0')}";
}

String? validateDouble(String? newValue) {
  double? tsoffset = double.tryParse(newValue ?? "");
  if (tsoffset == null) {
    return "Numbers with fractions only";
  }
  return null;
}

String? validateDoublePositive(String? newValue) {
  double? tsoffset = double.tryParse(newValue ?? "");
  if (tsoffset == null) {
    return "Numbers with fractions only";
  }
  if (tsoffset <= 0) {
    return "Greater than 0 only";
  }
  return null;
}

Row paramRow(BuildContext context, String param,
    {TextStyle? style, int double_fraction_digits = 2, String title = ""}) {
  paramMapSubscribe(param);
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Text(
        '${title.isEmpty ? param.toUpperCase() : title}',
        style: style,

      ),
      ValueListenableBuilder<dynamic>(
        valueListenable: paramMap[param]!,
        builder: (context, value, child) {
          if (value is double) {
            if (param.endsWith("_lat") || param.endsWith("_lon")) {
              double_fraction_digits = 7;
            }
            value = value.toStringAsFixed(double_fraction_digits);
          } else if (param.endsWith("_ts") && value is int) {
            value = tsToDateTimeStr(value);
          } else if (param.endsWith("_n_bytes") && value is int) {
            value = "${(value/1000).toInt()} kB";
          } else if (param.endsWith("_folder") && value is String) {
            value = display_dir(value);
          }
          //dlog("paramRow updated - param: $param value: $value");
          return Expanded(
              child: Text(
                value == null ? 'No data':'$value',
                textAlign: TextAlign.end,
                style: style,
                softWrap: true,
                overflow: TextOverflow.fade,
              )
          );
        },
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

Widget reactiveIconMapCard(ValueNotifier<Map<String, Icon>> value) {
  return ValueListenableBuilder<Map<String, Icon>>(
    valueListenable: value,
    builder: (BuildContext context, Map<String, Icon> _checkStateMapIcon,
        Widget? child) {
      dlog("reactiveIconMapCard build");
      List<Widget> checklist = [];
      for (String key in _checkStateMapIcon.keys) {
        Row row = Row(mainAxisAlignment: MainAxisAlignment.start, children: [
          _checkStateMapIcon[key]!,
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                key,
                style: Theme.of(context).textTheme.bodySmall,
                softWrap: true,
                overflow: TextOverflow.fade,
              ),
            ),
        ]);
        checklist.add(row);
      }

      return Card(
          child: Container(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: checklist,
        ),
      ));
    },
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

Widget reactivePrefDropDown(String pref_key, String title,
    ValueNotifier<Map<String, String>> bdaddr_to_name_map) {
  return ValueListenableBuilder<Map<String, String>>(
    valueListenable: bdaddr_to_name_map,
    builder: (BuildContext context, Map<String, String> bdaddr_to_name_map,
        Widget? child) {
      dlog("reactivePrefDropDown build");
      List<DropdownMenuItem<String>> devlist = List.empty(growable: true);
      for (MapEntry<String, String> entry in bdaddr_to_name_map.entries) {
        devlist
            .add(DropdownMenuItem(value: entry.key, child: Text(entry.value)));
      }
      return PrefDropdown(title: Text(title), items: devlist, pref: pref_key);
    },
  );
}

String display_dir(String dir)
{
     return dir.replaceFirst("/storage/emulated/0/", "Internal storage: ");
}
