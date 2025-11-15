import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'channels.dart';
import 'home.dart';

const String bleUartModeKey = 'ble_uart_mode';
const String bleQstarzModeKey = 'ble_qstarz_mode';
late final PrefServiceShared prefService;

String log_dir = "";


Future<void> main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); //https://stackoverflow.com/questions/57689492/flutter-unhandled-exception-servicesbinding-defaultbinarymessenger-was-accesse
  prefService = await PrefServiceShared.init(prefix: "pref_");
  await prefService.setDefaultValues({
    'reconnect': false,
    'secure': true,
    'device_cep': "5.0",
    'check_settings_location': false,
    'log_bt_rx': false,
    'disable_ntrip': false,
    'ble_gap_scan_mode': false,
    bleUartModeKey: false,
    bleQstarzModeKey: false,
    'autostart': false,
    'list_nearest_streams_first': true,
    'ntrip_host': "igs-ip.net",
    'ntrip_port': "2101",
    "mock_timestamp_use_system_time": true,
    "mock_timestamp_offset_secs": "0.0",
    "mock_lat_offset_meters": "0.0",
    "mock_lon_offset_meters": "0.0",
    "mock_alt_offset_meters": "0.0",

  });
  log_dir = await getLogDir();
  dlog("log_dir: $log_dir");
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
          theme: ThemeData.light(
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        ));
  }
}
