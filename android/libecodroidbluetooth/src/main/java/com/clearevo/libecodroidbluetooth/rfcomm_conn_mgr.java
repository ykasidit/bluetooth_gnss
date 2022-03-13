package com.clearevo.libecodroidbluetooth;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.ParcelUuid;
import android.os.Parcelable;
import android.util.Log;

import java.io.Closeable;
import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentLinkedQueue;


public class rfcomm_conn_mgr {

    BluetoothSocket m_bluetooth_socket;
    InputStream m_sock_is;
    OutputStream m_sock_os;
    Socket m_tcp_server_sock;
    BluetoothDevice m_target_bt_server_dev;

    List<Closeable> m_cleanup_closables;
    Thread m_conn_state_watcher;

    rfcomm_conn_callbacks m_rfcomm_to_tcp_callbacks;

    ConcurrentLinkedQueue<byte[]> m_incoming_buffers;
    ConcurrentLinkedQueue<byte[]> m_outgoing_buffers;

    final int MAX_SDP_FETCH_DURATION_SECS = 15;
    final int BTINCOMING_QUEUE_MAX_LEN = 100;
    static final String TAG = "btgnss_rfcmgr";
    static final String SPP_UUID_PREFIX = "00001101";
    static final UUID SPP_WELL_KNOWN_UUNID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");
    String m_tcp_server_host;
    int m_tcp_server_port;
    boolean m_readline_callback_mode = false;
    boolean m_secure = true;
    volatile boolean closed = false;
    Parcelable[] m_fetched_uuids = null;
    Context m_context;

    private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();

