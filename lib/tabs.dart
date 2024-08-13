import 'dart:async';

import 'package:bluetooth_gnss/about.dart';
import 'package:bluetooth_gnss/tab_connect.dart';
import 'package:bluetooth_gnss/tab_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pref/pref.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'main.dart';
import 'settings.dart';
import 'tab_rtk.dart';

enum TabsDemoStyle { iconsAndText, iconsOnly, textOnly }

const String WAITING_DEV = "No data";
const String TAB_CONNECT = 'Connect';
const String TAB_RTK = 'RTK/NTRIP';
const String TAB_MSG = 'Messages';

const double default_checklist_icon_size = 35;
const double default_connect_state_icon_size = 60;

const ICON_NOT_CONNECTED = Icon(
  Icons.bluetooth_disabled,
  color: Colors.red,
  size: default_connect_state_icon_size,
);
const FLOATING_ICON_BLUETOOTH_SETTINGS = Icon(
  Icons.settings_bluetooth,
  color: Colors.white,
);
const FLOATING_ICON_BLUETOOTH_CONNECT = Icon(
  Icons.bluetooth_connected,
  color: Colors.white,
);
const FLOATING_ICON_BLUETOOTH_CONNECTING = Icon(
  Icons.bluetooth_connected,
  color: Colors.white,
);
const ICON_CONNECTED = Icon(
  Icons.bluetooth_connected,
  color: Colors.blue,
  size: default_connect_state_icon_size,
);
const ICON_LOADING = Icon(
  Icons.access_time,
  color: Colors.grey,
  size: default_connect_state_icon_size,
);
const ICON_OK = Icon(
  Icons.check_circle,
  color: Colors.lightBlueAccent,
  size: default_checklist_icon_size,
);
const ICON_FAIL = Icon(
  Icons.cancel,
  color: Colors.blueGrey,
  size: default_checklist_icon_size,
);

class _Page {
  const _Page({this.icon, this.text});
  final IconData? icon;
  final String? text;
}

const List<_Page> _allPages = <_Page>[
  _Page(icon: Icons.bluetooth, text: TAB_CONNECT),
  _Page(icon: Icons.cloud_download, text: TAB_RTK),
  _Page(icon: Icons.view_list, text: TAB_MSG),
  /*
  TODO: add more pages?
  _Page(icon: Icons.location_on, text: 'Location'),
  _Page(icon: Icons.landscape, text: 'Map'),
  - take photo with geo metadata from connected dev
  - take vdo with geo metadata from connected dev
  */
];

class Tabs extends StatefulWidget {
  Tabs(this.pref_service, {super.key});
  final BasePrefService pref_service;
  TabsState? m_state;
  @override
  TabsState createState() {
    m_state = TabsState();
    return m_state!;
  }
}

class TabsState extends State<Tabs> with SingleTickerProviderStateMixin {
  static const method_channel =
      MethodChannel("com.clearevo.bluetooth_gnss/engine");
  static const event_channel =
      EventChannel("com.clearevo.bluetooth_gnss/engine_events");
  static const uninit_state = "Loading state...";

  String _status = "Loading status...";
  String _selected_device = "Loading selected device...";

  //Map<String, String> _check_state_map =

  final Map<String, Icon> _check_state_map_icon = {
    "Bluetooth On": ICON_LOADING,
    "Bluetooth Device Paired": ICON_LOADING,
    "Bluetooth Device Selected": ICON_LOADING,
    "Bluetooth Device Selected": ICON_LOADING,
    "Mock location enabled": ICON_LOADING,
  };

  Icon _m_floating_button_icon = const Icon(Icons.access_time);

  bool _is_bt_connected = false;
  bool get is_bt_connected => _is_bt_connected;

  bool _wakelock_enabled = false;
  bool _is_ntrip_connected = false;

  String get status => _status;
  int _ntrip_packets_count = 0;
  bool _is_bt_conn_thread_alive_likely_connecting = false;

  int _mock_location_set_ts = 0;

  set mock_location_set_ts(int value) {
    _mock_location_set_ts = value;
  }

