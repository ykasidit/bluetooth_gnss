package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import static android.content.Context.MODE_PRIVATE;

public class Autostart extends BroadcastReceiver {
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())
                || "tasker.MOCK".equals(intent.getAction()) ) {

            // defaults from preferences
            final SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);

            final GnssConnectionParams gnssConnectionParams = Util.createGnssConnectionFromPreferences(prefs);

            Util.connect(Autostart.class.getName(), context, gnssConnectionParams);
        }
    }
}