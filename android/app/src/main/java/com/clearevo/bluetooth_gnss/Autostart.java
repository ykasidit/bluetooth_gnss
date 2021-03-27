package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class Autostart extends BroadcastReceiver {
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())
                || "tasker.MOCK".equals(intent.getAction()) ) {
            Util.makeConnection(this.getClass().getName(), context, intent);
        }
    }
}