package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;

import static android.content.Context.MODE_PRIVATE;

public class Autostart extends BroadcastReceiver {
    public static final String TAG = "btgnss_as";
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())
                || "tasker.MOCK".equals(intent.getAction()) ) {
            Log.d(TAG, "onReceive start");
            try {
                // defaults from preferences
                final SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
                final GnssConnectionParams gnssConnectionParams = Util.createGnssConnectionFromPreferences(prefs);
                boolean autostart = prefs.getBoolean("flutter.pref_autostart", false);
                Log.d(TAG, "pref autostart: " +autostart);
                if (autostart) {
                    Util.connect(MainActivity.MAIN_ACTIVITY_CLASSNAME, context, gnssConnectionParams);
                }
            } catch (Exception e) {
                Log.d(TAG, "autostart got exception: " +Log.getStackTraceString(e));
            }
            Log.d(TAG, "onReceive done");
        }
    }
}