            if (BluetoothDevice.ACTION_UUID.equals(action)) {
                // from https://stackoverflow.com/questions/14812326/android-bluetooth-get-uuids-of-discovered-devices
                // This is when we can be assured that fetchUuidsWithSdp has completed.
                // So get the uuids and call fetchUuidsWithSdp on another device in list

                Log.d(TAG, "broadcastreceiver: got BluetoothDevice.ACTION_UUID");
                BluetoothDevice deviceExtra = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                Parcelable[] uuidExtra = intent.getParcelableArrayExtra(BluetoothDevice.EXTRA_UUID);
                Log.d(TAG, "broadcastreceiver: DeviceExtra: " + deviceExtra + " uuidExtra: "+uuidExtra);

                if (uuidExtra != null) {
                    for (Parcelable p : uuidExtra) {
                        Log.d(TAG, "in broadcastreceiver: uuidExtra parcelable part: " + p);
                    }
                    m_fetched_uuids = uuidExtra;
                } else {
                    Log.d(TAG, "broadcastreceiver: uuidExtra == null");
                }
            }
        }
    };


    public static BluetoothDevice get_first_bonded_bt_device_where_name_contains(String contains) throws Exception
    {
        Set<BluetoothDevice> bonded_devs = BluetoothAdapter.getDefaultAdapter().getBondedDevices();
        BluetoothDevice test_device = null;
        Log.d(TAG,"n bonded_devs: "+bonded_devs.size());

        for (BluetoothDevice bonded_dev : bonded_devs) {
            //Log.d(TAG,"bonded_dev: "+ bonded_dev.getName()+" bdaddr: "+bonded_dev.getAddress());
            if (bonded_dev.getName().contains(contains)) {
                String bt_dev_name = bonded_dev.getName();
                Log.d(TAG,"get_first_bonded_bt_device_where_name_contains() using this dev: name: "+bt_dev_name+" bdaddr: "+bonded_dev.getAddress());
                test_device = bonded_dev;
                break;
            }
        }

        if (test_device == null) {
            throw new Exception("failed to find a matching bonded (bluetooth paired) device - ABORT");
        }

        return test_device;
    }

    public static boolean is_bluetooth_on()
    {
        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        if (adapter != null) {
            return adapter.isEnabled();
        }

        return false;
    }

    public static HashMap<String, String> get_bd_map()
    {
        HashMap<String, String> ret = new HashMap<String, String>();

        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        if (adapter != null) {
            Set<BluetoothDevice> bonded_devs = adapter.getBondedDevices();
            for (BluetoothDevice bonded_dev : bonded_devs) {
                ret.put(bonded_dev.getAddress(), bonded_dev.getName());
            }
        }

        return ret;
    }


    //use this ctor for readline callback mode
    public rfcomm_conn_mgr(BluetoothDevice target_bt_server_dev, boolean secure, rfcomm_conn_callbacks cb, Context context) throws Exception {
        m_readline_callback_mode = true;
        m_secure = secure;
        init(target_bt_server_dev, secure, null, 0, cb, context);
    }

    //use this ctor and specify tcp_server_host, tcp_server_port for connect-and-stream-data-to-your-tcp-server mode
    public rfcomm_conn_mgr(BluetoothDevice target_bt_server_dev, boolean secure, final String tcp_server_host, final int tcp_server_port, rfcomm_conn_callbacks cb, Context context) throws Exception {
        init(target_bt_server_dev, secure, tcp_server_host, tcp_server_port, cb, context);
    }

    private void init(BluetoothDevice target_bt_server_dev, boolean secure, final String tcp_server_host, final int tcp_server_port, rfcomm_conn_callbacks cb, Context context) throws Exception
    {
        m_context = context;
        m_secure = secure;
        m_rfcomm_to_tcp_callbacks = cb;

        if (tcp_server_host == null) {
            Log.d(TAG, "tcp_server_host null so disabled conencting to tcp server mode...");
        }

        if (context == null) {
            throw new Exception("invalid context supplied is null");
        }

        if (target_bt_server_dev == null) {
            throw new Exception("invalid target_bt_server_dev supplied is null");
        }

        m_target_bt_server_dev = target_bt_server_dev;

        m_tcp_server_host = tcp_server_host;
        m_tcp_server_port = tcp_server_port;

        m_cleanup_closables = new ArrayList<Closeable>();
        m_incoming_buffers = new ConcurrentLinkedQueue<byte[]>();
        m_outgoing_buffers = new ConcurrentLinkedQueue<byte[]>();

        if (m_target_bt_server_dev == null)
            throw new Exception("m_target_bt_server_dev not specified");

        if (m_rfcomm_to_tcp_callbacks == null)
            throw new Exception("m_rfcomm_to_tcp_callbacks not specified");

        IntentFilter filter = new IntentFilter(BluetoothDevice.ACTION_UUID);
        m_context.registerReceiver(mReceiver, filter);

        Log.d(TAG, "init() done m_readline_callback_mode: "+m_readline_callback_mode);
    }



    public UUID fetch_dev_uuid_with_prefix(String uuid_prefix) throws Exception
    {
        BluetoothAdapter.getDefaultAdapter().cancelDiscovery();

        //always fetch fresh data from sdp - rfcomm channel numbers can change
        m_fetched_uuids = null;
        boolean fret = m_target_bt_server_dev.fetchUuidsWithSdp();
        if (!fret) {
            throw new Exception("fetchUuidsWithSdp returned false...");
        }
        Log.d(TAG, "fetch uuid started");


        final int total_wait_millis = MAX_SDP_FETCH_DURATION_SECS * 1000;
        final int fetch_recheck_steps = 30;
        final int fetch_recheck_step_duration = total_wait_millis / fetch_recheck_steps;

        for (int retry = 0; retry < fetch_recheck_steps; retry++){

            if (m_fetched_uuids != null) {
                Log.d(TAG, "fetch uuid complete at retry: "+retry);
                break; //fetch uuid success
            }
            Thread.sleep(fetch_recheck_step_duration);
            Log.d(TAG, "fetch uuid still not complete at retry: "+retry);
        }


        if (m_fetched_uuids == null) {
            throw new Exception("failed to get uuids from target device");
        }

        UUID found_spp_uuid = null;
        for (Parcelable parcelable : m_fetched_uuids) {

            if (parcelable == null) {
                continue;
            }

            if (!(parcelable instanceof ParcelUuid))
                continue;
            ParcelUuid parcelUuid = (ParcelUuid) parcelable;

            UUID this_uuid = parcelUuid.getUuid();
            if (this_uuid == null) {
                continue;
            }

            //Log.d(TAG, "target_dev uuid: " + uuid.toString());
            //00001101-0000-1000-8000-00805f9b34fb
            if (this_uuid.toString().startsWith(uuid_prefix)) {
                found_spp_uuid = this_uuid;
            }
        }

        Log.d(TAG, "found_spp_uuid: " + found_spp_uuid);
        BluetoothAdapter.getDefaultAdapter().cancelDiscovery();

        return found_spp_uuid;
    }


    public void connect() throws Exception
    {
        Log.d(TAG, "connect() start");

        try {

            try {
                if (m_bluetooth_socket != null) {
                    m_bluetooth_socket.close();
                    Log.d(TAG, "m_bluetooth_socket close() done");
                }
            } catch (Exception e) {
            }
            m_bluetooth_socket = null;

            try {
                if (m_secure) {
                    Log.d(TAG, "createRfcommSocketToServiceRecord SPP_WELL_KNOWN_UUNID");
                    m_bluetooth_socket = m_target_bt_server_dev.createRfcommSocketToServiceRecord(SPP_WELL_KNOWN_UUNID);
                } else {
                    Log.d(TAG, "createInsecureRfcommSocketToServiceRecord SPP_WELL_KNOWN_UUNID");
                    m_bluetooth_socket = m_target_bt_server_dev.createInsecureRfcommSocketToServiceRecord(SPP_WELL_KNOWN_UUNID);
                }

                if (m_bluetooth_socket == null)
                    throw new Exception("create rfcommsocket failed - got null ret from SPP_WELL_KNOWN_UUNID sock create to dev");
            } catch (Exception e) {
                Log.d(TAG, "alternative0 - try connect using well-knwon spp uuid failed - try fetch uuids and connect with found matching spp uuid...");
                UUID found_spp_uuid = fetch_dev_uuid_with_prefix(SPP_UUID_PREFIX);
                if (found_spp_uuid == null) {
                    throw new Exception("Failed to find SPP uuid in target bluetooth device (alternative0) - ABORT");
                }
                if (m_secure) {
                    Log.d(TAG, "alt0 createRfcommSocketToServiceRecord fetcheduuid");
                    m_bluetooth_socket = m_target_bt_server_dev.createRfcommSocketToServiceRecord(found_spp_uuid);
                } else {
                    Log.d(TAG, "alt0 createInsecureRfcommSocketToServiceRecord fetcheduuid");
                    m_bluetooth_socket = m_target_bt_server_dev.createInsecureRfcommSocketToServiceRecord(found_spp_uuid);
                }

                if (m_bluetooth_socket == null)
                    throw new Exception("create rfcommsocket failed - got null ret from alternative0 sock create to dev");
            }

            BluetoothAdapter.getDefaultAdapter().cancelDiscovery();
            Log.d(TAG, "calling m_bluetooth_socket.connect() START m_target_bt_server_dev: name: "+m_target_bt_server_dev.getName() +" bdaddr: "+m_target_bt_server_dev.getAddress());
            m_bluetooth_socket.connect();
            Log.d(TAG, "calling m_bluetooth_socket.connect() DONE m_target_bt_server_dev: name: "+m_target_bt_server_dev.getName() +" bdaddr: "+m_target_bt_server_dev.getAddress());

            if (m_rfcomm_to_tcp_callbacks != null)
                m_rfcomm_to_tcp_callbacks.on_rfcomm_connected();

            InputStream bs_is = m_bluetooth_socket.getInputStream();
            OutputStream bs_os = m_bluetooth_socket.getOutputStream();

            m_cleanup_closables.add(bs_is);
            m_cleanup_closables.add(bs_os);

            //start thread to read from bluetooth socket to incoming_buffer
            inputstream_to_queue_reader_thread incoming_thread = null;
            if (m_readline_callback_mode) {
                incoming_thread = new inputstream_to_queue_reader_thread(bs_is, m_rfcomm_to_tcp_callbacks);
            } else {
                incoming_thread = new inputstream_to_queue_reader_thread(bs_is, m_incoming_buffers);
            }
            m_cleanup_closables.add(incoming_thread);
            incoming_thread.start();

            //start thread to read from m_outgoing_buffers to bluetooth socket
            queue_to_outputstream_writer_thread outgoing_thread = new queue_to_outputstream_writer_thread(m_outgoing_buffers, bs_os);
            m_cleanup_closables.add(outgoing_thread);
            outgoing_thread.start();

            try {
                Thread.sleep(500);
            } catch (Exception e) {

            }

            if (incoming_thread.isAlive() == false)
                throw new Exception("incoming_thread died - not opening client socket...");

            if (outgoing_thread.isAlive() == false)
                throw new Exception("outgoing_thread died - not opening client socket...");

            inputstream_to_queue_reader_thread tmp_sock_is_reader_thread = null;
            queue_to_outputstream_writer_thread tmp_sock_os_writer_thread = null;

            if (m_tcp_server_host != null) {

                //open client socket to target tcp server
                Log.d(TAG, "start opening tcp socket to host: " + m_tcp_server_host + " port: " + m_tcp_server_port);
                m_tcp_server_sock = new Socket(m_tcp_server_host, m_tcp_server_port);
                m_sock_is = m_tcp_server_sock.getInputStream();
                m_sock_os = m_tcp_server_sock.getOutputStream();
                Log.d(TAG, "done opening tcp socket to host: " + m_tcp_server_host + " port: " + m_tcp_server_port);

                m_cleanup_closables.add(m_sock_is);
                m_cleanup_closables.add(m_sock_os);

                if (m_rfcomm_to_tcp_callbacks != null)
                    m_rfcomm_to_tcp_callbacks.on_target_tcp_connected();

                //start thread to read socket to outgoing_buffer
                tmp_sock_is_reader_thread = new inputstream_to_queue_reader_thread(m_sock_is, m_outgoing_buffers);
                tmp_sock_is_reader_thread.start();
                m_cleanup_closables.add(tmp_sock_is_reader_thread);

                //start thread to write from incoming buffer to socket
                tmp_sock_os_writer_thread = new queue_to_outputstream_writer_thread(m_incoming_buffers, m_sock_os);
                tmp_sock_os_writer_thread.start();
                m_cleanup_closables.add(tmp_sock_os_writer_thread);
            }

            final inputstream_to_queue_reader_thread sock_is_reader_thread = tmp_sock_is_reader_thread;
            final queue_to_outputstream_writer_thread sock_os_writer_thread = tmp_sock_os_writer_thread;


            //watch bluetooth socket state and both threads above
            m_conn_state_watcher = new Thread() {
                public void run() {
                    while (m_conn_state_watcher == this) {
                        try {

                            Thread.sleep(3000);

                            if (closed)
                                break; //if close() was called then dont notify on_bt_disconnected or on_target_tcp_disconnected

                            if (sock_is_reader_thread != null && sock_is_reader_thread.isAlive() == false) {
                                if (m_rfcomm_to_tcp_callbacks != null)
                                    m_rfcomm_to_tcp_callbacks.on_rfcomm_disconnected();
                                throw new Exception("sock_is_reader_thread died");
                            }

                            if (sock_os_writer_thread != null && sock_os_writer_thread.isAlive() == false) {
                                if (m_rfcomm_to_tcp_callbacks != null)
                                    m_rfcomm_to_tcp_callbacks.on_target_tcp_disconnected();
                                throw new Exception("sock_os_writer_thread died");
                            }

                            if (is_bt_connected() == false) {
                                throw new Exception("bluetooth device disconnected");
                            }

                        } catch (Exception e) {
                            if (e instanceof InterruptedException) {
                                Log.d(TAG, "rfcomm_to_tcp m_conn_state_watcher ending with signal from close()");
                            } else {
                                Log.d(TAG, "rfcomm_to_tcp m_conn_state_watcher ending with exception: " + Log.getStackTraceString(e));
                                try {
                                    if (m_rfcomm_to_tcp_callbacks != null)
                                        m_rfcomm_to_tcp_callbacks.on_rfcomm_disconnected();
                                } catch (Exception ee) {}
                            }
                            break;
                        }
                    }
                }
            };
            m_conn_state_watcher.start();
        } catch (Exception e) {
            Log.d(TAG, "connect() exception: "+Log.getStackTraceString(e));
            close();
            throw e;
        }
    }


    public boolean is_bt_connected()
    {
        try {
            return m_bluetooth_socket.isConnected();

        } catch (Exception e){
        }
        return false;
    }

    public void add_send_buffer(byte[] buffer)
    {
        m_outgoing_buffers.add(buffer);
    }

    public boolean isClosed()
    {
        return closed;
    }


    public synchronized void close()
    {
        if (closed)
            return;

        closed = true;

        try {
            if (m_context != null && mReceiver != null) {
                m_context.unregisterReceiver(mReceiver);
            }
        } catch (Exception e) {
        }


        try {
            m_conn_state_watcher.interrupt();
            m_conn_state_watcher = null;
        } catch (Exception e) {
        }

        try {
            m_bluetooth_socket.close();
            Log.d(TAG,"m_bluetooth_socket close() done");
        } catch (Exception e) {
        }
        m_bluetooth_socket = null;

        try {
            if (m_tcp_server_sock != null) {
                m_tcp_server_sock.close();
            }
        } catch (Exception e) {
        }
        m_tcp_server_sock = null;

        for (Closeable closeable : m_cleanup_closables) {
            try {
                closeable.close();
            } catch (Exception e) {
            }
        }
        m_cleanup_closables.clear();
    }

}
