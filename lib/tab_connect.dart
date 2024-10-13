import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'tabs.dart';

Widget buildTabConnectUi(BuildContext context, TabsState state) {
  Map<dynamic, dynamic> paramMap = state.paramMap;
  List<Widget> rows = List.empty();
  if (state.isBtConnected) {
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
                  Text((paramMap['lat_double_07_str'] ?? waitingDev),
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Lon:',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text((paramMap['lon_double_07_str'] ?? waitingDev),
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      String content =
                          (paramMap['lat_double_07_str'] ?? waitingDev) +
                              "," /* no space here for sharing to gmaps */ +
                              (paramMap['lon_double_07_str'] ?? waitingDev);
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
                          (paramMap['lat_double_07_str'] ?? waitingDev) +
                              "," +
                              (paramMap['lon_double_07_str'] ?? waitingDev);
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
                  Text(paramMap['GN_time'] ?? paramMap['GP_time'] ?? waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Ellipsoidal Height:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      paramMap['GN_ellipsoidal_height_double_02_str'] ??
                          paramMap['GP_ellipsoidal_height_double_02_str'] ??
                          waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Orthometric (MSL) Height:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      paramMap['GN_gga_alt_double_02_str'] ??
                          paramMap['GP_gga_alt_double_02_str'] ??
                          waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Geoidal Height:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      paramMap['GN_geoidal_height_double_02_str'] ??
                          paramMap['GP_geoidal_height_double_02_str'] ??
                          waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Fix status:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      (paramMap["GN_status"] ??
                          paramMap["GP_status"] ??
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
                      paramMap["GN_fix_quality"] ??
                          paramMap["GP_fix_quality"] ??
                          waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('UBLOX Fix Type:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["UBX_POSITION_navStat"] ?? waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('UBLOX XY Accuracy(m):',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["UBX_POSITION_hAcc"] ?? waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('UBLOX Z Accuracy(m):',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["UBX_POSITION_vAcc"] ?? waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('HDOP:', style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["hdop_str"] ?? waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Course:', style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["course_str"] ?? waitingDev,
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
                      ((paramMap["GP_n_sats_used"] ?? 0) +
                              (paramMap["GL_n_sats_used"] ?? 0) +
                              (paramMap["GA_n_sats_used"] ?? 0) +
                              (paramMap["GB_n_sats_used"] ?? 0) +
                              (paramMap["GQ_n_sats_used"] ?? 0))
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
                      "${paramMap["GA_n_sats_used_str"] ?? waitingDev} / ${paramMap["GA_n_sats_in_view_str"] ?? waitingDev}",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N GPS in use/view:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      "${paramMap["GP_n_sats_used_str"] ?? waitingDev} / ${paramMap["GP_n_sats_in_view_str"] ?? waitingDev}",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N GLONASS in use/view:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      "${paramMap["GL_n_sats_used_str"] ?? waitingDev} / ${paramMap["GL_n_sats_in_view_str"] ?? waitingDev}",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N BeiDou in use/view:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      "${paramMap["GB_n_sats_used_str"] ?? waitingDev} / ${paramMap["GB_n_sats_in_view_str"] ?? waitingDev}",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('N QZSS in use/view:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      "${paramMap["GQ_n_sats_used_str"] ?? waitingDev} / ${paramMap["GQ_n_sats_in_view_str"] ?? waitingDev}",
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
                  Text(state.mockLocationSetStatus,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Alt type used:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["alt_type"] ?? waitingDev,
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
                      paramMap["GN_GGA_count_str"] ??
                          paramMap["GP_GGA_count_str"] ??
                          waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Total RMC Count:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      paramMap["GN_RMC_count_str"] ??
                          paramMap["GP_RMC_count_str"] ??
                          waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Current log folder:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["logfile_folder"] ?? waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Current log name:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["logfile_name"] ?? waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Current log size (MB):',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                      paramMap["logfile_n_bytes"] == null
                          ? waitingDev
                          : (paramMap["logfile_n_bytes"] / 1000000).toString(),
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
                iconConnected,
                const Padding(
                  padding: EdgeInsets.all(5.0),
                ),
                Text(state.selectedDevice),
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
  } else if (state.isBtConnected == false && state.isBtConnThreadConnecting) {
    rows = <Widget>[
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        iconLoading,
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
      Text(state.selectedDevice),
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
    for (String key in state.checkStateMapIcon.keys) {
      Row row = Row(mainAxisAlignment: MainAxisAlignment.start, children: [
        state.checkStateMapIcon[key]!,
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
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: rows,
    ),
  ));
}
