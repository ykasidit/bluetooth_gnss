import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' show cos, sqrt, asin;

import 'package:bluetooth_gnss/utils_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:pref/pref.dart';

import 'channels.dart';
import 'connect.dart';
import 'main.dart';

const _settingsEventChannel =
    EventChannel("com.clearevo.bluetooth_gnss/settings_events");

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  final String title = "Settings";

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool loading = false;
  String log_bt_rx_log_uri = "";
  Stream<dynamic>? event_stream;
  StreamSubscription<dynamic>? event_stream_sub;
  @override
  void dispose() {
    developer.log("settings event stream cancel");
    event_stream_sub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    log_bt_rx_log_uri = prefService.get('log_bt_rx_log_uri') ?? "";
    event_stream = _settingsEventChannel.receiveBroadcastStream();
    if (true) {
      developer.log("settings event stream sub");
      event_stream_sub = event_stream!.listen((dynamic event) async {
        Map<dynamic, dynamic> eventMap = event as Map<dynamic, dynamic>? ?? {};

        if (eventMap.containsKey('callback_src')) {
          try {
            developer.log("settings got callback event: $eventMap");
          } catch (e) {
            developer.log('parse event_map exception: $e');
          }

          if (eventMap["callback_src"] == "get_mountpoint_list") {
            developer.log("dismiss progress dialog now0");

            setState(() {
              loading = false;
            });

            //get list from native engine
            List<dynamic> oriMpl =
                eventMap["callback_payload"] as List<dynamic>? ?? [];
            developer.log("got mpl: $oriMpl");
            if (oriMpl.isEmpty) {
              await toast(
                  "Failed to list mount-points list from server specified...");
              return;
            }

            //conv to List<String> and sort
            List<String> mountPointStrList =
                List<String>.generate(oriMpl.length, (i) => "${oriMpl[i]}");

            //filter startswith STR;
            mountPointStrList =
                mountPointStrList.where((s) => s.startsWith('STR;')).toList();

            //remove starting STR; to sort by mountpoint name
            mountPointStrList = List<String>.generate(mountPointStrList.length,
                (i) => mountPointStrList[i].substring(4));

            //filter for that contains ; so wont have errors for split further below
            mountPointStrList =
                mountPointStrList.where((s) => s.contains(';')).toList();

            mountPointStrList.sort();
            developer.log("mount_point_str_list: $mountPointStrList");

            int nmpl = mountPointStrList.length;
            await toast("Found $nmpl mountpoints...");
            bool sortByNearest =
                prefService.get('list_nearest_streams_first') ?? false;
            developer.log('sort_by_nearest: $sortByNearest');

            List<Map<String, String>> mountPointMapList =
                List.empty(growable: true);

            for (String val in mountPointStrList) {
              List<String> parts = val.split(";");
              //ref https://software.rtcm-ntrip.org/wiki/STR
              if (parts.length > 4) {
                mountPointMapList.add({
                  "mountpoint": parts[0],
                  "identifier": parts[1],
                  "lat": parts[8],
                  "lon": parts[9],
                  "distance_km": "0",
                });
              }
            }

            bool lastPosValid = false;
            if (sortByNearest) {
              try {
                double lastLat = 0;
                double lastLon = 0;
                String refLatLon = prefService.get('ref_lat_lon') ?? "";
                lastPosValid = false;
                if (refLatLon.contains(",")) {
                  List<String> parts = refLatLon.split(",");
                  if (parts.length == 2) {
                    try {
                      lastLat = double.parse(parts[0]);
                      lastLon = double.parse(parts[1]);
                      lastPosValid = true;
                    } catch (e) {
                      developer
                          .log("WARNING: parse last lat/lon exception {e}");
                    }
                  }
                }
                developer
                    .log('last_pos_valid: $lastPosValid $lastLat $lastLon');

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
                      developer.log('parse lat/lon exception: $e');
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
                  await toast(
                      "Sort by distance failed: Invalid Ref lat,lon position");
                }
              } catch (e) {
                developer.log('sort_by_nearest exception: $e');
                await toast("Sort by distance failed: $e");
              }
            }

            //make dialog to choose from mount_point_map_list
            String? chosenMountpoint;
            if (mounted) {
              chosenMountpoint = await showDialog<String>(
                  context: context,
                  barrierDismissible: true,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      title: const Text('Select stream:'),
                      children: mountPointMapList.map((valmap) {
                        String dispText =
                            "${valmap["mountpoint"]}: ${valmap["identifier"]} @ ${valmap["lat"]}, ${valmap["lon"]}";
                        developer.log(
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
            }
            developer.log("chosen_mountpoint: $chosenMountpoint");
            if (chosenMountpoint != null) {
              prefService.set('ntrip_mountpoint', chosenMountpoint);

              //force re-load of selected ntrip_mountpoint

              if (mounted) {
                await Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (BuildContext context) {
                  return SettingsScreen();
                }));
              }
            }
          } else if (eventMap["callback_src"] == "set_log_uri") {
            String log_uri = eventMap["callback_payload"] as String? ?? "";
            if (log_uri.isNotEmpty) {
              developer.log("set log_uri: $log_uri");
              prefService.set('log_bt_rx', true);
              prefService.set('log_bt_rx_log_uri', log_uri);
            } else {
              developer.log("clear log_uri");
              prefService.set('log_bt_rx', false);
              prefService.set('log_bt_rx_log_uri', log_uri);
            }
            setState(() {
              log_bt_rx_log_uri = Uri.decodeFull(log_uri);
            });
          }
        }
      }, onError: (dynamic error) {
        developer.log('Received error: ${error.message}');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
//create matching radiopreflist
    /*List<DropdownMenuItem<String>> devlist = List.empty(growable: true);
    for (dynamic bdaddr in getBdMap()) {
      devlist.add(DropdownMenuItem(
          value: bdaddr.toString(), child: Text(bdMap[bdaddr.toString()].toString())));
    }*/

    return PrefService(
        service: prefService,
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
                  reactivePrefDropDown(
                      'target_bdaddr',
                      "Select a Bluetooth device\n(Pair in Phone Settings > Device connection > Pair new device)",
                      bdMapNotifier),
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
                  ValueListenableBuilder<DateTime>(
                      valueListenable: setLiveArgsTs,
                      builder: (BuildContext context, DateTime setTs,
                          Widget? child) {
                        return PrefText(
                          key: ValueKey(
                              'mock_timestamp_offset_secs_${setTs.millisecondsSinceEpoch}'),
                          pref: 'mock_timestamp_offset_secs',
                          decoration: InputDecoration(
                            labelText: 'Live location timestamp offset (secs)',
                            suffixIcon: IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () async {
                                  await prefService.set(
                                      'mock_timestamp_offset_secs', '0.0');
                                  await setLiveArgs(); // if needed to reflect change
                                }),
                          ),
                          hintText: "Example: -1.5",
                          validator: validateDouble,
                          keyboardType: TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          onChange: (s) async => await setLiveArgs(),
                        );
                      }),
                  ValueListenableBuilder<DateTime>(
                      valueListenable: setLiveArgsTs,
                      builder: (BuildContext context, DateTime setTs,
                          Widget? child) {
                        return PrefText(
                          key: ValueKey(
                              'mock_lat_offset_meters_${setTs.millisecondsSinceEpoch}'),
                          pref: 'mock_lat_offset_meters',
                          decoration: InputDecoration(
                            labelText: 'Live latitude offset (meters)',
                            suffixIcon: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () async {
                                  await prefService.set(
                                      'mock_lat_offset_meters', '0.0');
                                  await setLiveArgs(); // if needed to reflect change
                                }),
                          ),
                          hintText: "Example: -2.5",
                          validator: validateDouble,
                          keyboardType: TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          onChange: (s) async => await setLiveArgs(),
                        );
                      }),
                  ValueListenableBuilder<DateTime>(
                      valueListenable: setLiveArgsTs,
                      builder: (BuildContext context, DateTime setTs,
                          Widget? child) {
                        return PrefText(
                          key: ValueKey('mock_lon_offset_meters_${setTs.millisecondsSinceEpoch}'),
                          pref: 'mock_lon_offset_meters',
                          decoration: InputDecoration(
                            labelText: 'Live longitude offset (meters)',
                            suffixIcon: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () async {
                                  await prefService.set(
                                      'mock_lon_offset_meters', '0.0');
                                  await setLiveArgs(); // if needed to reflect change
                                }),
                          ),
                          hintText: "Example: 3.5",
                          validator: validateDouble,
                          keyboardType: TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          onChange: (s) async => await setLiveArgs(),
                        );
                      }),
                  ValueListenableBuilder<DateTime>(
                      valueListenable: setLiveArgsTs,
                      builder: (BuildContext context, DateTime setTs,
                          Widget? child) {
                        return PrefText(
                          key: ValueKey('mock_alt_offset_meters_${setTs.millisecondsSinceEpoch}'),
                          pref: 'mock_alt_offset_meters',
                          decoration: InputDecoration(
                            labelText: 'Live altitude offset (meters)',
                            suffixIcon: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () async {
                                  await prefService.set(
                                      'mock_alt_offset_meters', '0.0');
                                  await setLiveArgs(); // if needed to reflect change
                                }),
                          ),
                          hintText: "Example: -10.5",
                          validator: validateDouble,
                          keyboardType: TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          onChange: (s) async => await setLiveArgs(),
                        );
                      }),
                  //mock_location_timestamp_offset_millis
                  PrefCheckbox(
                      title: Text("Enable Logging $log_bt_rx_log_uri"),
                      pref: 'log_bt_rx',
                      onChange: (bool? val) async {
                        prefService.set('log_bt_rx',
                            false); //set to false first and await event from java callback to set to true if all perm/folder set pass
                        prefService.set("log_bt_rx_log_uri", "");
                        setState(() {
                          log_bt_rx_log_uri = "";
                        });
                        bool enable = val!;
                        if (enable) {
                          bool writeEnabled = false;
                          try {
                            writeEnabled = (await methodChannel.invokeMethod(
                                    'is_write_enabled')) as bool? ??
                                false;
                          } catch (e) {
                            await toast(
                                "WARNING: check _is_connecting failed: $e");
                          }
                          if (writeEnabled == false) {
                            await toast(
                                "Write external storage permission required for data loggging...");
                          }
                          try {
                            await methodChannel.invokeMethod('set_log_uri');
                          } catch (e) {
                            await toast("WARNING: set_log_uri failed: $e");
                          }
                        }
                      }),
                  const PrefTitle(title: Text('RTK/NTRIP Server settings')),
                  Text(
                    "Set these if your Bluetooth GNSS device supports RTK,\n(Like Ardusimple U-Blox F9, etc)",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const PrefCheckbox(
                      title: Text("Disable NTRIP"), pref: 'disable_ntrip'),
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
                        String host = prefService.get('ntrip_host') ?? "";
                        String port = prefService.get('ntrip_port') ?? "";
                        String user = prefService.get('ntrip_user') ?? "";
                        String pass = prefService.get('ntrip_pass') ?? "";
                        if (host.isEmpty || port.isEmpty) {
                          await toast(
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
                              retCode = (await methodChannel
                                      .invokeMethod("get_mountpoint_list", {
                                    'ntrip_host': host,
                                    'ntrip_port': port,
                                    'ntrip_user': user,
                                    'ntrip_pass': pass,
                                  })) as int? ??
                                  -1;
                              developer.log(
                                  "get_mountpoint_list req waiting callback ret: $retCode");
                            } catch (e) {
                              setState(() {
                                loading = false;
                              });
                              await toast(
                                  "List mount-points failed invoke: $e");
                            }
                          });
                        } catch (e) {
                          developer.log(
                              "WARNING: Choose mount-point failed exception: $e");
                          try {
                            setState(() {
                              loading = false;
                            });
                            await toast("List mount-points failed start: $e");
                          } catch (e) {
                            developer.log("list mount point failed {e}");
                          }
                        }
                      },
                    ),
                  ),
                  const PrefCheckbox(
                      title: Text("Sort by nearest to Ref position"),
                      pref: 'list_nearest_streams_first'),

                  ValueListenableBuilder<DateTime>(
                      valueListenable: setLiveArgsTs,
                      builder: (BuildContext context, DateTime setTs,
                          Widget? child) {
                        developer.log("rebld pref live setTs:  $setTs");
                        return PrefText(
                            key: ValueKey(
                                'ref_lat_lon_${setTs.millisecondsSinceEpoch}'),
                            label: "Ref position lat, lon for sorting",
                            pref: 'ref_lat_lon',
                            hintText: "Example: 6.691289,101.674621",
                            validator: (String? t) {
                              if (t != null && t.contains(",")) {
                                List<String> parts = t.split(",");
                                if (parts.length == 2) {
                                  if (double.tryParse(parts[0]) != null &&
                                      double.tryParse(parts[1]) != null) {
                                    return null;
                                  }
                                }
                              }
                              return "Please enter a valid location: latitude, longitude";
                            });
                      }),
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
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 -
      c((lat2 - lat1) * p) / 2 +
      c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a));
}