  String _mock_location_set_status = WAITING_DEV;
  List<String> talker_ids = ["GP", "GL", "GA", "GB", "GQ"];

  TabController? _controller;
  TabsDemoStyle _demoStyle = TabsDemoStyle.iconsAndText;
  final bool _customIndicator = false;

  Timer? timer;
  static String note_how_to_disable_mock_location = "";
  Map<dynamic, dynamic> _param_map = <dynamic, dynamic>{};
  Map<dynamic, dynamic> get param_map => _param_map;
  List<Message> _msgList = [];
  List<Message> get msgList => _msgList;

  void wakelock_enable() {
    if (_wakelock_enabled == false) {
      WakelockPlus
          .enable(); //keep screen on for users to continuously monitor connection state
      _wakelock_enabled = true;
    }
  }

  void wakelock_disable() {
    if (_wakelock_enabled == true) {
      WakelockPlus
          .disable(); //keep screen on for users to continuously monitor connection state
      _wakelock_enabled = false;
    }
  }

  static void LogPrint(Object object) async {
    int defaultPrintLength = 1020;
    if (object.toString().length <= defaultPrintLength) {
      print(object);
    } else {
      String log = object.toString();
      int start = 0;
      int endIndex = defaultPrintLength;
      int logLength = log.length;
      int tmpLogLength = log.length;
      while (endIndex < logLength) {
        print(log.substring(start, endIndex));
        endIndex += defaultPrintLength;
        start += defaultPrintLength;
        tmpLogLength -= defaultPrintLength;
      }
      if (tmpLogLength > 0) {
        print(log.substring(start, logLength));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 2),
        (Timer t) => check_and_update_selected_device());
    _controller = TabController(vsync: this, length: _allPages.length);
    check_and_update_selected_device();

    event_channel.receiveBroadcastStream().listen((dynamic event) {
      Map<dynamic, dynamic> paramMap = event;
      if (paramMap.containsKey("is_dev_msg_map")) {
        print("got event is_dev_msg_parse");
        try {
          setState(() {
            msgList.add(Message.fromMap(paramMap));
          });
        } catch (e) {
          print('parse msg exception: $e');
        }
        return; //update messages only
      } else {
        print("got event pos update");
        setState(() {
          _param_map = paramMap;
        });
        // 660296614
        if (paramMap.containsKey('mock_location_set_ts')) {
          try {
            _mock_location_set_ts = paramMap['mock_location_set_ts'] ?? 0;
          } catch (e) {
            print('get parsed param exception: $e');
          }
        }
      }
    }, onError: (dynamic error) {
      print('Received error: ${error.message}');
    });
  }

  void cleanup() {
    print('cleanup()');
    if (timer != null) {
      timer!.cancel();
    }
  }

  @override
  void deactivate() {
    print('deactivate()');
    //cleanup();
  }

  @override
  void dispose() {
    print('dispose()');
    cleanup();

    _controller!.dispose();
    super.dispose();
  }

  void changeDemoStyle(TabsDemoStyle style) {
    setState(() {
      _demoStyle = style;
    });
  }

