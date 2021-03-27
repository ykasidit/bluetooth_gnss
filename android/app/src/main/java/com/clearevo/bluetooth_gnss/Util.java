package com.clearevo.bluetooth_gnss;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;

import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;

import org.jetbrains.annotations.NotNull;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Map;
import java.util.Objects;

import static android.content.Context.MODE_PRIVATE;

public class Util {

    @NotNull
    public static GnssConnection createGnssConnectionFromPreferences(SharedPreferences prefs) {
        final GnssConnection gnssConnection = new GnssConnection();
        gnssConnection.setBdaddr(prefs.getString("flutter.pref_target_bdaddr", null));
        gnssConnection.setSecure(prefs.getBoolean("flutter.pref_secure", true));
        gnssConnection.setReconnect(prefs.getBoolean("flutter.pref_reconnect", false));
        gnssConnection.setLogBtRx(prefs.getBoolean("flutter.pref_log_bt_rx", false));
        gnssConnection.setDisableNtrip(prefs.getBoolean("flutter.pref_disable_ntrip", false));

        for (String pk : bluetooth_gnss_service.REQUIRED_INTENT_EXTRA_PARAM_KEYS) {
            final String value = prefs.getString("flutter.pref_" + pk, null);
            if (value != null) gnssConnection.getExtraParams().put(pk, value);
        }

        return gnssConnection;
    }


    public static void overrideConnectionWithOptions(GnssConnection gnssConnection, String overriddenOptions) {
        Objects.requireNonNull(gnssConnection, "GnssConnection must already been initialised");
        if (overriddenOptions != null && !overriddenOptions.isEmpty()) {
            try {
                final JSONObject overrides = new JSONObject(overriddenOptions);
                gnssConnection.setBdaddr(overrides.optString("bdaddr", gnssConnection.getBdaddr()));
                gnssConnection.setSecure(overrides.optBoolean("secure", gnssConnection.isSecure()));
                gnssConnection.setReconnect(overrides.optBoolean("reconnect", gnssConnection.isReconnect()));
                gnssConnection.setLogBtRx(overrides.optBoolean("log_bt_rx", gnssConnection.isLogBtRx()));
                gnssConnection.setDisableNtrip(overrides.optBoolean("disable_ntrip", gnssConnection.isDisableNtrip()));

                final JSONObject overrides_extra_params = overrides.optJSONObject("extra");
                if (overrides_extra_params != null) {
                    for (String pk : bluetooth_gnss_service.REQUIRED_INTENT_EXTRA_PARAM_KEYS) {
                        final String value = overrides_extra_params.optString(pk, gnssConnection.getExtraParams().get(pk));
                        if (value != null) gnssConnection.getExtraParams().put(pk, value);
                    }
                }
            } catch (JSONException e) {
                Log.e(Util.class.getSimpleName(), e.getMessage(), e);
            }
        }
    }

    public static int connect(final String activityClassName,
                              final Context context,
                              final GnssConnection gnssConnection) {

        Log.w(activityClassName, gnssConnection.toString() + ":");
        for (Map.Entry<String, String> entry : gnssConnection.getExtraParams().entrySet()) {
            Log.w(activityClassName, "\t" + entry.getKey() + " = " + entry.getValue());
        }

        if (gnssConnection.getBdaddr() == null || gnssConnection.getBdaddr().trim().isEmpty() || !gnssConnection.getBdaddr().matches("^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$")) {
            Log.e(activityClassName, "Invalid BT mac address: " + gnssConnection.getBdaddr());
            return -1;
        }

        Log.d(activityClassName, "connect(): " + gnssConnection.getBdaddr());
        int ret = -1;

        Intent intent = new Intent(context, bluetooth_gnss_service.class);
        intent.putExtra("bdaddr", gnssConnection.getBdaddr());
        intent.putExtra("secure", gnssConnection.isSecure());
        intent.putExtra("reconnect", gnssConnection.isReconnect());
        intent.putExtra("log_bt_rx", gnssConnection.isLogBtRx());
        intent.putExtra("disable_ntrip", gnssConnection.isDisableNtrip());
        Log.d(activityClassName, "mainact extra_params: " + gnssConnection.getExtraParams());
        for (String key : gnssConnection.getExtraParams().keySet()) {
            String val = gnssConnection.getExtraParams().get(key);
            Log.d(activityClassName, "mainact extra_params key: " + key + " val: " + val);
            intent.putExtra(key, val);
        }
        intent.putExtra("activity_class_name", activityClassName);
        intent.putExtra("activity_icon_id", R.mipmap.ic_launcher);

        final ComponentName ssret;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ssret = context.startForegroundService(intent);
        } else {
            ssret = context.startService(intent);
        }

        Log.d(activityClassName, "MainActivity connect(): startservice ssret: " + ssret.flattenToString());
        return 0;
    }

}
