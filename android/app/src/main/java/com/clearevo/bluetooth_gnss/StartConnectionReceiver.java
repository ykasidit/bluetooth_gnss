package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Objects;
import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;

import static android.content.Context.MODE_PRIVATE;

public class StartConnectionReceiver extends BroadcastReceiver {
    public static final String TAG = "btgnss_scr";
    @Override
    public void onReceive(Context context, Intent intent) {
        if ("bluetooth.CONNECT".equals(intent.getAction())) {

            // defaults from preferences
            final SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);

            final GnssConnectionParams gnssConnectionParams = Util.createGnssConnectionFromPreferences(prefs);

            // get override from intent
            final Bundle extras = intent.getExtras();
            if (extras != null) {
                final String configStr = extras.getString("config");

                overrideConnectionWithOptions(gnssConnectionParams, configStr);
            }
            try {
                Util.connect(MainActivity.MAIN_ACTIVITY_CLASSNAME, context, gnssConnectionParams);
            } catch (Exception e) {
                Log.d(TAG, "scr onreceive got exception: " +Log.getStackTraceString(e));
            }
        }
    }

    private void overrideConnectionWithOptions(GnssConnectionParams gnssConnectionParams, String overriddenOptions) {
        Objects.requireNonNull(gnssConnectionParams, "GnssConnection must already been initialised");
        if (overriddenOptions != null && !overriddenOptions.isEmpty()) {
            try {
                final JSONObject overrides = new JSONObject(overriddenOptions);
                gnssConnectionParams.bdaddr = overrides.optString("bdaddr", gnssConnectionParams.bdaddr);
                gnssConnectionParams.secure = (overrides.optBoolean("secure", gnssConnectionParams.secure));
                gnssConnectionParams.reconnect = (overrides.optBoolean("reconnect", gnssConnectionParams.secure));
                gnssConnectionParams.logBtRx = (overrides.optBoolean("log_bt_rx", gnssConnectionParams.logBtRx));
                gnssConnectionParams.disableNtrip = (overrides.optBoolean("disable_ntrip", gnssConnectionParams.disableNtrip));

                final JSONObject overrides_extra_params = overrides.optJSONObject("extra");
                if (overrides_extra_params != null) {
                    for (String pk : bluetooth_gnss_service.REQUIRED_INTENT_EXTRA_PARAM_KEYS) {
                        final String value = overrides_extra_params.optString(pk, gnssConnectionParams.extraParams.get(pk));
                        if (value != null) gnssConnectionParams.extraParams.put(pk, value);
                    }
                }
            } catch (JSONException e) {
                Log.e(this.getClass().getSimpleName(), e.getMessage(), e);
            }
        }
    }
}