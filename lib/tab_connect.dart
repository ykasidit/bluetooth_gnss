import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';

import 'tabs.dart';

Widget BuildTabConnectUi(BuildContext context, TabsState state) {
  Map<dynamic, dynamic> _param_map = state.param_map;
  List<Widget> rows = List.empty();
  if (state.is_bt_connected) {
    rows = <Widget>[
      Card(
        child: Container(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: <Widget>[
              Text(
                'Live status',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(fontFamily: 'GoogleSans', color: Colors.blueGrey),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Lat:',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text((_param_map['lat_double_07_str'] ?? WAITING_DEV),
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Lon:',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text((_param_map['lon_double_07_str'] ?? WAITING_DEV),
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      String content =
                          (_param_map['lat_double_07_str'] ?? WAITING_DEV) +
                              "," /* no space here for sharing to gmaps */ +
                              (_param_map['lon_double_07_str'] ?? WAITING_DEV);
                      Share.share(
                              'https://www.google.com/maps/search/?api=1&query=$content')
                          .then((result) {
                        state.snackbar('Shared: $content');
                      });
                    },
                    child: const Icon(Icons.share),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(2.0),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      String content =
                          (_param_map['lat_double_07_str'] ?? WAITING_DEV) +
                              "," +
                              (_param_map['lon_double_07_str'] ?? WAITING_DEV);
                      Clipboard.setData(ClipboardData(text: content))
                          .then((result) {
                        state.snackbar('Copied to clipboard: $content');
                      });
                    },
                    child: const Icon(Icons.content_copy),
                  )
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Time from GNSS:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      _param_map['GN_time'] ??
                          _param_map['GP_time'] ??
                          WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Ellipsoidal Height:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      _param_map['GN_ellipsoidal_height_double_02_str'] ??
                          _param_map['GP_ellipsoidal_height_double_02_str'] ??
                          WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Orthometric (MSL) Height:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      _param_map['GN_gga_alt_double_02_str'] ??
                          _param_map['GP_gga_alt_double_02_str'] ??
                          WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Geoidal Height:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      _param_map['GN_geoidal_height_double_02_str'] ??
                          _param_map['GP_geoidal_height_double_02_str'] ??
                          WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Fix status:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      (_param_map["GN_status"] ??
                          _param_map["GP_status"] ??
                          "No data"),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Fix quality:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      _param_map["GN_fix_quality"] ??
                          _param_map["GP_fix_quality"] ??
                          WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('UBLOX Fix Type:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(_param_map["UBX_POSITION_navStat"] ?? WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('UBLOX XY Accuracy(m):',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(_param_map["UBX_POSITION_hAcc"] ?? WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('UBLOX Z Accuracy(m):',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(_param_map["UBX_POSITION_vAcc"] ?? WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('HDOP:', style: Theme.of(context).textTheme.bodySmall),
                  Text(_param_map["hdop_str"] ?? WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Course:', style: Theme.of(context).textTheme.bodySmall),
                  Text(_param_map["course_str"] ?? WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const Padding(
                padding: EdgeInsets.all(5.0),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N Sats used TOTAL:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      ((_param_map["GP_n_sats_used"] ?? 0) +
                              (_param_map["GL_n_sats_used"] ?? 0) +
                              (_param_map["GA_n_sats_used"] ?? 0) +
                              (_param_map["GB_n_sats_used"] ?? 0) +
                              (_param_map["GQ_n_sats_used"] ?? 0))
                          .toString(),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N Galileo in use/view:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      "${_param_map["GA_n_sats_used_str"] ?? WAITING_DEV} / ${_param_map["GA_n_sats_in_view_str"] ?? WAITING_DEV}",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N GPS in use/view:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      "${_param_map["GP_n_sats_used_str"] ?? WAITING_DEV} / ${_param_map["GP_n_sats_in_view_str"] ?? WAITING_DEV}",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N GLONASS in use/view:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      "${_param_map["GL_n_sats_used_str"] ?? WAITING_DEV} / ${_param_map["GL_n_sats_in_view_str"] ?? WAITING_DEV}",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N BeiDou in use/view:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      "${_param_map["GB_n_sats_used_str"] ?? WAITING_DEV} / ${_param_map["GB_n_sats_in_view_str"] ?? WAITING_DEV}",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N QZSS in use/view:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      "${_param_map["GQ_n_sats_used_str"] ?? WAITING_DEV} / ${_param_map["GQ_n_sats_in_view_str"] ?? WAITING_DEV}",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const Padding(
                padding: EdgeInsets.all(5.0),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Location sent to Android:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(state.mock_location_set_status,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Alt type used:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(_param_map["alt_type"] ?? WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const Padding(
                padding: EdgeInsets.all(5.0),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Total GGA Count:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      _param_map["GN_GGA_count_str"] ??
                          _param_map["GP_GGA_count_str"] ??
                          WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Total RMC Count:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      _param_map["GN_RMC_count_str"] ??
                          _param_map["GP_RMC_count_str"] ??
                          WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Current log folder:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(_param_map["logfile_folder"] ?? WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Current log name:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(_param_map["logfile_name"] ?? WAITING_DEV,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Current log size (MB):',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      _param_map["logfile_n_bytes"] == null
                          ? WAITING_DEV
                          : (_param_map["logfile_n_bytes"] / 1000000)
                              .toString(),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(10.0),
      ),
      Card(
        child: Container(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: <Widget>[
                Text(
                  'Connected',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(fontFamily: 'GoogleSans', color: Colors.grey),
                ),
                const Padding(
                  padding: EdgeInsets.all(5.0),
                ),
                ICON_CONNECTED,
                const Padding(
                  padding: EdgeInsets.all(5.0),
                ),
                Text(state.selected_device),
                const Padding(
                  padding: EdgeInsets.all(5.0),
                ),
                Text(
                    "- You can now use other apps like 'Waze' normally.\n- Location is now from connected device\n- To stop, press the 'Disconnect' menu in top-right options.",
                    style: Theme.of(context).textTheme.bodySmall),
                const Padding(
                  padding: EdgeInsets.all(5.0),
                ),
                /*Text(
                                        ""+note_how_to_disable_mock_location.toString(),
                                        style: Theme.of(context).textTheme.caption
                                ),*/
              ],
            )),
      ),
    ];
  } else if (state.is_bt_connected == false &&
      state.is_bt_conn_thread_alive_likely_connecting) {
    rows = <Widget>[
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ICON_LOADING,
      ]),
      const Padding(
        padding: EdgeInsets.all(15.0),
      ),
      Text(
        state.status,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const Padding(
        padding: EdgeInsets.all(10.0),
      ),
      Text(
        'Selected device:',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      Text(state.selected_device),
      const Padding(
        padding: EdgeInsets.all(10.0),
      ),
    ];
  } else {
    rows = <Widget>[
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

    List<Widget> checklist = [];
    for (String key in state.check_state_map_icon.keys) {
      Row row = Row(mainAxisAlignment: MainAxisAlignment.start, children: [
        state.check_state_map_icon[key]!,
        Container(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              key,
              style: Theme.of(context).textTheme.bodySmall,
            )),
      ]);
      checklist.add(row);
    }

    rows.add(Card(
        child: Container(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: checklist,
      ),
    )));

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
            child: Text(
              state.status,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ))
    ];
    rows.addAll(bottomWidgets);
  }

  return SingleChildScrollView(
      child: Padding(
    padding: const EdgeInsets.all(5.0),
    child: Container(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: rows,
    )),
  ));
}
