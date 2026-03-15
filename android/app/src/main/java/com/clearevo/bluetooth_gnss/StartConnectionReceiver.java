package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Objects;

import com.clearevo.libbluetooth_gnss_service.Log;
import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;

public class StartConnectionReceiver extends BroadcastReceiver {
    public static final String TAG = "btgnss_scr";
    @Override
    public void onReceive(Context context, Intent intent) {
        if ("bluetooth.CONNECT".equals(intent.getAction())) {
            // On Android 12+ (API 31+), starting foreground services from broadcast receivers
            // is restricted. Launch the Activity instead, which can start the service.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Log.d(TAG, "Android 12+: forwarding bluetooth.CONNECT intent to MainActivity");
                try {
                    Intent activityIntent = new Intent(context, MainActivity.class);
                    activityIntent.setAction("bluetooth.CONNECT");
                    activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    // Forward extras (config overrides)
                    if (intent.getExtras() != null) {
                        activityIntent.putExtras(intent.getExtras());
                    }
                    context.startActivity(activityIntent);
                } catch (Exception e) {
                    Log.d(TAG, "StartConnectionReceiver failed to launch activity: " + Log.getStackTraceString(e));
                }
                return;
            }

            // Pre-Android 12: start service directly
            try {
                final HashMap<String, Object> connectArgs = Util.load_last_connect_args(context);
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
                all_args.addAll(Arrays.asList(bluetooth_gnss_service.BT_MOCK_ARGS));
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
                Log.d(TAG, "WARNING: overrideconnectionwithoptions exception: "+Log.getStackTraceString(e));
            }
        }
    }
}
