// The original content is temporarily commented out to allow generating a self-contained demo - feel free to uncomment later.

// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:pref/pref.dart';
//
// import 'tabs.dart';
//
// const String bleUartModeKey = 'ble_uart_mode';
// const String bleQstarzModeKey = 'ble_qstarz_mode';
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized(); //https://stackoverflow.com/questions/57689492/flutter-unhandled-exception-servicesbinding-defaultbinarymessenger-was-accesse
//   final prefservice = await PrefServiceShared.init(prefix: "pref_");
//   await prefservice.setDefaultValues(
//           {
//             'reconnect': false,
//             'secure': true,
//             'check_settings_location': false,
//             'log_bt_rx': false,
//             'disable_ntrip': false,
//             'ble_gap_scan_mode': false,
//             bleUartModeKey: false,
//             bleQstarzModeKey: false,
//             'autostart': false,
//             'list_nearest_streams_first': true,
//             'ntrip_host': "igs-ip.net",
//             'ntrip_port': "2101"
//           }
//   );
//
//   runApp(App(prefservice));
// }
//
//
// class App extends StatefulWidget {
//   // This widget is the root of your application.
//
//   const App(this.prefService, {super.key});
//   final BasePrefService prefService;
//
//   @override
//   AppState createState() => AppState();
// }
//
// class AppState extends State<App> {
//
//   Tabs? mWidget;
//
//   @override
//   Widget build(BuildContext context) {
//     mWidget = Tabs(widget.prefService);
//     return PrefService(
//         service: widget.prefService,
//         child: MaterialApp(
//           title: 'Bluetooth GNSS',
//           home: mWidget,
//     ));
//   }
// }
//
//

import 'package:flutter/material.dart';
import 'package:bluetooth_gnss/src/rust/api/simple.dart';
import 'package:bluetooth_gnss/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
        body: Center(
          child: Text(
              'Action: Call Rust `greet("Tom")`\nResult: `${greet(name: "Tom")}`'),
        ),
      ),
    );
  }
}
