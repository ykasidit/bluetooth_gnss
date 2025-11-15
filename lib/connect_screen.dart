
import 'package:bluetooth_gnss/connect.dart';
import 'package:flutter/material.dart';

import 'channels.dart';
import 'connect_screen_connected.dart';
import 'connect_screen_connecting.dart';
import 'connect_screen_idle.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectState>(
      valueListenable: connectState,
      builder: (context, state, child) {
        dlog("connec_screen rebuild connect_state: $state");
        switch (state) {
          case ConnectState.Loading:
            return const Center(child: CircularProgressIndicator());
          case ConnectState.PendingRequirements:
            return ConnectScreenIdle();
          case ConnectState.ReadyToConnect:
            return ConnectScreenIdle();
          case ConnectState.Connecting:
            return ConnectScreenConnecting();
          case ConnectState.Connected:
            return ConnectScreenConnected();
        }
      },
    );
  }
}
