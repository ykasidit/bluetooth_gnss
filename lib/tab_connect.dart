import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'engine.dart';

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
                  Text(paramMap['lat_double_07_str'] as String? ?? waitingDev,
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Lon:',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(paramMap['lon_double_07_str'] as String? ?? waitingDev,
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      String content =
                          "${paramMap['lat_double_07_str'] ?? waitingDev},${paramMap['lon_double_07_str'] ?? waitingDev}"; //no space after comma for sharing to gmaps
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
                          "${paramMap['lat_double_07_str'] ?? waitingDev},${paramMap['lon_double_07_str'] ?? waitingDev}";
                      Clipboard.setData(ClipboardData(text: content))
                          .then((result) {
                        state.snackbar('Copied to clipboard: $content');
                      });
                    },
                    child: const Icon(Icons.content_copy),
                  )
                ],
              )
              ] + getDevSepcificRows(context, state) + [
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
                  Text(paramMap["alt_type"] as String? ?? waitingDev,
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
                      paramMap["GN_GGA_count_str"] as String? ??
                          paramMap["GP_GGA_count_str"] as String? ??
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
                      paramMap["GN_RMC_count_str"] as String? ??
                          paramMap["GP_RMC_count_str"] as String? ??
                          waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Current log folder:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["logfile_folder"] as String? ?? waitingDev,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Current log name:',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(paramMap["logfile_name"] as String? ?? waitingDev,
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

Map<String,String> QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP = {
'B':"POI",
'T':"time",
'D':'distance',
'S':'speed'
};

String getQstarzRCRLogType(int? asciiCode) {
  if (asciiCode == null) {
    return "";
  }
  String character = String.fromCharCode(asciiCode);
  String? lt = QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP[character];
  return "$character${lt==null?'':' ($lt)'}";
}
String getgetQstarzDateime(int? timestampS, int? millisecond) {
  if (timestampS == null || millisecond == null) {
    return "";
  }
  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestampS * 1000 + millisecond);
  return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
      "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}.${millisecond.toString().padLeft(3, '0')}";
}

List<Widget> getDevSepcificRows(BuildContext context, TabsState state) {
  Map<dynamic, dynamic> paramMap = state.paramMap;

  if (state.isQstarz) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Device Time:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(getgetQstarzDateime(paramMap['QSTARZ_timestamp_s'] as int? ?? 0, paramMap['QSTARZ_millisecond'] as int? ?? 0),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Fix status:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              (paramMap['QSTARZ_fix_status_matched'] ?? waitingDev).toString(),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('RCR:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              getQstarzRCRLogType(paramMap['QSTARZ_rcr'] as int?),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Float speed (km/h):',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_float_speed_kmh_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Float height (m):',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_float_height_m_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Heading (degrees):',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_heading_degrees_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('G-sensor X:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_g_sensor_x_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('G-sensor Y:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_g_sensor_y_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('G-sensor Z:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_g_sensor_z_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Max SNR:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_max_snr_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('HDOP:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_hdop_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('VDOP:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_vdop_double_02_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('N Satellites in view:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_satellite_count_view_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('N Satellites used:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_satellite_count_used_str'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Fix quality:',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['QSTARZ_fix_quality_matched'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Battery (%)',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              paramMap['battery_percent'] as String? ?? waitingDev,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      )

    ];
  }

  return [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Time from GNSS:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap['GN_time'] as String? ?? paramMap['GP_time'] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Ellipsoidal Height:',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            paramMap['GN_ellipsoidal_height_double_02_str'] as String? ??
                paramMap['GP_ellipsoidal_height_double_02_str'] as String? ??
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
            paramMap['GN_gga_alt_double_02_str'] as String? ??
                paramMap['GP_gga_alt_double_02_str'] as String? ??
                waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Geoidal Height:', style: Theme.of(context).textTheme.bodySmall),
        Text(
            paramMap['GN_geoidal_height_double_02_str'] as String? ??
                paramMap['GP_geoidal_height_double_02_str'] as String? ??
                waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Fix status:', style: Theme.of(context).textTheme.bodySmall),
        Text((paramMap["GN_status"] as String? ?? paramMap["GP_status"] as String? ?? "No data"),
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Fix quality:', style: Theme.of(context).textTheme.bodySmall),
        Text(
            paramMap["GN_fix_quality"] as String? ??
                paramMap["GP_fix_quality"] as String? ??
                waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('UBLOX Fix Type:', style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["UBX_POSITION_navStat"] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('UBLOX XY Accuracy(m):',
            style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["UBX_POSITION_hAcc"] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('UBLOX Z Accuracy(m):',
            style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["UBX_POSITION_vAcc"] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('HDOP:', style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["hdop_str"] as String? ?? waitingDev,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Course:', style: Theme.of(context).textTheme.bodySmall),
        Text(paramMap["course_str"] as String? ?? waitingDev,
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
  ];
}
