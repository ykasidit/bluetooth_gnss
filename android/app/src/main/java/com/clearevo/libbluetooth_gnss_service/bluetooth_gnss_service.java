package com.clearevo.libbluetooth_gnss_service;


import static android.app.PendingIntent.FLAG_IMMUTABLE;
import static android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.AppOpsManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.location.provider.ProviderProperties;
import android.net.Uri;
import android.os.Binder;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.ParcelUuid;



import android.widget.Toast;
import android.location.LocationManager;
import android.location.LocationProvider;
import android.os.Build;
import android.os.SystemClock;
import android.location.Location;

import androidx.core.app.NotificationCompat;
import androidx.documentfile.provider.DocumentFile;

import java.io.File;
import java.io.OutputStream;
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
import java.util.UUID;

import static com.clearevo.bluetooth_gnss.MainActivity.get_bd_map;
import static com.clearevo.libbluetooth_gnss_service.Log.*;
import static com.clearevo.libbluetooth_gnss_service.Log.m_log_operations_fos;
import static com.clearevo.libbluetooth_gnss_service.gnss_sentence_parser.fromHexString;
import static com.clearevo.libbluetooth_gnss_service.gnss_sentence_parser.toHexString;


import com.clearevo.bluetooth_gnss.MainActivity;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

//import com.flutter_rust_bridge.rust_lib_bluetooth_gnss.BuildConfig; //test that it can access



public class bluetooth_gnss_service extends Service implements rfcomm_conn_callbacks, gnss_sentence_parser.gnss_parser_callbacks, ntrip_conn_callbacks, LogObserver {

    static {
        System.loadLibrary("rust_lib_bluetooth_gnss");
    }

