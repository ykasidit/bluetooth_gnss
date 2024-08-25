package com.clearevo.libbluetooth_gnss_service;

import android.content.Context;
import android.content.Intent;


import androidx.test.InstrumentationRegistry;
import androidx.test.runner.AndroidJUnit4;

import org.junit.Test;
import org.junit.runner.RunWith;

import static org.junit.Assert.assertEquals;

/**
 * Instrumented test, which will execute on an Android device.
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
@RunWith(AndroidJUnit4.class)
public class test_start_service_ble_gap_scan_mode {

    static final String TAG = "btgnss_service";

    @Test
    public void useAppContext() throws Exception {
        // Context of the app under test.
        Context appContext = InstrumentationRegistry.getTargetContext();
        assertEquals("com.clearevo.libbluetooth_gnss_service.test", appContext.getPackageName());

        Log.d(TAG,"start test: "+this.getClass().getSimpleName());

        Intent intent = new Intent(appContext, bluetooth_gnss_service.class);
        intent.putExtra("ble_gap_scan_mode", true);
        appContext.startService(intent);

        int n_rounds = 10;
        for (int i = 0; i < n_rounds; i++) {
            Thread.sleep(1000);
        }
        appContext.stopService(intent);

        Thread.sleep(5000);

    }
}
