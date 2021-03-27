package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;

import static android.content.Context.MODE_PRIVATE;

public class StartConnectionReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if ("bluetooth.CONNECT".equals(intent.getAction())) {

            // defaults from preferences
            final SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);

            final GnssConnection gnssConnection = Util.createGnssConnectionFromPreferences(prefs);

            // get override from intent
            final Bundle extras = intent.getExtras();
            if (extras != null) {
                final String configStr = extras.getString("config");

                Util.overrideConnectionWithOptions(gnssConnection, configStr);
            }

            Util.connect(StartConnectionReceiver.class.getName(), context, gnssConnection);
        }
    }
}