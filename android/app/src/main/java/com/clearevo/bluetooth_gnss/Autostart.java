package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;


import com.clearevo.libbluetooth_gnss_service.Log;

import java.util.HashMap;

public class Autostart extends BroadcastReceiver {
    public static final String TAG = "btgnss_as";
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())
                || "tasker.MOCK".equals(intent.getAction()) ) {
            Log.d(TAG, "onReceive start");
            try {
                // defaults from preferences
                final HashMap<String, Object> connectArgs = Util.load_last_connect_args(context);
                Log.d(TAG, "pref autostart: " +connectArgs.get("autostart"));
                boolean autostart = (boolean) connectArgs.get("autostart");
                Log.d(TAG, "pref unboxed autostart: " +connectArgs.get("autostart"));
                if (autostart) {
                    Util.connect(context, connectArgs);
                }
            } catch (Exception e) {
                Log.d(TAG, "autostart got exception: " +Log.getStackTraceString(e));
            }
            Log.d(TAG, "onReceive done");
        }
    }
}