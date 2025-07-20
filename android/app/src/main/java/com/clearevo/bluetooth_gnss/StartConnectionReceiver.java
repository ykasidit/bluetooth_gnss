package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Objects;
import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;

public class StartConnectionReceiver extends BroadcastReceiver {
    public static final String TAG = "btgnss_scr";
    @Override
    public void onReceive(Context context, Intent intent) {
        if ("bluetooth.CONNECT".equals(intent.getAction())) {
            try {
            // defaults from preferences
            final HashMap<String, Object> connectArgs = Util.load_last_connect_args(context);

            // get override from intent
            final Bundle extras = intent.getExtras();
            if (extras != null) {
                final String configStr = extras.getString("config");
                overrideConnectionWithOptions(connectArgs, configStr);
            }
                Util.connect(context, connectArgs);
            } catch (Exception e) {
                Log.d(TAG, "StartConnectionReceiver onreceive got exception: " +Log.getStackTraceString(e));
            }

        }
    }

    private void overrideConnectionWithOptions(HashMap<String, Object> connectArgs, String overriddenOptions) {
        Objects.requireNonNull(connectArgs, "connectArgs must already been initialised");
        if (overriddenOptions != null && !overriddenOptions.isEmpty()) {
            try {
                final JSONObject overrides = new JSONObject(overriddenOptions);

                ArrayList<String> all_args = new ArrayList<String>();
                all_args.addAll(Arrays.asList(bluetooth_gnss_service.BT_CONNECT_ARGS));
                all_args.addAll(Arrays.asList(bluetooth_gnss_service.NTRIP_CONNECT_ARGS));
                for (String pk : all_args) {
                    final String value = overrides.optString(pk, null);
                    if (value != null) connectArgs.put(pk, value);
                }
                //legacy 'extra' args
                final JSONObject overrides_extra_params = overrides.optJSONObject("extra");
                if (overrides_extra_params != null) {
                    for (String pk : bluetooth_gnss_service.NTRIP_CONNECT_ARGS) {
                        final String value = overrides_extra_params.optString(pk, null);
                        if (value != null) connectArgs.put(pk, value);
                    }
                }
            } catch (Exception e) {
                Log.e(this.getClass().getSimpleName(), e.getMessage(), e);
            }
        }
    }
}