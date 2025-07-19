import 'dart:async';
import 'dart:developer' as developer;

import 'package:bluetooth_gnss/connect_screen.dart';
import 'package:bluetooth_gnss/settings_screen.dart';
import 'package:bluetooth_gnss/utils_ui.dart';
import 'package:flutter/material.dart';
import 'channels.dart';
import 'connect.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final screens = [
    const ConnectScreen(),
    MapScreen(),
    const SettingsScreen(),
  ];

  Timer? _checkConnectTimer;
  StreamSubscription<dynamic>? _eventChannelSubscription;

  @override
  void initState()
  {
    super.initState();
    developer.log("home initState()");
    developer.log("home event stream sub");
    _eventChannelSubscription = initEventChannels();
    Timer.periodic(const Duration(seconds: 2), (timer) {
      checkConnectState();
    });
  }

  @override
  void dispose() {
    developer.log("home dispose()");
    developer.log("home event stream cancel");
    _checkConnectTimer?.cancel();
    _eventChannelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth GNSS'),
        actions: [
          /*IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {},
          ),*/
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text('Menu', style: TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => setState(() => currentIndex = 2),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Bluetooth GNSS',
                  applicationVersion: '1.0.0',
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bluetooth), label: 'Connect'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await onFloatingButtonTap();
          } catch (ex, tr) {
            developer.log("onFloatingButtonTap exception: $ex: $tr");
          }
        },
        child: reactiveIcon(floatingButtonIcon),
      ),
    );
  }
}

ValueNotifier<IconData> floatingButtonIcon = ValueNotifier(Icons.access_time_filled_rounded);
