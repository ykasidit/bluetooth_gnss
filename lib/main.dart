// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';

import 'settings.dart';
import 'dart:async';


main() async {
  await PrefService.init(prefix: 'pref_');
  //PrefService.setString("target_bdaddr", null);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settings',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.indigo,
      ),
      home: ScrollableTabsDemo(),
    );
  }
}


enum TabsDemoStyle {
  iconsAndText,
  iconsOnly,
  textOnly
}

class _Page {
  const _Page({ this.icon, this.text });
  final IconData icon;
  final String text;
}

const List<_Page> _allPages = <_Page>[
  _Page(icon: Icons.bluetooth_connected, text: 'Connect'),
  _Page(icon: Icons.location_on, text: 'Location'),
  _Page(icon: Icons.satellite, text: 'Constellations'),
  _Page(icon: Icons.view_list, text: 'NMEA'),
];

class ScrollableTabsDemo extends StatefulWidget {
  @override
  ScrollableTabsDemoState createState() => ScrollableTabsDemoState();
}

class ScrollableTabsDemoState extends State<ScrollableTabsDemo> with SingleTickerProviderStateMixin {

  static const method_channel = MethodChannel("com.clearevo.bluetooth_gnss/engine");
  static const event_channel = EventChannel("com.clearevo.bluetooth_gnss/engine_events");

  String _status = "Loading status...";
  String _selected_device = "Loading selected device...";
  static const ICON_NOT_CONNECTED =  Icon(
    Icons.bluetooth_disabled,
    color: Colors.red,
    size: 60.0,
  );
  static const ICON_CONNECTED =  Icon(
    Icons.bluetooth_connected,
    color: Colors.blue,
    size: 60.0,
  );
  static const ICON_LOADING =  Icon(
    Icons.access_time,
    color: Colors.grey,
    size: 60.0,
  );

  static const ICON_OK =  Icon(
    Icons.check_circle,
    color: Colors.green,
    size: 60.0,
  );

  static const ICON_FAIL =  Icon(
    Icons.cancel,
    color: Colors.red,
    size: 60.0,
  );

  static const uninit_state = "Loading state...";

  //Map<String, String> _check_state_map =

  Map<String, Icon> _check_state_map_icon = {
    "Bluetooth On": ICON_LOADING,
    "Bluetooth Device Paired": ICON_LOADING,
    "Bluetooth Device Selected": ICON_LOADING,
    "Bluetooth Device Selected": ICON_LOADING,
    "Mock location enabled": ICON_LOADING,
  };



  Icon _main_icon = ICON_LOADING;
  String _main_state = "Loading...";
  bool _is_bt_connected = false;

  TabController _controller;
  TabsDemoStyle _demoStyle = TabsDemoStyle.iconsAndText;
  bool _customIndicator = false;

  Timer timer;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(Duration(seconds: 5), (Timer t) => check_and_update_selected_device());

    _controller = TabController(vsync: this, length: _allPages.length);

    check_and_update_selected_device();

    event_channel.receiveBroadcastStream().listen(
            (dynamic event) {

              Map<dynamic, dynamic> param_map = event;
              /*
          String eventstr = "$event";
          //print("got eventstr $eventstr");
          if (eventstr.contains(rx_event_splitter)) {
            List<String> splitted = eventstr.split(rx_event_splitter);
            if (splitted.length > 1 ) {
              print("got eventstr splitted $splitted");
              if (splitted[0] == "status" ) {
                setState(() {
                  String status = splitted[1];
                  print("setstate: $status");
                  _status = status;
                });
              }
            }
          }*/


        },
        onError: (dynamic error) {
          print('Received error: ${error.message}');
        }
    );

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void changeDemoStyle(TabsDemoStyle style) {
    setState(() {
      _demoStyle = style;
    });
  }

