import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'tabs.dart';

Widget BuildTabRtkUi(BuildContext context, TabsState state) {
  return SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Card(
              child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.is_ntrip_connected
                      ? 'NTRIP Connected'
                      : 'NTRIP Not Connected',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontFamily: 'GoogleSans',
                        color: Colors.blueGrey,
                      ),
                ),
                const Padding(padding: EdgeInsets.all(10.0)),
                Text((PrefService.of(context).get('ntrip_host') != null &&
                        PrefService.of(context).get('ntrip_port') != null)
                    ? "${PrefService.of(context).get('ntrip_host')}:${PrefService.of(context).get('ntrip_port')}"
                    : ''),
                const Padding(padding: EdgeInsets.all(10.0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text("NTRIP Server/Login filled:",
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                        (PrefService.of(context).get('ntrip_host') != null &&
                                PrefService.of(context)
                                    .get('ntrip_host')
                                    .toString()
                                    .isNotEmpty &&
                                PrefService.of(context).get('ntrip_port') !=
                                    null &&
                                PrefService.of(context)
                                    .get('ntrip_port')
                                    .toString()
                                    .isNotEmpty &&
                                PrefService.of(context)
                                        .get('ntrip_mountpoint') !=
                                    null &&
                                PrefService.of(context)
                                    .get('ntrip_mountpoint')
                                    .toString()
                                    .isNotEmpty &&
                                PrefService.of(context).get('ntrip_user') !=
                                    null &&
                                PrefService.of(context)
                                    .get('ntrip_user')
                                    .toString()
                                    .isNotEmpty &&
                                PrefService.of(context).get('ntrip_pass') !=
                                    null &&
                                PrefService.of(context)
                                    .get('ntrip_pass')
                                    .toString()
                                    .isNotEmpty)
                            ? ((PrefService.of(context).get('disable_ntrip') ??
                                    false)
                                ? "Yes but disabled"
                                : "Yes")
                            : "No",
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(10.0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text("NTRIP Stream selected:",
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                        PrefService.of(context).get('ntrip_mountpoint') ??
                            "None",
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(10.0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text("N NTRIP packets received:",
                        style: Theme.of(context).textTheme.bodySmall),
                    Text("$state.ntrip_packets_count",
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            )),
          ))));
}