  Decoration? getIndicator() {
    if (!_customIndicator) {
      return const UnderlineTabIndicator();
    }

    switch (_demoStyle) {
      case TabsDemoStyle.iconsAndText:
        return ShapeDecoration(
          shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4.0)),
                side: BorderSide(
                  color: Colors.white24,
                  width: 2.0,
                ),
              ) +
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4.0)),
                side: BorderSide(
                  color: Colors.transparent,
                  width: 4.0,
                ),
              ),
        );

      case TabsDemoStyle.iconsOnly:
        return ShapeDecoration(
          shape: const CircleBorder(
                side: BorderSide(
                  color: Colors.white24,
                  width: 4.0,
                ),
              ) +
              const CircleBorder(
                side: BorderSide(
                  color: Colors.transparent,
                  width: 4.0,
                ),
              ),
        );

      case TabsDemoStyle.textOnly:
        return ShapeDecoration(
          shape: const StadiumBorder(
                side: BorderSide(
                  color: Colors.white24,
                  width: 2.0,
                ),
              ) +
              const StadiumBorder(
                side: BorderSide(
                  color: Colors.transparent,
                  width: 4.0,
                ),
              ),
        );
    }
    return null;
  }

  Scaffold? _scaffold;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    final Color iconColor = Theme.of(context).hintColor;

    bool gapMode = false;

    _scaffold = Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Bluetooth GNSS'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                check_and_update_selected_device(true, false).then((sw) {
                  if (sw == null) {
                    return;
                  }
                  if (_is_bt_connected ||
                      _is_bt_conn_thread_alive_likely_connecting) {
                    toast(
                        "Please Disconnect first - cannot change settings during live connection...");
                    return;
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) {
                        dynamic bdmap = sw.m_bdaddr_to_name_map;
                        print("sw.bdaddr_to_name_map: $bdmap");
                        return settings_widget(widget.pref_service, bdmap);
                      }),
                    );
                  }
                });
              },
            ),
            // overflow menu
            PopupMenuButton(
              itemBuilder: (_) => <PopupMenuItem<String>>[
                const PopupMenuItem<String>(
                  value: 'disconnect',
                  child: Text('Disconnect/Stop'),
                ),
                const PopupMenuItem<String>(
                    value: 'issues', child: Text('Issues/Suggestions')),
                const PopupMenuItem<String>(
                    value: 'project', child: Text('Project page')),
                const PopupMenuItem<String>(
                    value: 'about', child: Text('About')),
              ],
              onSelected: menu_selected,
            ),
          ],
          bottom: TabBar(
            controller: _controller,
            isScrollable: true,
            indicator: getIndicator(),
            tabs: _allPages.map<Tab>((_Page page) {
              switch (_demoStyle) {
                case TabsDemoStyle.iconsAndText:
                  return Tab(text: page.text, icon: Icon(page.icon));
                case TabsDemoStyle.iconsOnly:
                  return Tab(icon: Icon(page.icon));
                case TabsDemoStyle.textOnly:
                default:
                  return Tab(text: page.text);
              }
            }).toList(),
          ),
        ),
        floatingActionButton: Visibility(
            visible: !_is_bt_connected,
            child: FloatingActionButton(
              onPressed: connect,
              tooltip: 'Connect',
              child: _m_floating_button_icon,
            )), // This trailing comma makes auto-formatting nicer for build methods.
        body: SafeArea(
          child: TabBarView(
            controller: _controller,
            children: _allPages.map<Widget>((_Page page) {
              String pname = page.text.toString();
              switch (pname) {
                case TAB_CONNECT:
                  return BuildTabConnectUi(context, this);
                case TAB_RTK:
                  return BuildTabRtkUi(context, this);
                case TAB_MSG:
                  return BuildTabMsg(context, this);
              }
              return SingleChildScrollView(
                  child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: Container(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "<UNDER DEVELOPMENT/>\n\nSorry, dev not done yet - please check again after next update...",
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            fontFamily: 'GoogleSans',
                            color: Colors.blueGrey,
                          ),
                    ),
                  ],
                )),
              ));
            }).toList(),
          ),
        ));

    return _scaffold!;
  }

  /////////////functions

  void menu_selected(String menu) async {
    print('menu_selected: $menu');
    switch (menu) {
      case "disconnect":
        await disconnect();
        break;
      case "about":
        final packageInfo = await PackageInfo.fromPlatform();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) {
            return Scaffold(
                appBar: AppBar(
                  title: const Text("About"),
                ),
                body: get_about_view(packageInfo.version.toString()));
          }),
        );
        break;
      case "issues":
        launch("https://github.com/ykasidit/bluetooth_gnss/issues");
        break;
      case "project":
        launch("https://github.com/ykasidit/bluetooth_gnss");
        break;
    }
  }

  void clear_disp_text() {
    _selected_device = "";
    _status = "";
  }

  //return settings_widget that can be used to get selected bdaddr
  Future<settings_widget_state?> check_and_update_selected_device(
      [bool userPressedSettingsTakeActionAndRetSw = false,
      bool userPressedConnectTakeActionAndRetSw = false]) async {
    _m_floating_button_icon = FLOATING_ICON_BLUETOOTH_SETTINGS;

    try {
      _is_bt_connected = await method_channel.invokeMethod('is_bt_connected');
      _is_ntrip_connected =
          await method_channel.invokeMethod('is_ntrip_connected');
      _ntrip_packets_count =
          await method_channel.invokeMethod('get_ntrip_cb_count');

      if (_is_bt_connected) {
        wakelock_enable();
      } else {
        wakelock_disable();
      }

      if (_is_bt_connected) {
        _status = "Connected";
        _m_floating_button_icon = FLOATING_ICON_BLUETOOTH_CONNECT;

        try {
          int mockSetMillisAgo;
          DateTime now = DateTime.now();
          int nowts = now.millisecondsSinceEpoch;
          _mock_location_set_status = "";
          mockSetMillisAgo = nowts - _mock_location_set_ts;
          //print("mock_location_set_ts $mock_set_ts, nowts $nowts");

          double secsAgo = mockSetMillisAgo / 1000.0;

          if (_mock_location_set_ts == 0) {
            setState(() {
              _mock_location_set_status = "Never";
            });
          } else {
            setState(() {
              _mock_location_set_status =
                  "${secsAgo.toStringAsFixed(3)} Seconds ago";
            });
          }
        } catch (e, trace) {
          print('get parsed param exception: $e $trace');
        }

        return null;
      }
    } on PlatformException catch (e) {
      toast("WARNING: check _is_bt_connected failed: $e");
      _is_bt_connected = false;
    }

    try {
      _is_bt_conn_thread_alive_likely_connecting =
          await method_channel.invokeMethod('is_conn_thread_alive');
      print(
          "_is_bt_conn_thread_alive_likely_connecting: $_is_bt_conn_thread_alive_likely_connecting");
      if (_is_bt_conn_thread_alive_likely_connecting) {
        setState(() {
          _status = "Connecting...";
        });
        return null;
      }
    } on PlatformException catch (e) {
      toast("WARNING: check _is_connecting failed: $e");
      _is_bt_conn_thread_alive_likely_connecting = false;
    }
    //print('check_and_update_selected_device1');

    _check_state_map_icon.clear();

    //print('check_and_update_selected_device2');

    List<String> notGrantedPermissions = await check_permissions_not_granted();
    if (notGrantedPermissions.isNotEmpty) {
      String msg =
          "Please allow required app permissions... Re-install app if declined earlier and not seeing permission request pop-up: $notGrantedPermissions";
      setState(() {
        _check_state_map_icon["App permissions"] = ICON_FAIL;
        _status = msg;
      });
      return null;
    }

    _check_state_map_icon["App permissions"] = ICON_OK;

    if (!(await is_bluetooth_on())) {
      String msg = "Please turn ON Bluetooth...";
      setState(() {
        _check_state_map_icon["Bluetooth is OFF"] = ICON_FAIL;
        _status = msg;
      });
      //print('check_and_update_selected_device4');

      if (userPressedConnectTakeActionAndRetSw ||
          userPressedSettingsTakeActionAndRetSw) {
        bool openActRet = false;
        try {
          openActRet =
              await method_channel.invokeMethod('open_phone_blueooth_settings');
          toast("Please turn ON Bluetooth...");
        } on PlatformException {
          //print("Please open phone Settings and change first (can't redirect screen: $e)");
        }
      }
      return null;
    }

    _check_state_map_icon["Bluetooth powered ON"] = ICON_OK;
    //print('check_and_update_selected_device5');

    Map<dynamic, dynamic> bdMap = await get_bd_map();
    settings_widget_state sw = settings_widget_state(bdMap);
    if (userPressedSettingsTakeActionAndRetSw) {
      return sw;
    }
    bool gapMode = PrefService.of(context).get('ble_gap_scan_mode') ?? false;
    if (gapMode) {
      //bt ble gap broadcast mode
      _check_state_map_icon["EcoDroidGPS-Broadcast device mode"] = ICON_OK;
    } else {
      //bt connect mode
      if (bdMap.isEmpty) {
        String msg =
            "Please pair your Bluetooth GPS/GNSS Receiver in phone Settings > Bluetooth first.\n\nClick floating button to go there...";
        setState(() {
          _check_state_map_icon["No paired Bluetooth devices"] = ICON_FAIL;
          _status = msg;
          _selected_device = "No paired Bluetooth devices yet...";
        });
        //print('check_and_update_selected_device6');
        if (userPressedConnectTakeActionAndRetSw ||
            userPressedSettingsTakeActionAndRetSw) {
          bool openActRet = false;
          try {
            openActRet = await method_channel
                .invokeMethod('open_phone_blueooth_settings');
            toast("Please pair your Bluetooth GPS/GNSS Device...");
          } on PlatformException {
            //print("Please open phone Settings and change first (can't redirect screen: $e)");
          }
        }
        return null;
      }
      //print('check_and_update_selected_device7');
      _check_state_map_icon["Found paired Bluetooth devices"] = ICON_OK;

      //print('check_and_update_selected_device8');

      //print('check_and_update_selected_device9');

      if (sw.get_selected_bdaddr(widget.pref_service).isEmpty) {
        String msg =
            "Please select your Bluetooth GPS/GNSS Receiver in Settings (the gear icon on top right)";
        /*Fluttertoast.showToast(
            msg: msg
        );*/
        setState(() {
          _check_state_map_icon[
                  "No device selected\n(select in top-right settings/gear icon)"] =
              ICON_FAIL;
          _selected_device =
              sw.get_selected_bd_summary(widget.pref_service) ?? "";
          _status = msg;
        });
        //print('check_and_update_selected_device10');

        return null;
      }
      _check_state_map_icon["Target device selected:\n"+selected_device] = ICON_OK;
    }

    //print('check_and_update_selected_device11');

    bool checkLocation =
        PrefService.of(context).get('check_settings_location') ?? true;

    if (checkLocation) {
      if (!(await is_location_enabled())) {
        String msg =
            "Location needs to be on and set to 'High Accuracy Mode' - Please go to phone Settings > Location to change this...";
        setState(() {
          _check_state_map_icon["Location must be ON and 'High Accuracy'"] =
              ICON_FAIL;
          _status = msg;
        });

        //print('pre calling open_phone_location_settings() user_pressed_connect_take_action_and_ret_sw $user_pressed_connect_take_action_and_ret_sw');

        if (userPressedConnectTakeActionAndRetSw) {
          bool openActRet = false;
          try {
            //print('calling open_phone_location_settings()');
            openActRet = await method_channel
                .invokeMethod('open_phone_location_settings');
            toast("Please set Location ON and 'High Accuracy Mode'...");
          } on PlatformException catch (e) {
            print(
                "Please open phone Settings and change first (can't redirect screen: $e)");
          }
        }
        //print('check_and_update_selected_device12');
        return null;
      }
      //print('check_and_update_selected_device13');
      _check_state_map_icon["Location is on and 'High Accuracy'"] = ICON_OK;
    }

    if (!(await is_mock_location_enabled())) {
      String msg =
          "Please go to phone Settings > Developer Options > Under 'Debugging', set 'Mock Location app' to 'Bluetooth GNSS'...";
      setState(() {
        _check_state_map_icon["'Mock Location app' not 'Bluetooth GNSS'\n"] =
            ICON_FAIL;
        _status = msg;
      });
      //print('check_and_update_selected_device14');
      if (userPressedConnectTakeActionAndRetSw) {
        bool openActRet = false;
        try {
          openActRet = await method_channel
              .invokeMethod('open_phone_developer_settings');
          toast("Please set 'Mock Locaiton app' to 'Blueooth GNSS'..");
        } on PlatformException catch (e) {
          print(
              "Please open phone Settings and change first (can't redirect screen: $e)");
        }
      }
      return null;
    }
    //print('check_and_update_selected_device15');
    _check_state_map_icon[
            "'Mock Location app' is 'Bluetooth GNSS'\n$note_how_to_disable_mock_location"] =
        ICON_OK;

    if (_is_bt_connected == false &&
        _is_bt_conn_thread_alive_likely_connecting) {
      setState(() {
        _m_floating_button_icon = FLOATING_ICON_BLUETOOTH_CONNECTING;
      });
      //print('check_and_update_selected_device16');
    } else {
      //ok - ready to connect
      setState(() {
        _status = "Please press the floating button to connect...";
        _m_floating_button_icon = FLOATING_ICON_BLUETOOTH_CONNECT;
      });
      //print('check_and_update_selected_device17');
    }

    setState(() {
      _selected_device = sw.get_selected_bd_summary(widget.pref_service) ?? "";
    });

    //setState((){});
    //print('check_and_update_selected_device18');

    return sw;
  }

  void toast(String msg) async {
    try {
      await method_channel.invokeMethod("toast", {"msg": msg});
    } catch (e) {
      print("WARNING: toast failed exception: $e");
    }
  }

  void snackbar(String msg) {
    try {
      final snackBar = SnackBar(content: Text(msg));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      print("WARNING: snackbar failed exception: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      if (_is_bt_connected) {
        toast("Disconnecting...");
      } else {
        //toast("Not connected...");
      }
      //call it in any case just to be sure service it is stopped (.close()) method called
      await method_channel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      toast("WARNING: disconnect failed: $e");
    }
  }

  Future<void> connect() async {
    print("main.dart connect() start");

    bool logBtRx = PrefService.of(context).get('log_bt_rx') ?? false;
    bool gapMode = PrefService.of(context).get('ble_gap_scan_mode') ?? false;
    bool bleUartMode = PrefService.of(context).get(BLE_UART_MODE_KEY) ?? false;
    bool bleQstarzMode =
        PrefService.of(context).get(BLE_QSTARTZ_MODE_KEY) ?? false;

    if (logBtRx) {
      bool writeEnabled = false;
      try {
        writeEnabled = await method_channel.invokeMethod('is_write_enabled');
      } on PlatformException catch (e) {
        toast("WARNING: check write_enabled failed: $e");
      }
      if (writeEnabled == false) {
        toast(
            "Write external storage permission required for data loggging...");
        return;
      }

      bool canCreateFile = false;
      try {
        canCreateFile = await method_channel
            .invokeMethod('test_can_create_file_in_chosen_folder');
      } on PlatformException catch (e) {
        toast(
            "WARNING: check test_can_create_file_in_chosen_folder failed: $e");
      }
      if (canCreateFile == false) {
        //TODO: try req permission firstu
        toast(
            "Please go to Settings > re-tick 'Enable logging' (failed to access chosen log folder)");
        return;
      }
    }

    if (gapMode) {
      bool coarseLocationEnabled = await is_coarse_location_enabled();
      if (coarseLocationEnabled == false) {
        toast("Coarse Locaiton permission required for BLE GAP mode...");
        return;
      }
    }

    if (_is_bt_connected) {
      toast("Already connected...");
      return;
    }

    if (_is_bt_conn_thread_alive_likely_connecting) {
      toast("Connecting, please wait...");
      return;
    }

    settings_widget_state? sw =
        await check_and_update_selected_device(false, true);
    if (sw == null) {
      //toast("Please see Pre-connect checklist...");
      return;
    }

    bool connecting = false;
    try {
      connecting = await method_channel.invokeMethod('is_conn_thread_alive');
    } on PlatformException catch (e) {
      toast("WARNING: check _is_connecting failed: $e");
    }

    if (connecting) {
      toast("Connecting - please wait...");
      return;
    }

    String bdaddr = sw.get_selected_bdaddr(widget.pref_service) ?? "";
    if (!gapMode) {}

    print("main.dart connect() start1");

    _param_map = <dynamic, dynamic>{}; //clear last conneciton params state...
    String status = "unknown";
    try {
      print("main.dart connect() start connect start");
      final bool ret = await method_channel.invokeMethod('connect', {
        "bdaddr": bdaddr,
        'secure': PrefService.of(context).get('secure') ?? true,
        'reconnect': PrefService.of(context).get('reconnect') ?? false,
        'ble_gap_scan_mode': gapMode,
        BLE_QSTARTZ_MODE_KEY: bleQstarzMode,
        BLE_UART_MODE_KEY: bleUartMode,
        'log_bt_rx': logBtRx,
        'disable_ntrip': PrefService.of(context).get('disable_ntrip') ?? false,
        'ntrip_host': PrefService.of(context).get('ntrip_host'),
        'ntrip_port': PrefService.of(context).get('ntrip_port'),
        'ntrip_mountpoint': PrefService.of(context).get('ntrip_mountpoint'),
        'ntrip_user': PrefService.of(context).get('ntrip_user'),
        'ntrip_pass': PrefService.of(context).get('ntrip_pass'),
      });
      print("main.dart connect() start connect done");
      if (ret) {
        status =
            "Starting connection to:\n${sw.get_selected_bdname(widget.pref_service) ?? ""}" ??
                "(No name)";
      } else {
        status = "Failed to connect...";
      }

      print("main.dart connect() start2");
    } on PlatformException catch (e) {
      status = "Failed to start connection: '${e.message}'.";
      print(status);
    }

    print("main.dart connect() start3");

    setState(() {
      _status = status;
    });

    print("main.dart connect() start4");

    print("marin.dart connect() done");
  }

  Future<Map<dynamic, dynamic>> get_bd_map() async {
    Map<dynamic, dynamic>? ret;
    try {
      ret = await method_channel
          .invokeMethod<Map<dynamic, dynamic>>('get_bd_map');
      //print("got bt_map: $ret");
    } on PlatformException catch (e) {
      String status = "get_bd_map exception: '${e.message}'.";
      //print(status);
    }
    return ret ?? {};
  }

  Future<bool> is_bluetooth_on() async {
    bool? ret = false;
    try {
      ret = await method_channel.invokeMethod<bool>('is_bluetooth_on');
    } on PlatformException catch (e) {
      String status = "is_bluetooth_on error: '${e.message}'.";
      print(status);
    }
    return ret!;
  }

  Future<List<String>> check_permissions_not_granted() async {
    List<String> ret = ['failed_to_list_ungranted_permissions'];
    try {
      List<Object?>? ret0 = await method_channel
          .invokeMethod<List<Object?>>('check_permissions_not_granted');
      ret.clear();
      for (Object? o in ret0 ?? []) {
        ret.add((o ?? "").toString());
      }
    } on PlatformException catch (e) {
      String status = "check_permissions_not_granted error: '${e.message}'.";
      print(status);
    }
    return ret;
  }

  Future<bool> is_location_enabled() async {
    bool? ret = false;
    try {
      //print("is_location_enabled try0");
      ret = await method_channel.invokeMethod<bool>('is_location_enabled');
      //print("is_location_enabled got ret: $ret");
    } on PlatformException catch (e) {
      String status = "is_location_enabled exception: '${e.message}'.";
      print(status);
    }
    return ret!;
  }

  Future<bool> is_coarse_location_enabled() async {
    bool? ret = false;
    try {
      //print("is_coarse_location_enabled try0");
      ret =
          await method_channel.invokeMethod<bool>('is_coarse_location_enabled');
      //print("is_coarse_location_enabled got ret: $ret");
    } on PlatformException catch (e) {
      String status = "is_coarse_location_enabled exception: '${e.message}'.";
      print(status);
    }
    return ret!;
  }

  Future<bool> is_mock_location_enabled() async {
    bool? ret = false;
    try {
      //print("is_mock_location_enabled try0");
      ret = await method_channel.invokeMethod<bool>('is_mock_location_enabled');
      //print("is_mock_location_enabled got ret $ret");
    } on PlatformException catch (e) {
      String status = "is_mock_location_enabled exception: '${e.message}'.";
      print(status);
    }
    return ret!;
  }

  String get selected_device => _selected_device;

  Map<String, Icon> get check_state_map_icon => _check_state_map_icon;

  bool get is_ntrip_connected => _is_ntrip_connected;

  int get ntrip_packets_count => _ntrip_packets_count;

  bool get is_bt_conn_thread_alive_likely_connecting =>
      _is_bt_conn_thread_alive_likely_connecting;

  int get mock_location_set_ts => _mock_location_set_ts;

  String get mock_location_set_status => _mock_location_set_status;

  set mock_location_set_status(String value) {
    _mock_location_set_status = value;
  }
}
