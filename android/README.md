Preparation
-----------

* Download the [Flutter SDK](https://flutter.dev/docs/get-started/install) and add the path to `flutter/bin` to your $PATH
* Add `flutter.sdk` to the `local.properties` file (not the bin folder)
 ```
 flutter.sdk=/path/to/flutter
 ```
* Run `flutter pub get` in the android directory (where this README file is located)
* Create the file `key.properties` and add your keystore information
```
storeFile=/path/to/keystore.jks
storePassword=*********
keyAlias=bluetooth_gnss
keyPassword=**********
``` 
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
