package com.clearevo.libbluetooth_gnss_service;


import static android.app.PendingIntent.FLAG_IMMUTABLE;
import static android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION;
import static com.clearevo.bluetooth_gnss.MainActivity.MAIN_ACTIVITY_CLASSNAME;
import static com.clearevo.bluetooth_gnss.MainActivity.get_bd_map;
import static com.clearevo.libbluetooth_gnss_service.Log.LogObserver;
import static com.clearevo.libbluetooth_gnss_service.Log.d;
import static com.clearevo.libbluetooth_gnss_service.Log.getStackTraceString;
import static com.clearevo.libbluetooth_gnss_service.Log.m_log_operations_fos;
import static com.clearevo.libbluetooth_gnss_service.gnss_sentence_parser.fromHexString;

import android.app.AppOpsManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.location.LocationManager;
import android.location.LocationProvider;
import android.net.Uri;
import android.os.Binder;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.SystemClock;
import android.text.TextUtils;
import android.widget.Toast;

import androidx.core.app.NotificationCompat;
import androidx.documentfile.provider.DocumentFile;

import com.clearevo.bluetooth_gnss.R;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.OutputStream;
import java.math.BigDecimal;
import java.text.SimpleDateFormat;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

//import com.flutter_rust_bridge.rust_lib_bluetooth_gnss.BuildConfig; //test that it can access



public class bluetooth_gnss_service extends Service implements gnss_sentence_parser.gnss_parser_callbacks, ntrip_conn_callbacks, LogObserver {

    static {
        System.loadLibrary("rust_lib_bluetooth_gnss");
    }

