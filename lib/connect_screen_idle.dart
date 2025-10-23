import 'dart:developer' as developer;

import 'package:bluetooth_gnss/connect.dart';
import 'package:flutter/material.dart';

import 'utils_ui.dart';

class ConnectScreenIdle extends StatefulWidget {
  const ConnectScreenIdle({super.key});
  @override
  ConnectScreenIdleState createState() => ConnectScreenIdleState();
}

class ConnectScreenIdleState extends State<ConnectScreenIdle> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: idleRows(context),
      ),
    ));
  }
}

List<Widget> idleRows(BuildContext context) {
  developer.log("idleRows build start");
  List<Widget> rows = <Widget>[
    Text(
      'Pre-connect checklist',
      style: Theme.of(context)
          .textTheme
          .titleSmall!
          .copyWith(fontFamily: 'GoogleSans', color: Colors.blueGrey),
      //style: Theme.of(context).textTheme.headline,
    ),
    const Padding(
      padding: EdgeInsets.all(10.0),
    ),
  ];

  rows.add(reactiveIconMapCard(checkStateMapIcon));

  List<Widget> bottomWidgets = [
    const Padding(
      padding: EdgeInsets.all(15.0),
    ),
    Card(
        child: Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(15.0),
        ),
        Text(
          'Next step',
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontFamily: 'GoogleSans',
                color: Colors.blueGrey,
              ),
        ),
        const Padding(
          padding: EdgeInsets.all(10.0),
        ),
        Container(
          padding: const EdgeInsets.all(10.0),
          child: reactiveText(
            connectStatus,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    ))
  ];
  rows.addAll(bottomWidgets);
  developer.log("notConnectedRows build done");
  return rows;
}
