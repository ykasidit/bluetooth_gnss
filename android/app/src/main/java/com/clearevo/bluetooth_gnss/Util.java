package com.clearevo.bluetooth_gnss;

import static com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service.log;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;


import com.clearevo.libbluetooth_gnss_service.Log;
import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.lang.reflect.Type;
import java.util.HashMap;
import java.util.Map;

public class Util {

    public static final String TAG = "btgnss_util";
    public static final String LAST_CONN_FILE_NAME = "last_connect_dev.json";

    public static File get_connect_args_file(Context context) throws Exception
    {
        return new File(context.getFilesDir(), LAST_CONN_FILE_NAME);
    }
    public static void save_connect_args(Context context, HashMap<String, Object> connectArgs) throws Exception
    {
        Gson gson = new Gson();
        String jsonString = gson.toJson(connectArgs);
        File file = get_connect_args_file(context);
        try (FileWriter writer = new FileWriter(file)) {
            writer.write(jsonString);
        }
    }

    public static HashMap<String, Object> load_last_connect_args(Context context) throws Exception {
        Gson gson = new Gson();
        Type type = new TypeToken<HashMap<String, Object>>(){}.getType();
        try (FileReader reader = new FileReader(get_connect_args_file(context))) {
            return gson.fromJson(reader, type);
        }
    }

    public static int connect(final Context context, HashMap<String, Object> args) throws Exception {
        Log.d(TAG, "connect(): args: " + args);
        Intent intent = new Intent(context, bluetooth_gnss_service.class);
        intent.putExtra("args", args);
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