    static final String TAG = "btgnss_service";
    public static final String BLE_GAP_SCAN_MODE = "ble_gap_scan_mode";
    public static final UUID nordic_uart_service_uuid = UUID.fromString("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
    public static final UUID qstarz_chrc_tx_uuid = UUID.fromString("6E400004-B5A3-F393-E0A9-E50E24DCCA9E");
    String[] SATS_USED_KEYS = new String[]{"GP_n_sats_used", "GL_n_sats_used", "GA_n_sats_used", "GB_n_sats_used", "GQ_n_sats_used"};

    rfcomm_conn_mgr g_rfcomm_mgr = null;
    ntrip_conn_mgr m_ntrip_conn_mgr = null;
    private gnss_sentence_parser m_gnss_parser = new gnss_sentence_parser();

    Thread m_connecting_thread = null;
    Thread m_ntrip_connecting_thread = null;
    Handler m_handler = new Handler();
    String m_bdaddr = "";
    boolean m_auto_reconnect = false;
    boolean m_secure_rfcomm = true;
    Class m_target_activity_class;
    int m_icon_id;
    int m_ntrip_cb_count;
    int m_ntrip_cb_count_added_to_send_buffer;
    HashMap<String, Object> m_start_connect_args;

    boolean m_ubx_mode = true;
    boolean m_ubx_send_enable_extra_used_packets = true;
    boolean m_send_gga_to_ntrip = true;
    boolean m_all_ntrip_params_specified = false;
    long m_last_ntrip_gga_send_ts = 0;
    public static final long SEND_GGA_TO_NTRIP_EVERY_MILLIS = 29 * 1000;
    //{ntrip_user=null, ntrip_mountpoint=null, secure=true, autostart=false, ntrip_pass=null, ble_gap_scan_mode=false, reconnect=false, log_bt_rx_log_uri=, mock_location_timestamp_offset_millis=0, bdaddr=98:D3:61:FD:78:33, ntrip_host=igs-ip.net, ntrip_port=2101, disable_ntrip=false}
    public static final String BT_ARG_SECURE = "secure";
    public static final String BT_ARG_AUTOSTART = "autostart";
    public static final String BT_ARG_RECONNECT = "reconnect";
    public static final String BT_ARG_BDADDR = "bdaddr";
    public static final String BT_ARG_LOG_BT_RX_URI = "log_bt_rx_log_uri";
    public static final String BT_ARG_MOCK_USE_SYSTEM_TIMESTAMP = "mock_timestamp_use_system_time";
    public static final String BT_ARG_MOCK_TIMESTAMP_OFFSET_SECS = "mock_timestamp_offset_secs";
    public static final String BT_ARG_MOCK_LAT_OFFSET_METERS = "mock_lat_offset_meters";
    public static final String BT_ARG_MOCK_LON_OFFSET_METERS = "mock_lon_offset_meters";
    public static final String BT_ARG_MOCK_ALT_OFFSET_METERS = "mock_alt_offset_meters";
    public static final String BT_ARG_DEVICE_CEP = "device_cep";

    FusedLocationProviderClient fusedClient;
    public static final String[] BT_CONNECT_ARGS = {
            BT_ARG_BDADDR,
            BT_ARG_SECURE,
            BT_ARG_RECONNECT,
            BT_ARG_AUTOSTART,
            BT_ARG_LOG_BT_RX_URI,
            BT_ARG_DEVICE_CEP,
    };

    public static final String[] BT_MOCK_ARGS = {
            BT_ARG_MOCK_USE_SYSTEM_TIMESTAMP,
            BT_ARG_MOCK_TIMESTAMP_OFFSET_SECS,
            BT_ARG_MOCK_LAT_OFFSET_METERS,
            BT_ARG_MOCK_LON_OFFSET_METERS,
            BT_ARG_MOCK_ALT_OFFSET_METERS
    };


    public static final String NTRIP_ARG_HOST = "ntrip_host";
    public static final String NTRIP_ARG_PORT = "ntrip_port";
    public static final String NTRIP_ARG_MOUNTPOINT = "ntrip_mountpoint";
    public static final String NTRIP_ARG_USER = "ntrip_user";
    public static final String NTRIP_ARG_PASS = "ntrip_pass";
    public static final String NTRIP_ARG_DISABLE = "disable_ntrip";
    public static final String[] NTRIP_CONNECT_ARGS = {NTRIP_ARG_HOST, NTRIP_ARG_PORT, NTRIP_ARG_MOUNTPOINT, NTRIP_ARG_USER, NTRIP_ARG_PASS, NTRIP_ARG_DISABLE};
    String m_log_bt_rx_log_uri = "";
    boolean m_disable_ntrip = false;
    boolean m_ble_qstarz_mode = false;
    OutputStream m_log_bt_rx_fos = null;
    OutputStream m_log_bt_rx_csv_fos = null;
    long log_bt_rx_bytes_written = 0;
    public static bluetooth_gnss_service curInstance = null;
    boolean mock_location_timestamp_use_system_time = false;
    double mock_timestamp_offset_secs = 0.0;
    double mock_lat_offset_meters = 0.0;
    double mock_lon_offset_meters = 0.0;
    double mock_alt_offset_meters = 0.0;
    public static final double latlonMetersToDegMultiplier = 1.0 / 111_320.0;

    public static final String POSITION_UPDATE_INTENT_ACTION = "com.clearevo.libbluetooth_gnss_service.POSITION_UPDATE";
    public static final String PARSED_NMEA_UPDATE_INTENT_ACTION = "com.clearevo.libbluetooth_gnss_service.PARSED_NMEA_UPDATE";
    public static final String INTENT_EXTRA_DATA_JSON_KEY = "data_json";

    public void setLiveArgs(HashMap<String, Object> connectArgs)
    {
        mock_location_timestamp_use_system_time = (boolean) connectArgs.get(BT_ARG_MOCK_USE_SYSTEM_TIMESTAMP);
        mock_timestamp_offset_secs = (double) connectArgs.get(BT_ARG_MOCK_TIMESTAMP_OFFSET_SECS);
        mock_lat_offset_meters =  (double) connectArgs.get(BT_ARG_MOCK_LAT_OFFSET_METERS);
        mock_lon_offset_meters =  (double) connectArgs.get(BT_ARG_MOCK_LON_OFFSET_METERS);
        mock_alt_offset_meters =  (double) connectArgs.get(BT_ARG_MOCK_ALT_OFFSET_METERS);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // If we get killed, after returning from here, restart
        log(TAG, "onStartCommand");
        Log.logObserver = this;
        closing = false;

        curInstance = this;

        if (intent != null) {
            try {
                HashMap<String, Object> connectArgs = (HashMap<String, Object>) intent.getSerializableExtra("args");
                log(TAG, "onStartCommand args: "+connectArgs);
                {
                    m_bdaddr = (String) connectArgs.get(BT_ARG_BDADDR);
                    if (m_bdaddr == null || m_bdaddr.isEmpty()) {
                        throw new Exception("invalid arg: "+BT_ARG_BDADDR+" val: "+m_bdaddr);
                    }
                    m_secure_rfcomm = (boolean) connectArgs.get(BT_ARG_SECURE);
                    m_auto_reconnect = (boolean) connectArgs.get(BT_ARG_RECONNECT);
                    m_log_bt_rx_log_uri = (String) connectArgs.get(BT_ARG_LOG_BT_RX_URI);
                    m_disable_ntrip = (boolean) connectArgs.get(NTRIP_ARG_DISABLE);
                    try {
                        m_device_cep = Double.parseDouble((String) connectArgs.get(BT_ARG_DEVICE_CEP));
                    } catch (Exception e) {}
                    setLiveArgs(connectArgs);
                    m_target_activity_class = Class.forName(MAIN_ACTIVITY_CLASSNAME);
                    m_icon_id = R.mipmap.ic_launcher;

                    if (m_log_bt_rx_log_uri != null && (!m_log_bt_rx_log_uri.isEmpty())) {
                        String log_uri = m_log_bt_rx_log_uri;
                        if (!log_uri.isEmpty()) {
                            curInstance.prepare_log_output_streams(log_uri);
                        }
                    }

                    if (m_auto_reconnect) {
                        start_auto_reconnect_thread(connectArgs);
                    } else {
                        connect(connectArgs);
                    }
                }
            } catch (Exception e) {
                String msg = "bluetooth_gnss_service: startservice: parse intent failed - cannot start... - exception: " + getStackTraceString(e);
                log(TAG, msg);
            }

        } else {
            String msg = "bluetooth_gnss_service: startservice: null intent - cannot start...";
            log(TAG, msg);
            toast(msg);
        }

        return START_REDELIVER_INTENT;
    }

    public static final String log_uri_pref_key = "flutter.pref_log_uri";

    void connect(HashMap<String, Object> connectArgs) {
        closing = false;
        {
            m_start_connect_args = connectArgs;
            if (m_bdaddr == null) {
                String msg = "bluetooth_gnss_service: startservice: Target Bluetooth device not specifed - cannot start...";
                log(TAG, msg);
                toast(msg);
            } else {
                log(TAG, "onStartCommand got bdaddr");
                int start_ret = connect(connectArgs, m_bdaddr, m_secure_rfcomm, getApplicationContext());
                if (start_ret == 0) {
                    start_foreground("Connecting...", "target device: " + m_bdaddr, "");
                }
                m_all_ntrip_params_specified = true;
                try {
                    for (String key : NTRIP_CONNECT_ARGS) {
                        Object val = m_start_connect_args.get(key);
                        if (val == null || (val instanceof String && ((String)val).isEmpty())) {
                            log(TAG, "key: " + key + "got null or empty string so m_all_ntrip_params_specified false");
                            m_all_ntrip_params_specified = false;
                            break;
                        }
                    }
                } catch (Exception e) {
                    log(TAG, "WARNING: check m_all_ntrip_params_specified exception: " + Log.getStackTraceString(e));
                    m_all_ntrip_params_specified = false;
                }
                log(TAG, "m_all_ntrip_params_specified: " + m_all_ntrip_params_specified);
                //ntrip connection would start after we get next gga bashed on this m_all_ntrip_params_specified flag
            }
        }
    }

    public void start_ntrip_conn_if_specified_but_not_connected() {

        if (!m_all_ntrip_params_specified) {
            return;
        }

        if (m_disable_ntrip) {
            return;
        }

        if (is_trying_ntrip_connect()) {
            log(TAG, "start_ntrip_conn_if_specified - ntrip already is_trying_ntrip_connect - omit this call");
            return;
        }

        if (is_ntrip_connected()) {
            log(TAG, "start_ntrip_conn_if_specified - ntrip already connected - omit this call");
            return;
        }

        try {
            if (System.currentTimeMillis() - last_ntrip_connect_retry > 10000) {
                if (m_all_ntrip_params_specified) {
                    log(TAG, "start_ntrip_conn_if_specified call connect_ntrip() since m_all_ntrip_params_specified true");
                    int port = -1;
                    try {
                        port = Integer.parseInt((String) m_start_connect_args.get(NTRIP_ARG_PORT));
                        connect_ntrip((String) m_start_connect_args.get(NTRIP_ARG_HOST), port, (String) m_start_connect_args.get(NTRIP_ARG_MOUNTPOINT), (String) m_start_connect_args.get(NTRIP_ARG_USER), (String) m_start_connect_args.get(NTRIP_ARG_PASS));
                    } catch (Exception e) {
                        log(TAG, "call connect_ntrip exception: " + getStackTraceString(e));
                    }
                } else {
                    log(TAG, "dont call connect_ntrip() since m_all_ntrip_params_specified false");
                }
                last_ntrip_connect_retry = System.currentTimeMillis();
            }
        } catch (Exception e) {
            log(TAG, "start_ntrip_conn_if_specified exception: " + getStackTraceString(e));
        }
    }

    long last_ntrip_connect_retry = 0;

    public boolean is_bt_connected() {
        if (g_rfcomm_mgr != null && g_rfcomm_mgr.is_bt_connected()) {
            return true;
        }
        return false;
    }

    public boolean is_trying_bt_connect() {
        return m_connecting_thread != null && m_connecting_thread.isAlive();
    }

    public boolean is_trying_ntrip_connect() {
        return m_ntrip_connecting_thread != null && m_ntrip_connecting_thread.isAlive();
    }

    Thread m_auto_reconnect_thread = null;
    public static final long AUTO_RECONNECT_MILLIS = 15 * 1000;

    public void stop_auto_reconnect_thread() {

        log(TAG, "stop_auto_reconnect_thread start");
        if (m_auto_reconnect_thread != null && m_auto_reconnect_thread.isAlive()) {
            //interrupt old thread so it will end...
            log(TAG, "stop_auto_reconnect_thread1.0");
            try {
                m_auto_reconnect_thread.interrupt();
                log(TAG, "stop_auto_reconnect_thread1.1");
            } catch (Exception e) {
                log(TAG, "interrrupt old m_auto_reconnect_thread failed exception: " + getStackTraceString(e));
            }
            log(TAG, "stop_auto_reconnect_thread1.2");
            m_handler.post(new Runnable() {
                @Override
                public void run() {
                    toast("Auto-Reconnect: Stopped");
                }
            });
        }
        log(TAG, "stop_auto_reconnect_thread end");
    }

    void start_auto_reconnect_thread(HashMap<String, Object> connectArgs) {
        m_start_connect_args = connectArgs;
        if (m_auto_reconnect) {

            stop_auto_reconnect_thread();

            m_auto_reconnect_thread = new Thread() {

                public void run() {

                    log(TAG, "auto-reconnect thread: " + this.hashCode() + " START");

                    try {

                        while (m_auto_reconnect_thread == this && m_auto_reconnect) {

                            //connect() must be run from main service thread in case it needs to post
                            if (!is_bt_connected() && !is_trying_bt_connect()) {
                                log(TAG, "auto-reconnect thread - has target dev and not connected - try reconnect...");
                                m_handler.post(new Runnable() {
                                    @Override
                                    public void run() {
                                        toast("Auto-Reconnect: Trying to connect...");
                                        connect(connectArgs);
                                    }
                                });
                            } else {
                                log(TAG, "auto-reconnect thread - likely already connecting or already connected or no target dev");
                            }

                            try {
                                log(TAG, "auto-reconnect thread: " + this.hashCode() + " - start sleep");
                                Thread.sleep(AUTO_RECONNECT_MILLIS);
                            } catch (InterruptedException e) {
                                log(TAG, "auto-reconnect thread: " + this.hashCode() + " - sleep interrupted likely by close() - break out of loop and end now");
                                break;
                            }

                        }
                    } catch (Throwable tr) {
                        log(TAG, "auto-reconnect thread exception: " + getStackTraceString(tr));
                    }

                    log(TAG, "auto-reconnect thread: " + this.hashCode() + " END");
                }

            };
            m_auto_reconnect_thread.start();

        }
    }

    int connect(HashMap<String, Object> connectArgs, String bdaddr, boolean secure, Context context) {
        closing = false;
        int ret = -1;
        m_start_connect_args = connectArgs;

        try {


            if (is_trying_bt_connect()) {
                toast("connection already starting - please wait...");
                return 1;
            } else if (g_rfcomm_mgr != null && g_rfcomm_mgr.is_bt_connected()) {
                toast("already connected");
                return 2;
            } else {

                log(TAG, "using dev bdaddr:" + bdaddr);
                HashMap<String, String> bdaddr_to_name_map = get_bd_map(m_handler, getApplicationContext(), null);
                String name = ""+bdaddr; //set default name to bdaddr and dont raise exception if not found name
                if (bdaddr_to_name_map.containsKey(bdaddr)) {
                    name = bdaddr_to_name_map.get(bdaddr);
                } else {
                    log(TAG, "warning: bdaddr_to_name_map doesnt contain key of selected bdaddr: "+bdaddr);
                }
                if (name == null) {
                    throw new Exception("invalid state - device name is null");
                }
                log(TAG, "using dev name:" + name);
                m_ble_qstarz_mode = name.startsWith("QSTARZ");
                log(TAG, "m_ble_qstarz_mode:" + m_ble_qstarz_mode);

                m_gnss_parser = new gnss_sentence_parser(); //use new instance
                m_gnss_parser.set_callback(this);

                toast("connecting to: " + bdaddr);
                if (g_rfcomm_mgr != null) {
                    g_rfcomm_mgr.close();
                }
                try {
                    BluetoothAdapter.getDefaultAdapter().cancelDiscovery();
                } catch (Throwable tr) {}
                BluetoothDevice dev = BluetoothAdapter.getDefaultAdapter().getRemoteDevice(bdaddr);

                if (dev == null) {
                    toast("Please pair your Bluetooth GPS Receiver in phone Bluetooth Settings...");
                    throw new Exception("no paired bluetooth devices...");
                } else {
                    //ok
                }
                g_rfcomm_mgr = new rfcomm_conn_mgr(dev, secure, this, context, m_ble_qstarz_mode);

                start_connecting_thread();
            }
            ret = 0;
        } catch (Exception e) {
            String emsg = getStackTraceString(e);
            log(TAG, "connect() exception: " + emsg);
            toast("Connect failed: " + emsg);
        }

        return ret;
    }


    public int connect_ntrip(String host, int port, String first_mount_point, String user, String pass) {
        log(TAG, "connect_ntrip set m_ntrip_conn_mgr start");

        if (is_trying_ntrip_connect()) {
            log(TAG, "connect_ntrip - omit as already trying ntrip_connect");
            return 0;
        }

        if (is_ntrip_connected()) {
            log(TAG, "connect_ntrip - omit as already trying ntrip_connected");
            return 0;
        }

        if (m_ntrip_conn_mgr != null) {
            try {
                m_ntrip_conn_mgr.close();
            } catch (Throwable e) {
            }
            m_ntrip_conn_mgr = null;
        }

        try {
            m_ntrip_conn_mgr = new ntrip_conn_mgr(host, port, first_mount_point, user, pass, this);
            log(TAG, "connect_ntrip set m_ntrip_conn_mgr done");
            //need new thread here else will fail network on mainthread below...
            m_ntrip_connecting_thread = new Thread() {
                public void run() {
                    try {
                        m_ntrip_conn_mgr.connect();
                    } catch (Exception e) {
                        log(TAG, "m_ntrip_conn_mgr.conenct() exception: " + getStackTraceString(e));
                        final Exception ex = e;
                        try {
                            m_handler.post(
                                    new Runnable() {
                                        @Override
                                        public void run() {
                                            toast_long("NTRIP Connect Failed: " + ex.toString());
                                        }
                                    }
                            );
                        } catch (Throwable tr) {
                        }
                    }
                }
            };
            m_ntrip_connecting_thread.start();
            return 0;
        } catch (Exception e) {
            log(TAG, "connect_ntrip exception: " + getStackTraceString(e));
            m_ntrip_conn_mgr = null;
        }
        return -1;
    }

    public boolean is_ntrip_connected() {
        if (m_ntrip_conn_mgr != null && m_ntrip_conn_mgr.is_connected()) {
            return true;
        }
        return false;
    }


    @Override //ntrip data callbacks
    public void on_read(byte[] read_buff) {

        try {
            //log(TAG, "ntrip on_read: "+read_buff.toString());
            m_ntrip_cb_count += 1;
            g_rfcomm_mgr.add_send_buffer(read_buff);
            m_ntrip_cb_count_added_to_send_buffer += 1;
        } catch (Exception e) {
            log(TAG, "ntrip callback on_readline exception: " + getStackTraceString(e));
        }
    }


    boolean closing = false;
    //return true if was connected
    public boolean close() {
        closing = true;
        log(TAG, "close()0");
        deactivate_mock_location();


        boolean was_connected = false;

        if (g_rfcomm_mgr != null) {
            log(TAG, "close()3");
            was_connected = g_rfcomm_mgr.is_bt_connected();
            g_rfcomm_mgr.close();
            log(TAG, "close()4");
        }

        log(TAG, "close() m_ntrip_conn_mgr: "+m_ntrip_conn_mgr);
        if (m_ntrip_conn_mgr != null) {
            try {
                log(TAG, "close() m_ntrip_conn_mgr.close()");
                m_ntrip_conn_mgr.close();
            } catch (Exception e) {
            }
        }
        m_ntrip_cb_count = 0;
        m_ntrip_cb_count_added_to_send_buffer = 0;

        try {
            if (m_log_bt_rx_fos != null) {
                m_log_bt_rx_fos.close();
                m_log_bt_rx_fos = null;
            }
        } catch (Exception e) {}
        try {
            if (m_log_bt_rx_csv_fos != null) {
                m_log_bt_rx_csv_fos.close();
                m_log_bt_rx_csv_fos = null;
            }
        } catch (Exception e) {}
        try {
            if (m_log_operations_fos != null) {
                m_log_operations_fos.close();
                m_log_operations_fos = null;
            }
        } catch (Exception e) {}
        log_file_uri = null;

        return was_connected;
    }

    void toast(String msg)
    {
        //dont toast if running in background
        if (m_is_bound) {
            try {
                Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
            } catch (Throwable e) {
                log(TAG, "toast() exception: "+ getStackTraceString(e));
            }
            log(TAG, "toast msg: "+msg);
        } else {
            log(TAG, "m_is_bound false so omit: toast msg: "+msg);
        }


    }

    void toast_long(String msg)
    {
        //dont toast if running in background
        if (m_is_bound) {
            try {
                Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            } catch (Exception e) {
                log(TAG, "toast() exception: "+ getStackTraceString(e));
            }
            log(TAG, "toast msg: "+msg);
        } else {
            log(TAG, "m_is_bound false so omit: toast msg: "+msg);
        }


    }

    public void on_rfcomm_connected()
    {
        log(TAG, "on_rfcomm_connected()");
        m_handler.post(
                new Runnable() {
                    @Override
                    public void run() {
                        toast("Connected...");
                        updateNotification("Connected...", "Target device: "+m_bdaddr, "");
                    }
                }
        );

        //try send some initial ubx queries to device:
        if (m_ubx_mode && m_ubx_send_enable_extra_used_packets) {
            new Thread() {
                public void run() {
                    try {
                        g_rfcomm_mgr.add_send_buffer(fromHexString("B5 62 06 01 03 00 F1 00 01 FC 13"));  //enable pubx config data - for pubx accuracies
                        g_rfcomm_mgr.add_send_buffer(fromHexString("B5 62 0A 04 00 00 0E 34"));  //poll ubx-mon-ver for hardware/firmware info of the receiver
                        g_rfcomm_mgr.add_send_buffer(fromHexString("B5 62 0A 28 00 00 32 A0"));  //poll ubx-mon-gnss default system-settings
                    } catch (Exception e) {
                        log(TAG, "m_ubx_send_enable_extra_used_packets exception: "+ getStackTraceString(e));
                    }
                }
            }.start();
        }
    }



    public void on_rfcomm_disconnected()
    {
        log(TAG, "on_rfcomm_disconnected() m_auto_reconnect: "+m_auto_reconnect);
        m_handler.post(
                new Runnable() {
                    @Override
                    public void run() {
                        toast("Disconnected...");
                        updateNotification("Disconnected...", "Target device: "+m_bdaddr, "");
                    }
                }
        );
        deactivate_mock_location();
        close();
    }

    public static HashMap<String, Object> jsonToMap(JSONObject jsonObj) throws Exception {
        HashMap<String, Object> map = new HashMap<>();

        // Get all keys of the JSONObject
        Iterator<String> keys = jsonObj.keys();

        // Iterate through keys and put key-value pairs into the HashMap
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = jsonObj.get(key);

            // If the value is a JSONObject, convert it recursively
            if (value instanceof JSONObject) {
                map.put(key, jsonToMap((JSONObject) value));  // Recursion for nested objects
            }
            // If the value is a JSONArray, convert it to a List<Object>
            else if (value instanceof JSONArray) {
                map.put(key, jsonToList((JSONArray) value));  // Convert JSONArray to List<Object>
            } else {
                map.put(key, value);  // Otherwise, put the value directly
            }
        }

        return map;
    }

