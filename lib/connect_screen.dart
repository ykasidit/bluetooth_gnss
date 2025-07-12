import 'package:bluetooth_gnss/connect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pref/pref.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:developer' as developer;

import 'const.dart';
import 'native_channels.dart';
import 'utils_ui.dart';

const BT_ON = "Bluetooth On";
const BT_PAIRED = "Bluetooth Device Paired";
const BT_SELECTED = "Bluetooth Device Selected";

final Map<String, Icon> _checkStateMapIcon = {
  BT_ON: iconLoading,
  BT_PAIRED: iconLoading,
  BT_SELECTED: iconLoading,
};

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<Widget> rows = List.empty();
    rows.add(
        ValueListenableBuilder<bool>(
          valueListenable: isBtConnThreadConnecting,
          builder: (context, value, child) => value ? Column(children: connectingRows(context)) : Column(),
        )
    );
    rows.add(
        ValueListenableBuilder<bool>(
          valueListenable: isBtConnected,
          builder: (context, value, child) => Column(children: value? connectedRows(context): notConnectedRows(context))
        )
    );
    return SingleChildScrollView(
        child: Padding(
      padding: const EdgeInsets.all(5.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: rows,
      ),
    ));
  }

  List<Widget> connectedRows(BuildContext context) {
    return <Widget>[
      Card(
        child: Container(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: <Widget>[
              Text(
                'Live status',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontFamily: 'GoogleSans', color: Colors.blueGrey),
              ),
              paramRow(context, 'lat'),
              paramRow(context, 'lon'),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      String content =
                          "${paramMap['lat_double_07_str'] ?? waitingDev},${paramMap['lon_double_07_str'] ?? waitingDev}"; //no space after comma for sharing to gmaps
                      Share.share(
                          'https://www.google.com/maps/search/?api=1&query=$content')
                          .then((result) {
                        snackbar(context, 'Shared: $content');
                      });
                    },
                    child: const Icon(Icons.share),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(2.0),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      String content =
                          "${paramMap['lat_double_07_str'] ?? waitingDev},${paramMap['lon_double_07_str'] ?? waitingDev}";
                      Clipboard.setData(ClipboardData(text: content))
                          .then((result) {
                        snackbar(
                            context, 'Copied to clipboard: $content');
                      });
                    },
                    child: const Icon(Icons.content_copy),
                  )
                ],
              )
            ] +
                getDevSepcificRows(context) +
                [
                  const Padding(
                    padding: EdgeInsets.all(5.0),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('Location sent to Android:',
                          style: Theme.of(context).textTheme.bodySmall),
                      reactiveText(mockLocationSetStatus,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  paramRow(context, 'alt_type'),
                  const Padding(
                    padding: EdgeInsets.all(5.0),
                  ),
                  paramRow(context, 'gga_count'),
                  paramRow(context, 'rmc_count'),
                  paramRow(context, 'log_folder'),
                  paramRow(context, 'logfile_name'),
                  paramRow(context, 'logfile_size_mb'),
                ],
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(10.0),
      ),
      Card(
        child: Container(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: <Widget>[
                Text(
                  'Connected',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(fontFamily: 'GoogleSans', color: Colors.grey),
                ),
                const Padding(
                  padding: EdgeInsets.all(5.0),
                ),
                iconConnected,
                const Padding(
                  padding: EdgeInsets.all(5.0),
                ),
                Text(connectSelectedDevice.value),
                const Padding(
                  padding: EdgeInsets.all(5.0),
                ),
                Text(
                    "- You can now use other apps like 'Waze' normally.\n- Location is now from connected device\n- To stop, press the 'Disconnect' menu in top-right options.",
                    style: Theme.of(context).textTheme.bodySmall),
                const Padding(
                  padding: EdgeInsets.all(5.0),
                ),
              ],
            )),
      ),
      Padding(
          padding: const EdgeInsets.all(5.0),
          child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isNtripConnected.value
                          ? 'NTRIP Connected'
                          : 'NTRIP Not Connected',
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontFamily: 'GoogleSans',
                        color: Colors.blueGrey,
                      ),
                    ),
                    const Padding(padding: EdgeInsets.all(10.0)),
                    Text((PrefService.of(context).get('ntrip_host') != null &&
                        PrefService.of(context).get('ntrip_port') != null)
                        ? "${PrefService.of(context).get('ntrip_host')}:${PrefService.of(context).get('ntrip_port')}"
                        : ''),
                    const Padding(padding: EdgeInsets.all(10.0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text("NTRIP Server/Login filled:",
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(
                            (PrefService.of(context).get('ntrip_host') != null &&
                                PrefService.of(context)
                                    .get('ntrip_host')
                                    .toString()
                                    .isNotEmpty &&
                                PrefService.of(context).get('ntrip_port') !=
                                    null &&
                                PrefService.of(context)
                                    .get('ntrip_port')
                                    .toString()
                                    .isNotEmpty &&
                                PrefService.of(context)
                                    .get('ntrip_mountpoint') !=
                                    null &&
                                PrefService.of(context)
                                    .get('ntrip_mountpoint')
                                    .toString()
                                    .isNotEmpty &&
                                PrefService.of(context).get('ntrip_user') !=
                                    null &&
                                PrefService.of(context)
                                    .get('ntrip_user')
                                    .toString()
                                    .isNotEmpty &&
                                PrefService.of(context).get('ntrip_pass') !=
                                    null &&
                                PrefService.of(context)
                                    .get('ntrip_pass')
                                    .toString()
                                    .isNotEmpty)
                                ? ((PrefService.of(context)
                                .get('disable_ntrip') ??
                                false)
                                ? "Yes but disabled"
                                : "Yes")
                                : "No",
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.all(10.0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text("NTRIP Stream selected:",
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(
                            PrefService.of(context).get('ntrip_mountpoint') ??
                                "None",
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.all(10.0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text("N NTRIP packets received:",
                            style: Theme.of(context).textTheme.bodySmall),
                        reactiveText(ntripPacketsCount,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              )))
    ];
  }
  List<Widget> connectingRows(BuildContext context)
  {
    return <Widget>[
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        iconLoading,
      ]),
      const Padding(
        padding: EdgeInsets.all(15.0),
      ),
      Text(
        connectStatus.value,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const Padding(
        padding: EdgeInsets.all(10.0),
      ),
      Text(
        'Selected device:',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      reactiveText(connectSelectedDevice),
      const Padding(
        padding: EdgeInsets.all(10.0),
      ),
    ];
  }
  
  List<Widget> notConnectedRows(BuildContext context) {
    List<Widget> rows = <Widget>[
      Text(
        'Pre-connect checklist',
        style: Theme.of(context)
            .textTheme
            .titleSmall!
            .copyWith(fontFamily: 'GoogleSans', color: Colors.blueGrey),
        //style: Theme.of(context).textTheme.headline,
      ),
      const Padding(
        padding: EdgeInsets.all(10.0),
      ),
    ];

    List<Widget> checklist = [];
    for (String key in _checkStateMapIcon.keys) {
      Row row = Row(mainAxisAlignment: MainAxisAlignment.start, children: [
        _checkStateMapIcon[key]!,
        Container(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              key,
              style: Theme.of(context).textTheme.bodySmall,
            )),
      ]);
      checklist.add(row);
    }

    rows.add(Card(
        child: Container(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: checklist,
          ),
        )));

    List<Widget> bottomWidgets = [
      const Padding(
        padding: EdgeInsets.all(15.0),
      ),
      Card(
          child: Column(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(15.0),
              ),
              Text(
                'Next step',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontFamily: 'GoogleSans',
                  color: Colors.blueGrey,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(10.0),
              ),
              Container(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  connectStatus.value,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ))
    ];
    rows.addAll(bottomWidgets);
    return rows;
  } 

Future<Map<dynamic, dynamic>?> checkUpdateSelectedDev(
      [bool userPressedSettingsTakeActionAndRetSw = false,
      bool userPressedConnectTakeActionAndRetSw = false]) async {
    _floatingButtonIcon = iconBluetoothSettings;

    try {
      _isBtConnected =
          (await methodChannel.invokeMethod('is_bt_connected')) as bool? ??
              false;
      _isNtripConnected =
          (await methodChannel.invokeMethod('is_ntrip_connected')) as bool? ??
              false;
      ntripPacketsCount =
          (await methodChannel.invokeMethod('get_ntrip_cb_count')) as int? ?? 0;

      if (_isBtConnected) {
        await wakelockEnable();
      } else {
        await wakelockDisable();
      }

      if (_isBtConnected) {
        _status = "Connected";
        _floatingButtonIcon = iconConnect;

        try {
          int mockSetMillisAgo;
          DateTime now = DateTime.now();
          int nowts = now.millisecondsSinceEpoch;
          mockLocationSetStatus = "";
          mockSetMillisAgo = nowts - _mockLocationSetTs;
          //developer.log("mock_location_set_ts $mock_set_ts, nowts $nowts");

          double secsAgo = mockSetMillisAgo / 1000.0;

          if (_mockLocationSetTs == 0) {
              mockLocationSetStatus.value = "Never";
          } else {

              mockLocationSetStatus.value = "${secsAgo.toStringAsFixed(3)} Seconds ago";

          }
        } catch (e, trace) {
          developer.log('get parsed param exception: $e $trace');
        }

        return null;
      }
    } on PlatformException catch (e) {
      await toast("WARNING: check _is_bt_connected failed: $e");
      _isBtConnected.value = false;
    }

    try {
      _isBtConnThreadConnecting.value =
          await methodChannel.invokeMethod('is_conn_thread_alive') as bool? ??
              false;
      developer.log(
          "_is_bt_conn_thread_alive_likely_connecting: $_isBtConnThreadConnecting");
      if (_isBtConnThreadConnecting) {
        setState(() {
          _status = "Connecting...";
        });
        return null;
      }
    } on PlatformException catch (e) {
      await toast("WARNING: check _is_connecting failed: $e");
      _isBtConnThreadConnecting = false;
    }
    //developer.log('check_and_update_selected_device1');

    _checkStateMapIcon.clear();

    //developer.log('check_and_update_selected_device2');

    List<String> notGrantedPermissions = await checkPermissions();
    if (notGrantedPermissions.isNotEmpty) {
      String msg =
          "Please allow required app permissions... Re-install app if declined earlier and not seeing permission request pop-up: $notGrantedPermissions";
      setState(() {
        _checkStateMapIcon["App permissions"] = iconFail;
        _status = msg;
      });
      return null;
    }

    _checkStateMapIcon["App permissions"] = iconOk;

    if (!(await isBluetoothOn())) {
      String msg = "Please turn ON Bluetooth...";
      setState(() {
        _checkStateMapIcon["Bluetooth is OFF"] = iconFail;
        _status = msg;
      });
      //developer.log('check_and_update_selected_device4');

      if (userPressedConnectTakeActionAndRetSw ||
          userPressedSettingsTakeActionAndRetSw) {
        try {
          await methodChannel.invokeMethod('open_phone_blueooth_settings');
          await toast("Please turn ON Bluetooth...");
        } on PlatformException {
          //developer.log("Please open phone Settings and change first (can't redirect screen: $e)");
        }
      }
      return null;
    }

    _checkStateMapIcon["Bluetooth powered ON"] = iconOk;
    //developer.log('check_and_update_selected_device5');

    Map<dynamic, dynamic> bdMap = await getBdMap();
    String bdsum = await getSelectedBdSummary(widget.prefService);
    if (userPressedSettingsTakeActionAndRetSw) {
      return null;
    }
    if (!mounted) {
      return null;
    }
    bool gapMode = PrefService.of(context).get('ble_gap_scan_mode') ?? false;
    if (gapMode) {
      //bt ble gap broadcast mode
      _checkStateMapIcon["EcoDroidGPS-Broadcast device mode"] = iconOk;
    } else {
      //bt connect mode
      if (bdMap.isEmpty) {
        String msg =
            "Please pair your Bluetooth GPS/GNSS Receiver in phone Settings > Bluetooth first.\n\nClick floating button to go there...";
        setState(() {
          _checkStateMapIcon["No paired Bluetooth devices"] = iconFail;
          _status = msg;
          _selectedDevice = "No paired Bluetooth devices yet...";
        });
        //developer.log('check_and_update_selected_device6');
        if (userPressedConnectTakeActionAndRetSw ||
            userPressedSettingsTakeActionAndRetSw) {
          try {
            await methodChannel.invokeMethod('open_phone_blueooth_settings');
            await toast("Please pair your Bluetooth GPS/GNSS Device...");
          } on PlatformException {
            //developer.log("Please open phone Settings and change first (can't redirect screen: $e)");
          }
        }
        return null;
      }
      //developer.log('check_and_update_selected_device7');
      _checkStateMapIcon["Found paired Bluetooth devices"] = iconOk;

      //developer.log('check_and_update_selected_device8');

      //developer.log('check_and_update_selected_device9');

      if (getSelectedBdaddr(widget.prefService).isEmpty ||
          (await getSelectedBdname(widget.prefService)).isEmpty) {
        String msg =
            "Please select your Bluetooth GPS/GNSS Receiver in Settings (the gear icon on top right)";
        /*Fluttertoast.showToast(
            msg: msg
        );*/
        setState(() {
          _checkStateMapIcon[
                  "No device selected\n(select in top-right settings/gear icon)"] =
              iconFail;
          _selectedDevice = bdsum;
          _status = msg;
        });
        //developer.log('check_and_update_selected_device10');

        return null;
      }
      _checkStateMapIcon["Target device selected:\n$selectedDevice"] = iconOk;
    }

    //developer.log('check_and_update_selected_device11');
    if (!mounted) {
      return null;
    }
    bool checkLocation =
        PrefService.of(context).get('check_settings_location') ?? true;

    if (checkLocation) {
      if (!(await isLocationEnabled())) {
        String msg =
            "Location needs to be on and set to 'High Accuracy Mode' - Please go to phone Settings > Location to change this...";
        setState(() {
          _checkStateMapIcon["Location must be ON and 'High Accuracy'"] =
              iconFail;
          _status = msg;
        });

        //developer.log('pre calling open_phone_location_settings() user_pressed_connect_take_action_and_ret_sw $user_pressed_connect_take_action_and_ret_sw');

        if (userPressedConnectTakeActionAndRetSw) {
          try {
            //developer.log('calling open_phone_location_settings()');
            await methodChannel.invokeMethod('open_phone_location_settings');
            await toast("Please set Location ON and 'High Accuracy Mode'...");
          } on PlatformException catch (e) {
            developer.log(
                "Please open phone Settings and change first (can't redirect screen: $e)");
          }
        }
        //developer.log('check_and_update_selected_device12');
        return null;
      }
      //developer.log('check_and_update_selected_device13');
      _checkStateMapIcon["Location is on and 'High Accuracy'"] = iconOk;
    }

    if (!(await isMockLocationEnabled())) {
      String msg =
          "Please go to phone Settings > Developer Options > Under 'Debugging', set 'Mock Location app' to 'Bluetooth GNSS'...";
      setState(() {
        _checkStateMapIcon["'Mock Location app' not 'Bluetooth GNSS'\n"] =
            iconFail;
        _status = msg;
      });
      //developer.log('check_and_update_selected_device14');
      if (userPressedConnectTakeActionAndRetSw) {
        try {
          await methodChannel.invokeMethod('open_phone_developer_settings');
          await toast("Please set 'Mock Locaiton app' to 'Blueooth GNSS'..");
        } on PlatformException catch (e) {
          developer.log(
              "Please open phone Settings and change first (can't redirect screen: $e)");
        }
      }
      return null;
    }
    //developer.log('check_and_update_selected_device15');
    _checkStateMapIcon[
            "'Mock Location app' is 'Bluetooth GNSS'\n$notHowToDisableMockLocation"] =
        iconOk;

    if (_isBtConnected == false && _isBtConnThreadConnecting) {
      setState(() {
        _floatingButtonIcon = iconConnecting;
      });
      //developer.log('check_and_update_selected_device16');
    } else {
      //ok - ready to connect
      setState(() {
        _status = "Please press the floating button to connect...";
        _floatingButtonIcon = iconConnect;
      });
      //developer.log('check_and_update_selected_device17');
    }

    setState(() {
      _selectedDevice = bdsum;
    });

    //setState((){});
    //developer.log('check_and_update_selected_device18');

    return bdMap;
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

}

List<Widget> getDevSepcificRows(BuildContext context) {
  if (isQstarz.value) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Device Time:', style: Theme.of(context).textTheme.bodySmall),
          Text(
              getgetQstarzDateime(paramMap['QSTARZ_timestamp_s'] as int? ?? 0,
                  paramMap['QSTARZ_millisecond'] as int? ?? 0),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Fix status:', style: Theme.of(context).textTheme.bodySmall),
          Text((paramMap['QSTARZ_fix_status_matched'] ?? waitingDev).toString(),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('RCR:', style: Theme.of(context).textTheme.bodySmall),
          Text(getQstarzRCRLogType(paramMap['QSTARZ_rcr'] as int?),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Float speed (km/h):',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_float_speed_kmh_double_02_str'] as String? ??
                  waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Float height (m):',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_float_height_m_double_02_str'] as String? ??
                  waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Heading (degrees):',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_heading_degrees_double_02_str'] as String? ??
                  waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('G-sensor X:', style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_g_sensor_x_double_02_str'] as String? ??
                  waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('G-sensor Y:', style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_g_sensor_y_double_02_str'] as String? ??
                  waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('G-sensor Z:', style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_g_sensor_z_double_02_str'] as String? ??
                  waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Max SNR:', style: Theme.of(context).textTheme.bodySmall),
          Text(paramMap['QSTARZ_max_snr_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('HDOP:', style: Theme.of(context).textTheme.bodySmall),
          Text(paramMap['QSTARZ_hdop_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('VDOP:', style: Theme.of(context).textTheme.bodySmall),
          Text(paramMap['QSTARZ_vdop_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('N Satellites in view:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_satellite_count_view_str'] as String? ??
                  waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('N Satellites used:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_satellite_count_used_str'] as String? ??
                  waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Fix quality:', style: Theme.of(context).textTheme.bodySmall),
          Text(paramMap['QSTARZ_fix_quality_matched'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Battery (%)', style: Theme.of(context).textTheme.bodySmall),
          Text(paramMap['battery_percent'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      )
    ];
  }

  return [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Time from GNSS:', style: Theme.of(context).textTheme.bodySmall),
        Text(
            paramMap['GN_time'] as String? ??
                paramMap['GP_time'] as String? ??
                waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Ellipsoidal Height:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            paramMap['GN_ellipsoidal_height_double_02_str'] as String? ??
                paramMap['GP_ellipsoidal_height_double_02_str'] as String? ??
                waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Orthometric (MSL) Height:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            paramMap['GN_gga_alt_double_02_str'] as String? ??
                paramMap['GP_gga_alt_double_02_str'] as String? ??
                waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Geoidal Height:', style: Theme.of(context).textTheme.bodySmall),
        Text(
            paramMap['GN_geoidal_height_double_02_str'] as String? ??
                paramMap['GP_geoidal_height_double_02_str'] as String? ??
                waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Fix status:', style: Theme.of(context).textTheme.bodySmall),
        Text(
            (paramMap["GN_status"] as String? ??
                paramMap["GP_status"] as String? ??
                "No data"),
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Fix quality:', style: Theme.of(context).textTheme.bodySmall),
        Text(
            paramMap["GN_fix_quality"] as String? ??
                paramMap["GP_fix_quality"] as String? ??
                waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('UBLOX Fix Type:', style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["UBX_POSITION_navStat"] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('UBLOX XY Accuracy(m):',
            style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["UBX_POSITION_hAcc"] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('UBLOX Z Accuracy(m):',
            style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["UBX_POSITION_vAcc"] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('HDOP:', style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["hdop_str"] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Course:', style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["course_str"] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    const Padding(
      padding: EdgeInsets.all(5.0),
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('N Sats used TOTAL:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            ((paramMap["GP_n_sats_used"] ?? 0) +
                    (paramMap["GL_n_sats_used"] ?? 0) +
                    (paramMap["GA_n_sats_used"] ?? 0) +
                    (paramMap["GB_n_sats_used"] ?? 0) +
                    (paramMap["GQ_n_sats_used"] ?? 0))
                .toString(),
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('N Galileo in use/view:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            "${paramMap["GA_n_sats_used_str"] ?? waitingDev} / ${paramMap["GA_n_sats_in_view_str"] ?? waitingDev}",
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('N GPS in use/view:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            "${paramMap["GP_n_sats_used_str"] ?? waitingDev} / ${paramMap["GP_n_sats_in_view_str"] ?? waitingDev}",
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('N GLONASS in use/view:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            "${paramMap["GL_n_sats_used_str"] ?? waitingDev} / ${paramMap["GL_n_sats_in_view_str"] ?? waitingDev}",
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('N BeiDou in use/view:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            "${paramMap["GB_n_sats_used_str"] ?? waitingDev} / ${paramMap["GB_n_sats_in_view_str"] ?? waitingDev}",
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('N QZSS in use/view:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            "${paramMap["GQ_n_sats_used_str"] ?? waitingDev} / ${paramMap["GQ_n_sats_in_view_str"] ?? waitingDev}",
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  ];
}





