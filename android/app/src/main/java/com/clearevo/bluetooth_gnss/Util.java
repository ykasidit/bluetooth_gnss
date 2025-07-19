package com.clearevo.bluetooth_gnss;

import static com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service.ble_qstarz_mode;
import static com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service.ble_uart_mode;
import static com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service.log;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;


import com.clearevo.libbluetooth_gnss_service.Log;
import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;
import com.google.gson.Gson;

import org.jetbrains.annotations.NotNull;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.Map;

public class Util {

    public static final String TAG = "btgnss_util";
    public static final String LAST_CONN_FILE_NAME = "last_connect_dev.json";

    public static File get_prev_conn_param_file(Context context) throws Exception
    {
        return new File(context.getFilesDir(), LAST_CONN_FILE_NAME);
    }
    public static void save_last_connect_dev(Context context, GnssConnectionParams gnssConnectionParams) throws Exception
    {
        Gson gson = new Gson();
        String jsonString = gson.toJson(gnssConnectionParams);
        File file = get_prev_conn_param_file(context);
        try (FileWriter writer = new FileWriter(file)) {
            writer.write(jsonString);
        }
    }

    public static GnssConnectionParams load_last_connect_dev(Context context) throws Exception
    {
            Gson gson = new Gson();
            try (FileReader reader = new FileReader(get_prev_conn_param_file(context))) {
                return gson.fromJson(reader, GnssConnectionParams.class);
            }
    }


    public static int connect(final String activityClassName,
                              final Context context,
                              final GnssConnectionParams gnssConnectionParams) {

        Log.d(TAG, "activityClassName: "+activityClassName+" gnssConnectionParams: "+gnssConnectionParams.toString() + ":");
        for (Map.Entry<String, String> entry : gnssConnectionParams.extraParams.entrySet()) {
            Log.d(TAG, "\t" + entry.getKey() + " = " + entry.getValue());
        }
        gnssConnectionParams.gapMode = false; //disabled - no longer supported

        Log.d(TAG, "connect(): " + gnssConnectionParams.bdaddr);
        int ret = -1;

        Intent intent = new Intent(context, bluetooth_gnss_service.class);
        intent.putExtra("bdaddr", gnssConnectionParams.bdaddr);
        intent.putExtra("secure", gnssConnectionParams.secure);
        intent.putExtra("reconnect", gnssConnectionParams.reconnect);
        intent.putExtra("log_bt_rx_log_uri", gnssConnectionParams.log_bt_rx_log_uri);
        intent.putExtra("disable_ntrip", gnssConnectionParams.disableNtrip);
        intent.putExtra(ble_qstarz_mode, gnssConnectionParams.ble_qstarz_mode);
        intent.putExtra(ble_uart_mode, gnssConnectionParams.ble_uart_mode);
        intent.putExtra("mock_location_timestamp_offset_millis", gnssConnectionParams.mock_location_timestamp_offset_millis);
        Log.d(TAG, "gnssConnectionParams.isGapMode(): "+ gnssConnectionParams.gapMode);
        intent.putExtra(bluetooth_gnss_service.BLE_GAP_SCAN_MODE, gnssConnectionParams.gapMode);
        Log.d(TAG, "mainact extra_params: " + gnssConnectionParams.extraParams);
        for (String key : gnssConnectionParams.extraParams.keySet()) {
            String val = gnssConnectionParams.extraParams.get(key);
            Log.d(TAG, "mainact extra_params key: " + key + " val: " + val);
            intent.putExtra(key, val);
        }
        intent.putExtra("activity_class_name", MainActivity.MAIN_ACTIVITY_CLASSNAME);
        intent.putExtra("activity_icon_id", R.mipmap.ic_launcher);
        if (gnssConnectionParams.bdaddr == null) {
            gnssConnectionParams.bdaddr = ""; //no need to do null handling below
        }
        boolean gap_mode = intent.getBooleanExtra(bluetooth_gnss_service.BLE_GAP_SCAN_MODE, false);
        gap_mode = false; //DISABLED gap_mode - no longer supported
        Log.d(TAG, "util.connect() gap_mode: "+gap_mode+" ble_uart_mode: "+intent.getBooleanExtra(ble_uart_mode, false)+" ble_qstarz_mode: "+intent.getBooleanExtra(ble_qstarz_mode, false));
        if (gnssConnectionParams.ble_uart_mode) {
            Log.e(TAG, "ble uart not implemented yet");
            return -99;
        } else {
            //bt classic rfcomm spp mode
            if (gnssConnectionParams.bdaddr.trim().isEmpty() || !gnssConnectionParams.bdaddr.matches("^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$")) {
                Log.e(TAG, "Invalid BT mac address: " + gnssConnectionParams.bdaddr);
                return -1;
            }
        }

        final ComponentName ssret;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ssret = context.startForegroundService(intent);
        } else {
            ssret = context.startService(intent);
        }

        Log.d(TAG, "connect(): startservice ssret: " + ssret.flattenToString());
        return 0;
    }



}
