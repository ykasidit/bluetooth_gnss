package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;

public class StartConnectionReceiver extends BroadcastReceiver {

    static final String TAG = "btgnss_receiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        SharedPreferences sharedPref = PreferenceManager.getDefaultSharedPreferences(context);

        if ("bluetooth.CONNECT".equals(intent.getAction())) {

            try {
                JSONObject extras = new JSONObject(intent.getExtras().getString("config"));
                final String bdaddr  = extras.getString("bdaddr");
                Util.connect(this.getClass().getName(), context, bdaddr, true, false, false, false, new HashMap<>());
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
    }


}