package com.clearevo.bluetooth_gnss;

import static com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service.log;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.location.Location;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.provider.Settings;

import android.widget.Toast;
import android.net.Uri;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.clearevo.libbluetooth_gnss_service.Log;
import com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service;
import com.clearevo.libbluetooth_gnss_service.ntrip_conn_mgr;
import com.clearevo.libbluetooth_gnss_service.rfcomm_conn_mgr;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;
import io.flutter.plugin.common.EventChannel;
import android.content.pm.PermissionInfo;

public class MainActivity extends FlutterActivity {
public static final String APPLICATION_ID = "com.clearevo.bluetooth_gnss";
    private static final String ENGINE_METHOD_CHANNEL = "com.clearevo.bluetooth_gnss/engine";
    private static final String ENGINE_EVENTS_CHANNEL = "com.clearevo.bluetooth_gnss/engine_events";
    private static final String SETTINGS_EVENTS_CHANNEL = "com.clearevo.bluetooth_gnss/settings_events";
    public static final String MAIN_ACTIVITY_CLASSNAME = "com.clearevo.bluetooth_gnss.MainActivity";
    private static final int CHOOSE_FOLDER = 1;
    static final String TAG = "btgnss_main";
    EventChannel.EventSink m_events_sink;
    EventChannel.EventSink m_settings_events_sink;
    bluetooth_gnss_service m_service;
    boolean mBound = false;

    Handler m_handler;
    final int MESSAGE_PARAMS_MAP = 0;
    final int MESSAGE_SETTINGS_MAP = 1;
    final int MESSAGE_DEVICE_MESSAGE = 2;

    public static Location lastInternalGNSSLocation;
    boolean internalGNSSLocationSubscribed = false;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        Log.initTraceFile(getApplicationContext());

        GeneratedPluginRegistrant.registerWith(flutterEngine);
        BinaryMessenger messenger = flutterEngine.getDartExecutor().getBinaryMessenger();
        new EventChannel(messenger, ENGINE_EVENTS_CHANNEL).setStreamHandler(
            new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object args, final EventChannel.EventSink events) {
                    m_events_sink = events;
                    Log.d(TAG, "ENGINE_EVENTS_CHANNEL added listener: " + events + " args: " + args);
                }

