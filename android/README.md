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