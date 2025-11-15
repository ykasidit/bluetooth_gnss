import 'package:bluetooth_gnss/connect.dart';
import 'package:flutter/material.dart';

import 'channels.dart';
import 'utils_ui.dart';

class ConnectScreenConnecting extends StatefulWidget {
  const ConnectScreenConnecting({super.key});
  @override
  ConnectScreenConnectingState createState() => ConnectScreenConnectingState();
}

class ConnectScreenConnectingState extends State<ConnectScreenConnecting> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Padding(
      padding: const EdgeInsets.all(5.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: connectingRows(context),
      ),
    ));
  }
}

List<Widget> connectingRows(BuildContext context) {
  dlog("connectingRows build start");
  return <Widget>[
    const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      iconLoading,
    ]),
    const Padding(
      padding: EdgeInsets.all(15.0),
    ),
    Text(
      connectStatus.value,
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const Padding(
      padding: EdgeInsets.all(10.0),
    ),
    Text(
      'Selected device:',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    reactiveText(connectSelectedDevice),
    const Padding(
      padding: EdgeInsets.all(10.0),
    ),
  ];
}
