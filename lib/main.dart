import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pref/pref.dart';

import 'tab_messages.dart';
import 'tabs.dart';

const String BLE_UART_MODE_KEY = 'ble_uart_mode';
const String BLE_QSTARTZ_MODE_KEY = 'ble_qstarz_mode';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); //https://stackoverflow.com/questions/57689492/flutter-unhandled-exception-servicesbinding-defaultbinarymessenger-was-accesse
  final prefservice = await PrefServiceShared.init(prefix: "pref_");
  await prefservice.setDefaultValues(
          {
            'reconnect': false,
            'secure': true,
            'check_settings_location': false,
            'log_bt_rx': false,
            'disable_ntrip': false,
            'ble_gap_scan_mode': false,
            BLE_UART_MODE_KEY: false,
            BLE_QSTARTZ_MODE_KEY: false,
            'autostart': false,
            'list_nearest_streams_first': true,
            'ntrip_host': "igs-ip.net",
            'ntrip_port': "2101"
          }
  );

  runApp(App(prefservice));
}


class App extends StatefulWidget {
  // This widget is the root of your application.

  const App(this.pref_service, {super.key});
  final BasePrefService pref_service;

  @override
  AppState createState() => AppState();
}

class AppState extends State<App> {

  Tabs? m_widget;

  @override
  Widget build(BuildContext context) {
    m_widget = Tabs(widget.pref_service);
    return PrefService(
        service: widget.pref_service,
        child: MaterialApp(
          title: 'Bluetooth GNSS',
          home: m_widget,
    ));
  }
}

