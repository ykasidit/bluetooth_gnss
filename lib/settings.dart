import 'dart:io';
import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';
import 'package:flutter/services.dart';
import 'package:progress_dialog/progress_dialog.dart';

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
  Map<dynamic, dynamic> m_bdaddr_to_name_map;
  String _selected_dev = "Loading...";
  ProgressDialog m_pr;

  static const method_channel = MethodChannel("com.clearevo.bluetooth_gnss/engine");
  static const event_channel = EventChannel("com.clearevo.bluetooth_gnss/engine_events");
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
                m_pr.dismiss();
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

              List<Map<String, String>> mount_point_map_list = new List<Map<String, String>>();
              for (String val in mount_point_str_list) {
                  List<String> parts = val.split(";");
                  //ref https://software.rtcm-ntrip.org/wiki/STR
                  if (parts.length > 4) {
                    mount_point_map_list.add(
                        {
                          "mountpoint": parts[0],
                          "identifier": parts[1],
                        }
                    );
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
                                String disp_text = "${valmap["mountpoint"]}: ${valmap["identifier"]}";
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
    print("get_selected_bdname: bdaddr: $bdaddr");
    if (bdaddr == null || !(m_bdaddr_to_name_map.containsKey(bdaddr)) )
      return null;
    return m_bdaddr_to_name_map[bdaddr];
  }

  String get_selected_bd_summary()
  {
    print("get_selected_bd_summary 0");
    String ret = '';
    String bdaddr = get_selected_bdaddr();
    print("get_selected_bd_summary selected bdaddr: $bdaddr");
    String bdname = get_selected_bdname();
    if ( bdaddr == null || bdname == null) {
      ret += "No device selected";
    } else {
      ret +=  bdname;
      ret += " ($bdaddr)";
    }
    print("get_selected_bd_summary ret $ret");
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
          CheckboxPreference("Secure RFCOMM connection", 'secure'),
          CheckboxPreference("Auto-reconnect mode (takes effect in next connection)", 'reconnect'),
          CheckboxPreference("Check for Settings > 'Location' ON and 'High Accuracy'", 'check_settings_location'),
          PreferenceTitle('RTK/NTRIP Server settings'),
          PreferenceText(
            "Set these if your Bluetooth GNSS device supports RTK,\n(Like EcoDroidGPS + Ardusimple U-Blox F9 etc)",
            style: Theme.of(context).textTheme.caption,
          ),
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
                    m_pr.dismiss();
                  } catch (e) {}
                }
              },
            ),
          ),
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
