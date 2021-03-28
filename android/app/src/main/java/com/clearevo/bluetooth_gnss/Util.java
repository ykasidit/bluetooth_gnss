package com.clearevo.bluetooth_gnss;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;

import org.jetbrains.annotations.NotNull;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Map;
import java.util.Objects;

public class Util {

    @NotNull
    public static GnssConnectionParams createGnssConnectionFromPreferences(SharedPreferences prefs) {
        final GnssConnectionParams gnssConnectionParams = new GnssConnectionParams();
        gnssConnectionParams.setBdaddr(prefs.getString("flutter.pref_target_bdaddr", null));
        gnssConnectionParams.setSecure(prefs.getBoolean("flutter.pref_secure", true));
        gnssConnectionParams.setReconnect(prefs.getBoolean("flutter.pref_reconnect", false));
        gnssConnectionParams.setLogBtRx(prefs.getBoolean("flutter.pref_log_bt_rx", false));
        gnssConnectionParams.setDisableNtrip(prefs.getBoolean("flutter.pref_disable_ntrip", false));

        for (String pk : bluetooth_gnss_service.REQUIRED_INTENT_EXTRA_PARAM_KEYS) {
            final String value = prefs.getString("flutter.pref_" + pk, null);
            if (value != null) gnssConnectionParams.getExtraParams().put(pk, value);
        }

        return gnssConnectionParams;
    }


    public static void overrideConnectionWithOptions(GnssConnectionParams gnssConnectionParams, String overriddenOptions) {
        Objects.requireNonNull(gnssConnectionParams, "GnssConnection must already been initialised");
        if (overriddenOptions != null && !overriddenOptions.isEmpty()) {
            try {
                final JSONObject overrides = new JSONObject(overriddenOptions);
                gnssConnectionParams.setBdaddr(overrides.optString("bdaddr", gnssConnectionParams.getBdaddr()));
                gnssConnectionParams.setSecure(overrides.optBoolean("secure", gnssConnectionParams.isSecure()));
                gnssConnectionParams.setReconnect(overrides.optBoolean("reconnect", gnssConnectionParams.isReconnect()));
                gnssConnectionParams.setLogBtRx(overrides.optBoolean("log_bt_rx", gnssConnectionParams.isLogBtRx()));
                gnssConnectionParams.setDisableNtrip(overrides.optBoolean("disable_ntrip", gnssConnectionParams.isDisableNtrip()));

                final JSONObject overrides_extra_params = overrides.optJSONObject("extra");
                if (overrides_extra_params != null) {
                    for (String pk : bluetooth_gnss_service.REQUIRED_INTENT_EXTRA_PARAM_KEYS) {
                        final String value = overrides_extra_params.optString(pk, gnssConnectionParams.getExtraParams().get(pk));
                        if (value != null) gnssConnectionParams.getExtraParams().put(pk, value);
                    }
                }
            } catch (JSONException e) {
                Log.e(Util.class.getSimpleName(), e.getMessage(), e);
            }
        }
    }

    public static int connect(final String activityClassName,
                              final Context context,
                              final GnssConnectionParams gnssConnectionParams) {

        Log.w(activityClassName, gnssConnectionParams.toString() + ":");
        for (Map.Entry<String, String> entry : gnssConnectionParams.getExtraParams().entrySet()) {
            Log.w(activityClassName, "\t" + entry.getKey() + " = " + entry.getValue());
        }

        if (gnssConnectionParams.getBdaddr() == null || gnssConnectionParams.getBdaddr().trim().isEmpty() || !gnssConnectionParams.getBdaddr().matches("^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$")) {
            Log.e(activityClassName, "Invalid BT mac address: " + gnssConnectionParams.getBdaddr());
            return -1;
        }

        Log.d(activityClassName, "connect(): " + gnssConnectionParams.getBdaddr());
        int ret = -1;

        Intent intent = new Intent(context, bluetooth_gnss_service.class);
        intent.putExtra("bdaddr", gnssConnectionParams.getBdaddr());
        intent.putExtra("secure", gnssConnectionParams.isSecure());
        intent.putExtra("reconnect", gnssConnectionParams.isReconnect());
        intent.putExtra("log_bt_rx", gnssConnectionParams.isLogBtRx());
        intent.putExtra("disable_ntrip", gnssConnectionParams.isDisableNtrip());
        Log.d(activityClassName, "mainact extra_params: " + gnssConnectionParams.getExtraParams());
        for (String key : gnssConnectionParams.getExtraParams().keySet()) {
            String val = gnssConnectionParams.getExtraParams().get(key);
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