    // Convert a JSONArray to a List<Object>
    public static List<Object> jsonToList(JSONArray array) throws Exception {
        List<Object> list = new ArrayList<>();

        // Iterate through the JSONArray
        for (int i = 0; i < array.length(); i++) {
            Object value = array.get(i);

            // If the value is a JSONObject, convert it to a Map
            if (value instanceof JSONObject) {
                list.add(jsonToMap((JSONObject) value));
            }
            // If the value is another JSONArray, convert it recursively
            else if (value instanceof JSONArray) {
                list.add(jsonToList((JSONArray) value));
            } else {
                list.add(value);  // Otherwise, add the value directly
            }
        }

        return list;
    }


    public static DateTimeFormatter sql_date_formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS");


    public static String convertUnixTimeStampToSQLDateTime(long unixTimeStampMillis) throws Exception {
        // Convert Unix timestamp to LocalDateTime in UTC without timezone or locale
        LocalDateTime dateTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(unixTimeStampMillis), ZoneOffset.UTC);

        // Format it as SQL datetime (yyyy-MM-dd HH:mm:ss.SSS) with milliseconds


        // Return formatted date time string
        return dateTime.format(sql_date_formatter);
    }


    @Override
    public void on_read_object(JSONObject object) {
        if (closing) {
            d(TAG, "on_read_object ignore as already closing");
            return;
        }

        if (object == null)
            return;
        if (m_ble_qstarz_mode) {
            /*
             {
             "fix_status":3,
             "fix_status_matched":"3D",
             "rcr":84,
             "millisecond":700,
             "latitude":6.41639016,
             "longitude":101.37057211,
             "timestamp_s":1726303552,
             "float_speed_kmh":0.2592799961566925,
             "float_height_m":27.68000030517578,
             "heading_degrees":100.06999969482422,
             "g_sensor_x":-0.17578125,
             "g_sensor_y":0.2578125,
             "g_sensor_z":0.93359375,
             "max_snr":22,
             "hdop":1.850000023841858,
             "vdop":0.9700000286102295,
             "satellite_count_view":20,
             "satellite_count_used":4,
             "fix_quality":1,
             "fix_quality_matched":"GPS fix (SPS)",
             "battery_percent":100,"dummy":0,
             "series_number":0,
             "gsv_fields":[{"prn":0,"elevation":8194,"azimuth":35,"snr":33},{"prn":0,"elevation":7168,"azimuth":39,"snr":98},{"prn":0,"elevation":7958,"azimuth":45,"snr":47}]}
* */
            try {
                //d(TAG, "on_read_object ondevicemessage start: "+object);
                if (object.getInt("fix_status") >= 3) {
                    //3D so fix is ok now - get lat lon to send mock location
                    double lat = new BigDecimal(object.getString("latitude")).doubleValue(); //handle old phone precision lost
                    double lon = new BigDecimal(object.getString("longitude")).doubleValue(); //handle old phone precision lost
                    //object.getDouble("latitude");
                    //object.getDouble("longitude");
                    double float_height_m = object.getDouble("float_height_m");
                    double heading_degrees = object.getDouble("heading_degrees");
                    double float_speed_kmh = object.getDouble("float_speed_kmh");
                    double hdop = object.getDouble("hdop");
                    double vdop = Double.NaN;
                    try{vdop = object.getDouble("vdop");}catch (Exception e){};
                    double accuracy = hdop * get_connected_device_CEP();
                    double vaccuracy = vdop * get_connected_device_CEP();
                    int satellite_count_used = object.getInt("satellite_count_used");
                    long new_ts = (object.getLong("timestamp_s")*1000L) + object.getLong("millisecond");
                    try {
                        String time_str = QstarzUtils.getQstarzDatetime(object.getLong("timestamp_s"), object.getLong("millisecond"));//convertUnixTimeStampToSQLDateTime(new_ts);
                        object.put("time", time_str);
                    } catch (Exception e) {};
                    //d(TAG, "time: "+time_str);
                    setMock(lat, lon, (float) accuracy, (float) vaccuracy, float_height_m, heading_degrees, (float) float_speed_kmh, false, satellite_count_used, hdop, "QSTARZ_BLE", new_ts);
                }
                HashMap<String, Object> param_map = m_gnss_parser.getM_parsed_params_hashmap();
                HashMap<String, Object> qstarz_param_map = jsonToMap(object);
                String talker = "QSTARZ";
                for (String key : qstarz_param_map.keySet()) {
                    Object value = qstarz_param_map.get(key);
                    m_gnss_parser.put_param(talker, key, value);
                }
                {
                    String ts = QstarzUtils.getQstarzDatetime((int) param_map.get("QSTARZ_timestamp_s"), (int) param_map.get("QSTARZ_millisecond"));
                    m_gnss_parser.put_param(talker, "timestamp", ts);
                }
                {
                    String rcr_logtype = QstarzUtils.getQstarzRCRLogType((int) param_map.get("QSTARZ_rcr"));
                    m_gnss_parser.put_param(talker, "rcr_logtype", rcr_logtype);
                }

                //log(TAG, "qstarz ble lat: " + param_map.get("lat"));
                //log(TAG, "qstarz ble lon: " + param_map.get("lon"));
                try {
                    if (m_activity_for_nmea_param_callbacks != null) {
                        m_activity_for_nmea_param_callbacks.onPositionUpdate((HashMap<String, Object>) param_map.clone());
                    }
                } catch (Exception e) {
                    log(TAG, "bluetooth_gnss_service call callback in m_activity_for_nmea_param_callbacks exception: " + getStackTraceString(e));
                }
                //d(TAG, "on_read_object ondevicemessage success");
            } catch (Exception e) {
                log(TAG, "WARNING: on_read_object m_ble_qstarz_mode exception: "+Log.getStackTraceString(e));
            }
        }
    }

    public void start_connecting_thread()
    {
        m_connecting_thread = new Thread() {
            public void run() {
                try {
                    log(TAG, "rfcomm connect to dev");
                    g_rfcomm_mgr.connect();
                } catch (final Exception e) {
                    m_handler.post(
                            new Runnable() {
                                @Override
                                public void run() {
                                    String emsg = "Connect failed: "+e.toString();
                                    toast(emsg);
                                    updateNotification("Connect failed: "+ getStackTraceString(e), "Target device: "+m_bdaddr, emsg);
                                }
                            }
                    );
                    log(TAG, "g_rfcomm_mgr connect exception: "+ getStackTraceString(e));
                }
            }
        };

        m_connecting_thread.start();
    }
    Uri log_file_uri = null;
    SimpleDateFormat log_name_sdf = new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US);
    SimpleDateFormat csv_sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US);
    public void log_bt_rx(byte[] read_buf)
    {
        if (read_buf == null || read_buf.length == 0)
            return;
        try {
            if (log_file_uri != null) {
                if (m_log_bt_rx_log_uri != null && (!m_log_bt_rx_log_uri.isEmpty()) && read_buf != null) {
                    if (m_log_bt_rx_fos != null) {
                        m_log_bt_rx_fos.write(read_buf);
                        log_bt_rx_bytes_written += read_buf.length;
                        //log(TAG, "log_bt_rx: written n bytes: "+read_buf.length);
                    }
                }
            }
        } catch (Throwable tr) {
            log(TAG, "log_bt_rx exception: "+ getStackTraceString(tr));
        }
    }

    public static void log(String msg)
    {
        log(TAG, msg);
    }

    public static void log(String tag, String msg)
    {
        d(tag, msg);
    }

    public static boolean test_can_create_file_in_chosen_folder(Context context, String log_uri)
    {
        try {
            if (log_uri.isEmpty()) {
                throw new Exception("folder not chosen yet - please tick enable logging in settings to choose");
            }
            return test_can_create_file(context, log_uri);
        } catch (Throwable tr) {
            String msg = "WARNING: test_can_create_file_in_chosen_folder failed exception: "+ getStackTraceString(tr);
            log(TAG, msg);
            return false;
        }
    }


    public static boolean test_can_create_file(Context context, String log_folder_uri_str)
    {
        try {
            DocumentFile df = create_new_file(context, log_folder_uri_str, "text/plain", "test_folder_access");
            if (df.exists()) {
                df.delete();
                return true;
            }
        } catch (Throwable tr) {
            String msg = "WARNING: test_can_create_file failed exception: "+ getStackTraceString(tr);
            log(TAG, msg);
            return false;
        }
        return false;
    }

    public static DocumentFile create_new_file(Context context, String log_folder_uri_str, String mime, String fname) throws Exception {
        if (log_folder_uri_str == null) {
            throw new Exception("no log folder set in settings");
        }
            Uri log_folder_uri = Uri.parse(log_folder_uri_str);
            //ref: https://stackoverflow.com/questions/61118918/create-new-file-in-the-directory-returned-by-intent-action-open-document-tree
            DocumentFile dd = DocumentFile.fromTreeUri(context, log_folder_uri);
            if (dd == null) {
                throw new Exception("Failed to access folder");
            }
            DocumentFile df = dd.createFile(mime, fname);
            if (df == null) {
                throw new Exception("Failed to create file in folder");
            }
            if (df.exists()) {
                df.delete();
            }
            df = dd.createFile(mime, fname);
            if (!df.exists()) {
                throw new Exception("Failed to create file in folder after delete of old file");
            }
            return df;
    }

    public OutputStream get_df_os(DocumentFile df) throws Exception {
        return getApplicationContext().getContentResolver().openOutputStream(df.getUri());
    }

    public void prepare_log_output_streams(String log_folder_uri_str) {
        try {
            if (log_folder_uri_str == null) {
                throw new Exception("no log folder set in settings");
            }
            Uri log_folder_uri = Uri.parse(log_folder_uri_str);
            //ref: https://stackoverflow.com/questions/61118918/create-new-file-in-the-directory-returned-by-intent-action-open-document-tree
            DocumentFile dd = DocumentFile.fromTreeUri(getApplicationContext(), log_folder_uri);
            if (dd == null) {
                throw new Exception("Failed to access folder");
            }

            DocumentFile df = create_new_file(getApplicationContext(), log_folder_uri_str, "text/plain", (log_name_sdf.format(new Date()) + "_rx_log.txt"));
            DocumentFile df_csv = create_new_file(getApplicationContext(), log_folder_uri_str, "text/csv", (log_name_sdf.format(new Date()) + "_location_log.csv"));
            DocumentFile lf = create_new_file(getApplicationContext(), log_folder_uri_str, "text/plain", (log_name_sdf.format(new Date()) + "_operations_log.txt"));
            if (df == null) {
                throw new Exception("Failed to create file in folder");
            }
            log_file_uri = df.getUri();
            log(TAG, "log_bt_rx: log_fp: " + df.getUri().toString());
            log_bt_rx_bytes_written = 0;
            m_log_bt_rx_fos = get_df_os(df);
            m_log_bt_rx_csv_fos = get_df_os(df_csv);
            m_log_operations_fos = get_df_os(lf);
            m_log_bt_rx_csv_fos.write("time,lat,lon,alt\n".getBytes());
            m_log_bt_rx_csv_fos.flush();
            log(TAG, "log_bt_rx: m_log_bt_rx_fos ready");
        } catch (Throwable tr) {
            String msg = "WARNING: Logging failed - pls re-tick 'Settings' > 'Enable logging' - error:\n"+ getStackTraceString(tr);
            toast(msg);
            log(TAG, msg);
        }
    }


    public void on_readline(byte[] readline)
    {
        try {
            //log(TAG, "rfcomm on_readline: "+new String(readline, "ascii"));
            log_bt_rx(readline);
            HashMap<String, Object> parsed_nmea = m_gnss_parser.parse(readline);            
            String nmea_name = "";
            if (parsed_nmea != null && parsed_nmea.containsKey("name")) {
                nmea_name = (String) parsed_nmea.get("name");
            }
            if (nmea_name.startsWith("GGA")) {
                if (m_all_ntrip_params_specified) {
                    start_ntrip_conn_if_specified_but_not_connected();
                }
                if (m_send_gga_to_ntrip && is_ntrip_connected()) {
                    log(TAG, "consider send gga to ntrip if not sent since millis: " + SEND_GGA_TO_NTRIP_EVERY_MILLIS);
                    long now = System.currentTimeMillis();
                    if (now >= m_last_ntrip_gga_send_ts) {
                        if (now - m_last_ntrip_gga_send_ts > SEND_GGA_TO_NTRIP_EVERY_MILLIS) {
                            m_last_ntrip_gga_send_ts = now;
                            String send_str = (parsed_nmea.get("contents")) + "\r\n";
                            log(TAG, "yes send to ntrip now: "+send_str);
                            m_ntrip_conn_mgr.send_buff_to_server(send_str.getBytes("ascii"));
                        }
                    } else {
                        m_last_ntrip_gga_send_ts = 0;
                    }
                }
            }
            if (parsed_nmea != null) {
                m_activity_for_nmea_param_callbacks.onDeviceMessage(gnss_sentence_parser.MessageType.NMEA, (HashMap<String, Object>) parsed_nmea.clone());
            }
        } catch (Exception e) {
            log(TAG, "bluetooth_gnss_service on_readline parse exception: "+ getStackTraceString(e));
        }
    }

    public void on_readline_stream_connected()
    {
        log(TAG, "on_readline_stream_connected()");
        m_handler.post(
                new Runnable() {
                    @Override
                    public void run() {
                        toast("Data stream connected...");
                        updateNotification("Connected...", "Target device: "+m_bdaddr, "");
                    }
                }
        );
    }

    public void on_readline_stream_closed()
    {
        log(TAG, "on_readline_stream_closed()");
        m_handler.post(
                new Runnable() {
                    @Override
                    public void run() {
                        toast("Data stream disconnected...");
                        updateNotification("Disconnected...", "Target device: "+m_bdaddr, "");
                    }
                }
        );
    }

    public void on_target_tcp_connected() {
        log(TAG, "on_target_tcp_connected()");
        m_last_ntrip_gga_send_ts = 0;
    }

    public void on_target_tcp_disconnected(){
        log(TAG, "on_target_tcp_disconnected()");
    }

    @Override
    public void onCreate() {
        log(TAG, "onCreate()");
        super.onCreate();
    }

    void start_foreground(String title, String text, String ticker)
    {
        log(TAG, "start_forgroud 0");
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            startForeground(1, getMyActivityNotification(title, text, ticker));
        } else {
            startForeground(1, getMyActivityNotification(title, text, ticker), FOREGROUND_SERVICE_TYPE_LOCATION);
        }
        log(TAG, "start_forgroud end");
    }

    String notification_channel_id = "BLUETOOTH_GNSS_CHANNEL_ID";
    String notification_name = "BLUETOOTH_GNSS";

    private Notification getMyActivityNotification(String title, String text, String ticker){

        Intent notificationIntent = new Intent(this.getApplicationContext(), m_target_activity_class);
        PendingIntent pendingIntent =
                PendingIntent.getActivity(this.getApplicationContext(), 0, notificationIntent, FLAG_IMMUTABLE);


        NotificationManager mNotificationManager =
                (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
         {
            NotificationChannel channel = new NotificationChannel(notification_channel_id,
                    notification_name,
                    NotificationManager.IMPORTANCE_DEFAULT);
            channel.setDescription("Bluetooth GNSS Status");
            mNotificationManager.createNotificationChannel(channel);
        }

        Notification notification = null;

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, notification_channel_id)
                .setSmallIcon(m_icon_id)
                .setContentTitle(title)
                .setContentText(text)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true);

        notification = builder.build();

        return notification;
    }

    private void updateNotification(String title, String text, String ticker) {

        if (ticker == null || ticker.length() == 0) {
            ticker = new Date().toString();
        }

        Notification notification = getMyActivityNotification(title, text, ticker);

        NotificationManager mNotificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        mNotificationManager.notify(1, notification);
    }

    public static boolean is_location_enabled(Context context)
    {
        log(TAG, "is_location_enabled() 0");
        LocationManager lm = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        boolean gps_enabled = false;
        try {
            gps_enabled = gps_enabled && lm.isProviderEnabled(GPS_PROVIDER);
        } catch(Exception e) {
            log(TAG, "check gps_enabled exception: "+ getStackTraceString(e));
        }
        return gps_enabled;
    }

    public static boolean is_mock_location_enabled(Context context, int app_uid, String app_id_string)
    {
        LocationManager locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        boolean mock_enabled = false;
        try {
            //log(TAG,"is_mock_location_enabled Build.VERSION.SDK_INT >= Build.VERSION_CODES.M");
            AppOpsManager opsManager = (AppOpsManager) context.getSystemService(Context.APP_OPS_SERVICE);
            mock_enabled = (opsManager.checkOp(AppOpsManager.OPSTR_MOCK_LOCATION, app_uid, app_id_string)== AppOpsManager.MODE_ALLOWED);
        } catch(Exception e) {
            if (e instanceof java.lang.SecurityException) {
                //no need to print - expected
            } else {
                log(TAG, "check mock_enabled exception: " + getStackTraceString(e));
            }
            mock_enabled = false;
        }
        //log(TAG,"is_mock_location_enabled ret "+mock_enabled);
        return mock_enabled;
    }

    /*final float[] gravity = new float[3];
    final float[] geomagnetic = new float[3];
    final float[] sensor_r = new float[9];
    final float[] orientation = new float[3];

    SensorEventListener sensorListener = new SensorEventListener() {
        @Override
        public void onSensorChanged(SensorEvent event) {
            if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
                System.arraycopy(event.values, 0, gravity, 0, event.values.length);
            } else if (event.sensor.getType() == Sensor.TYPE_MAGNETIC_FIELD) {
                System.arraycopy(event.values, 0, geomagnetic, 0, event.values.length);
            }

            if (SensorManager.getRotationMatrix(sensor_r, null, gravity, geomagnetic)) {
                SensorManager.getOrientation(sensor_r, orientation);
                float azimuthRad = orientation[0];
                float _azimuthDeg = (float) Math.toDegrees(azimuthRad);
                if (_azimuthDeg < 0) _azimuthDeg += 360;
                azimuthDeg = _azimuthDeg;
                //Log.d(TAG, "sensors got new azimuthDeg: "+azimuthDeg);
                azimuthDegTs = System.currentTimeMillis();
            }
        }

        @Override
        public void onAccuracyChanged(Sensor sensor, int accuracy) {
        }
    };
    float azimuthDeg = Float.NaN;
    long azimuthDegTs = 0L;
    SensorManager sensorManager;
    Sensor accel;
    Sensor magnet;

    boolean init_sensor_done = false;

    void init_sensors()
    {
        try {
            sensorManager = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
            accel = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
            magnet = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD);
            sensorManager.registerListener(sensorListener, accel, SensorManager.SENSOR_DELAY_UI);
            sensorManager.registerListener(sensorListener, magnet, SensorManager.SENSOR_DELAY_UI);
            init_sensor_done = true;
        } catch (Throwable tr) {
            Log.d(TAG, "WARNING: init_sensors exception: "+Log.getStackTraceString(tr));
        }
    }

    void close_sensors()
    {
        try {
            if (sensorManager != null && sensorListener != null) {
                sensorManager.unregisterListener(sensorListener);
            }
        } catch (Throwable tr) {}
        init_sensor_done = false;
    }
*/

    public static final String FUSED_PROVIDER = "fused";
    public static final String GPS_PROVIDER = "gps";
    public static final float DEFAULT_MOCK_ACCURACY = 5.0f;
    String[] providers_to_mock = new String[] {FUSED_PROVIDER, GPS_PROVIDER};

    private void setMock(double latitude, double longitude, float accuracy, float vaccuracy, double altitude, double bearing_degrees, float speed_m_s, boolean alt_is_elipsoidal, int n_sats, double hdop, String talker, long gnss_ts) {
        if (closing) {
            d(TAG, "setmock ignore as already closing");
            return;
        }

        if (Float.isNaN(accuracy)) {
            accuracy = DEFAULT_MOCK_ACCURACY;
        }

        //double sensor_azimuth = azimuthDeg;

        /*
        gpt:
        What Advanced Users Say

    "To make Google Maps work, I had to mock both GPS and fused providers, and make sure to match timestamps with System.currentTimeMillis()."

    "Setting speed and bearing carefully improved how Maps responds."

    "Don't set bearing when you're stationary or it'll mess up the arrow."
        * */

        long system_ts = System.currentTimeMillis();
        long system_ts_nanos = SystemClock.elapsedRealtimeNanos();
        //Log.d(TAG, "setMock gnss_ts: "+gnss_ts +" vs system_ts: "+system_ts+" = system_to_gnss_ts_diff: "+system_to_gnss_ts_diff);


        activate_mock_location(); //this will check a static flag and not re-activate if already active
        LocationManager locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        long mock_base_ts = (mock_location_timestamp_use_system_time? system_ts : gnss_ts);
        long mock_set_ts = mock_base_ts + ((long)(mock_timestamp_offset_secs*1000.0));
        m_gnss_parser.put_param("", "mock_location_system_ts", system_ts);
        m_gnss_parser.put_param("", "mock_location_gnss_ts", gnss_ts);
        m_gnss_parser.put_param("", "mock_location_timestamp_use_system_time", mock_location_timestamp_use_system_time);
        m_gnss_parser.put_param("", "mock_location_base_ts", mock_base_ts);
        m_gnss_parser.put_param("", "mock_timestamp_offset_secs", mock_timestamp_offset_secs);
        m_gnss_parser.put_param("", "mock_location_set_ts", mock_set_ts);

        m_gnss_parser.put_param("", "mock_location_base_lat", latitude);
        m_gnss_parser.put_param("", "mock_location_base_lon", longitude);
        m_gnss_parser.put_param("", "mock_location_base_alt", altitude);
        m_gnss_parser.put_param("", "mock_lat_offset_meters", mock_lat_offset_meters);
        m_gnss_parser.put_param("", "mock_lon_offset_meters", mock_lon_offset_meters);
        m_gnss_parser.put_param("", "mock_alt_offset_meters", mock_alt_offset_meters);
        latitude += mock_lat_offset_meters*latlonMetersToDegMultiplier;
        longitude += mock_lon_offset_meters*latlonMetersToDegMultiplier;
        altitude += mock_alt_offset_meters;
        m_gnss_parser.put_param("", "mock_location_set_lat", latitude);
        m_gnss_parser.put_param("", "mock_location_set_lon", longitude);
        m_gnss_parser.put_param("", "mock_location_set_accuracy", accuracy);
        m_gnss_parser.put_param("", "mock_location_set_vaccuracy", vaccuracy);
        m_gnss_parser.put_param("", "mock_location_set_alt", altitude);
        m_gnss_parser.put_param("", "mock_location_gnss_bearing", bearing_degrees);
        //m_gnss_parser.put_param("", "mock_location_sensor_bearing", sensor_azimuth);
        m_gnss_parser.put_param("", "mock_location_set_bearing", null);
        /// ////// modern way
        double mock_bearing = Double.NaN;

        for (String provider : providers_to_mock) {
            try {
                //Log.d(TAG, "setmock to provider: " + provider + " START");

                Location newLocation = new Location(provider);
                newLocation.setTime(mock_set_ts);

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    newLocation.setMock(true);
                }

                newLocation.setLatitude(latitude);
                newLocation.setLongitude(longitude);
                newLocation.setAccuracy(accuracy);
                newLocation.setAltitude(altitude);
                if (!Float.isNaN(vaccuracy)) {
                    newLocation.setVerticalAccuracyMeters(vaccuracy);
                }

                if (!Double.isNaN(bearing_degrees) && (!Float.isNaN(speed_m_s) && speed_m_s > 1.5)) {
                    mock_bearing = bearing_degrees;
                } else {
                    /* arrow heading seems to work on gmaps if i disable: if (!Float.isNaN(speed_m_s) && speed_m_s <= 1.5) {
                        mock_bearing = sensor_azimuth;
                    }*/
                }
                if (!Double.isNaN(mock_bearing)) {
                    newLocation.setBearing((float) mock_bearing);
                    m_gnss_parser.put_param("", "mock_location_set_bearing", mock_bearing);
                }

                newLocation.setSpeed(speed_m_s);

                if (n_sats > 0) {
                    Bundle bundle = new Bundle();
                    bundle.putInt("satellites", n_sats);
                    newLocation.setExtras(bundle);
                }


                newLocation.setElapsedRealtimeNanos(system_ts_nanos);

                if (!TextUtils.equals(provider, FUSED_PROVIDER)) {
                    locationManager.setTestProviderLocation(provider, newLocation);
                } else  {
                    //FUSED_PROVIDER
                    try {
                        if (fusedClient == null) {
                            fusedClient = LocationServices.getFusedLocationProviderClient(this);
                            fusedClient.setMockMode(true);
                        }
                        fusedClient.setMockLocation(newLocation);
                        //Log.d(TAG, "fusedClient mock done for provider: "+provider);
                    } catch (Throwable e) {
                        Log.d(TAG, "WARNING: fusedClient mock failed: " + Log.getStackTraceString(e));
                    }
                }

            } catch (Throwable tr) {
                if (("" + tr).contains("unknown")) {
                    // ok
                } else {
                    log("WARNING: setTestProviderLocation for provider: " + provider + " exception: " + tr);
                }
            }
        }
        /// /////////////////


        long intent_pos_broadcast_ts = System.currentTimeMillis();
        try {
            Intent intent = new Intent();
            intent.setAction(POSITION_UPDATE_INTENT_ACTION);
            JSONObject jo = new JSONObject();
            try {jo.put("java_ts", intent_pos_broadcast_ts);} catch (Exception e) {}
            try {jo.put("system_ts", intent_pos_broadcast_ts);} catch (Exception e) {}
            try {jo.put("gnss_ts", gnss_ts);} catch (Exception e) {}
            try {jo.put("latitude", latitude);} catch (Exception e) {}
            try {jo.put("longitude", longitude);} catch (Exception e) {}
            try {jo.put("altitude", altitude);} catch (Exception e) {}
            try {jo.put("accuracy", accuracy);} catch (Exception e) {}
            try {jo.put("bearing", mock_bearing);} catch (Exception e) {}
            try {jo.put("speed_m_s", speed_m_s);} catch (Exception e) {}
            try {jo.put("n_sats", n_sats);} catch (Exception e) {}
            intent.putExtra(INTENT_EXTRA_DATA_JSON_KEY, jo.toString());
            getApplicationContext().sendBroadcast(intent);
        } catch (Throwable tr) {
            log(TAG, "WARNING: broadcast position intent failed exception: "+ getStackTraceString(tr));
        }
        m_gnss_parser.put_param("", "intent_pos_broadcast_ts", intent_pos_broadcast_ts);

        //////////////hooks
        m_gnss_parser.put_param("", "hdop", hdop);
        m_gnss_parser.put_param("", "location_from_talker", talker);
        m_gnss_parser.put_param("", "lat", latitude);
        m_gnss_parser.put_param("", "lon", longitude);
        m_gnss_parser.put_param("", "alt", altitude);
        m_gnss_parser.put_param("", "alt_type", alt_is_elipsoidal?"ellipsoidal":"orthometric");
        m_gnss_parser.put_param("", "bearing_degrees", bearing_degrees);
        //m_gnss_parser.put_param("", "sensor_azimuth", sensor_azimuth);
        m_gnss_parser.put_param("", "speed_m_s", (double) speed_m_s);
        double speed_kmh = speed_m_s * 3.6;
        double speed_mph = speed_m_s * 2.23694;
        m_gnss_parser.put_param("", "speed_kmh", speed_kmh);
        m_gnss_parser.put_param("", "speed_mph", speed_mph);
        m_gnss_parser.put_param("", "n_sats", n_sats);
        m_gnss_parser.put_param("", "accuracy", accuracy);

        //intent_pos_broadcast_ts
        if (log_file_uri != null) {
            m_gnss_parser.put_param("", "logfile_uri", log_file_uri.toString());
            log(TAG, "log_file_uri.toString() "+log_file_uri.toString());
            String ls = log_file_uri.getLastPathSegment();
            if (ls.contains("/")) {
                String[] parts = ls.split("/");
                if (parts.length > 1) {
                    m_gnss_parser.put_param("", "logfile_folder", parts[0]);
                    m_gnss_parser.put_param("", "logfile_name", parts[1]);
                }
            } else {
                log(TAG, "ls: "+log_file_uri.toString());
                m_gnss_parser.put_param("", "logfile_folder", log_file_uri.toString());
                m_gnss_parser.put_param("", "logfile_name", ls);
            }
            m_gnss_parser.put_param("", "logfile_n_bytes", log_bt_rx_bytes_written);
            m_gnss_parser.put_param("", "logfile_size_mb", ((double)log_bt_rx_bytes_written)/1_000_000.0);
        }
        if (m_log_bt_rx_csv_fos != null) {
            try {
                String line = csv_sdf.format(mock_set_ts)+","+latitude+","+longitude+","+altitude+"\n";
                m_log_bt_rx_csv_fos.write(line.getBytes());
                m_log_bt_rx_csv_fos.flush();
            } catch (Exception e) {
                log(TAG, "WARNING: write csv exception: "+ getStackTraceString(e));
            }
        }
        if (m_log_bt_rx_fos != null) {
            try {
                m_log_bt_rx_fos.flush();
            } catch (Exception e) {
                log(TAG, "WARNING: write bt rx file exceptionn: "+Log.getStackTraceString(e));
            }
        }
    }

    private void deactivate_mock_location() {
        log(TAG, "deactivate_mock_location0");
        //close_sensors();
        if (fusedClient != null) {
            try {
                fusedClient.setMockMode(false);
            } catch (Throwable tr) {
                Log.d(TAG, "WARNING: deactivate_mock_location() fusedClient.setMockMode(false) exception: "+Log.getStackTraceString(tr));
            }
            fusedClient = null;
        }
        if (is_mock_location_active()) {
            log(TAG, "deactivate_mock_location1");
            try {
                LocationManager locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);

                for (String provider : providers_to_mock) {
                    try {
                        if (
                                TextUtils.equals(provider, FUSED_PROVIDER)) {
                            continue;
                        }
                        //Log.d(TAG, "deactivate_mock_location() provider: " + provider+" START");
                        // Remove the test provider safely
                        log(TAG, "deactivate_mock_location set enabled false");
                        locationManager.setTestProviderEnabled(provider, false);
                        locationManager.removeTestProvider(provider);
                        //Log.d(TAG, "deactivate_mock_location() provider: " + provider+" SUCCESS");
                    } catch (Throwable tr) {
                        //Log.d(TAG, "deactivate_mock_location() provider: " + provider+" FAILED exception: "+Log.getStackTraceString(tr));
                        if ((""+tr).contains("unknown")) {
                            //ok
                        } else {
                            log("WARNING: setTestProviderEnabled for provider: " + provider + " exception: " + tr);
                        }
                    }
                }

                g_mock_location_active = false;
                m_handler.post(
                        new Runnable() {
                            @Override
                            public void run() {
                                log(TAG, "deactivate_mock_location toast");
                                toast("Deactivated Mock location provider...");
                                updateNotification("Bluetooth GNSS - Not active...", "Deactivated", "");
                            }
                        }
                );
                log(TAG, "deactivate_mock_location success");
            } catch (Exception e) {
                log(TAG, "deactivate_mock_location exception: " + getStackTraceString(e));
            }
        }
        log(TAG, "deactivate_mock_location return");
    }

    //TODO: tell user must set to none if want to use app again
    /*public static boolean isDeviceUsingMockProvider(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return Settings.Secure.getString(
                    context.getContentResolver(),
                    Settings.Secure.MOCK_LOCATION_APP
            ) != null;
        } else {
            return !Settings.Secure.getString(
                    context.getContentResolver(),
                    Settings.Secure.ALLOW_MOCK_LOCATION
            ).equals("0");
        }
    }*/

    private void activate_mock_location() {
        if (closing) {
            d(TAG, "activate_mock_location ignore as already closing");
            return;
        }
        //init_sensors();
        if (!is_mock_location_active()) {
            try {
                log(TAG, "activate_mock_location 0");
                LocationManager locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
                for (String provider : providers_to_mock) {
                    try {
                        if (TextUtils.equals(provider, FUSED_PROVIDER)) {
                            continue;
                        }
                        //Log.d(TAG, "activate_mock_location() provider: " + provider+" START");
                        LocationProvider providerObj = locationManager.getProvider(provider);
                        locationManager.addTestProvider(
                                provider,
                                providerObj.requiresNetwork(),
                                providerObj.requiresSatellite(),
                                providerObj.requiresCell(),
                                providerObj.hasMonetaryCost(),
                                providerObj.supportsAltitude(),
                                providerObj.supportsSpeed(),
                                providerObj.supportsBearing(),
                                providerObj.getPowerRequirement(),
                                providerObj.getAccuracy()
                        );
                        locationManager.setTestProviderEnabled(provider, true);
                        //Log.d(TAG, "activate_mock_location() provider: " + provider+" SUCCESS");
                    } catch (Throwable tr) {
                        //Log.d(TAG, "activate_mock_location() provider: " + provider+" FAILED exception: "+Log.getStackTraceString(tr));
                        if ((""+tr).contains("unknown")) {
                            //ok
                        } else {
                            log("WARNING: setTestProviderEnabled for provider: " + provider + " exception: " + tr);
                        }
                    }
                }
                m_handler.post(
                        new Runnable() {
                            @Override
                            public void run() {
                                log(TAG, "activate_mock_location 1");
                                toast("Activated Mock location provider...");
                                updateNotification("Bluetooth GNSS - Active...", "Connected to: "+get_connected_device_alias(), "");
                            }
                        }
                );
                g_mock_location_active = true;
                log(TAG, "activate_mock_location 2");
            } catch (Exception e) {
                String st = getStackTraceString(e);
                if (st.contains("already exists")) {
                    log(TAG, "activate_mock_location exception but already exits so set success flag");
                    g_mock_location_active = true;
                    m_handler.post(
                            new Runnable() {
                                @Override
                                public void run() {
                                    toast("Activated Mock location provider...");
                                    updateNotification("Bluetooth GNSS - Active...", "Connected to: "+get_connected_device_alias(), "");
                                }
                            }
                    );
                }
                log(TAG, "activate_mock_location exception: " + st);

            }
            log(TAG, "activate_mock_location done");
        }
    }

    static boolean g_mock_location_active = false;

    private boolean is_mock_location_active() {
        return g_mock_location_active;
    }

    public String get_connected_device_alias()
    {
        return ""+m_bdaddr;
    }

    // Binder given to clients
    private final IBinder m_binder = new LocalBinder();
    gnss_sentence_parser.gnss_parser_callbacks m_activity_for_nmea_param_callbacks;

    public void set_callback(gnss_sentence_parser.gnss_parser_callbacks cb)
    {
        m_activity_for_nmea_param_callbacks = cb;
    }


    public final String[] GGA_MESSAGE_TALKER_TRY_LIST = {
            "GN",
            "GA",
            "GB",
            "GP",
            "GL",
            "GQ"
    };

    double m_device_cep = 5.0;
    double DEFAULT_UBLOX_M8030_CEP = 2.0;
    double DEFAULT_UBLOX_ZED_F9P_CEP = 1.5;

    public double get_connected_device_CEP()
    {
        return m_device_cep;
    }

    @Override
    public void onPositionUpdate(HashMap<String, Object> params_map) {

        if (closing) {
            d(TAG, "onPositionUpdate ignore as already closing");
            return;
        }

        //log(TAG, "service: onPositionUpdate() start");
        try {
            Intent intent = new Intent();
            intent.setAction(PARSED_NMEA_UPDATE_INTENT_ACTION);
            JSONObject jo = new JSONObject();
            for (String k :params_map.keySet()) {
                try {
                    jo.put(k, params_map.get(k));
                } catch (Exception e) {}
            }
            intent.putExtra(INTENT_EXTRA_DATA_JSON_KEY, jo.toString());
            getApplicationContext().sendBroadcast(intent);
        } catch (Throwable tr) {
            log(TAG, "WARNING: broadcast position intent failed exception: "+ getStackTraceString(tr));
        }
        //try set_mock
        double lat = Double.NaN, lon = Double.NaN, alt = Double.NaN, hdop = Double.NaN, vdop = Double.NaN, speed = 0.0, bearing = Double.NaN, accuracy = Double.NaN;
        int n_sats = 0;
        for (String talker : GGA_MESSAGE_TALKER_TRY_LIST) {

            try {
                if (params_map.containsKey(talker+"_lat_ts")) {
                    long new_ts = (long) params_map.get(talker+"_rmc_ts");
                    if (new_ts > 0) {
                        lat = (double) params_map.get(talker+"_lat");
                        lon = (double) params_map.get(talker+"_lon");
                        String ellips_height_key = talker+"_ellipsoidal_height";
                        boolean alt_is_ellipsoidal = false;
                        if (params_map.containsKey(ellips_height_key)) {
                            alt_is_ellipsoidal = true;
                            alt = (double) params_map.get(ellips_height_key);
                            //log(TAG, "ellips_height_key valid");
                        } else {
                            alt = (double) params_map.get(talker+"_alt");
                            //log(TAG, "ellips_height_key not valid");
                        }

                        for (String sk : SATS_USED_KEYS) {
                            if (params_map.containsKey(sk)) {
                                Object val = params_map.get(sk);
                                if (val != null && val instanceof Integer) {
                                    n_sats += (Integer) val;
                                }
                            }
                        }
                        hdop = (double) params_map.get(talker+"_hdop");
                        speed = (double) params_map.get(talker+"_speed"); //Speed in knots (nautical miles per hour).
                        try {
                            vdop = (double) params_map.get("ANY_gsa_vdop");
                        } catch (Exception e) {}
                        speed = speed * 0.514444; //convert to m/s
                        try {
                            Object course = null;
                            if (params_map.containsKey(talker+"_true_course")) {  // value from VTG
                                course = params_map.get(talker+"_true_course");
                            } else if (params_map.containsKey(talker+"_course")) {  // value from RMC (RMC course = VTG true course)
                                course = params_map.get(talker+"_course");
                            }
                            //log(TAG, "course: "+course);
                            if (course != null) {
                                bearing = (double) course;
                            }
                        } catch (Exception e) {
                            log(TAG, "get course failed exception: "+ getStackTraceString(e));
                        }
                        if (params_map.containsKey("UBX_POSITION_hAcc")) {
                            try {
                                accuracy = Double.parseDouble((String) params_map.get("UBX_POSITION_hAcc"));
                            } catch (Exception e) {}
                        }
                        double vaccuracy = Double.NaN;
                        if (params_map.containsKey("UBX_POSITION_vAcc")) {
                            try {
                                vaccuracy = Double.parseDouble((String) params_map.get("UBX_POSITION_vAcc"));
                            } catch (Exception e) {}
                        }

                        //if not ubx or ubx conv failed...
                        if (Double.isNaN(accuracy)) {
                            accuracy = hdop * get_connected_device_CEP();
                        }
                        if (Double.isNaN(vaccuracy)) {
                            vaccuracy = vdop * get_connected_device_CEP();
                        }
                        setMock(lat, lon, (float) accuracy, (float) vaccuracy, alt, bearing, (float) speed, alt_is_ellipsoidal, n_sats, hdop, talker, new_ts);
                        break;
                    } else {
                        //omit as same ts as last
                    }
                }
            } catch (Exception e) {
                log(TAG, "bluetooth_gnss_service on_updated_nmea_params talker: "+talker+" exception: "+ getStackTraceString(e));
            }
        }

        //log(TAG, "service: on_updated_nmea_params() act");

        //report params to activity
        try {
            if (m_activity_for_nmea_param_callbacks != null) {
                m_activity_for_nmea_param_callbacks.onPositionUpdate((HashMap<String, Object>) params_map.clone());
            }
        } catch (Exception e) {
            log(TAG, "bluetooth_gnss_service call callback in m_activity_for_nmea_param_callbacks exception: "+ getStackTraceString(e));
        }
    }

    @Override
    public void onDeviceMessage(gnss_sentence_parser.MessageType messageType, HashMap<String, Object> message_map) {

    }

    public int get_ntrip_cb_count()
    {
        return m_ntrip_cb_count;
    }

    @Override
    public void onLog(Date d, String livel, String tag, String msg) {
        /*HashMap<String, Object> ret = new HashMap<>();
        ret.put("tx", false);
        ret.put("name", tag);
        ret.put("contents", msg);
        m_activity_for_nmea_param_callbacks.onDeviceMessage(gnss_sentence_parser.MessageType.App, ret);*/
    }

    /**
     * Class used for the client Binder.  Because we know this service always
     * runs in the same process as its clients, we don't need to deal with IPC.
     */
    public class LocalBinder extends Binder {
        public bluetooth_gnss_service getService() {
            // Return this instance of LocalService so clients can call public methods
            return bluetooth_gnss_service.this;
        }
    }

    boolean m_is_bound = false;

    @Override
    public boolean onUnbind(Intent intent) {
        m_is_bound = false;
        return super.onUnbind(intent);
    }

    @Override
    public IBinder onBind(Intent intent) {
        m_is_bound = true;
        log(TAG, "onBind()");
        return m_binder;
    }

    @Override
    public void onDestroy() {
        log(TAG, "onDestroy()");
        boolean was_connected = close();
        stop_auto_reconnect_thread();
        toast("Stopped Bluetooth GNSS Service...");
    }
}
