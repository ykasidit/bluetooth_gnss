package com.clearevo.libbluetooth_gnss_service;

import android.content.Context;
import android.util.Log;

import androidx.documentfile.provider.DocumentFile;
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
public class test_documentfile_new_file_write {

    static final String TAG = "btgnss_service";

    @Test
    public void useAppContext() throws Exception {
        // Context of the app under test.
        Context appContext = InstrumentationRegistry.getTargetContext();
        assertEquals("com.clearevo.libbluetooth_gnss_service.test", appContext.getPackageName());

        Log.d(TAG,"start");
        DocumentFile dd = null;
        Log.d(TAG,"done");

    }
}
