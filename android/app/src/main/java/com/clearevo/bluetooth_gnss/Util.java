package com.clearevo.bluetooth_gnss;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;

import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

import static android.content.Context.MODE_PRIVATE;

public class Util {

    public static void makeConnection(final String TAG, Context context, Intent intent) {
        // defaults from preferences
        final SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);

        String bdaddr = prefs.getString("flutter.pref_target_bdaddr", null);
        boolean secure = prefs.getBoolean("flutter.pref_secure", true);
        boolean reconnect = prefs.getBoolean("flutter.pref_reconnect", false);
        boolean log_bt_rx = prefs.getBoolean("flutter.pref_log_bt_rx", false);
        boolean disable_ntrip = prefs.getBoolean("flutter.pref_disable_ntrip", false);
        final HashMap<String, String> extra_params = new HashMap<>();

        for (String pk : bluetooth_gnss_service.REQUIRED_INTENT_EXTRA_PARAM_KEYS) {
            final String value = prefs.getString("flutter.pref_" + pk, null);
            if (value != null) extra_params.put(pk, value);
        }

        // get override from intent
        Bundle extras = intent.getExtras();
        if (extras != null) {
            final String configStr = extras.getString("config");

            if (configStr != null && !configStr.isEmpty()) {
                try {
                    final JSONObject overrides = new JSONObject(configStr);
                    bdaddr = overrides.optString("bdaddr", bdaddr);
                    secure = overrides.optBoolean("secure", secure);
                    reconnect = overrides.optBoolean("reconnect", reconnect);
                    log_bt_rx = overrides.optBoolean("log_bt_rx", log_bt_rx);
                    disable_ntrip = overrides.optBoolean("disable_ntrip", disable_ntrip);

                    final JSONObject overrides_extra_params = overrides.optJSONObject("extra");
                    if (overrides_extra_params != null) {
                        for (String pk : bluetooth_gnss_service.REQUIRED_INTENT_EXTRA_PARAM_KEYS) {
                            final String value = overrides_extra_params.optString(pk, extra_params.get(pk));
                            if (value != null) extra_params.put(pk, value);
                        }
                    }
                } catch (JSONException e) {
                    Log.e(TAG, e.getMessage(), e);
                }
            }
        }

        if (bdaddr != null) {
            Util.connect(TAG, context, bdaddr, secure, reconnect, log_bt_rx, disable_ntrip, extra_params);
        }
    }

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

        final ComponentName ssret;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ssret = context.startForegroundService(intent);
        } else {
            ssret = context.startService(intent);
        }

        Log.d(TAG, "MainActivity connect(): startservice ssret: " + ssret.flattenToString());
        return 0;
    }

}