                @Override
                public void onCancel(Object args) {
                    m_events_sink = null;
                    Log.d(TAG, "ENGINE_EVENTS_CHANNEL cancelled listener args: " + args);
                }
            }
        );
        new EventChannel(messenger, SETTINGS_EVENTS_CHANNEL).setStreamHandler(
                new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object args, final EventChannel.EventSink events) {
                        m_settings_events_sink = events;
                        Log.d(TAG, "SETTINGS_EVENTS_CHANNEL added listener: " + events);
                    }

                    @Override
                    public void onCancel(Object args) {
                        m_settings_events_sink = null;
                        Log.d(TAG, "SETTINGS_EVENTS_CHANNEL cancelled listener");
                    }
                }
        );
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), ENGINE_METHOD_CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            Object return_success_val = null;
                            try {
                                //Log.d(TAG, "got method call: "+call.method);
                                if (call.method.equals("connect")) {
                                    Log.d(TAG,"MethodChannel method: "+call.method+" args: "+call.arguments);
                                    HashMap<String, Object> connectArgs = call.arguments();
                                    Util.save_connect_args(getApplicationContext(), connectArgs); //service read from this to get args for intent/autostart cases
                                    final Context context = getApplicationContext();
                                    new Thread() {
                                        public void run() {
                                            try {
                                                //getcanonicalname somehow returns null, getname() would return something with $ at the end so wont work to launch the activity from the service notification, so just use a string literal here
                                                Util.connect(context, connectArgs);
                                            } catch (Throwable tr) {
                                                Log.d(TAG, "connect() exception: " + Log.getStackTraceString(tr));
                                            }
                                        }
                                    }.start();
                                    int ret = 0;
                                    Log.d(TAG, "connect() ret: " + ret);
                                    return_success_val = true;
                                } else if (call.method.equals("get_mountpoint_list")) {
                                    String host = call.argument("ntrip_host");
                                    String port = call.argument("ntrip_port");
                                    String user = call.argument("ntrip_user");
                                    String pass = call.argument("ntrip_pass");
                                    new Thread() {
                                        public void run() {
                                            ArrayList<String> ret = new ArrayList<String>(); //init with empty list in case get fails
                                            try {
                                                ret = get_mountpoint_list(host, Integer.parseInt(port), user, pass);
                                                if (ret == null) {
                                                    ret = new ArrayList<String>(); //init with empty list in case get fails - can't push null into concurrenthashmap
                                                }
                                                Log.d(TAG, "get_mountpoint_list ret: " + ret);
                                            } catch (Exception e) {
                                                Log.d(TAG, "on_updated_nmea_params sink update exception: " + Log.getStackTraceString(e));
                                                toast("Get mountpoint_list fialed: " + e);
                                            }
                                            ConcurrentHashMap<String, Object> cbmap = new ConcurrentHashMap<String, Object>();
                                            cbmap.put("callback_src", "get_mountpoint_list");
                                            cbmap.put("callback_payload", ret);
                                            Message msg = m_handler.obtainMessage(MESSAGE_SETTINGS_MAP, cbmap);
                                            msg.sendToTarget();
                                        }
                                    }.start();
                                    return_success_val = 0;
                                } else if (call.method.equals("toast")) {
                                    String msg = call.argument("msg");
                                    toast(msg);
                                    return_success_val = 0;
                                } else if (call.method.equals("setLiveArgs")) {
                                    m_service.setLiveArgs(call.arguments());
                                    return_success_val = 0;
                                } else if (call.method.equals("dlog")) {
                                    Log.d("btgnss_ui", call.argument("msg"));
                                    return_success_val = 0;
                                } else if (call.method.equals("disconnect")) {
                                    try {
                                        Log.d(TAG, "disconnect0");
                                        if (m_service != null && mBound) {
                                            Log.d(TAG, "disconnect1");
                                            try {
                                                m_service.stop_auto_reconnect_thread();
                                            } catch (Throwable tr) {}
                                            try {
                                                m_service.close();
                                            } catch (Throwable tr) {}
                                            return_success_val = true;
                                            Log.d(TAG, "disconnect2");
                                        }
                                        Log.d(TAG, "disconnect3");
                                        Intent intent = new Intent(getApplicationContext(), bluetooth_gnss_service.class);
                                        stopService(intent);
                                        Log.d(TAG, "disconnect4");
                                    } catch (Exception e) {
                                        Log.d(TAG, "disconnect exception: " + Log.getStackTraceString(e));
                                    }
                                    return_success_val = false;
                                } else if (call.method.equals("get_bd_map")) {
                                    return_success_val = get_bd_map(m_handler, getApplicationContext(), this);
                                } else if (call.method.equals("check_permissions_not_granted")) {
                                    List<String> ret = check_permissions_not_granted();
                                    if (ret.isEmpty()) {
                                        //all permissions ok - subscribe location now
                                        if (!internalGNSSLocationSubscribed) {
                                            Log.d(TAG, "all perm ok - RealLocationHelper start get TODO");
                                            /*RealLocationHelper.getRealLocation(getApplicationContext(), new RealLocationHelper.LocationCallback() {
                                                @Override
                                                public void onLocationReceived(Location location) {
                                                    Log.e(TAG, "RealLocationHelper onLocationReceived: " + location);
                                                    lastInternalGNSSLocation = location;
                                                }

                                                @Override
                                                public void onLocationError(String message) {
                                                    Log.e(TAG, "RealLocationHelper Error: " + message);
                                                }
                                            });*/
                                            internalGNSSLocationSubscribed = true;
                                        }
                                    }
                                    return_success_val = ret;
                                } else if (call.method.equals("is_bluetooth_on")) {
                                    return_success_val = rfcomm_conn_mgr.is_bluetooth_on();
                                } else if (call.method.equals("is_ntrip_connected")) {
                                    return_success_val = m_service != null && m_service.is_ntrip_connected();
                                } else if (call.method.equals("get_ntrip_cb_count")) {
                                    if (m_service != null) {
                                        return_success_val = m_service.get_ntrip_cb_count();
                                    } else {
                                        return_success_val = 0;
                                    }
                                } else if (call.method.equals("is_bt_connected")) {
                                    return_success_val = mBound && m_service != null && m_service.is_bt_connected();
                                } else if (call.method.equals("is_conn_thread_alive")) {
                                    return_success_val = mBound && m_service != null && m_service.is_trying_bt_connect();
                                } else if (call.method.equals("open_phone_settings")) {
                                    return_success_val = open_phone_settings();
                                } else if (call.method.equals("open_phone_developer_settings")) {
                                    return_success_val = open_phone_developer_settings();
                                } else if (call.method.equals("open_phone_blueooth_settings")) {
                                    return_success_val = open_phone_bluetooth_settings();
                                } else if (call.method.equals("open_phone_location_settings")) {
                                    return_success_val = open_phone_location_settings();
                                } else if (call.method.equals("clear_trace_file")) {
                                    return_success_val = Log.clearTraceFile(getApplicationContext());
                                } else if (call.method.equals("set_log_uri")) {
                                    Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
                                    // Optionally, specify a URI for the directory that should be opened in
                                    // the system file picker when it loads.
                                    //intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, Do);
                                    startActivityForResult(intent, CHOOSE_FOLDER);
                                    return_success_val = true;
                                } else if (call.method.equals("get_log_dir")) {
                                    File log_dir = Log.getLogsDir(getApplicationContext());
                                    if (log_dir == null) {
                                        return_success_val = "";
                                    } else {
                                        return_success_val = log_dir.getAbsolutePath();
                                    }
                                } else if (call.method.equals("is_write_enabled")) {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                        /*android 11 - no need writ ext storage perm*/
                                        return_success_val = true;
                                    } else if (ContextCompat.checkSelfPermission(getApplicationContext(), Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) {
                                        return_success_val = true;
                                    } else {
                                        Log.d(TAG, "is_write_enabled check write permission not granted yet so requesting permission now");
                                        Toast.makeText(getApplicationContext(), "BluetoothGNSS needs external storage write permissions to log data - please allow...", Toast.LENGTH_LONG).show();
                                        new Thread() {
                                            public void run() {
                                                try {
                                                    Thread.sleep(1000);
                                                } catch (Exception e) {
                                                }
                                                m_handler.post(
                                                        new Runnable() {
                                                            @Override
                                                            public void run() {
                                                                ActivityCompat.requestPermissions(MainActivity.this, new String[]{
                                                                        Manifest.permission.WRITE_EXTERNAL_STORAGE
                                                                }, 2);
                                                            }
                                                        }
                                                );
                                            }
                                        }.start();
                                        return_success_val = false;
                                    }
                                } else if (call.method.equals("is_mock_location_enabled")) {
                                    return_success_val = bluetooth_gnss_service.is_mock_location_enabled(getApplicationContext(), android.os.Process.myUid(), APPLICATION_ID);
                                } else if (call.method.equals("is_location_enabled")) {

                                    Log.d(TAG, "is_location_enabled 0");
                                    if (ContextCompat.checkSelfPermission(getApplicationContext(), Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
                                            ContextCompat.checkSelfPermission(getApplicationContext(), Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                                    ) {

                                        Log.d(TAG, "is_location_enabled check locaiton permission already granted");

                                        if (call.method.equals("is_location_enabled")) {
                                            return_success_val = bluetooth_gnss_service.is_location_enabled(getApplicationContext());
                                        } else if (call.method.equals("is_mock_location_enabled")) {
                                            return_success_val = bluetooth_gnss_service.is_mock_location_enabled(getApplicationContext(), android.os.Process.myUid(), APPLICATION_ID);
                                        }
                                    } else {
                                        Log.d(TAG, "is_location_enabled check locaiton permission not granted yet so requesting permission now");
                                        Toast.makeText(getApplicationContext(), "BluetoothGNSS needs to check location settings - please allow...", Toast.LENGTH_LONG).show();

                                        new Thread() {
                                            public void run() {
                                                try {
                                                    Thread.sleep(1000);
                                                } catch (Exception e) {
                                                }
                                                m_handler.post(
                                                        new Runnable() {
                                                            @Override
                                                            public void run() {
                                                                ActivityCompat.requestPermissions(MainActivity.this, new String[]{
                                                                        Manifest.permission.ACCESS_FINE_LOCATION,
                                                                        Manifest.permission.ACCESS_COARSE_LOCATION,
                                                                }, 1);
                                                            }
                                                        }
                                                );
                                            }
                                        }.start();
                                        return_success_val = false;
                                    }

                                } else if (call.method.equals("is_coarse_location_enabled")) {

                                    if (
                                            ContextCompat.checkSelfPermission(getApplicationContext(), Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                                    ) {

                                        //Log.d(TAG, "is_coarse_location_enabled check locaiton permission already granted");
                                        return_success_val = true;
                                    } else {
                                        Log.d(TAG, "is_coarse_location_enabled check locaiton permission not granted yet so requesting permission now");
                                        Toast.makeText(getApplicationContext(), "BluetoothGNSS needs to check coarse location settings - please allow...", Toast.LENGTH_LONG).show();

                                        new Thread() {
                                            public void run() {
                                                try {
                                                    Thread.sleep(1000);
                                                } catch (Exception e) {
                                                }
                                                m_handler.post(
                                                        new Runnable() {
                                                            @Override
                                                            public void run() {
                                                                ActivityCompat.requestPermissions(MainActivity.this, new String[]{
                                                                        Manifest.permission.ACCESS_COARSE_LOCATION,
                                                                }, 1);
                                                            }
                                                        }
                                                );
                                            }
                                        }.start();
                                        return_success_val = false;
                                    }

                                } else {
                                    result.notImplemented();
                                }
                            } catch (Throwable tr) {
                                log(TAG, "WARNING: exception in mainactivity handler: " + call.method + " exception: " + Log.getStackTraceString(tr));
                            }
                            if (return_success_val != null) {
                                result.success(return_success_val);
                            } else {
                                log(TAG, "WARNING: return_success_val not set in mainactivity handler: " + call.method);
                                result.success(false);
                            }
                        }
                );

        create();
    }


    @Override
    public void onActivityResult(int requestCode, int resultCode,
                                 Intent resultData) {
        if (requestCode == CHOOSE_FOLDER) {
            Context context = getApplicationContext();
            Log.d(TAG, "activity result choose folder");
            String uri_str = "";
            if (resultCode == this.RESULT_OK) {
                if (resultData != null) {
                    Uri uri = resultData.getData();
                    uri_str = uri.toString();
                    if (uri_str != null && context != null) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                            getContext().getContentResolver().takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                        }

                        ConcurrentHashMap<String, Object> cbmap = new ConcurrentHashMap<String, Object>();
                        cbmap.put("callback_src", "set_log_uri");
                        cbmap.put("callback_payload", uri_str);
                        Message msg = m_handler.obtainMessage(MESSAGE_SETTINGS_MAP, cbmap);
                        msg.sendToTarget();
                        String umsg = "Logging callback ok: save to: "+uri_str;
                        Log.d(TAG, umsg);
                    }
                }
            } else {
                //Log.d(TAG, "choose_folder not ok so disable log uri: " + log_uri_pref_key);
                ConcurrentHashMap<String, Object> cbmap = new ConcurrentHashMap<String, Object>();
                cbmap.put("callback_src", "set_log_uri");
                cbmap.put("callback_payload", "");
                Message msg = m_handler.obtainMessage(MESSAGE_SETTINGS_MAP, cbmap);
                msg.sendToTarget();
                String umsg = "Logging callback not ok: save to: "+uri_str;
                Log.d(TAG, umsg);
            }
        }
    }

    public void create() {
        Log.d(TAG, "create()");
        m_handler = new Handler(getMainLooper()) {
            @Override
            public void handleMessage(Message inputMessage) {
                if (inputMessage.what == MESSAGE_PARAMS_MAP || inputMessage.what == MESSAGE_DEVICE_MESSAGE) {
                    try {
                        if (mBound == false || m_events_sink == null) {
                            //Log.d(TAG, "mBound == false || m_events_sink == null so not delivering params_map");
                        } else {
                            Object params_map = inputMessage.obj;
                            if (params_map instanceof HashMap) {
                                if (inputMessage.what == MESSAGE_DEVICE_MESSAGE) {
                                    ((HashMap)params_map).put("is_dev_msg_map", true);
                                } else {
                                    //dont put
                                    ((HashMap)params_map).remove("is_dev_msg_map");
                                }
                                /*
                        PREVENT BELOW: try clone the hashmap...
                        D/btgnss_mainactvty(15208): handlemessage exception: java.util.ConcurrentModificationException
D/btgnss_mainactvty(15208): 	at java.util.HashMap$HashIterator.nextNode(HashMap.java:1441)
D/btgnss_mainactvty(15208): 	at java.util.HashMap$EntryIterator.next(HashMap.java:1475)
D/btgnss_mainactvty(15208): 	at java.util.HashMap$EntryIterator.next(HashMap.java:1473)
D/btgnss_mainactvty(15208): 	at io.flutter.plugin.common.StandardMessageCodec.writeValue(StandardMessageCodec.java:289)
D/btgnss_mainactvty(15208): 	at io.flutter.plugin.common.StandardMethodCodec.encodeSuccessEnvelope(StandardMethodCodec.java:57)
D/btgnss_mainactvty(15208): 	at io.flutter.plugin.common.EventChannel$IncomingStreamRequestHandler$EventSinkImplementation.success(EventChannel.java:226)
D/btgnss_mainactvty(15208): 	at com.clearevo.bluetooth_gnss.MainActivity$1.handleMessage(MainActivity.java:64)
                        * */
                                //params_map = ((HashMap) params_map).clone();
                                //Log.d(TAG, "cloned HashMap to prevent ConcurrentModificationException...");
                            }

                            m_events_sink.success(params_map);
                            //Log.d(TAG, "mainactivity sent "+((inputMessage.what == MESSAGE_PARAMS_MAP)?"params_map: "+params_map:"dev_msg"));

                        }
                    } catch (Exception e) {
                        Log.d(TAG, "handlemessage MESSAGE_PARAMS_MAP exception: " + Log.getStackTraceString(e));
                    }
                } else if (inputMessage.what == MESSAGE_SETTINGS_MAP) {
                    Log.d(TAG, "mainactivity handler got settings map");
                    try {
                        if (m_settings_events_sink == null) {
                            Log.d(TAG, "m_settings_events_sink == null so not delivering params_map");
                        } else {
                            Object params_map = inputMessage.obj;
                            m_settings_events_sink.success(params_map);
                        }
                    } catch (Exception e) {
                        Log.d(TAG, "handlemessage MESSAGE_SETTINGS_MAP exception: " + Log.getStackTraceString(e));
                    }
                }
            }
        };
    }



    public ArrayList<String> get_mountpoint_list(String host, int port, String user, String pass) {
        ArrayList<String> ret = null;
        ntrip_conn_mgr mgr = null;
        try {
            mgr = new ntrip_conn_mgr(host, port, "", user, pass, null);
            ret = mgr.get_mount_point_list();
        } catch (Exception e) {
            Log.d(TAG, "get_mountpoint_list call exception: " + Log.getStackTraceString(e));
        } finally {
            if (mgr != null) {
                try {
                    mgr.close();
                } catch (Exception e) {
                }
            }
        }
        return ret;
    }

    public boolean open_phone_settings() {
        try {
            startActivity(new Intent(android.provider.Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS));
            return true;
        } catch (Exception e) {
            Log.d(TAG, "launch phone settings activity exception: " + Log.getStackTraceString(e));
        }
        return false;
    }

    public boolean open_phone_bluetooth_settings() {
        try {
            startActivity(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS));
            return true;
        } catch (Exception e) {
            Log.d(TAG, "launch phone settings activity exception: " + Log.getStackTraceString(e));
        }
        return false;
    }

    public boolean open_phone_location_settings() {
        try {
            startActivity(new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS));
            return true;
        } catch (Exception e) {
            Log.d(TAG, "launch phone settings activity exception: " + Log.getStackTraceString(e));
        }
        return false;
    }

    public boolean open_phone_developer_settings() {
        try {
            startActivity(new Intent(android.provider.Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS));
            return true;
        } catch (Exception e) {
            Log.d(TAG, "launch phone settings activity exception: " + Log.getStackTraceString(e));
        }
        return false;
    }

    public void onPositionUpdate(HashMap<String, Object> params_map) {
        //Log.d(TAG, "mainactivity onPositionUpdate()");
        try {
            Message msg = m_handler.obtainMessage(MESSAGE_PARAMS_MAP, params_map);
            msg.sendToTarget();
        } catch (Exception e) {
            Log.d(TAG, "on_updated_nmea_params sink update exception: " + Log.getStackTraceString(e));
        }
    }

    public void onDeviceMessage(String type, HashMap<String, Object> message_map) {
        try {
            message_map.put("type", type);
            Message msg = m_handler.obtainMessage(MESSAGE_DEVICE_MESSAGE, message_map);
            msg.sendToTarget();
        } catch (Exception e) {
            Log.d(TAG, "on_updated_nmea_params sink update exception: " + Log.getStackTraceString(e));
        }
    }

    public void toast(String msg) {
        toast(msg, m_handler, getApplicationContext());
    }

    public static void toast(String msg, Handler handler, Context context) {
        handler.post(
                new Runnable() {
                    @Override
                    public void run() {
                        try {
                            Toast.makeText(context, msg, Toast.LENGTH_LONG).show();
                        } catch (Exception e) {
                            Log.d(TAG, "toast exception: " + Log.getStackTraceString(e));
                        }
                    }
                }
        );
    }

    public void stop_service_if_not_connected() {
        if (mBound && m_service != null && m_service.is_bt_connected()) {
            toast("Bluetooth GNSS running in backgroud...");
        } else {
            Intent intent = new Intent(getApplicationContext(), bluetooth_gnss_service.class);
            stopService(intent);
        }
    }

    @Override
    public void onDestroy() {
        Log.d(TAG, "onDestroy()");
        super.onDestroy();
    }

    @Override
    protected void onStart() {
        Log.d(TAG, "onStart()");
        super.onStart();
        // Bind to LocalService
        Intent intent = new Intent(this, bluetooth_gnss_service.class);
        bindService(intent, connection, Context.BIND_AUTO_CREATE);
    }


    @Override
    protected void onStop() {
        Log.d(TAG, "onStop()");
        super.onStop();
        unbindService(connection);
        mBound = false;

    }

    @Override
    protected void onPause() {
        Log.d(TAG, "onPause()");
        super.onPause();
    }

    @Override
    protected void onResume() {
        Log.d(TAG, "onResume()");
        super.onResume();
    }

    /**
     * Defines callbacks for service binding, passed to bindService()
     */
    private ServiceConnection connection = new ServiceConnection() {

        @Override
        public void onServiceConnected(ComponentName className,
                                       IBinder service) {

            Log.d(TAG, "onServiceConnected()");

            // We've bound to LocalService, cast the IBinder and get LocalService instance
            bluetooth_gnss_service.LocalBinder binder = (bluetooth_gnss_service.LocalBinder) service;
            m_service = binder.getService();
            mBound = true;
            m_service.set_callback(MainActivity.this);
        }

        @Override
        public void onServiceDisconnected(ComponentName arg0) {
            Log.d(TAG, "onServiceDisconnected()");
            mBound = false;
            m_service.set_callback(null);
        }
    };

    List<String> askedPermissions = new ArrayList<>();

    public List<String> check_permissions_not_granted()
    {
            //check/ask manifest permissions
            PackageInfo info = null;
            try {
                info = getApplicationContext().getPackageManager().getPackageInfo(getApplicationContext().getPackageName(), PackageManager.GET_PERMISSIONS);
            } catch (PackageManager.NameNotFoundException e) { /* */ }
            List<String> needed = new ArrayList<>();
            if (info != null && info.requestedPermissions != null && info.requestedPermissionsFlags != null) {
                for (int i = 0; i < info.requestedPermissions.length; i++) {
                    int flags = info.requestedPermissionsFlags[i];
                    if ((flags & PackageInfo.REQUESTED_PERMISSION_GRANTED) == 0) {
                        needed.add(info.requestedPermissions[i]);
                    }
                }
            }
            List<String> notGrantedPermission = getNotGrantedPermissions(getApplicationContext(), needed);
            if (notGrantedPermission.contains(Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
                notGrantedPermission.remove(Manifest.permission.WRITE_EXTERNAL_STORAGE); //not always required, only required if user enables logging
            }
            if (notGrantedPermission.contains(Manifest.permission.READ_EXTERNAL_STORAGE)) {
                notGrantedPermission.remove(Manifest.permission.READ_EXTERNAL_STORAGE); //not always required, only required if user enables logging
            }
        Log.d(TAG, "should ask manifest perm notGrantedPermission: " + Arrays.toString(notGrantedPermission.toArray()));
            if (!notGrantedPermission.isEmpty()) {
                Log.d(TAG, "ask now perm notGrantedPermission: " + Arrays.toString(notGrantedPermission.toArray()));
                //already_asked_perm = true;
                String[] perm_array = notGrantedPermission.toArray(new String[notGrantedPermission.size()]);
                m_handler.post(new Runnable() {
                    @Override
                    public void run() {
                        ActivityCompat.requestPermissions(MainActivity.this, perm_array, 1);
                    }
                });
            }
            return notGrantedPermission;
    }

    boolean isRequestingPermission = false;

    public List<String> getNotGrantedPermissions(Context context, List<String> needed_ori) {
        PackageManager pm = context.getPackageManager();
        List<String> needed = new ArrayList<>(needed_ori); // Copy for mutation
        List<String> filtered = new ArrayList<>();

        for (String perm : needed) {
            try {
                // Check if permission is declared in manifest
                PackageInfo info = pm.getPackageInfo(context.getPackageName(), PackageManager.GET_PERMISSIONS);
                String[] declaredPerms = info.requestedPermissions;
                if (declaredPerms == null || !Arrays.asList(declaredPerms).contains(perm)) {
                    // Permission not in manifest, cannot be granted
                    continue;
                }

                // Check if permission is already granted
                if (ContextCompat.checkSelfPermission(context, perm) == PackageManager.PERMISSION_GRANTED) {
                    continue;
                }

                // Check if system will prompt (true = can prompt, false = system silently denies)
                if (ActivityCompat.shouldShowRequestPermissionRationale((Activity) MainActivity.this, perm)
                        || !isPermissionNotAlwaysRequired(perm)) {
                    filtered.add(perm);
                }

            } catch (PackageManager.NameNotFoundException e) {
                log("getNotGrantedPermissions: exception: "+e); // Defensive
            }
        }

        return filtered;
    }

    public static final List<String> NOT_ALWAYS_REQUIRED_PERMISSIONS = Arrays.asList(new String[] {
            "android.permission.ACCESS_MOCK_LOCATION",
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
    });

    private boolean isPermissionNotAlwaysRequired(String permission) {
        try {
            if (NOT_ALWAYS_REQUIRED_PERMISSIONS.contains(permission))
                return true;
            PermissionInfo info = getApplicationContext().getPackageManager().getPermissionInfo(permission, 0);
            return (info.protectionLevel & PermissionInfo.PROTECTION_FLAG_PRIVILEGED) != 0
                    || (info.protectionLevel & PermissionInfo.PROTECTION_FLAG_SYSTEM) != 0;
        } catch (PackageManager.NameNotFoundException e) {
            return true; // Treat unknown permissions as system-level (can't be granted)
        }
    }



    @SuppressLint("MissingPermission")
    public static HashMap<String, String> get_bd_map(Handler handler, Context context, Activity activity) {
        Log.d(TAG, "get_bd_map() start");
        HashMap<String, String> ret = new HashMap<String, String>();
        try {
            BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
            // Check if Bluetooth is enabled
            if (!adapter.isEnabled()) {
                // Prompt user to enable Bluetooth (not shown here)
                Log.d(TAG, "get_bd_map() Bluetooth is not enabled");
                return ret;
            }
            if (adapter != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT)
                            != PackageManager.PERMISSION_GRANTED) {
                        Log.d(TAG, "get_bd_map() perm not granted, requesting bluetooth_connect");
                        ActivityCompat.requestPermissions(activity,
                                new String[]{Manifest.permission.BLUETOOTH_CONNECT}, 2);
                        return ret;
                    }
                }
                Set<BluetoothDevice> bonded_devs = adapter.getBondedDevices();
                Log.d(TAG, "get_bd_map() adapter bonded dev len: "+bonded_devs.size());
                for (BluetoothDevice bonded_dev : bonded_devs) {
                    String bname = bonded_dev.getName();
                    String bdaddr = bonded_dev.getAddress();
                    if (bdaddr == null)
                        continue;
                    if (bname == null)
                        bname = bdaddr;
                    ret.put(bdaddr, bname);
                }
                Log.d(TAG, "get_bd_map() bdmap ret len: "+ret.size());
            }
        } catch (Exception e) {
            Log.d(TAG, "CRITICAL WARNING: get_bd_map exception: "+Log.getStackTraceString(e));
        }

        return ret;
    }


}