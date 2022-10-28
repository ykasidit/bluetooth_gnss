import 'dart:io';
import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';
import 'package:flutter/services.dart';
import 'package:progress_dialog/progress_dialog.dart';
import 'dart:math' show cos, sqrt, asin;

class settings_widget extends StatefulWidget {

  settings_widget(Map<dynamic, dynamic> bdaddr_to_name_map) {
    _bd_map = bdaddr_to_name_map;
  }

  Map<dynamic, dynamic> _bd_map;

  final String title = "Settings";

  @override
  settings_widget_state createState() => settings_widget_state(_bd_map);
}


class settings_widget_state extends State<settings_widget> {

  List<RadioPreference> _bd_dev_pref_list;
  Map<dynamic, dynamic> m_bdaddr_to_name_map = new Map<dynamic, dynamic>();
  String _selected_dev = "Loading...";
  ProgressDialog m_pr;

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
              bool sort_by_nearest = PrefService.getBool('list_nearest_streams_first') ?? false;
              print('sort_by_nearest: $sort_by_nearest');

              List<Map<String, String>> mount_point_map_list = new List<Map<String, String>>();

              for (String val in mount_point_str_list) {
                  List<String> parts = val.split(";");
                  //ref https://software.rtcm-ntrip.org/wiki/STR
                  if (parts.length > 4) {
                    mount_point_map_list.add(
                        {
                          "mountpoint": parts[0],
                          "identifier": parts[1],
                          "lat": parts[8]??0,
                          "lon": parts[9]??0,
                          "distance_km": "0",
                        }
                    );
                }
              }

              bool last_pos_valid = false;
              if (sort_by_nearest) {
                try {
                  last_pos_valid = false;
                  double last_lat = 0;
                  double last_lon = 0;
                  print('last_pos_valid: $last_pos_valid $last_lat $last_lon');

                  if (last_pos_valid) {

                    //calc distance into the map in the list
                    double distance_km = 999999;
                    for (Map<String, String> vmap in mount_point_map_list) {
                      try {
                        double lat = double.parse(vmap["lat"]);
                        double lon = double.parse(vmap["lon"]);
                        distance_km =
                            calculateDistance(last_lat, last_lon, lat, lon);
                      } catch (e) {
                        print('parse lat/lon exception: $e');
                      }
                      vmap["distance_km"] = distance_km.truncateToDouble().toString();
                    }

                    //sort the list according to distance: https://stackoverflow.com/questions/22177838/sort-a-list-of-maps-in-dart-second-level-sort-in-dart
                    mount_point_map_list.sort((m1, m2) {
                      return double.parse(m1["distance_km"]).compareTo(double.parse(m2["distance_km"]));
                    });

                  } else {
                    toast("Sort by distance failed: failed to get last position");
                  }

                } catch (e) {
                  print('sort_by_nearest exception: $e');
                  toast("Sort by distance failed: $e");
                }
              }
              //make dialog to choose from mount_point_map_list

              String chosen_mountpoint = await showDialog<String>(
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
              PrefService.setString('ntrip_mountpoint', chosen_mountpoint);

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

    //create matching radiopreflist
    List<RadioPreference> devlist = List<RadioPreference>();
    for (String bdaddr in bdaddr_to_name_map.keys) {
      devlist.add(
          RadioPreference(
              bdaddr_to_name_map[bdaddr], bdaddr, "target_bdaddr")
      );
    }
    _bd_dev_pref_list = devlist;

  }

  String get_selected_bdaddr()
  {
    return PrefService.get("target_bdaddr");
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

    return MaterialApp(
      title: 'EcoDroidGPS Settings',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Settings'),
        ),
        body: PreferencePage([
          PreferenceTitle('Selected Target Bluetooth device:'),
          PreferenceText(
            "$_selected_dev",
            style: Theme.of(context).textTheme.caption,
          ),
          PreferenceDialogLink(
            "Select...",
            dialog: PreferenceDialog(
              _bd_dev_pref_list,
              title: 'Select Bluetooth Device',
              submitText: 'Save',
              cancelText: 'Cancel',
              onlySaveOnSubmit: true,
            ),
            onPop: () => setState(() {_selected_dev = get_selected_bd_summary();}),
          ),
          PreferenceTitle('Bluetooth Connection settings'),
          CheckboxPreference("EcoDroidGPS-Broadcast device mode", 'ble_gap_scan_mode'),
          PreferenceText(
            "(Experimental) For use with 'EcoDroidGPS-Broadcast' device\nfrom www.ClearEvo.com\n(This device broadcasts GNSS location over BLE GAP\n to an any number of Android phones/tablets concurrently)",
            style: Theme.of(context).textTheme.caption,
          ),
          CheckboxPreference("Secure RFCOMM connection", 'secure'),
          CheckboxPreference("Auto-reconnect (when disconnected)", 'reconnect'),
          CheckboxPreference("Autostart (connect on phone boot)", 'autostart'),
          CheckboxPreference("Check for Settings > 'Location' ON and 'High Accuracy'", 'check_settings_location'),
          CheckboxPreference(
              "Enable logging", 'log_bt_rx',
              onEnable: () async {
                bool write_enabled = false;
                try {
                  write_enabled = await method_channel.invokeMethod('is_write_enabled');
                } on PlatformException catch (e) {
                  toast("WARNING: check _is_connecting failed: $e");
                }
                if (write_enabled == false) {
                  toast("Write external storage permission required for data loggging...");
                  PrefService.setBool('log_bt_rx', false);
                  return false;
                }
                try {
                  await method_channel.invokeMethod('set_log_uri');
                } on PlatformException catch (e) {
                  toast("WARNING: set_log_uri failed: $e");
                  PrefService.setBool('log_bt_rx', false);
                  return false;
                }
                return true;
              },
              onDisable: () async {
                PrefService.setString('log_uri', null);
              }
          ),
          PreferenceTitle('RTK/NTRIP Server settings'),
          PreferenceText(
            "Set these if your Bluetooth GNSS device supports RTK,\n(Like EcoDroidGPS + Ardusimple U-Blox F9 etc)",
            style: Theme.of(context).textTheme.caption,
          ),
          CheckboxPreference("Disable NTRIP", 'disable_ntrip'),
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
            child: RaisedButton(
              child: Text(
                'List streams from above server',
              ),
              onPressed: () async {

                if (PrefService.getString('ntrip_host') == null || PrefService.getString('ntrip_host') == "" || PrefService.getString('ntrip_port') == null) {
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
                          'ntrip_host': PrefService.getString('ntrip_host'),
                          'ntrip_port': PrefService.getString('ntrip_port'),
                          'ntrip_user': PrefService.getString('ntrip_user'),
                          'ntrip_pass': PrefService.getString('ntrip_pass'),
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
          CheckboxPreference("Try list nearest streams first", 'list_nearest_streams_first'),
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