
import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:flutter/services.dart';
import 'dart:math' show cos, sqrt, asin;

class settings_widget extends StatefulWidget {

  settings_widget(Map<dynamic, dynamic> this._bd_map);
  Map<dynamic, dynamic> _bd_map;
  final String title = "Settings";

  @override
  settings_widget_state createState() => settings_widget_state(_bd_map);
}


class settings_widget_state extends State<settings_widget> {

  Map<dynamic, dynamic> m_bdaddr_to_name_map = new Map<dynamic, dynamic>();
  String _selected_dev = "Loading...";

  static const method_channel = MethodChannel("com.clearevo.bluetooth_gnss/engine");
  static const event_channel = EventChannel("com.clearevo.bluetooth_gnss/settings_events");
  void toast(String msg) async
  {
    try {
      await method_channel.invokeMethod(
          "toast",
          {
            "msg": msg
          }
      );

    }  catch (e) {
      print("WARNING: toast failed exception: $e");
    }
  }

  @override
  void initState() {
    _selected_dev = get_selected_bd_summary();
    event_channel.receiveBroadcastStream().listen(
            (dynamic event) async {

          Map<dynamic, dynamic> event_map = event;

    if (event_map.containsKey('callback_src')) {
            try {
              print("settings got callback event: $event_map");
            } catch (e) {
              print('parse event_map exception: $e');
            }

            if (event_map["callback_src"] == "get_mountpoint_list") {
              print("dismiss progress dialog now0");
              if (m_pr != null) {
                print("dismiss progress dialog now...");
                m_pr.hide();
                //new Future.delayed(const Duration(seconds: 1), () => (m_pr != null && m_pr.isShowing()) ? m_pr.dismiss() : null); //fast dismisses wont close the dialog like if no internet cases
              }

              //get list from native engine
              List<dynamic> ori_mpl = event_map["callback_payload"];
              print("got mpl: $ori_mpl");
              if (ori_mpl == null || ori_mpl.length == 0) {
                toast("Failed to list mount-points list from server specified...");
                return;
              }

              //conv to List<String> and sort
              List<String> mount_point_str_list = List<String>.generate(ori_mpl.length, (i) => "${ori_mpl[i]}");

              //filter startswith STR;
              mount_point_str_list = mount_point_str_list.where((s) => s.startsWith('STR;')).toList();

              //remove starting STR; to sort by mountpoint name
              mount_point_str_list = List<String>.generate(mount_point_str_list.length, (i) => "${mount_point_str_list[i].substring(4)}");

              //filter for that contains ; so wont have errors for split further below
              mount_point_str_list = mount_point_str_list.where((s) => s.contains(';')).toList();

              mount_point_str_list.sort();
              print("mount_point_str_list: $mount_point_str_list");

              int nmpl = mount_point_str_list.length;
              toast("Found $nmpl mountpoints...");
              bool sort_by_nearest = PrefService.of(context).get('list_nearest_streams_first') ?? false;
              print('sort_by_nearest: $sort_by_nearest');

              List<Map<String, String>> mount_point_map_list = new List.empty(growable: true);

              for (String val in mount_point_str_list) {
                  List<String> parts = val.split(";");
                  //ref https://software.rtcm-ntrip.org/wiki/STR
                  if (parts.length > 4) {
                    mount_point_map_list.add(
                        {
                          "mountpoint": parts[0],
                          "identifier": parts[1],
                          "lat": parts[8]??"0",
                          "lon": parts[9]??"0",
                          "distance_km": "0",
                        }
                    );
                }
              }

              bool last_pos_valid = false;
              if (sort_by_nearest) {
                try {
                  double last_lat = 0;
                  double last_lon = 0;
                  String ref_lat_lon = PrefService.of(context).get('ref_lat_lon') ?? "";
                  last_pos_valid = false;
                  if (ref_lat_lon.contains(",")) {
                    List<String> parts = ref_lat_lon.split(",");
                    if (parts.length == 2) {
                      try {
                        last_lat = double.parse(parts[0]);
                        last_lon = double.parse(parts[1]);
                        last_pos_valid = true;
                      } catch (e) {}
                    }
                  }
                  print('last_pos_valid: $last_pos_valid $last_lat $last_lon');

                  if (last_pos_valid) {

                    //calc distance into the map in the list
                    double distance_km = 999999;
                    for (Map<String, String> vmap in mount_point_map_list) {
                      try {
                        double lat = double.parse(vmap["lat"].toString());
                        double lon = double.parse(vmap["lon"].toString());
                        distance_km =
                            calculateDistance(last_lat, last_lon, lat, lon);
                      } catch (e) {
                        print('parse lat/lon exception: $e');
                      }
                      vmap["distance_km"] = distance_km.truncateToDouble().toString();
                    }

                    //sort the list according to distance: https://stackoverflow.com/questions/22177838/sort-a-list-of-maps-in-dart-second-level-sort-in-dart
                    mount_point_map_list.sort((m1, m2) {
                      return double.parse(m1["distance_km"].toString()).compareTo(double.parse(m2["distance_km"].toString()));
                    });

                  } else {
                    toast("Sort by distance failed: Invalid Ref lat,lon position");
                  }

                } catch (e) {
                  print('sort_by_nearest exception: $e');
                  toast("Sort by distance failed: $e");
                }
              }
              //make dialog to choose from mount_point_map_list

              String? chosen_mountpoint = await showDialog<String>(
                  context: context,
                  barrierDismissible: true,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      title: const Text('Select stream:'),
                      children: mount_point_map_list.map(
                              (valmap) {
                                String disp_text = "${valmap["mountpoint"]}: ${valmap["identifier"]} @ ${valmap["lat"]}, ${valmap["lon"]}";
                                print("disp_text sort_by_nearest $sort_by_nearest last_pos_valid $last_pos_valid");
                                if (sort_by_nearest && last_pos_valid) {
                                  disp_text += ": ${valmap["distance_km"]} km";
                                }
                            return SimpleDialogOption(
                                onPressed: () {
                                  Navigator.pop(context, "${valmap["mountpoint"]}");
                                },
                                child: Text(disp_text)
                            );
                          }
                      ).toList(),
                    );
                  }
              );

              print("chosen_mountpoint: $chosen_mountpoint");
              PrefService.of(context).set('ntrip_mountpoint', chosen_mountpoint);

              //force re-load of selected ntrip_mountpoint
              Navigator.of(context).pushReplacement(
                  new MaterialPageRoute(
                      builder: (BuildContext context){
                        return new settings_widget(m_bdaddr_to_name_map);
                      }
                  )
              );

            }
          }

        },
        onError: (dynamic error) {
          print('Received error: ${error.message}');
        }
    );
  }

  settings_widget_state(Map<dynamic, dynamic> bdaddr_to_name_map) {
    m_bdaddr_to_name_map = bdaddr_to_name_map;
  }

  String get_selected_bdaddr()
  {
    return PrefService.of(context).get("target_bdaddr");
  }

  String get_selected_bdname()
  {
    String bdaddr = get_selected_bdaddr();
    //print("get_selected_bdname: bdaddr: $bdaddr");
    if (bdaddr == null || !(m_bdaddr_to_name_map.containsKey(bdaddr)) )
      return "";
    return m_bdaddr_to_name_map[bdaddr];
  }

  String get_selected_bd_summary()
  {
    //print("get_selected_bd_summary 0");
    String ret = '';
    String bdaddr = get_selected_bdaddr();
    //print("get_selected_bd_summary selected bdaddr: $bdaddr");
    String bdname = get_selected_bdname();
    if ( bdaddr == null || bdname == null) {
      ret += "No device selected";
    } else {
      ret +=  bdname;
      ret += " ($bdaddr)";
    }
    //print("get_selected_bd_summary ret $ret");
    return ret;
  }



  @override
  Widget build(BuildContext context) {
//create matching radiopreflist
    List<DropdownMenuItem> devlist = List.empty(growable: true);
    for (String bdaddr in m_bdaddr_to_name_map.keys) {
      devlist.add(
          DropdownMenuItem(
              value: bdaddr, child: Text(m_bdaddr_to_name_map[bdaddr].toString())
          )
      );
    }

    return MaterialApp(
      title: 'EcoDroidGPS Settings',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Settings'),
        ),
        body: PrefPage(children: [
          PrefTitle(title: Text('Target device:')),
          PrefText(
            pref: "$_selected_dev",
            style: Theme.of(context).textTheme.caption,
          ),
          PrefDropdown(items: devlist, pref: 'target_bdaddr'),
          PrefTitle(title: Text('Bluetooth Connection settings')),
          PrefCheckbox(title: Text("Secure RFCOMM connection"), pref: 'secure'),
      PrefCheckbox(title: Text("Auto-reconnect (when disconnected"), pref: 'reconnect'),
        PrefCheckbox(title: Text("Autostart (connect on phone boot"),pref: 'autostart'),
    PrefCheckbox(title: Text("Check for Settings > 'Location' ON and 'High Accuracy'"), pref: 'check_settings_location'),
    PrefCheckbox(title: Text(
              "Enable Logging (location/nmea/debug-trace)"), pref:'log_bt_rx',
              onChange: (bool? _val) async {
                bool enable = _val!;
                if (enable) {
                  bool write_enabled = false;
                  try {
                    write_enabled =
                    await method_channel.invokeMethod('is_write_enabled');
                  } on PlatformException catch (e) {
                    toast("WARNING: check _is_connecting failed: $e");
                  }
                  if (write_enabled == false) {
                    toast(
                        "Write external storage permission required for data loggging...");
                  }
                  try {
                    await method_channel.invokeMethod('set_log_uri');
                  } on PlatformException catch (e) {
                    toast("WARNING: set_log_uri failed: $e");
                  }
                  PrefService.of(context).set('log_bt_rx', false); //set by java-side mainactivity on success only
                } else {
                  PrefService.of(context).set('log_uri', "");
                }
              }
          ),
          PrefTitle(title: Text('RTK/NTRIP Server settings')),
          Text(
            "Set these if your Bluetooth GNSS device supports RTK,\n(Like EcoDroidGPS + Ardusimple U-Blox F9 etc)",
            style: Theme.of(context).textTheme.caption,
          ),
          PrefCheckbox(title: Text("Disable NTRIP"), pref: 'disable_ntrip'),
          TextFieldPreference('Host', 'ntrip_host',
              defaultVal: 'www.igs-ip.net', validator: (str) {
                if (str == "") {
                  return "Invalid Host domain/IP";
                }
                return null;
              }
          ),
          TextFieldPreference('Port', 'ntrip_port',
              defaultVal: '2101', validator: (str) {
                int port = intParse(str);
                if (port == null || !(port >= 0 && port <= 65535)) {
                  return "Invalid port";
                }
                return null;
              }
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: ElevatedButton(
              child: Text(
                'List streams from above server',
              ),
              onPressed: () async {

                if (PrefService.of(context).get('ntrip_host') == null || PrefService.of(context).getString('ntrip_host') == "" || PrefService.of(context).get('ntrip_port') == null) {
                  toast("Please specify the ntrip_host and ntrip_port first...");
                  return;
                }

                int ret_code = -1;


                try {
                  m_pr = new ProgressDialog(context,type: ProgressDialogType.Normal, isDismissible: false, showLogs: true);
                  m_pr.style(
                    message: 'Connecting to NTRIP server...',
                    borderRadius: 10.0,
                    backgroundColor: Colors.white,
                    progressWidget: CircularProgressIndicator(),
                    elevation: 10.0,
                    insetAnimCurve: Curves.easeInOut,
                  );
                  m_pr.show();

                  //make sure dialog shows first otherwise if no internet the .dismoiss wont work if immediate fail and progress dialog would block forever
                  new Future.delayed(const Duration(seconds: 1), () async
                  {
                    ret_code = await method_channel.invokeMethod(
                        "get_mountpoint_list",
                        {
                          'ntrip_host': PrefService.of(context).get('ntrip_host'),
                          'ntrip_port': PrefService.of(context).get('ntrip_port'),
                          'ntrip_user': PrefService.of(context).get('ntrip_user'),
                          'ntrip_pass': PrefService.of(context).get('ntrip_pass'),
                        }
                    );
                    print("get_mountpoint_list req waiting callback ret: $ret_code");
                  }
                  );

                } catch (e) {
                  print("WARNING: Choose mount-point failed exception: $e");
                  try {
                    toast("List mount-points failed: $e");
                    m_pr.hide();
                  } catch (e) {}
                }
              },
            ),
          ),
          CheckboxPreference("Sort by nearest to to Ref lat,lon", 'list_nearest_streams_first'),
          TextFieldPreference('Ref lat,lon', 'ref_lat_lon'),
          TextFieldPreference('Stream (mount-point)', 'ntrip_mountpoint',
              defaultVal: '', validator: (str) {
                if (str == null) {
                  return "Invalid mount-point";
                }
                return null;
              }
          ),
          TextFieldPreference('User', 'ntrip_user',
              defaultVal: '', validator: (str) {
                return null;
              }
          ),
          TextFieldPreference('Password', 'ntrip_pass',
              defaultVal: '', validator: (str) {
                return null;
              }
          ),

        ]),
      ),
    );
  }
}

int intParse(String input) {
  String source = input.trim();
  return int.tryParse(source);
}

//https://stackoverflow.com/questions/54138750/total-distance-calculation-from-latlng-list
double calculateDistance(lat1, lon1, lat2, lon2){
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 - c((lat2 - lat1) * p)/2 +
      c(lat1 * p) * c(lat2 * p) *
          (1 - c((lon2 - lon1) * p))/2;
  return 12742 * asin(sqrt(a));
}