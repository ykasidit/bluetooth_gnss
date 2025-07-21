import 'dart:developer' as developer;

import 'package:bluetooth_gnss/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pref/pref.dart';
import 'package:share_plus/share_plus.dart';

import 'const.dart';
import 'utils_ui.dart';

class ConnectScreenConnected extends StatefulWidget {
  const ConnectScreenConnected({super.key});
  @override
  ConnectScreenConnectedState createState() => ConnectScreenConnectedState();
}

class ConnectScreenConnectedState extends State<ConnectScreenConnected> {
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
        children: connectedRows(context),
      ),
    ));
  }
}

List<Widget> connectedRows(BuildContext context) {
  developer.log("connectingRows build start");
  return <Widget>[
    Card(
      child: Container(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: <Widget>[
                Text(
                  'Live status',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontFamily: 'GoogleSans', color: Colors.blueGrey),
                ),
                paramRow(context, 'lat',
                    double_fraction_digits: POS_FRACTION_DIGITS,
                    style: Theme.of(context).textTheme.headlineSmall),
                paramRow(context, 'lon',
                    double_fraction_digits: POS_FRACTION_DIGITS,
                    style: Theme.of(context).textTheme.headlineSmall),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () async {
                        var lcsv = getLatLonCsv();
                        if (lcsv.isEmpty) {
                          await toast("Position not ready");
                          return;
                        }
                        await Share.share(
                            'https://www.google.com/maps/search/?api=1&query=$lcsv');
                        if (context.mounted) {
                          snackbar(context, 'Shared: $lcsv');
                        }
                      },
                      child: const Icon(Icons.share),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(2.0),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        var lcsv = getLatLonCsv();
                        if (lcsv.isEmpty) {
                          await toast("Position not ready");
                          return;
                        }
                        await Clipboard.setData(ClipboardData(text: lcsv));
                        if (context.mounted) {
                          snackbar(context, 'Copied to clipboard: $lcsv');
                        }
                      },
                      child: const Icon(Icons.content_copy),
                    )
                  ],
                )
              ] +
              getDevSepcificRows(context) +
              [  const Padding(
                padding: EdgeInsets.all(5.0),
              )]+
              getStatRows(context)
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
              Text(connectSelectedDevice.value),
              const Padding(
                padding: EdgeInsets.all(5.0),
              ),
              Text(
                  "- You can now use other apps like 'Waze' normally.\n- Location is now from connected device\n- To stop, press the 'Disconnect' menu in top-right options.",
                  style: Theme.of(context).textTheme.bodySmall),
              const Padding(
                padding: EdgeInsets.all(5.0),
              ),
            ],
          )),
    ),
    Padding(
        padding: const EdgeInsets.all(5.0),
        child: Card(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isNtripConnected.value
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
                              PrefService.of(context).get('ntrip_mountpoint') !=
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
                      PrefService.of(context).get('ntrip_mountpoint') ?? "None",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const Padding(padding: EdgeInsets.all(10.0)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text("N NTRIP packets received:",
                      style: Theme.of(context).textTheme.bodySmall),
                  reactiveText(ntripPacketsCount,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        )))
  ];
}

List<Widget> getDevSepcificRows(BuildContext context) {
  if (isQstarz.value) {
      List<List<String>> m = [
        ["Device Time", "QSTARZ_timestamp"],
        ["Fix status", "QSTARZ_fix_status_matched"],
        ['RCR', "QSTARZ_rcr_logtype"],
        ['Float speed (km/h)', "QSTARZ_float_speed_kmh"],
        ['Float height (m)', "QSTARZ_float_height_m"],
        ["Heading (degrees)", "QSTARZ_heading_degrees"],
        ['G-sensor X', "QSTARZ_g_sensor_x"],
        ['G-sensor Y', "QSTARZ_g_sensor_y"],
        ['G-sensor Z', "QSTARZ_g_sensor_z"],
        ["Max SNR", "course"],
        ["HDOP", "QSTARZ_hdop"],
        ["VDOP", "QSTARZ_vdop"],
        ['N Satellites in view', "QSTARZ_satellite_count_view"],
        ['N Satellites used', "QSTARZ_satellite_count_used_str"],
        ['Fix quality', "QSTARZ_fix_quality_matched"],
        ['Battery (%)', "QSTARZ_battery_percent"],
      ];
      return paramRowList(context, m);
  } else {
    List<List<String>> m = [
      ["Time from GNSS", "ANY_rmc_ts"],
      ["Ellipsoidal Height", "ANY_ellipsoidal_height"],
      ["Orthometric (MSL) Height", "ANY_gga_alt"],
      ["Geoidal Height", "ANY_geoidal_height"],
      ["Fix status", "ANY_status"],
      ['Fix quality', "ANY_fix_quality"],
      ['UBLOX Fix Type', "UBX_POSITION_navStat"],
      ['UBLOX XY Accuracy (m)', "UBX_POSITION_hAcc"],
      ["UBLOX Z Accuracy(m)", "UBX_POSITION_vAcc"],
      ['HDOP', "hdop"],
      ["Course", "course"],
      ["N Sats used TOTAL", "n_sats"],
      ["N Galileo in use/view", "GA_n_sats_used"],
      ['N GPS in use/view', "GP_n_sats_used"],
      ['N GLONASS in use/view', "GL_n_sats_used"],
      ['N BeiDou in use/view', "GB_n_sats_used"],
      ['N QZSS in use/view', "GQ_n_sats_used"],
    ];
    List<Widget> ret = paramRowList(context, m);
    return ret;
  }
}

List<Widget> getStatRows(BuildContext context)
{
  List<List<String>> m = [
    ["System Time at Mock", "mock_location_system_ts"],
    ["GNSS Time at Mock", "mock_location_gnss_ts"],
    ["Mock use System Time", "mock_location_timestamp_use_system_time"],
    ["Mock Base Time", "mock_location_base_ts"],
    ["Mock Time Offset (ms)", "mock_location_timestamp_offset_millis"],
    ["Mock Final Time", "mock_location_set_ts"],
    ["Mock altitude type", "alt_type"],
    ["GGA count", "GN_GGA_count"],
    ["RMC count", "GN_RMC_count"],
    ["Log folder", "logfile_folder"],
    ["Logfile name", "logfile_name"],
    ["Logfile size (MB)", "logfile_size_mb"],
  ];
  List<Widget> ret = paramRowList(context, m);
  return ret;
}
