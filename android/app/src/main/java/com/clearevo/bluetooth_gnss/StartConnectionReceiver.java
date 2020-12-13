package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;

import java.util.HashMap;

public class StartConnectionReceiver extends BroadcastReceiver {

    static final String TAG = "btgnss_receiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        SharedPreferences sharedPref = PreferenceManager.getDefaultSharedPreferences(context);

        // assumes WordService is a registered service
        Util.connect(this.getClass().getName(), context, "00:00:00:00:00:00", true, false, false, false, new HashMap<>());
    }


}