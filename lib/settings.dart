import 'package:bluetooth_gnss/main.dart';
import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:flutter/services.dart';
import 'dart:math' show cos, sqrt, asin;
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

class settings_widget extends StatefulWidget {
  const settings_widget(this.pref_service, this._bd_map, {super.key});
  final BasePrefService pref_service;
  final Map<dynamic, dynamic> _bd_map;
  final String title = "Settings";

  @override
  settings_widget_state createState() => settings_widget_state(_bd_map);
}

class settings_widget_state extends State<settings_widget> {
  Map<dynamic, dynamic> m_bdaddr_to_name_map = <dynamic, dynamic>{};
  String _selected_dev = "Loading...";
  bool loading = false;

  static const method_channel =
      MethodChannel("com.clearevo.bluetooth_gnss/engine");
  static const event_channel =
      EventChannel("com.clearevo.bluetooth_gnss/settings_events");
  void toast(String msg) async {
    try {
      await method_channel.invokeMethod("toast", {"msg": msg});
    } catch (e) {
      print("WARNING: toast failed exception: $e");
    }
  }

  @override
  void initState() {
    _selected_dev = get_selected_bd_summary(widget.pref_service) ?? "";
    event_channel.receiveBroadcastStream().listen((dynamic event) async {
      Map<dynamic, dynamic> eventMap = event;

      if (eventMap.containsKey('callback_src')) {
        try {
          print("settings got callback event: $eventMap");
        } catch (e) {
          print('parse event_map exception: $e');
        }

        if (eventMap["callback_src"] == "get_mountpoint_list") {
          print("dismiss progress dialog now0");

          setState(() {
            loading = false;
          });

          //get list from native engine
          List<dynamic> oriMpl = eventMap["callback_payload"];
          print("got mpl: $oriMpl");
          if (oriMpl.isEmpty) {
            toast("Failed to list mount-points list from server specified...");
            return;
          }

          //conv to List<String> and sort
          List<String> mountPointStrList =
              List<String>.generate(oriMpl.length, (i) => "${oriMpl[i]}");

          //filter startswith STR;
          mountPointStrList =
              mountPointStrList.where((s) => s.startsWith('STR;')).toList();

          //remove starting STR; to sort by mountpoint name
          mountPointStrList = List<String>.generate(
              mountPointStrList.length,
              (i) => mountPointStrList[i].substring(4));

          //filter for that contains ; so wont have errors for split further below
          mountPointStrList =
              mountPointStrList.where((s) => s.contains(';')).toList();

          mountPointStrList.sort();
          print("mount_point_str_list: $mountPointStrList");

          int nmpl = mountPointStrList.length;
          toast("Found $nmpl mountpoints...");
          bool sortByNearest =
              widget.pref_service.get('list_nearest_streams_first') ??
                  false;
          print('sort_by_nearest: $sortByNearest');

          List<Map<String, String>> mountPointMapList =
              List.empty(growable: true);

          for (String val in mountPointStrList) {
            List<String> parts = val.split(";");
            //ref https://software.rtcm-ntrip.org/wiki/STR
            if (parts.length > 4) {
              mountPointMapList.add({
                "mountpoint": parts[0],
                "identifier": parts[1],
                "lat": parts[8] ?? "0",
                "lon": parts[9] ?? "0",
                "distance_km": "0",
              });
            }
          }

          bool lastPosValid = false;
          if (sortByNearest) {
            try {
              double lastLat = 0;
              double lastLon = 0;
              String refLatLon =
                  widget.pref_service.get('ref_lat_lon') ?? "";
              lastPosValid = false;
              if (refLatLon.contains(",")) {
                List<String> parts = refLatLon.split(",");
                if (parts.length == 2) {
                  try {
                    lastLat = double.parse(parts[0]);
                    lastLon = double.parse(parts[1]);
                    lastPosValid = true;
                  } catch (e) {}
                }
              }
              print('last_pos_valid: $lastPosValid $lastLat $lastLon');

              if (lastPosValid) {
                //calc distance into the map in the list
                double distanceKm = 999999;
                for (Map<String, String> vmap in mountPointMapList) {
                  try {
                    double lat = double.parse(vmap["lat"].toString());
                    double lon = double.parse(vmap["lon"].toString());
                    distanceKm =
                        calculateDistance(lastLat, lastLon, lat, lon);
                  } catch (e) {
                    print('parse lat/lon exception: $e');
                  }
                  vmap["distance_km"] =
                      distanceKm.truncateToDouble().toString();
                }

                //sort the list according to distance: https://stackoverflow.com/questions/22177838/sort-a-list-of-maps-in-dart-second-level-sort-in-dart
                mountPointMapList.sort((m1, m2) {
                  return double.parse(m1["distance_km"].toString())
                      .compareTo(double.parse(m2["distance_km"].toString()));
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

          String? chosenMountpoint = await showDialog<String>(
              context: context,
              barrierDismissible: true,
              builder: (BuildContext context) {
                return SimpleDialog(
                  title: const Text('Select stream:'),
                  children: mountPointMapList.map((valmap) {
                    String dispText =
                        "${valmap["mountpoint"]}: ${valmap["identifier"]} @ ${valmap["lat"]}, ${valmap["lon"]}";
                    print(
                        "disp_text sort_by_nearest $sortByNearest last_pos_valid $lastPosValid");
                    if (sortByNearest && lastPosValid) {
                      dispText += ": ${valmap["distance_km"]} km";
                    }
                    return SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context, "${valmap["mountpoint"]}");
                        },
                        child: Text(dispText));
                  }).toList(),
                );
              });

          print("chosen_mountpoint: $chosenMountpoint");
          widget.pref_service.set('ntrip_mountpoint', chosenMountpoint);

          //force re-load of selected ntrip_mountpoint
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (BuildContext context) {
            return settings_widget(widget.pref_service, m_bdaddr_to_name_map);
          }));
        }
      }
    }, onError: (dynamic error) {
      print('Received error: ${error.message}');
    });
  }

