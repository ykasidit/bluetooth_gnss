// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'engine.dart';

Widget createAboutView(String version) {
  String md = """
Hybrid GNSS
==============
App version: $version
  
Purpose
------

Use this app to get more accurate positioning data (latitude, longitude, elevation...) from external 'Bluetooth GNSS Receivers' (like 'Bad Elf GPS PRO+', 'HOLUX', 'Garmin GLO' etc) and use it as the position for apps in this phone (like Waze, etc) via 'Mock location app' Android Developer Settings.

${TabsState.notHowToDisableMockLocation}
This app 'bluetooth_gnss' is free software and released under the GNU GPL for anyone to study/use/modify/share at:
- <https://github.com/ykasidit/bluetooth_gnss>

Special thanks
--------------

- Thanks to [Bad Elf](https://bad-elf.com) for providing a few of their devices to test with.  
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

This app's UI uses, and I would like to hereby say thanks all authors of, packages listed in below url - their respective authors and licenses described on their pages under <https://pub.dev/packages>
- https://github.com/ykasidit/bluetooth_gnss/blob/master/pubspec.yaml

Notices for engine part of this app
-----------------------------------

I would like to hereby say thanks all authors of, the 'Java Marine API' - NMEA 0183 library for Java - under the GNU LGPL - see the project page for more info:
- <https://github.com/ktuukkan/marine-api>

---

Copyright and License
---------------------

Copyright (C) 2019-2023 Kasidit Yusuf <ykasidit@gmail.com> and all respective project source code contributors.

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
    onTapLink: (text, url, title) {
      url != null ? launchUrl(Uri.dataFromString(url)) : "";
    },
    data: md,
  );
}
