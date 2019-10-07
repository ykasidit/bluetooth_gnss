import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';

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

  @override
  void initState() {
    _selected_dev = get_selected_bd_summary();
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
        ]),
      ),
    );
  }
}
