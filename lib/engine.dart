import 'dart:async';
import 'dart:developer' as developer;

import 'package:bluetooth_gnss/about.dart';
import 'package:bluetooth_gnss/tab_connect.dart';
import 'package:bluetooth_gnss/tab_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pref/pref.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings.dart';
import 'tab_rtk.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const String waitingDev = "No data";
const String tabConnect = 'Connect';
const String tabRtk = 'RTK/NTRIP';
const String tabMsg = 'Messages';

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
const methodChannel =
      MethodChannel("com.clearevo.bluetooth_gnss/engine");
const eventChannel =
      EventChannel("com.clearevo.bluetooth_gnss/engine_events");
const uninitState = "Loading state...";

//params
Map<dynamic, dynamic> _paramMap = <dynamic, dynamic>{};
Map<dynamic, dynamic> get paramMap => _paramMap;
String _status = "Loading status...";
String _selectedDevice = "Loading selected device...";
//Map<String, String> _check_state_map =
final Map<String, Icon> _checkStateMapIcon = {
  "Bluetooth On": iconLoading,
  "Bluetooth Device Paired": iconLoading,
  "Bluetooth Device Selected": iconLoading,
  "Mock location enabled": iconLoading,
};
  Icon _floatingButtonIcon = const Icon(Icons.access_time);
  bool _isBtConnected = false;
  bool isQstarz = false;
  bool get isBtConnected => _isBtConnected;

  String get status => _status;
  bool _isBtConnThreadConnecting = false;
  int _mockLocationSetTs = 0;
  set mockLocationSetTs(int value) {
    _mockLocationSetTs = value;
  }

  RxString mockLocationSetStatus = waitingDev;
  /////////////////////

  /// ntrip tab
  bool _isNtripConnected = false;
  int ntripPacketsCount = 0;

  /// //////////////

  ///////////////////msg tab
  final List<Message> _msgList = [];
  List<Message> get msgList => _msgList;
  final maxMsgListSize = 1000;
  final TextEditingController contentsController = TextEditingController();
  List<Message> filteredMessages = [];
  bool autoScroll = true;
  // Dropdown filter variables
  bool? isTxFilter;
  String? nameFilter;
  List<String> uniqueNames = [];
  bool isMessageInFilter(Message message) {
    final matchesIsTx = isTxFilter == null || message.tx == isTxFilter;
    final matchesName = nameFilter == null || message.name == nameFilter;
    final matchesContents = message.contents
        .toLowerCase()
        .contains(contentsController.text.toLowerCase());
    return matchesIsTx && matchesName && matchesContents;
  }


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


  void initState() {
    checkUpdateSelectedDev();

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

  void cleanup() {
    developer.log('cleanup()');
  }


  //return settings_widget that can be used to get selected bdaddr
  Future<Map<dynamic, dynamic>?> checkUpdateSelectedDev(
      [bool userPressedSettingsTakeActionAndRetSw = false,
      bool userPressedConnectTakeActionAndRetSw = false]) async {
    _floatingButtonIcon = iconBluetoothSettings;

    try {
      _isBtConnected = (await methodChannel.invokeMethod('is_bt_connected')) as bool? ?? false;
      _isNtripConnected =
      (await methodChannel.invokeMethod('is_ntrip_connected'))  as bool? ?? false;
      ntripPacketsCount = (await methodChannel.invokeMethod('get_ntrip_cb_count')) as int? ?? 0;

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
            setState(() {
              mockLocationSetStatus = "Never";
            });
          } else {
            setState(() {
              mockLocationSetStatus =
                  "${secsAgo.toStringAsFixed(3)} Seconds ago";
            });
          }
        } catch (e, trace) {
          developer.log('get parsed param exception: $e $trace');
        }

        return null;
      }
    } on PlatformException catch (e) {
      await toast("WARNING: check _is_bt_connected failed: $e");
      _isBtConnected = false;
    }

    try {
      _isBtConnThreadConnecting =
          await methodChannel.invokeMethod('is_conn_thread_alive') as bool? ?? false;
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

      if (getSelectedBdaddr(widget.prefService).isEmpty || (await getSelectedBdname(widget.prefService)).isEmpty) {
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
          "Please go to phone Settings > Developer Options > Under 'Debugging', set 'Mock Location app' to 'Hybrid GNSS'...";
      setState(() {
        _checkStateMapIcon["'Mock Location app' not 'Hybrid GNSS'\n"] =
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
            "'Mock Location app' is 'Hybrid GNSS'\n$notHowToDisableMockLocation"] =
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

  Future<void> toast(String msg) async {
    try {
      print("toast start");
      await methodChannel.invokeMethod("toast", {"msg": msg});
      print("toast done");
    } catch (e) {
      print("WARNING: toast failed exception: $e");
    }
  }

  void snackbar(String msg) {
    try {
      final snackBar = SnackBar(content: Text(msg));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      developer.log("WARNING: snackbar failed exception: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      if (_isBtConnected) {
        print("disconnect() toast start");
        await toast("Disconnecting...");
        print("disconnect() toast done");
      } else {
        await toast("Not connected...");
      }
      print("disconnect() invoke disconnect start");
      //call it in any case just to be sure service it is stopped (.close()) method called
      await methodChannel.invokeMethod('disconnect');
      print("disconnect() invoke disconnect done");
    } on Exception catch (e, trace) {
      developer.log("disconnect failed: $e $trace");
      await toast("WARNING: disconnect failed: $e");
    }
  }

  Future<void> connect() async {
    developer.log("main.dart connect() start");
    String log_bt_rx_log_uri = PrefService.of(context).get('log_bt_rx_log_uri') ?? "";
    bool autostart = PrefService.of(context).get('autostart') ?? false;
    bool gapMode = PrefService.of(context).get('ble_gap_scan_mode') ?? false;
    String log_uri = PrefService.of(context).get('log_bt_rx_log_uri') as String? ?? "";

    if (log_bt_rx_log_uri.isNotEmpty) {
      bool writeEnabled = false;
      try {
        writeEnabled = (await methodChannel.invokeMethod('is_write_enabled')) as bool? ?? false;
      } on PlatformException catch (e) {
        await toast("WARNING: check write_enabled failed: $e");
      }
      if (writeEnabled == false) {
        await toast(
            "Write external storage permission required for data loggging...");
        return;
      }

      bool canCreateFile = false;
      try {

          canCreateFile = (await methodChannel.invokeMethod(
              'test_can_create_file_in_chosen_folder',
              {"log_bt_rx_log_uri": log_uri})) as bool? ?? false;

      } on PlatformException catch (e) {
        await toast(
            "WARNING: check test_can_create_file_in_chosen_folder failed: $e");
      }
      if (canCreateFile == false) {
        //TODO: try req permission firstu
        await toast(
            "Please go to Settings > re-tick 'Enable logging' (failed to access chosen log folder)");
        return;
      }
    }

    if (gapMode) {
      bool coarseLocationEnabled = await isCoarseLocationEnabled();
      if (coarseLocationEnabled == false) {
        await toast("Coarse Locaiton permission required for BLE GAP mode...");
        return;
      }
    }

    if (_isBtConnected) {
      await toast("Already connected...");
      return;
    }

    if (_isBtConnThreadConnecting) {
      await toast("Connecting, please wait...");
      return;
    }

    Map<dynamic, dynamic>? bdmap = await checkUpdateSelectedDev(false, true);
    if (bdmap == null) {
      //toast("Please see Pre-connect checklist...");
      return;
    }

    bool connecting = false;
    try {
      connecting = (await methodChannel.invokeMethod('is_conn_thread_alive')) as bool? ?? false;
    } on PlatformException catch (e) {
      await toast("WARNING: check _is_connecting failed: $e");
    }

    if (connecting) {
      await toast("Connecting - please wait...");
      return;
    }

    if (!mounted) {
      return;
    }

    String bdaddr = (PrefService.of(context).get("target_bdaddr")) as String? ?? "";
    if (bdaddr.isEmpty) {
      developer.log("main.dart connect() start1");
      snackbar("No bluetooth device selected in settings");
      return;
    }
    if (!gapMode) {}

    developer.log("main.dart connect() start1");
    if (!mounted) {
      return;
    }
    _paramMap = <dynamic, dynamic>{}; //clear last conneciton params state...
    String status = "unknown";
    try {
      developer.log("main.dart connect() start connect start");
      final bool ret = (await methodChannel.invokeMethod('connect', {
        "bdaddr": bdaddr,
        'secure': PrefService.of(context).get('secure') ?? true,
        'reconnect': PrefService.of(context).get('reconnect') ?? false,
        'ble_gap_scan_mode': gapMode,
        'log_bt_rx_log_uri': log_bt_rx_log_uri,
        'disable_ntrip': PrefService.of(context).get('disable_ntrip') ?? false,
        'ntrip_host': PrefService.of(context).get('ntrip_host'),
        'ntrip_port': PrefService.of(context).get('ntrip_port'),
        'ntrip_mountpoint': PrefService.of(context).get('ntrip_mountpoint'),
        'ntrip_user': PrefService.of(context).get('ntrip_user'),
        'ntrip_pass': PrefService.of(context).get('ntrip_pass'),
        'autostart': autostart,
      })) as bool? ?? false;
      developer.log("main.dart connect() start connect done");
      if (ret) {
        status = "Connecting - please wait ...";
      } else {
        status = "Failed to connect...";
      }

      developer.log("main.dart connect() start2");
    } on PlatformException catch (e) {
      status = "Failed to start connection: '${e.message}'.";
      developer.log(status);
    }

    developer.log("main.dart connect() start3");

    setState(() {
      _status = status;
    });

    developer.log("main.dart connect() start4");

    developer.log("marin.dart connect() done");
  }

  String getSelectedBdaddr(BasePrefService prefService) {
    return prefService.get("target_bdaddr") ?? "";
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

  String get selectedDevice => _selectedDevice;

  Map<String, Icon> get checkStateMapIcon => _checkStateMapIcon;

  bool get isNtripConnected => _isNtripConnected;

  int get ntripPacketCount => ntripPacketsCount;

  bool get isBtConnThreadConnecting => _isBtConnThreadConnecting;