    static final String TAG = "btgnss_service";
    static final long BLE_GAP_SCAN_LOOP_DURAITON_MILLIS = 3000;
    String ECODROIDGPS_BROADCAST_MODE = "ECODROIDGPS_BROADCAST";
    public static final String BLE_GAP_SCAN_MODE = "ble_gap_scan_mode";
    public static final UUID eddystone_service_uuid = UUID.fromString("0000feaa-0000-1000-8000-00805f9b34fb");  //https://proandroiddev.com/scanning-google-eddystone-in-android-application-cf181e0a8648
    public static final UUID nordic_uart_service_uuid = UUID.fromString("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
    public static final UUID nordic_chrc_rx_uuid = UUID.fromString("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
    public static final UUID nordic_chrc_tx_uuid = UUID.fromString("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
    public static final UUID qstarz_chrc_tx_uuid = UUID.fromString("6E400004-B5A3-F393-E0A9-E50E24DCCA9E");
    public static final long BLE_GAP_SCAN_MODE_SETMOCK_INTERVAL = 1000;
    String[] SATS_USED_KEYS = new String[]{"GP_n_sats_used", "GL_n_sats_used", "GA_n_sats_used", "GB_n_sats_used", "GQ_n_sats_used"};


    public long m_last_BLE_GAP_SCAN_MODE_SETMOCK_ts = 0;
    public String m_last_BLE_GAP_DEV_NAME = "";

    rfcomm_conn_mgr g_rfcomm_mgr = null;
    ntrip_conn_mgr m_ntrip_conn_mgr = null;
    private gnss_sentence_parser m_gnss_parser = new gnss_sentence_parser();

    final String EDG_DEVICE_PREFIX = "EcoDroidGPS";
    public static final String BROADCAST_ACTION_NMEA = "com.clearevo.bluetooth_gnss.NMEA";
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
    Intent m_start_intent;

    boolean m_ubx_mode = true;
    boolean m_ubx_send_enable_extra_used_packets = true;
    boolean m_ubx_send_disable_extra_used_packets = false;
    boolean m_send_gga_to_ntrip = true;
    boolean m_all_ntrip_params_specified = false;
    long m_last_ntrip_gga_send_ts = 0;
    public static final long SEND_GGA_TO_NTRIP_EVERY_MILLIS = 29 * 1000;
    public static final String[] REQUIRED_INTENT_EXTRA_PARAM_KEYS = {"ntrip_host", "ntrip_port", "ntrip_mountpoint", "ntrip_user", "ntrip_pass"};
    String m_log_bt_rx_log_uri = "";
    boolean m_disable_ntrip = false;
    boolean m_ble_gap_scan_mode = false;
    boolean m_ble_qstarz_mode = false;
    OutputStream m_log_bt_rx_fos = null;
    OutputStream m_log_bt_rx_csv_fos = null;
    long log_bt_rx_bytes_written = 0;
    public static bluetooth_gnss_service curInstance = null;


    public static final String ble_uart_mode = "ble_uart_mode";
    public static final String ble_qstarz_mode = "ble_qstarz_mode";

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // If we get killed, after returning from here, restart
        log(TAG, "onStartCommand");
        Log.logObserver = this;
        closing = false;

        curInstance = this;

        if (intent != null) {
            try {

                m_ble_gap_scan_mode = intent.getBooleanExtra(BLE_GAP_SCAN_MODE, false);
                m_ble_qstarz_mode = intent.getBooleanExtra(ble_qstarz_mode, false);

                {

                    m_bdaddr = intent.getStringExtra("bdaddr");
                    m_secure_rfcomm = intent.getBooleanExtra("secure", true);
                    m_auto_reconnect = intent.getBooleanExtra("reconnect", false);

                    m_log_bt_rx_log_uri = intent.getStringExtra("log_bt_rx_log_uri");
                    m_disable_ntrip = intent.getBooleanExtra("disable_ntrip", false);
                    log(TAG, "m_secure_rfcomm: " + m_secure_rfcomm);
                    log(TAG, "m_log_bt_rx_log_uri: " + m_log_bt_rx_log_uri);
                    log(TAG, "m_disable_ntrip: " + m_disable_ntrip);
                    String cn = intent.getStringExtra("activity_class_name");
                    m_start_intent = intent;
                    if (cn == null) {
                        throw new Exception("activity_class_name not specified");
                    }
                    m_target_activity_class = Class.forName(cn);
                    log(TAG, "m_target_activity_class: " + m_target_activity_class.getCanonicalName());
                    if (!intent.hasExtra("activity_icon_id")) {
                        throw new Exception("activity_icon_id not specified");
                    }
                    m_icon_id = intent.getIntExtra("activity_icon_id", 0);

                    if (m_log_bt_rx_log_uri != null && (!m_log_bt_rx_log_uri.isEmpty())) {
                        String log_uri = m_log_bt_rx_log_uri;
                        if (!log_uri.isEmpty()) {
                            curInstance.prepare_log_output_streams(log_uri);
                        }
                    }

                    if (m_auto_reconnect) {
                        start_auto_reconnect_thread();
                    } else {
                        connect();
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

    void connect() {
        if (m_ble_gap_scan_mode) {
            log(TAG, "onStartCommand pre call start_forground m_ble_gap_scan_mode " + m_ble_gap_scan_mode);
            start_foreground("Scanning GPS broadcasts...", "", "");
            log(TAG, "onStartCommand post call start_forground m_ble_gap_scan_mode " + m_ble_gap_scan_mode);
            handle_ble_gap_scan_enable_changed();
        } else {
            if (m_bdaddr == null) {
                String msg = "bluetooth_gnss_service: startservice: Target Bluetooth device not specifed - cannot start...";
                log(TAG, msg);
                toast(msg);
            } else {
                log(TAG, "onStartCommand got bdaddr");
                int start_ret = connect(m_bdaddr, m_secure_rfcomm, getApplicationContext());
                if (start_ret == 0) {
                    start_foreground("Connecting...", "target device: " + m_bdaddr, "");
                }
                m_all_ntrip_params_specified = true;
                for (String key : REQUIRED_INTENT_EXTRA_PARAM_KEYS) {
                    if (m_start_intent.getStringExtra(key) == null || m_start_intent.getStringExtra(key).length() == 0) {
                        log(TAG, "key: " + key + "got null or empty string so m_all_ntrip_params_specified false");
                        m_all_ntrip_params_specified = false;
                        break;
                    }
                }
                log(TAG, "m_all_ntrip_params_specified: " + m_all_ntrip_params_specified);
                //ntrip connection would start after we get next gga bashed on this m_all_ntrip_params_specified flag
            }
        }
    }

    Thread ble_gap_scan_thread = null;

    public boolean is_ble_gap_scan_thread_running() {
        return ble_gap_scan_thread != null && ble_gap_scan_thread.isAlive();
    }

    //credit to https://github.com/joelwass/Android-BLE-Scan-Example/blob/master/app/src/main/java/com/example/joelwasserman/androidbletutorial/MainActivity.java
    private ScanCallback leScanCallback = new ScanCallback() {

        @SuppressLint("MissingPermission")
        //we already have permissions if we have the scan result called back
        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            super.onScanResult(callbackType, result);
            if (result == null) {
                log(TAG, "WARNING: onScanResult got null result");
                return;
            }
            log(TAG, "lescancallback onScanResult Device Name: " + result.getDevice().getName() + " rssi: " + result.getRssi());
            if (m_ble_gap_scan_mode) {
                byte[] scan_record_bytes = null;
                ScanRecord scanRecord = result.getScanRecord();
                scan_record_bytes = scanRecord.getBytes();
                if (scan_record_bytes == null) {
                    scan_record_bytes = new byte[0];
                }
                log(TAG, "onScanResult Device Name: " + result.getDevice().getName() + " rssi: " + result.getRssi() + " scanrecord bytes: " + toHexString(scan_record_bytes));
                //ex: 02 01 1A 04 09 45 44 47 03 03 AA FE 12 16 AA FE 30 00 E1 6A 6D FD 03 10 9B 91 3C 38 50 32 28 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                parse_scan_record_bytes_and_set_location(scan_record_bytes);
                m_last_BLE_GAP_DEV_NAME = result.getDevice().getName();
            }
        }
    };




    public void parse_scan_record_bytes_and_set_location(byte[] gap_buffer) {

        if (closing) {
            d(TAG, "parse_scan_record_bytes_and_set_location ignore as already closing");
            return;
        }

        long now = System.currentTimeMillis();

        //handle system time change
        if (m_last_BLE_GAP_SCAN_MODE_SETMOCK_ts != 0) {
            if (now < m_last_BLE_GAP_SCAN_MODE_SETMOCK_ts || now > (m_last_BLE_GAP_SCAN_MODE_SETMOCK_ts + 2 * BLE_GAP_SCAN_MODE_SETMOCK_INTERVAL)) {
                m_last_BLE_GAP_SCAN_MODE_SETMOCK_ts = 0;
            }
        }

        if (now - m_last_BLE_GAP_SCAN_MODE_SETMOCK_ts > BLE_GAP_SCAN_MODE_SETMOCK_INTERVAL) {
            m_last_BLE_GAP_SCAN_MODE_SETMOCK_ts = now; //ok
        } else {
            return; //dont parse/announce locaiton yet
        }
        try {
            ecodroidgps_gap_buffer_parser.ecodroidgps_broadcasted_location loc = ecodroidgps_gap_buffer_parser.parse(gap_buffer);
            log(TAG, "ECODROIDGPS_BROADCAST_MODE got broadcast: lat: " + loc.lat + " lon: " + loc.lon + " timestamp: " + loc.timestamp);

            int n_sats = 0;
            double lat = loc.lat, lon = loc.lon, alt = 0.0, hdop = 0.0, speed = 0.0, bearing = 0.0 / 0.0;
            double accuracy = hdop * get_connected_device_CEP();
            m_gnss_parser.put_param("GN", "time", loc.timestamp_str);
            setMock(lat, lon, alt, (float) accuracy, (float) bearing, (float) speed, false, n_sats, hdop, "GN", loc.timestamp);

            HashMap<String, Object> param_map = m_gnss_parser.getM_parsed_params_hashmap();
            log(TAG, "ble gap lat: " + param_map.get("lat_double_07_str"));
            log(TAG, "ble gap lon: " + param_map.get("lon_double_07_str"));
            try {
                if (m_activity_for_nmea_param_callbacks != null) {
                    m_activity_for_nmea_param_callbacks.onPositionUpdate(param_map);
                }
            } catch (Exception e) {
                log(TAG, "bluetooth_gnss_service call callback in m_activity_for_nmea_param_callbacks exception: " + getStackTraceString(e));
            }

        } catch (Throwable tr) {
            log(TAG, "parse_scan_record_bytes_and_set_location exception: " + getStackTraceString(tr));
        }
    }

    public void handle_ble_gap_scan_enable_changed() {
        log(TAG, "handle_ble_gap_scan_enable_changed() m_ble_gap_scan_mode " + m_ble_gap_scan_mode);
        if (m_ble_gap_scan_mode || m_ble_qstarz_mode) {
            if (is_ble_gap_scan_thread_running()) {
                log(TAG, "handle_ble_gap_scan_enable_changed() m_ble_gap_scan_mode " + m_ble_gap_scan_mode + " already running so omit");
            } else {
                ble_gap_scan_thread = new Thread() {
                    public void run() {
                        log(TAG, "ble_gap_scan_thread START");
                        BluetoothLeScanner btLeScanner = null;
                        boolean scan_stopped = false;
                        try {

                            //credit to https://github.com/joelwass/Android-BLE-Scan-Example/blob/master/app/src/main/java/com/example/joelwasserman/androidbletutorial/MainActivity.java
                            BluetoothManager btManager = (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
                            BluetoothAdapter btAdapter = btManager.getAdapter();
                            List<ScanFilter> filters = new ArrayList<>();

                            if (m_ble_gap_scan_mode) {
                                filters.add(
                                        new ScanFilter.Builder()
                                                .setServiceUuid(new ParcelUuid(eddystone_service_uuid))
                                                .build());
                                ScanSettings settings = new ScanSettings.Builder()
                                        .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                                        .build();

                                btLeScanner = btAdapter.getBluetoothLeScanner();

                                while (ble_gap_scan_thread == this) {
                                    log(TAG, "btLeScanner.startScan(leScanCallback); START");
                                    btLeScanner.startScan(filters, settings, leScanCallback);
                                    log(TAG, "btLeScanner.startScan(leScanCallback); DONE");
                                    Thread.sleep(BLE_GAP_SCAN_LOOP_DURAITON_MILLIS);
                                }
                            }
                        } catch (Throwable tr) {
                            log(TAG, "ble_gap_scan_thread hash " + this.hashCode() + " failed with exception: " + getStackTraceString(tr));
                        } finally {
                            try {
                                if (btLeScanner != null) {
                                    btLeScanner.stopScan(leScanCallback);
                                }
                            } catch (Throwable tr) {
                            }
                            close();
                        }
                        log(TAG, "ble_gap_scan_thread END");
                    }
                };
                ble_gap_scan_thread.start();
            }
        } else {
            close();
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
                        port = Integer.parseInt(m_start_intent.getStringExtra("ntrip_port"));
                        connect_ntrip(m_start_intent.getStringExtra("ntrip_host"), port, m_start_intent.getStringExtra("ntrip_mountpoint"), m_start_intent.getStringExtra("ntrip_user"), m_start_intent.getStringExtra("ntrip_pass"));
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
        if (m_ble_gap_scan_mode) {
            if (System.currentTimeMillis() - m_last_BLE_GAP_SCAN_MODE_SETMOCK_ts < BLE_GAP_SCAN_MODE_SETMOCK_INTERVAL * 3) {
                return true;
            }
            return false;
        }
        if (g_rfcomm_mgr != null && g_rfcomm_mgr.is_bt_connected()) {
            return true;
        }
        return false;
    }

    public boolean is_trying_bt_connect() {
        if (is_ble_gap_scan_thread_running())
            return true;
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
        }
        log(TAG, "stop_auto_reconnect_thread end");
    }

    void start_auto_reconnect_thread() {
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
                                        connect();
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

    int connect(String bdaddr, boolean secure, Context context) {
        int ret = -1;

        try {


            if (is_trying_bt_connect()) {
                toast("connection already starting - please wait...");
                return 1;
            } else if (g_rfcomm_mgr != null && g_rfcomm_mgr.is_bt_connected()) {
                toast("already connected - press Back to disconnect and exit...");
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

                BluetoothAdapter.getDefaultAdapter().cancelDiscovery();
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

        if (is_ble_gap_scan_thread_running()) {
            try {
                ble_gap_scan_thread.interrupt();
            } catch (Throwable tr) {}
            ble_gap_scan_thread = null;
        }

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
                //d(TAG, "on_read_object ondevicemessage start");
                if (object.getInt("fix_status") >= 3) {
                    //3D so fix is ok now - get lat lon to send mock location
                    double lat = object.getDouble("latitude");
                    double lon = object.getDouble("longitude");
                    double float_height_m = object.getDouble("float_height_m");
                    double heading_degrees = object.getDouble("heading_degrees");
                    double float_speed_kmh = object.getDouble("float_speed_kmh");
                    double hdop = object.getDouble("hdop");
                    double accuracy = hdop * get_connected_device_CEP();
                    int satellite_count_used = object.getInt("satellite_count_used");
                    long new_ts = (object.getLong("timestamp_s")*1000L) + object.getLong("millisecond");
                    String time_str = convertUnixTimeStampToSQLDateTime(new_ts);
                    object.put("time", time_str);
                    d(TAG, "time: "+time_str);
                    setMock(lat, lon, float_height_m, (float) accuracy, (float) heading_degrees, (float) float_speed_kmh, false, satellite_count_used, hdop, "QSTARZ_BLE", new_ts);
                }
                HashMap<String, Object> param_map = m_gnss_parser.getM_parsed_params_hashmap();
                HashMap<String, Object> qstarz_param_map = jsonToMap(object);
                for (String key : qstarz_param_map.keySet()) {
                    Object value = qstarz_param_map.get(key);
                    String talker = "QSTARZ";
                    m_gnss_parser.put_param(talker, key, value);
                }
                log(TAG, "qstarz ble lat: " + param_map.get("lat_double_07_str"));
                log(TAG, "qstarz ble lon: " + param_map.get("lon_double_07_str"));
                try {
                    if (m_activity_for_nmea_param_callbacks != null) {
                        m_activity_for_nmea_param_callbacks.onPositionUpdate(param_map);
                    }
                } catch (Exception e) {
                    log(TAG, "bluetooth_gnss_service call callback in m_activity_for_nmea_param_callbacks exception: " + getStackTraceString(e));
                }
                d(TAG, "on_read_object ondevicemessage success");
            } catch (Exception e) {
                Log.d(TAG, "WARNING: on_read_object m_ble_qstarz_mode exception: "+Log.getStackTraceString(e));
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
    SimpleDateFormat log_name_sdf = new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss");
    SimpleDateFormat csv_sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
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
            android.util.Log.d(TAG, msg);
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
            android.util.Log.d(TAG, msg);
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

    public boolean prepare_log_output_streams(String log_folder_uri_str) {
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
            return true;
        } catch (Throwable tr) {
            String msg = "WARNING: Logging failed - pls re-tick 'Settings' > 'Enable logging' - error:\n"+ getStackTraceString(tr);
            toast(msg);
            android.util.Log.d(TAG, msg);
            return false;
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
            m_activity_for_nmea_param_callbacks.onDeviceMessage(gnss_sentence_parser.MessageType.NMEA, parsed_nmea);
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
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
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
            log(TAG, "is_location_enabled() getting providers");
            List<String> providers = lm.getAllProviders();
            for (String p : providers) {
                log(TAG,"location provider enabled: "+p);
            }

            log(TAG, "is_location_enabled() 1");

            gps_enabled = lm.isProviderEnabled(LocationManager.GPS_PROVIDER);
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

            if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                //log(TAG,"is_mock_location_enabled Build.VERSION.SDK_INT >= Build.VERSION_CODES.M");
                AppOpsManager opsManager = (AppOpsManager) context.getSystemService(Context.APP_OPS_SERVICE);
                mock_enabled = (opsManager.checkOp(AppOpsManager.OPSTR_MOCK_LOCATION, app_uid, app_id_string)== AppOpsManager.MODE_ALLOWED);
            } else {
                // in marshmallow this will always return true
                //log(TAG,"is_mock_location_enabled older models");
                mock_enabled = !android.provider.Settings.Secure.getString(context.getContentResolver(), "mock_location").equals("0");
            }
        } catch(Exception e) {
            log(TAG, "check mock_enabled exception: "+ getStackTraceString(e));
        }
        //log(TAG,"is_mock_location_enabled ret "+mock_enabled);
        return mock_enabled;
    }

    File bt_gnss_test_debug_mock_location_1_1_mode_flag = new File("/sdcard/bt_gnss_test_debug_mock_location_1_1_mode_flag");
    public static final String POSITION_UPDATE_INTENT_ACTION = "com.clearevo.libbluetooth_gnss_service.POSITION_UPDATE";
    public static final String PARSED_NMEA_UPDATE_INTENT_ACTION = "com.clearevo.libbluetooth_gnss_service.PARSED_NMEA_UPDATE";
    public static final String INTENT_EXTRA_DATA_JSON_KEY = "data_json";
    private void setMock(double latitude, double longitude, double altitude, float accuracy, float bearing, float speed, boolean alt_is_elipsoidal, int n_sats, double hdop, String talker, long new_ts) {
        if (closing) {
            d(TAG, "setmock ignore as already closing");
            return;
        }
        long ts = System.currentTimeMillis();

        try {
            if (bt_gnss_test_debug_mock_location_1_1_mode_flag.isFile()) {
                log(TAG, "NOTE: bt_gnss_test_debug_mock_location_1_1_mode_flag exists - overriding lat, lon to 1, 1");
                latitude = 1;
                longitude = 1;
            }
        } catch (Throwable tr) {
            log(TAG, "WARNING: check bt_gnss_test_debug_mock_location_1_1_mode_flag exception: "+ getStackTraceString(tr));
        }

        try {
            Intent intent = new Intent();
            intent.setAction(POSITION_UPDATE_INTENT_ACTION);
            JSONObject jo = new JSONObject();
            try {jo.put("java_ts", ts);} catch (Exception e) {}
            try {jo.put("latitude", latitude);} catch (Exception e) {}
            try {jo.put("longitude", longitude);} catch (Exception e) {}
            try {jo.put("altitude", altitude);} catch (Exception e) {}
            try {jo.put("accuracy", accuracy);} catch (Exception e) {}
            try {jo.put("bearing", bearing);} catch (Exception e) {}
            try {jo.put("speed", speed);} catch (Exception e) {}
            try {jo.put("n_sats", n_sats);} catch (Exception e) {}
            intent.putExtra(INTENT_EXTRA_DATA_JSON_KEY, jo.toString());
            getApplicationContext().sendBroadcast(intent);
        } catch (Throwable tr) {
            log(TAG, "WARNING: broadcast position intent failed exception: "+ getStackTraceString(tr));
        }

        log(TAG, "setMock accuracy_meters: "+accuracy);

        activate_mock_location(); //this will check a static flag and not re-activate if already active
        LocationManager locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);

        Location newLocation = new Location(LocationManager.GPS_PROVIDER);
        newLocation.setTime(System.currentTimeMillis());
        newLocation.setLatitude(latitude);
        newLocation.setLongitude(longitude);
        newLocation.setAccuracy(accuracy);
        newLocation.setAltitude(altitude);
        if (!Double.isNaN(bearing))
            newLocation.setBearing(bearing);
        else {
            //log(TAG, "bearing is nan so not setting in newlocation");
        }
        newLocation.setSpeed(speed);
        if (n_sats > 0) {
            Bundle bundle = new Bundle();
            bundle.putInt("satellites", n_sats);
            newLocation.setExtras(bundle);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            newLocation.setElapsedRealtimeNanos(SystemClock.elapsedRealtimeNanos());

        }
        locationManager.setTestProviderStatus(LocationManager.GPS_PROVIDER,
                LocationProvider.AVAILABLE,
                null,System.currentTimeMillis());
        log(TAG, "setMock lat: "+newLocation.getLatitude());
        log(TAG, "setMock lon: "+newLocation.getLongitude());
        if (newLocation.getExtras() != null) {
            log(TAG, "setMock satellites: " + newLocation.getExtras().getInt("satellites"));
        }
        locationManager.setTestProviderLocation(LocationManager.GPS_PROVIDER, newLocation);

        //////////////hooks
        m_gnss_parser.put_param("", "hdop", hdop);
        m_gnss_parser.put_param("", "location_from_talker", talker);
        m_gnss_parser.put_param("", "lat", latitude);
        m_gnss_parser.put_param("", "lon", longitude);
        m_gnss_parser.put_param("", "alt", altitude);
        m_gnss_parser.put_param("", "alt_type", alt_is_elipsoidal?"ellipsoidal":"orthometric");
        if (!Double.isNaN(bearing))
            m_gnss_parser.put_param("", "course", bearing);
        m_gnss_parser.put_param("", "n_sats", n_sats);
        m_gnss_parser.put_param("", "accuracy", accuracy);
        m_gnss_parser.put_param("", "mock_location_set_ts", System.currentTimeMillis());
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
            }
            m_gnss_parser.put_param("", "logfile_n_bytes", log_bt_rx_bytes_written);
        }
        if (m_log_bt_rx_csv_fos != null) {
            try {
                String line = csv_sdf.format(new_ts)+","+latitude+","+longitude+","+altitude+"\n";
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
        if (is_mock_location_active()) {
            log(TAG, "deactivate_mock_location1");
            try {
                LocationManager locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
                // Remove the test provider safely
                if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    log(TAG, "deactivate_mock_location set enabled false");
                    locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, false);
                }

                try {
                    log(TAG, "deactivate_mock_location rm provider");
                    locationManager.removeTestProvider(LocationManager.GPS_PROVIDER);
                } catch (IllegalArgumentException e) {
                    // Handle case where the provider is not set or doesn't exist
                    e(TAG, "WARNING: removeTestProvider: Provider does not exist.");
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

    private void activate_mock_location() {
        if (closing) {
            d(TAG, "activate_mock_location ignore as already closing");
            return;
        }
        if (!is_mock_location_active()) {
            try {
                log(TAG, "activate_mock_location 0");
                LocationManager locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
                locationManager.addTestProvider(LocationManager.GPS_PROVIDER,
                        /*boolean requiresNetwork*/ false,
                        /*boolean requiresSatellite*/ true,
                        /*boolean requiresCell*/ false,
                        /*boolean hasMonetaryCost*/ false,
                        /*boolean supportsAltitude*/ true,
                        /*boolean supportsSpeed*/ true,
                        /*boolean supportsBearing */ true,
                        ProviderProperties.POWER_USAGE_LOW,
                        ProviderProperties.ACCURACY_FINE);
                locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, true);
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
        if (m_ble_gap_scan_mode) {
            return m_last_BLE_GAP_DEV_NAME;
        }
        return ""+m_bdaddr;
    }

    // Binder given to clients
    private final IBinder m_binder = new LocalBinder();
    gnss_sentence_parser.gnss_parser_callbacks m_activity_for_nmea_param_callbacks;
    long last_set_mock_location_ts = 0;

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

    double DEFAULT_CEP = 4.0;
    double DEFAULT_UBLOX_M8030_CEP = 2.0;
    double DEFAULT_UBLOX_ZED_F9P_CEP = 1.5;

    public double get_connected_device_CEP()
    {
        //TODO - later set per detected device or adjustable by user in settings
        return DEFAULT_CEP;
    }

    @Override
    public void onPositionUpdate(HashMap<String, Object> params_map) {

        if (closing) {
            d(TAG, "onPositionUpdate ignore as already closing");
            return;
        }

        log(TAG, "service: onPositionUpdate() start");
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
        double lat = 0.0, lon = 0.0, alt = 0.0, hdop = 0.0, speed = 0.0, bearing = 0.0/0.0;
        int n_sats = 0;
        for (String talker : GGA_MESSAGE_TALKER_TRY_LIST) {

            try {
                if (params_map.containsKey(talker+"_lat_ts")) {
                    long new_ts = (long) params_map.get(talker+"_lat_ts");
                    if (new_ts != last_set_mock_location_ts) {
                        lat = (double) params_map.get(talker+"_lat");
                        lon = (double) params_map.get(talker+"_lon");
                        String ellips_height_key = talker+"_ellipsoidal_height";
                        boolean alt_is_ellipsoidal = false;
                        if (params_map.containsKey(ellips_height_key)) {
                            alt_is_ellipsoidal = true;
                            alt = (double) params_map.get(ellips_height_key);
                            log(TAG, "ellips_height_key valid");
                        } else {
                            alt = (double) params_map.get(talker+"_alt");
                            log(TAG, "ellips_height_key not valid");
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
                        speed = speed * 0.514444; //convert to m/s
                        try {
                            Object course = null;
                            if (params_map.containsKey(talker+"_true_course")) {  // value from VTG
                                course = params_map.get(talker+"_true_course");
                            } else if (params_map.containsKey(talker+"_course")) {  // value from RMC (RMC course = VTG true course)
                                course = params_map.get(talker+"_course");
                            }
                            log(TAG, "course: "+course);
                            if (course != null) {
                                bearing = (double) course;
                            }
                        } catch (Exception e) {
                            log(TAG, "get course failed exception: "+ getStackTraceString(e));
                        }
                        double accuracy = -1.0;
                        if (params_map.containsKey("UBX_POSITION_hAcc")) {
                            try {
                                accuracy = Double.parseDouble((String) params_map.get("UBX_POSITION_hAcc"));
                            } catch (Exception e) {}
                        }

                        //if not ubx or ubx conv failed...
                        if (accuracy == -1.0) {
                            accuracy = hdop * get_connected_device_CEP();
                        }
                        setMock(lat, lon, alt, (float) accuracy, (float) bearing, (float) speed, alt_is_ellipsoidal, n_sats, hdop, talker, new_ts);
                        break;
                    } else {
                        //omit as same ts as last
                    }
                }
            } catch (Exception e) {
                log(TAG, "bluetooth_gnss_service on_updated_nmea_params talker: "+talker+" exception: "+ getStackTraceString(e));
            }
        }

        log(TAG, "service: on_updated_nmea_params() act");

        //report params to activity
        try {
            if (m_activity_for_nmea_param_callbacks != null) {
                m_activity_for_nmea_param_callbacks.onPositionUpdate(params_map);
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
