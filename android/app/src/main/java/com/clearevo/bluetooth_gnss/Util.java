package com.clearevo.bluetooth_gnss;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;

import java.util.HashMap;
import java.util.Map;

public class Util {
    public static int connect(final String TAG,
                              final Context context,
                              final String bdaddr,
                              final boolean secure,
                              final boolean reconnect,
                              final boolean log_bt_rx,
                              final boolean disable_ntrip,
                              final HashMap<String, String> extra_params) {

        Log.w(TAG, bdaddr + "," + secure + "," + reconnect + "," + log_bt_rx + "," + disable_ntrip + "," + extra_params.size() + ":");
        for (Map.Entry<String, String> entry : extra_params.entrySet()) {
            Log.w(TAG, "\t" + entry.getKey() + " = " + entry.getValue());
        }
        Log.d(TAG, "MainActivity connect(): " + bdaddr);
        int ret = -1;

        Intent intent = new Intent(context, bluetooth_gnss_service.class);
        intent.putExtra("bdaddr", bdaddr);
        intent.putExtra("secure", secure);
        intent.putExtra("reconnect", reconnect);
        intent.putExtra("log_bt_rx", log_bt_rx);
        intent.putExtra("disable_ntrip", disable_ntrip);
        Log.d(TAG, "mainact extra_params: " + extra_params);
        for (String key : extra_params.keySet()) {
            String val = extra_params.get(key);
            Log.d(TAG, "mainact extra_params key: " + key + " val: " + val);
            intent.putExtra(key, val);
        }
        intent.putExtra("activity_class_name", TAG);
        intent.putExtra("activity_icon_id", R.mipmap.ic_launcher);


        ComponentName ssret = context.startService(intent);
        Log.d(TAG, "MainActivity connect(): startservice ssret: " + ssret.flattenToString());
        return 0;
    }

}
