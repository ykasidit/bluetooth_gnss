package com.clearevo.bluetooth_gnss;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;


import com.clearevo.libbluetooth_gnss_service.Log;

import java.util.HashMap;

public class Autostart extends BroadcastReceiver {
    public static final String TAG = "btgnss_as";
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action) || "tasker.MOCK".equals(action)) {
            Log.d(TAG, "onReceive start action: " + action);

            // On Android 12+ (API 31+), starting foreground services from broadcast receivers
            // is restricted for custom intents. BOOT_COMPLETED is exempt, but tasker.MOCK is not.
            if ("tasker.MOCK".equals(action) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Log.d(TAG, "Android 12+: forwarding tasker.MOCK intent to MainActivity");
                try {
                    Intent activityIntent = new Intent(context, MainActivity.class);
                    activityIntent.setAction("tasker.MOCK");
                    activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    context.startActivity(activityIntent);
                } catch (Exception e) {
                    Log.d(TAG, "Autostart failed to launch activity: " + Log.getStackTraceString(e));
                }
                Log.d(TAG, "onReceive done (forwarded to activity)");
                return;
            }

            // BOOT_COMPLETED (all versions) or tasker.MOCK (pre-Android 12): start service directly
            try {
                final HashMap<String, Object> connectArgs = Util.load_last_connect_args(context);
                Log.d(TAG, "pref autostart: " +connectArgs.get("autostart"));
                boolean autostart = (boolean) connectArgs.get("autostart");
                Log.d(TAG, "pref unboxed autostart: " +connectArgs.get("autostart"));
                if (autostart) {
                    Util.connect(context, connectArgs);
                }
            } catch (Exception e) {
                Log.d(TAG, "autostart got exception: " +Log.getStackTraceString(e));
            }
            Log.d(TAG, "onReceive done");
        }
    }
}
