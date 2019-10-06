// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

Widget get_about_view(){
  String md = """
  
Purpose
=======

Use this app to get more accurate positioning data (latitude, longitude, elevation...) from external 'Bluetooth GNSS Receivers' (like 'EcoDroidGPS', 'HOLUX', 'Garmin GLO' etc) and use it as the position for apps in this phone (like Google Maps, etc) via 'Mock location app' Android Developer Settings.

"""+ScrollableTabsDemoState.note_how_to_disable_mock_location+"""

This app is provided for free by [www.ClearEvo.com](http://www.clearevo.com) - home of the 'EcoDroidGPS' Bluetooth GPS Receiver for Android phones and Tablets.

Also, the source code of this app's engine, named 'libbluetooth_gnss', is free software, re-licensed and released under the GNU GPL for anyone to study/use/modify/share freely at:
- <https://github.com/ykasidit/libbluetooth_gnss>

Copyright (c) 2019 Kasidit Yusuf. All rights reserved.


Notices for the UI part of this app
-----------------------

This app's UI uses, and I would like to hereby say thanks all authors of, below flutter packages - their respective authors and licenses described on their pages under <https://pub.dev/packages>
- preferences
- flutter_gallery_assets
- flutter_markdown


Notices for engine part of this app
-----------------------------------

This 'libbluetooth_gnss' engine uses, and I would like to hereby say thanks all authors of, the 'Java Marine API' - NMEA 0183 library for Java - under the GNU LGPL - see the project page for more info:
- <https://github.com/ktuukkan/marine-api>

""";

  return Markdown(data: md);
}