  Decoration getIndicator() {
    if (!_customIndicator)
      return const UnderlineTabIndicator();

    switch(_demoStyle) {
      case TabsDemoStyle.iconsAndText:
        return ShapeDecoration(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4.0)),
            side: BorderSide(
              color: Colors.white24,
              width: 2.0,
            ),
          ) + const RoundedRectangleBorder(
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
          ) + const CircleBorder(
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
          ) + const StadiumBorder(
            side: BorderSide(
              color: Colors.transparent,
              width: 4.0,
            ),
          ),
        );
    }
    return null;
  }

  Scaffold _scaffold;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = Theme.of(context).accentColor;

    _scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth GNSS'),
        actions: <Widget>[

          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              check_and_update_selected_device(true).then(
                      (sw) {
                        if (sw == null || sw.m_bdaddr_to_name_map == null) {
                          toast("Please turn ON Bluetooth and pair your Bluetooth Device first...");
                          return;
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) {
                              dynamic bdmap = sw.m_bdaddr_to_name_map;
                              print("sw.bdaddr_to_name_map: $bdmap");
                              return settings_widget(bdmap);
                            }
                            ),
                          );
                        }
                      }
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          indicator: getIndicator(),
          tabs: _allPages.map<Tab>((_Page page) {
            assert(_demoStyle != null);
            switch (_demoStyle) {
              case TabsDemoStyle.iconsAndText:
                return Tab(text: page.text, icon: Icon(page.icon));
              case TabsDemoStyle.iconsOnly:
                return Tab(icon: Icon(page.icon));
              case TabsDemoStyle.textOnly:
                return Tab(text: page.text);
            }
            return null;
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: connect,
        tooltip: 'Connect',
        child: Icon(Icons.bluetooth_connected),
      ), // This trailing comma makes auto-formatting nicer for build methods.
      body: TabBarView(
        controller: _controller,
        children: _allPages.map<Widget>((_Page page) {
          String pname = page.text;
          print ("page: $pname");

          switch (pname) {

            case "Connect":
              List<Widget> rows = null;
              if (_is_bt_connected) {

                rows = <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:
                    [
                      ICON_CONNECTED,
                      Text(
                        "Connected",
                        style: Theme.of(context).textTheme.headline,
                      ),
                    ]
                  ),
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                  ),
                  Text(
                    '$_status',
                    style: Theme.of(context).textTheme.headline,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                  ),
                  Text(
                    'Selected device:',
                    style: Theme.of(context).textTheme.caption,
                  ),
                  Text(
                      '$_selected_device'
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                  ),
                ];

          } else {

                rows = <Widget>[
                  Text(
                      'Pre-connect checklist:',
                      style: Theme.of(context).textTheme.headline,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                  ),
                ];

                for (String key in _check_state_map_icon.keys) {
                  Row row = Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children:
                      [
                        _check_state_map_icon[key],
                        Text(
                            key
                        ),
                      ]
                  );
                  rows.add(row);
                }

                List<Widget> bottom_widgets = [
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                  ),
                  Text(
                    'Next step:',
                    style: Theme.of(context).textTheme.headline,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                  ),
                  Text(
                    '$_status',
                    style: Theme.of(context).textTheme.body2,
                  ),
                ];
                rows.addAll(bottom_widgets);
              }

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: rows,
                  ),
                )
              );
              break;


            case "Locaiton":
              return Scaffold(
              );
          }
          return Scaffold();
        }).toList(),
      ),
    );

    return _scaffold;
  }


  /////////////functions

  void clear_disp_text() {
    _selected_device = "";
    _status = "";
  }

  //return settings_widget that can be used to get selected bdaddr
  Future<settings_widget_state> check_and_update_selected_device([bool return_sw_if_has_paired_dev=false]) async {

    _is_bt_connected = false;
    try {
      _is_bt_connected = await method_channel.invokeMethod('is_bt_connected');
    } on PlatformException catch (e) {
      toast("WARNING: check _is_bt_connected failed: $e");
    }

    _check_state_map_icon.clear();
    _main_icon = ICON_FAIL;
    _main_state = "Not ready";

    if (! (await is_bluetooth_on())) {
      String msg = "Bluetooth is OFF - Please turn ON Bluetooth...";
      clear_disp_text();
      setState(() {
        _check_state_map_icon["Blueototh is OFF"] = ICON_FAIL;
        _status = msg;

      });
      /*
      Fluttertoast.showToast(
          msg: msg
      );*/
      return null;
    }
    _check_state_map_icon["Blueototh powered ON"] = ICON_OK;

    Map<dynamic, dynamic> bd_map = await get_bd_map();
    if (bd_map.length == 0) {
      String msg = "Please pair your Bluetooth GPS/GNSS Receiver in phone Settings > Bluetooth first";
      clear_disp_text();
      setState(() {
        _check_state_map_icon["No paired Blueototh devices"] = ICON_FAIL;

        _status = msg;
        _selected_device = "No paired Bluetooth devices yet...";

      });
      /*
      Fluttertoast.showToast(
          msg: msg
      );*/
      return null;
    }
    _check_state_map_icon["Found some paired Blueototh devices"] = ICON_OK;

    settings_widget_state sw = settings_widget_state(bd_map);
    if (return_sw_if_has_paired_dev) {
      return sw;
    }

    if (sw.get_selected_bdaddr() == null) {
      String msg = "Please select your Bluetooth GPS/GNSS Receiver in Settings (the gear icon on top right)";
      /*Fluttertoast.showToast(
          msg: msg
      );*/
      setState(() {
        _check_state_map_icon["Device not selected in gear icon"] = ICON_FAIL;
        _selected_device = sw.get_selected_bd_summary();
        _status = msg;
      });
      _main_icon = ICON_NOT_CONNECTED;
      _main_state = "Not connected";

      return null;
    }

    _check_state_map_icon["Device selected"] = ICON_OK;
    _main_icon = ICON_OK;


    //ok - ready to connect
    setState(() {
      _selected_device = sw.get_selected_bd_summary();
      _status = "Please press the button below to connect...";
    });

    return sw;
  }

  void toast(String msg)
  {
    /*
    */
    if (true) {
      Fluttertoast.showToast(
        msg: msg,
      );
    } else {
      final snackBar = SnackBar(content: Text(msg));

      Scaffold.of(context).showSnackBar(snackBar);
    }

  }

  Future<void> connect() async {
    settings_widget_state sw = await check_and_update_selected_device();
    if (sw == null) {
      toast("Can't connect yet - please see Pre-connect checklist...");
      return;
    }

    String bdaddr = sw.get_selected_bdaddr();
    if (bdaddr == null) {
      toast(
        "Please select your Bluetooth GPS/GNSS Receiver device...",
      );

      Map<dynamic, dynamic> bdaddr_to_name_map = await get_bd_map();
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) {
              return settings_widget(bdaddr_to_name_map);
            }
        ),
      );
      return;
    }

    setState(() {
      _main_icon = ICON_LOADING;
      _main_state = "Connecting...";
    });

    String status = "unknown";
    try {
      final int ret = await method_channel.invokeMethod('connect', {"bdaddr": bdaddr});
      if (ret == 0) {
        status = "Connecting...";
      } else {
        status = "Failed to connect...";
        setState(() {
          _main_icon = ICON_NOT_CONNECTED;
          _main_state = "Not connected";
        });
      }

    } on PlatformException catch (e) {
      status = "Failed to start connection: '${e.message}'.";
    }

    setState(() {
      _status = status;
    });
  }

  Future<Map<dynamic, dynamic>> get_bd_map() async {
    Map<dynamic, dynamic> ret = null;
    try {
      ret = await method_channel.invokeMethod<Map<dynamic, dynamic>>('get_bd_map');
      print("got bt_map: $ret");
    } on PlatformException catch (e) {
      String status = "get_bd_map exception: '${e.message}'.";
      print(status);
    }
    return ret;
  }

  Future<bool> is_bluetooth_on() async {
    bool ret = false;
    try {
      ret = await method_channel.invokeMethod<bool>('is_bluetooth_on');
    } on PlatformException catch (e) {
      String status = "is_bluetooth_on exception: '${e.message}'.";
      print(status);
    }
    return ret;
  }

}