  settings_widget_state(Map<dynamic, dynamic> bdaddr_to_name_map) {
    m_bdaddr_to_name_map = bdaddr_to_name_map;
  }

  String get_selected_bdaddr(BasePrefService prefService) {
    return prefService.get("target_bdaddr") ?? "";
  }

  String get_selected_bdname(BasePrefService prefService) {
    String? bdaddr = get_selected_bdaddr(prefService);
    //print("get_selected_bdname: bdaddr: $bdaddr");
    if (!(m_bdaddr_to_name_map.containsKey(bdaddr))) {
      return "";
    }
    return m_bdaddr_to_name_map[bdaddr];
  }

  String get_selected_bd_summary(BasePrefService prefService) {
    //print("get_selected_bd_summary 0");
    String ret = '';
    String bdaddr = get_selected_bdaddr(prefService);
    //print("get_selected_bd_summary selected bdaddr: $bdaddr");
    String bdname = get_selected_bdname(prefService);
    if (bdaddr.isEmpty) {
      ret += "No device selected";
    } else {
      ret += bdname;
      ret += " ($bdaddr)";
    }
    //print("get_selected_bd_summary ret $ret");
    return ret;
  }

  @override
  Widget build(BuildContext context) {
//create matching radiopreflist
    List<DropdownMenuItem> devlist = List.empty(growable: true);
    devlist.add(
        const DropdownMenuItem(
            value: BLE_QSTARTZ_MODE_KEY, child: Text("Qstarz BLE GPS")
        )
    );
    for (String bdaddr in m_bdaddr_to_name_map.keys) {
      devlist.add(DropdownMenuItem(
          value: bdaddr, child: Text(m_bdaddr_to_name_map[bdaddr].toString())));
    }

    return PrefService(
        service: widget.pref_service,
        child: MaterialApp(
      title: 'Settings',
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ModalProgressHUD(
            inAsyncCall: loading,
            child: PrefPage(children: [
              const PrefTitle(title: Text('Target device:')),
              PrefDropdown(title: const Text("Select a Bluetooth device\n(Pair in Phone Settings > Device connection > Pair new device)"), items: devlist, pref: 'target_bdaddr'),
              const PrefTitle(title: Text('Bluetooth Connection settings')),
              const PrefCheckbox(
                  title: Text("Secure RFCOMM connection"), pref: 'secure'),
              const PrefCheckbox(
                  title: Text("Auto-reconnect - when disconnected"),
                  pref: 'reconnect'),
              const PrefCheckbox(
                  title: Text("Autostart - connect on phone boot"),
                  pref: 'autostart'),
              const PrefCheckbox(
                  title: Text(
                      "Check for Settings > 'Location' ON and 'High Accuracy'"),
                  pref: 'check_settings_location'),
              PrefCheckbox(
                  title: const Text("Enable Logging (location/nmea/debug-trace)"),
                  pref: 'log_bt_rx',
                  onChange: (bool? val) async {
                    bool enable = val!;
                    if (enable) {
                      bool writeEnabled = false;
                      try {
                        writeEnabled = await method_channel
                            .invokeMethod('is_write_enabled');
                      } on PlatformException catch (e) {
                        toast("WARNING: check _is_connecting failed: $e");
                      }
                      if (writeEnabled == false) {
                        toast(
                            "Write external storage permission required for data loggging...");
                      }
                      try {
                        await method_channel.invokeMethod('set_log_uri');
                      } on PlatformException catch (e) {
                        toast("WARNING: set_log_uri failed: $e");
                      }
                      widget.pref_service.set('log_bt_rx',
                          false); //set by java-side mainactivity on success only
                    } else {
                      widget.pref_service.set('log_uri', "");
                    }
                  }),
              const PrefTitle(title: Text('RTK/NTRIP Server settings')),
              Text(
                "Set these if your Bluetooth GNSS device supports RTK,\n(Like Ardusimple U-Blox F9, etc)",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const PrefCheckbox(title: Text("Disable NTRIP"), pref: 'disable_ntrip'),
              PrefText(
                  label: 'Host',
                  pref: 'ntrip_host',
                  validator: (str) {
                    str = str.toString();
                    if (str == "") {
                      return "Invalid Host domain/IP";
                    }
                    return null;
                  }),
              PrefText(
                  label: 'Port',
                  pref: 'ntrip_port',
                  validator: (str) {
                    str = str.toString();
                    int? port = intParse(str);
                    if (port == null || !(port >= 0 && port <= 65535)) {
                      return "Invalid port";
                    }
                    return null;
                  }),
              const PrefText(label: "Ref lat,lon for sorting", pref: 'ref_lat_lon'),
              PrefText(
                  label: "Stream (mount-point)",
                  pref: 'ntrip_mountpoint',
                  validator: (str) {
                    if (str == null) {
                      return "Invalid mount-point";
                    }
                    return null;
                  }),
              PrefText(
                  label: 'User',
                  pref: 'ntrip_user',
                  validator: (str) {
                    return null;
                  }),
              PrefText(
                  label: 'Password',
                  pref: 'ntrip_pass',
                  obscureText: true,
                  validator: (str) {
                    return null;
                  }),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: ElevatedButton(
                  child: const Text(
                    'List streams from above server',
                  ),
                  onPressed: () async {
                    String host =
                        widget.pref_service.get('ntrip_host') ?? "";
                    String port =
                        widget.pref_service.get('ntrip_port') ?? "";
                    String user =
                        widget.pref_service.get('ntrip_user') ?? "";
                    String pass =
                        widget.pref_service.get('ntrip_pass') ?? "";
                    if (host.isEmpty || port.isEmpty) {
                      toast(
                          "Please specify the ntrip_host and ntrip_port first...");
                      return;
                    }

                    int retCode = -1;

                    try {
                      setState(() {
                        loading = true;
                      });
                      //make sure dialog shows first otherwise if no internet the .dismoiss wont work if immediate fail and progress dialog would block forever
                      Future.delayed(const Duration(seconds: 0), () async {
                        try {
                          retCode = await method_channel
                              .invokeMethod("get_mountpoint_list", {
                            'ntrip_host': host,
                            'ntrip_port': port,
                            'ntrip_user': user,
                            'ntrip_pass': pass,
                          });
                          print(
                              "get_mountpoint_list req waiting callback ret: $retCode");
                        } catch (e) {
                          setState(() {
                            loading = false;
                          });
                          toast("List mount-points failed invoke: $e");
                        }
                      });
                    } catch (e) {
                      print("WARNING: Choose mount-point failed exception: $e");
                      try {
                        setState(() {
                          loading = false;
                        });
                        toast("List mount-points failed start: $e");
                      } catch (e) {}
                    }
                  },
                ),
              ),
              const PrefCheckbox(
                  title: Text("Sort by nearest to to Ref lat,lon"),
                  pref: 'list_nearest_streams_first'),
            ]),
          )),
    ));
  }
}

int? intParse(String input) {
  String source = input.trim();
  return int.tryParse(source);
}

//https://stackoverflow.com/questions/54138750/total-distance-calculation-from-latlng-list
double calculateDistance(lat1, lon1, lat2, lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 -
      c((lat2 - lat1) * p) / 2 +
      c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a));
}
