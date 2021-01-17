package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;

import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;

import static android.content.Context.MODE_PRIVATE;

public class StartConnectionReceiver extends BroadcastReceiver {

    static final String TAG = "btgnss_receiver";

    @Override
    public void onReceive(Context context, Intent intent) {


        if ("bluetooth.CONNECT".equals(intent.getAction())) {
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
            final String configStr = intent.getExtras().getString("config");

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

            if (bdaddr != null) {
                Util.connect(this.getClass().getName(), context, bdaddr, secure, reconnect, log_bt_rx, disable_ntrip, extra_params);
            }
        }
    }


}