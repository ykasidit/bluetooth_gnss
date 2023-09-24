// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';

const String _markdownData = """# Markdown Example
Markdown allows you to easily include formatted text, images, and even formatted Dart code in your app.

## Styling
Style text as _italic_, __bold__, or `inline code`.

- Use bulleted lists
- To better clarify
- Your points

## Links
You can use [hyperlinks](hyperlink) in markdown

## Images

You can include images:

![Flutter logo](https://flutter.io/images/flutter-mark-square-100.png#100x100)

## Markdown widget

This is an example of how to create your own Markdown widget:

    new Markdown(data: 'Hello _world_!');

## Code blocks
Formatted Dart code looks really pretty too:

```
void main() {
  runApp(new MaterialApp(
    home: new Scaffold(
      body: new Markdown(data: markdownData)
    )
  ));
}
```

Enjoy!
""";

Widget get_about_view(String version) {
  String md = """
  
Bluetooth GNSS
==============
App version: """+version+ """

  
Purpose
------

Use this app to get more accurate positioning data (latitude, longitude, elevation...) from external 'Bluetooth GNSS Receivers' (like 'EcoDroidGPS', 'HOLUX', 'Garmin GLO' etc) and use it as the position for apps in this phone (like Waze, etc) via 'Mock location app' Android Developer Settings.

"""+ScrollableTabsDemoState.note_how_to_disable_mock_location+"""

This free and open source app is provided for free by [www.ClearEvo.com](http://www.clearevo.com) - home of the 'EcoDroidGPS' Bluetooth GPS Receiver for Android phones and Tablets.

This app 'bluetooth_gnss', amd its engine - 'libbluetooth_gnss', are free software and released under the GNU GPL for anyone to study/use/modify/share at:
- <https://github.com/ykasidit/bluetooth_gnss>
- <https://github.com/ykasidit/libbluetooth_gnss>

Special thanks
--------------

- Thanks to Geoffrey Peck from Australia for his tests, observations and suggestions.
- Thanks to Peter Mousley from Australia for his expert advice, tests, code review and guidance.
- Thanks to [Auric Goldfinger](https://github.com/auricgoldfinger) for his great contribution in developing the auto connect on bluetooth feature and the detailed readme merged into above.
- Thanks to everyone who provided comments/suggestions on the [bluetooth_gnss project issues page on github](https://github.com/ykasidit/bluetooth_gnss/issues).

Authors
--------

- [Kasidit Yusuf](https://github.com/ykasidit)
- [Auric Goldfinger](https://github.com/auricgoldfinger)
- For the most up-to-date list, run `git shortlog -sne` in the respective cloned git repos.

Notices for the UI part of this app
-----------------------

This app's UI uses, and I would like to hereby say thanks all authors of, below flutter packages - their respective authors and licenses described on their pages under <https://pub.dev/packages>
- preferences
- flutter_gallery_assets
- flutter_markdown
- progress_dialog
- package_info
- share
- url_launcher
- geolocator


Notices for engine part of this app
-----------------------------------

This 'libbluetooth_gnss' engine uses, and I would like to hereby say thanks all authors of, the 'Java Marine API' - NMEA 0183 library for Java - under the GNU LGPL - see the project page for more info:
- <https://github.com/ktuukkan/marine-api>


---

Copyright and License
---------------------

Copyright (C) 2019 Kasidit Yusuf <ykasidit@gmail.com> and all respective project source code contributors.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
    
""";

  return Markdown(
    selectable: true,
    onTapLink: (text, url, title){
      url != null ? launch(url) : "";
    },
    data: md,
  );
}
