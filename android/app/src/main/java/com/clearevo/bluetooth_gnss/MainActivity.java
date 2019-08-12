package com.clearevo.bluetooth_gnss;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;
import android.util.Log;

import java.util.HashMap;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugins.GeneratedPluginRegistrant;

import com.clearevo.libecodroidbluetooth.*;

public class MainActivity extends FlutterActivity implements nmea_parser.nmea_parser_callbacks {

    private static final String ENGINE_METHOD_CHANNEL = "com.clearevo.bluetooth_gnss/engine";
    private static final String ENGINE_EVENTS_CHANNEL = "com.clearevo.bluetooth_gnss/engine_events";
    static final String TAG = "btgnss_mainactvty";
    EventChannel.EventSink m_events_sink;
    bluetooth_gnss_service m_service;
    boolean mBound = false;


    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        GeneratedPluginRegistrant.registerWith(this);

        new MethodChannel(getFlutterView(), ENGINE_METHOD_CHANNEL).setMethodCallHandler(
                new MethodCallHandler() {
                    @Override
                    public void onMethodCall(MethodCall call, Result result) {
                        if (call.method.equals("connect")) {
                            String bdaddr = call.argument("bdaddr");
                            int ret = connect(bdaddr);
                            result.success(ret);
                        } else if (call.method.equals("get_bd_map")) {
                            result.success(rfcomm_conn_mgr.get_bd_map());
                        } else if (call.method.equals("is_bluetooth_on")) {
                            result.success(rfcomm_conn_mgr.is_bluetooth_on());
                        } else if (call.method.equals("is_bt_connected")) {
                            if (mBound && m_service != null && m_service.is_bt_connected()) {
                                result.success(true);
                            } else {
                                result.success(false);
                            }
                        } else {
                            result.notImplemented();
                        }
                    }
                }
        );

        new EventChannel(getFlutterView(), ENGINE_EVENTS_CHANNEL).setStreamHandler(
                new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object args, final EventChannel.EventSink events) {
                        Log.w(TAG, "adding listener");
                        m_events_sink = events;
                    }

                    @Override
                    public void onCancel(Object args) {
                        Log.w(TAG, "cancelling listener");
                        m_events_sink = null;
                    }
                }
        );
    }


    public void on_updated_nmea_params(HashMap<String, Object> params_map)
    {
        try {
            m_events_sink.success(params_map);
        } catch (Exception e) {
            Log.d(TAG, "on_updated_nmea_params sink update exception: "+Log.getStackTraceString(e));
        }
    }

    @Override
    public void onBackPressed() {
        Intent intent = new Intent(getApplicationContext(), bluetooth_gnss_service.class);
        stopService(intent);
        super.onBackPressed();
    }

    int connect(String bdaddr)
    {
        Log.d(TAG, "connect(): "+bdaddr);
        int ret = -1;

        Intent intent = new Intent(getApplicationContext(), bluetooth_gnss_service.class);
        intent.putExtra("bdaddr", bdaddr);
        startService(intent);

        return 0;
    }

    @Override
    protected void onStart() {
        super.onStart();
        // Bind to LocalService
        Intent intent = new Intent(this, bluetooth_gnss_service.class);
        bindService(intent, connection, Context.BIND_AUTO_CREATE);

    }


    @Override
    protected void onStop() {
        super.onStop();
        unbindService(connection);
        mBound = false;

    }

    /** Defines callbacks for service binding, passed to bindService() */
    private ServiceConnection connection = new ServiceConnection() {

        @Override
        public void onServiceConnected(ComponentName className,
                                       IBinder service) {

            Log.d(TAG, "onServiceConnected()");

            // We've bound to LocalService, cast the IBinder and get LocalService instance
            bluetooth_gnss_service.LocalBinder binder = (bluetooth_gnss_service.LocalBinder) service;
            m_service = binder.getService();
            mBound = true;
            m_service.m_nmea_parser.set_callbacks(MainActivity.this);
        }

        @Override
        public void onServiceDisconnected(ComponentName arg0) {
            mBound = false;
        }
    };

}