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

enum TabsDemoStyle { iconsAndText, iconsOnly, textOnly }

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

class _Page {
  const _Page({this.icon, this.text});
  final IconData? icon;
  final String? text;
}

const List<_Page> _allPages = <_Page>[
  _Page(icon: Icons.bluetooth, text: tabConnect),
  _Page(icon: Icons.cloud_download, text: tabRtk),
  _Page(icon: Icons.view_list, text: tabMsg),
  /*
  TODO: add more pages?
  _Page(icon: Icons.location_on, text: 'Location'),
  _Page(icon: Icons.landscape, text: 'Map'),
  //Take photo with geo metadata + write on img
  //take vdo with geo metadata + write on vdo    
   */
];

class Tabs extends StatefulWidget {
  const Tabs(this.prefService, {super.key});
  final BasePrefService prefService;
  @override
  TabsState createState() => TabsState();
}

class TabsState extends State<Tabs>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const methodChannel =
      MethodChannel("com.clearevo.bluetooth_gnss/engine");
  static const eventChannel =
      EventChannel("com.clearevo.bluetooth_gnss/engine_events");
  static const uninitState = "Loading state...";

  TabsState();

  ////////connect tab
  List<String> talkerIds = ["GP", "GL", "GA", "GB", "GQ"];
  TabController? _controller;
  TabsDemoStyle _demoStyle = TabsDemoStyle.iconsAndText;
  final bool _customIndicator = false;
  Timer? timer;
  static String notHowToDisableMockLocation = "";
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
  bool get isBtConnected => _isBtConnected;

  String get status => _status;
  bool _isBtConnThreadConnecting = false;
  int _mockLocationSetTs = 0;
  set mockLocationSetTs(int value) {
    _mockLocationSetTs = value;
  }

  String mockLocationSetStatus = waitingDev;
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

  void filterMessages() {
    filteredMessages = msgList.where((message) {
      return isMessageInFilter(message);
    }).toList();
  }

  void showDialogMessage(Message message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(message.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: contentsController,
                    decoration: const InputDecoration(
                      hintText: 'Search in message...',
                    ),
                    onChanged: (query) {
                      // Implement search and highlight within the dialog
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(message.contents),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    // Implement share functionality
                  },
                ),
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  ScrollController scrollController = ScrollController();
  void scrollToBottom() {
    if (autoScroll &&
        filteredMessages.isNotEmpty &&
        scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }
  ///////////////////

  void wakelockEnable() async {
    if (await WakelockPlus.enabled == false) {
      WakelockPlus
          .enable(); //keep screen on for users to continuously monitor connection state
    }
  }

  void wakelockDisable() async {
    if (await WakelockPlus.enabled == true) {
      WakelockPlus
          .disable(); //keep screen on for users to continuously monitor connection state
    }
  }

  bool isInBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // These are the callbacks
    switch (state) {
      case AppLifecycleState.resumed:
        // widget is resumed
        isInBackground = false;
        break;
      case AppLifecycleState.inactive:
        isInBackground = true;
        // widget is inactive
        break;
      case AppLifecycleState.paused:
        // widget is paused
        isInBackground = true;
        break;
      case AppLifecycleState.detached:
        isInBackground = true;
        // widget is detached
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle this case.
        isInBackground = true;
        // widget is detached
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(
        const Duration(seconds: 2), (Timer t) => checkUpdateSelectedDev());
    _controller = TabController(vsync: this, length: _allPages.length);
    checkUpdateSelectedDev();

    eventChannel.receiveBroadcastStream().listen((dynamic event) {
      Map<dynamic, dynamic> paramMap = event;
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
            _mockLocationSetTs = paramMap['mock_location_set_ts'] ?? 0;
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
    if (timer != null) {
      timer!.cancel();
    }
  }

  @override
  void dispose() {
    developer.log('dispose()');
    cleanup();

    _controller!.dispose();
    // Remove the observer
    WidgetsBinding.instance.removeObserver(this);
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
  }

  Scaffold? _scaffold;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    _scaffold = Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Bluetooth GNSS'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                getBdMap().then((bdmap) {
                  if (_isBtConnected || _isBtConnThreadConnecting) {
                    toast(
                        "Please Disconnect first - cannot change settings during live connection...");
                    return;
                  } else {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) {
                          developer.log("sw.bdaddr_to_name_map: $getBdMap()");
                          return SettingsWidget(widget.prefService, bdmap);
                        }),
                      );
                    }
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
              onSelected: menuSelected,
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
            visible: !_isBtConnected,
            child: FloatingActionButton(
              onPressed: connect,
              tooltip: 'Connect',
              child: _floatingButtonIcon,
            )), // This trailing comma makes auto-formatting nicer for build methods.
        body: SafeArea(
          child: TabBarView(
            controller: _controller,
            children: _allPages.map<Widget>((_Page page) {
              String pname = page.text.toString();
              switch (pname) {
                case tabConnect:
                  return buildTabConnectUi(context, this);
                case tabRtk:
                  return buildTabRtkUi(context, this);
                case tabMsg:
                  return buildTabMsg(context, this);
              }
              return SingleChildScrollView(
                  child: Padding(
                padding: const EdgeInsets.all(25.0),
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
                ),
              ));
            }).toList(),
          ),
        ));

    return _scaffold!;
  }

  /////////////functions
  void menuSelected(String menu) async {
    developer.log('menu_selected: $menu');
    switch (menu) {
      case "disconnect":
        await disconnect();
        break;
      case "about":
        final packageInfo = await PackageInfo.fromPlatform();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) {
              return Scaffold(
                  appBar: AppBar(
                    title: const Text("About"),
                  ),
                  body: createAboutView(packageInfo.version.toString()));
            }),
          );
        }
        break;
      case "issues":
        await launchUrl(
            Uri.parse("https://github.com/ykasidit/bluetooth_gnss/issues"));
        break;
      case "project":
        await launchUrl(
            Uri.parse("https://github.com/ykasidit/bluetooth_gnss"));
        break;
    }
  }

  void clearDispText() {
    _selectedDevice = "";
    _status = "";
  }

  //return settings_widget that can be used to get selected bdaddr
  Future<Map<dynamic, dynamic>?> checkUpdateSelectedDev(
      [bool userPressedSettingsTakeActionAndRetSw = false,
      bool userPressedConnectTakeActionAndRetSw = false]) async {
    _floatingButtonIcon = iconBluetoothSettings;

    if (isInBackground) {
      developer.log('isInBackground so not refreshing state...');
      return null;
    }

    try {
      _isBtConnected = await methodChannel.invokeMethod('is_bt_connected');
      _isNtripConnected =
          await methodChannel.invokeMethod('is_ntrip_connected');
      ntripPacketsCount =
          await methodChannel.invokeMethod('get_ntrip_cb_count');

      if (_isBtConnected) {
        wakelockEnable();
      } else {
        wakelockDisable();
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
      toast("WARNING: check _is_bt_connected failed: $e");
      _isBtConnected = false;
    }

    try {
      _isBtConnThreadConnecting =
          await methodChannel.invokeMethod('is_conn_thread_alive');
      developer.log(
          "_is_bt_conn_thread_alive_likely_connecting: $_isBtConnThreadConnecting");
      if (_isBtConnThreadConnecting) {
        setState(() {
          _status = "Connecting...";
        });
        return null;
      }
    } on PlatformException catch (e) {
      toast("WARNING: check _is_connecting failed: $e");
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
          toast("Please turn ON Bluetooth...");
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
            toast("Please pair your Bluetooth GPS/GNSS Device...");
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
            toast("Please set Location ON and 'High Accuracy Mode'...");
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
          toast("Please set 'Mock Locaiton app' to 'Blueooth GNSS'..");
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

  void toast(String msg) async {
    try {
      await methodChannel.invokeMethod("toast", {"msg": msg});
    } catch (e) {
      developer.log("WARNING: toast failed exception: $e");
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
        toast("Disconnecting...");
      } else {
        //toast("Not connected...");
      }
      //call it in any case just to be sure service it is stopped (.close()) method called
      await methodChannel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      toast("WARNING: disconnect failed: $e");
    }
  }

  Future<void> connect() async {
    developer.log("main.dart connect() start");
    bool logBtRx = PrefService.of(context).get('log_bt_rx') ?? false;
    bool gapMode = PrefService.of(context).get('ble_gap_scan_mode') ?? false;

    if (logBtRx) {
      bool writeEnabled = false;
      try {
        writeEnabled = await methodChannel.invokeMethod('is_write_enabled');
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
        canCreateFile = await methodChannel
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
      bool coarseLocationEnabled = await isCoarseLocationEnabled();
      if (coarseLocationEnabled == false) {
        toast("Coarse Locaiton permission required for BLE GAP mode...");
        return;
      }
    }

    if (_isBtConnected) {
      toast("Already connected...");
      return;
    }

    if (_isBtConnThreadConnecting) {
      toast("Connecting, please wait...");
      return;
    }

    Map<dynamic, dynamic>? bdmap = await checkUpdateSelectedDev(false, true);
    if (bdmap == null) {
      //toast("Please see Pre-connect checklist...");
      return;
    }

    bool connecting = false;
    try {
      connecting = await methodChannel.invokeMethod('is_conn_thread_alive');
    } on PlatformException catch (e) {
      toast("WARNING: check _is_connecting failed: $e");
    }

    if (connecting) {
      toast("Connecting - please wait...");
      return;
    }

    if (!mounted) {
      return;
    }

    String bdaddr = PrefService.of(context).get("target_bdaddr");
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
      final bool ret = await methodChannel.invokeMethod('connect', {
        "bdaddr": bdaddr,
        'secure': PrefService.of(context).get('secure') ?? true,
        'reconnect': PrefService.of(context).get('reconnect') ?? false,
        'ble_gap_scan_mode': gapMode,
        'log_bt_rx': logBtRx,
        'disable_ntrip': PrefService.of(context).get('disable_ntrip') ?? false,
        'ntrip_host': PrefService.of(context).get('ntrip_host'),
        'ntrip_port': PrefService.of(context).get('ntrip_port'),
        'ntrip_mountpoint': PrefService.of(context).get('ntrip_mountpoint'),
        'ntrip_user': PrefService.of(context).get('ntrip_user'),
        'ntrip_pass': PrefService.of(context).get('ntrip_pass'),
      });
      developer.log("main.dart connect() start connect done");
      if (ret) {
        status = "Connecting ...";
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
    String? bdaddr = getSelectedBdaddr(prefService);
    //developer.log("get_selected_bdname: bdaddr: $bdaddr");
    Map<dynamic, dynamic> bdMap = await getBdMap();
    if (!(bdMap.containsKey(bdaddr))) {
      return "";
    }
    return bdMap[bdaddr] ?? "";
  }

  Future<String> getSelectedBdSummary(BasePrefService prefService) async {
    //developer.log("get_selected_bd_summary 0");
    String ret = '';
    String bdaddr = getSelectedBdaddr(prefService);
    //developer.log("get_selected_bd_summary selected bdaddr: $bdaddr");
    String bdname = await getSelectedBdname(prefService);
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
    } on PlatformException {
      //String status = "get_bd_map exception: '${e.message}'.";
      //developer.log(status);
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
}
