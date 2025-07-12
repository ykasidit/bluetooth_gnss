import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pref/pref.dart';

import 'home.dart';
import 'native_channels.dart';

const String bleUartModeKey = 'ble_uart_mode';
const String bleQstarzModeKey = 'ble_qstarz_mode';
late final PrefServiceShared prefService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); //https://stackoverflow.com/questions/57689492/flutter-unhandled-exception-servicesbinding-defaultbinarymessenger-was-accesse
  prefService = await PrefServiceShared.init(prefix: "pref_");
  await prefService.setDefaultValues(
          {
            'reconnect': false,
            'secure': true,
            'check_settings_location': false,
            'log_bt_rx': false,
            'disable_ntrip': false,
            'ble_gap_scan_mode': false,
            bleUartModeKey: false,
            bleQstarzModeKey: false,
            'autostart': false,
            'list_nearest_streams_first': true,
            'ntrip_host': "igs-ip.net",
            'ntrip_port': "2101"
          }
  );
  initEventChannels();
  runApp(App());
}


class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return PrefService(
        service: prefService,
        child: MaterialApp(
          title: 'Bluetooth GNSS',
          theme: ThemeData.dark(
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        )
    );
  }
}

