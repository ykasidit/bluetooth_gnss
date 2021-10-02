Bluetooth GNSS
--------------

This is the source code repo for the Bluetooth GNSS app. Connect your Android phone to external Bluetooth GPS, GLONASS, Galileo and BeiDou receivers and use their location.

This is the UI part.

The engine part is hosted at <https://github.com/ykasidit/libbluetooth_gnss>.

Build instructions
-----------

* Download the [Flutter SDK](https://flutter.dev/docs/get-started/install) and add the path to `flutter/bin` to your $PATH
* Add `flutter.sdk` to the `local.properties` file (not the bin folder)
 ```
 flutter.sdk=/path/to/flutter
 ```
* Run `flutter pub get` in the *android* directory
* Create the file `key.properties` and add your keystore information
```
storeFile=/path/to/keystore.jks
storePassword=*********
keyAlias=bluetooth_gnss
keyPassword=**********
``` 
* Install the [Lombok plugin](https://projectlombok.org/setup/android) in Android Studio
  * Go to `File > Settings > Plugins`
  * Click on `Browse repositories...`
  * Search for `Lombok Plugin`
  * Click on `Install plugin`
  * Restart Android Studio 
* Resync project Gradle

Initiate connection using external intent
-----------------------------------------
I'm using [Tasker](https://play.google.com/store/apps/details?id=net.dinglisch.android.taskerm) to send the intent, but other methods are possible

### Configure the task
On the `TASKS` tab, create a new task (e.g. _Connect GPS_) and add the action _Send Intent_. It is configured as follows:
* Action: `bluetooth.CONNECT`
* Cat: `Default`
* Mime Type: `text/plain`
* Data: _&lt;empty&gt;_
* Extra: _&lt;see json string below&gt;_
* Package: `com.clearevo.bluetooth_gnss`
* Class: _&lt;empty&gt;_
* Target: `Broadcast Receiver`

**json string in Extra field**

Add this string without newlines. All values are optional. Note that `config` is without double quotes

```
config: {
    "bdaddr": "%bt_address",
    "secure": false,
    "reconnect": true,
    "log_bt_rx": true,
    "disable_ntrip": true,
    "extra": {
        "ntrip_user": "taskeruser",
        "ntrip_mountpoint": "taskermount",
        "ntrip_host": "taskerhost",
        "ntrip_port": "2000",
        "ntrip_pass": "taskerpass"
    }
}
```

**Example**

If you only want to override the bluetooth address, you can send this as extra:

```
config: {bdaddr:"%bt_address"}
```

If you don't use the BT Connection Event (see below) but the BT Connection state, you have to use the real address of your device:

```
config: {bdaddr: "00:11:22:33:44:55:66"}
```

If you want to disable ntrip as well:

```
config: {bdaddr: "00:11:22:33:44:55:66", disable_ntrip: true}
```

### Configure the event
On the `PROFILES` tab, you can use a state change or a event. In this example, I'm using the [BT Connection event](https://tasker.joaoapps.com/userguide/en/help/eh_bt_connect_disconnect.html) with the following conditions:

* `%bt_connected EQ true`
* `$bt_address EQ 00:11:22:33:44:55:66`, the bluetooth address of the GPS receiver

This will trigger the event only when my GPS receiver is connected. You can add multiple devices here, which is why I choose this method: in the action, the variable `%bt_address` will be available as well and I'll use that to pass to Bluetooth GNSS.

Special thanks
--------------

- Thanks to 'Geoffrey Peck' from Australia for all his tests, observations and suggestions.
- Thanks to [Auric Goldfinger](https://github.com/auricgoldfinger) for his great contribution in developing the auto connect on bluetooth feature and the detailed readme merged into above.
- Thanks to everyone who provided comments/suggestions on the [bluetooth_gnss project issues page on github](https://github.com/ykasidit/bluetooth_gnss/issues).

Authors
--------

- [Kasidit Yusuf](https://github.com/ykasidit)
- [Auric Goldfinger](https://github.com/auricgoldfinger)
- For the most up-to-date list, run `git shortlog -sne` in this git repo.

Copyright and License
---------------------

Copyright (C) 2019 Kasidit Yusuf and all respective project source code contributors.

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
