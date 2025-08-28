package com.clearevo.libbluetooth_gnss_service;

import static com.clearevo.libbluetooth_gnss_service.NativeParser.parse_qstarz_pkt;
import static com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service.log;
import static com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service.nordic_uart_service_uuid;
import static com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service.qstarz_chrc_tx_uuid;
import static com.clearevo.libbluetooth_gnss_service.gnss_sentence_parser.toHexString;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.BluetoothSocket;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.ParcelUuid;
import android.os.Parcelable;

import androidx.annotation.NonNull;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.Closeable;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;


public class rfcomm_conn_mgr {

    BluetoothSocket m_bluetooth_socket;
    InputStream m_sock_is;
    OutputStream m_sock_os;
    Socket m_tcp_server_sock;
    public BluetoothDevice m_target_bt_server_dev;

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
                Log.d(TAG, "broadcastreceiver: DeviceExtra: " + deviceExtra + " uuidExtra: " + uuidExtra);

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


    public static boolean is_bluetooth_on() {

        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        if (adapter != null) {
            return adapter.isEnabled();
        }

        return false;
    }


    //use this ctor for readline callback mode
    public rfcomm_conn_mgr(BluetoothDevice target_bt_server_dev, boolean secure, rfcomm_conn_callbacks cb, Context context, boolean ble_mode) throws Exception {
        m_readline_callback_mode = true;
        m_secure = secure;
        m_ble_mode = ble_mode;
        init(target_bt_server_dev, secure, null, 0, cb, context);
    }

    //use this ctor and specify tcp_server_host, tcp_server_port for connect-and-stream-data-to-your-tcp-server mode
    public rfcomm_conn_mgr(BluetoothDevice target_bt_server_dev, boolean secure, final String tcp_server_host, final int tcp_server_port, rfcomm_conn_callbacks cb, Context context) throws Exception {
        init(target_bt_server_dev, secure, tcp_server_host, tcp_server_port, cb, context);
    }

    private void init(BluetoothDevice target_bt_server_dev, boolean secure, final String tcp_server_host, final int tcp_server_port, rfcomm_conn_callbacks cb, Context context) throws Exception {
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

        Log.d(TAG, "init() done m_readline_callback_mode: " + m_readline_callback_mode);
    }


    public UUID fetch_dev_uuid_with_prefix(String uuid_prefix) throws Exception {
        //BluetoothAdapter.getDefaultAdapter().cancelDiscovery();

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

        for (int retry = 0; retry < fetch_recheck_steps; retry++) {

            if (m_fetched_uuids != null) {
                Log.d(TAG, "fetch uuid complete at retry: " + retry);
                break; //fetch uuid success
            }
            Thread.sleep(fetch_recheck_step_duration);
            Log.d(TAG, "fetch uuid still not complete at retry: " + retry);
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
        //BluetoothAdapter.getDefaultAdapter().cancelDiscovery();

        return found_spp_uuid;
    }


    public void connect() throws Exception {
        Log.d(TAG, "connect() start");

        try {

            close_gatt();
            BluetoothAdapter.getDefaultAdapter().cancelDiscovery();
            if (m_ble_mode) {
                connect_ble(m_target_bt_server_dev);
            } else {
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
                Log.d(TAG, "calling m_bluetooth_socket.connect() START m_target_bt_server_dev: name: " + m_target_bt_server_dev.getName() + " bdaddr: " + m_target_bt_server_dev.getAddress());
                m_bluetooth_socket.connect();
                Log.d(TAG, "calling m_bluetooth_socket.connect() DONE m_target_bt_server_dev: name: " + m_target_bt_server_dev.getName() + " bdaddr: " + m_target_bt_server_dev.getAddress());
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
                                    } catch (Exception ee) {
                                    }
                                }
                                break;
                            }
                        }
                    }
                };
                m_conn_state_watcher.start();
            }
        } catch (Exception e) {
            Log.d(TAG, "connect() exception: "+Log.getStackTraceString(e));
            close();
            throw e;
        }
    }


    public boolean is_bt_connected()
    {
        try {
            if (m_ble_mode) {
                /*if (1==1)
                return true;
                if (BluetoothGatt.STATE_CONNECTED == m_ble_conn_state)
                    return true;*/
                BluetoothManager bluetoothManager = (BluetoothManager) m_context.getSystemService(Context.BLUETOOTH_SERVICE);
                int connectionState = bluetoothManager.getConnectionState(m_target_bt_server_dev, BluetoothProfile.GATT);
                boolean connected = connectionState == BluetoothProfile.STATE_CONNECTED;
                if (!connected) {
                    Log.d(TAG, "ble !connected connectionState: " + connectionState);
                }
                return connected;
            } else {
                return m_bluetooth_socket.isConnected();
            }

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

        log(TAG, "close bluetoothGatt");
        close_gatt();

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


    /////////// ble uart stuff

    boolean m_ble_mode = false;
    private BluetoothGatt bluetoothGatt;
    // Descriptor UUID for enabling notifications
    private static final UUID CLIENT_CHARACTERISTIC_CONFIG_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    private void enableTxNotifications(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
        // Enable notification locally
        gatt.setCharacteristicNotification(characteristic, true);

        // Write to the descriptor to enable notification on the remote side
        BluetoothGattDescriptor descriptor = characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG_UUID);
        if (descriptor != null) {
            descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
            gatt.writeDescriptor(descriptor);
        }
    }

    int m_ble_conn_state = BluetoothGatt.STATE_DISCONNECTED;

    void close_gatt()
    {
        if (bluetoothGatt != null) {
            try {
                bluetoothGatt.disconnect();
            } catch (Exception e) {}
            try {
                bluetoothGatt.close();
            } catch (Exception e) {}
        }
        bluetoothGatt = null;
    }

    CountDownLatch ble_connecting_latch;
    final int CONNECT_BLE_TIMEOUT_SECS = 15;
    private void connect_ble(BluetoothDevice device) throws Exception {
        close_gatt();
        ble_connecting_latch = new CountDownLatch(1);
        bluetoothGatt = device.connectGatt(m_context, false, gattCallback);
        boolean success = ble_connecting_latch.await(CONNECT_BLE_TIMEOUT_SECS, TimeUnit.SECONDS);
        if (!success) {
            log(TAG, "connect gatt timed-out");
            close_gatt();
        } else {
            log(TAG, "connect gatt completed");
        }
    }

    private final BluetoothGattCallback gattCallback = new BluetoothGattCallback() {

        @Override
        public void onConnectionStateChange(@NonNull BluetoothGatt gatt, int status, int newState) {
            super.onConnectionStateChange(gatt, status, newState);
            log(TAG, "ble onConnectionStateChange: "+newState);
            m_ble_conn_state = newState;
            if (newState == BluetoothGatt.STATE_CONNECTED) {
                log(TAG, "Connected to GATT server, discovering services...");
                gatt.discoverServices();
            } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                ble_connecting_latch.countDown();
                log(TAG, "Disconnected from GATT server");
                close();
            }
        }

        @Override
        public void onServicesDiscovered(@NonNull BluetoothGatt gatt, int status) {
            super.onServicesDiscovered(gatt, status);
            ble_connecting_latch.countDown(); //connecting completed
            log("ble onServicesDiscovered() gatt scan status: "+status);
            if (status == BluetoothGatt.GATT_SUCCESS) {
                // Get the Nordic UART Service
                BluetoothGattService service = gatt.getService(nordic_uart_service_uuid);

                if (service != null) {
                    log(TAG, "Nordic/qstarz UART Service discovered");
                    // Get the TX characteristic
                    BluetoothGattCharacteristic txCharacteristic = service.getCharacteristic(qstarz_chrc_tx_uuid);
                    if (txCharacteristic != null) {
                        log(TAG, "TX Characteristic found, enabling notifications...");
                        // Enable notifications on the TX characteristic
                        enableTxNotifications(gatt, txCharacteristic);
                        //notify connected
                        if (m_rfcomm_to_tcp_callbacks != null) {
                            m_rfcomm_to_tcp_callbacks.on_rfcomm_connected();
                        }

                        //watch ble conn state
                        m_conn_state_watcher = new Thread() {
                            public void run() {
                                while (m_conn_state_watcher == this) {
                                    try {

                                        Thread.sleep(3_000);

                                        if (closed)
                                            break; //if close() was called then dont notify on_bt_disconnected or on_target_tcp_disconnected

                                        if (is_bt_connected() == false) {
                                            throw new Exception("bluetooth device disconnected");
                                        }

                                    } catch (Exception e) {
                                        if (e instanceof InterruptedException) {
                                            log(TAG, "rfcomm_to_tcp m_conn_state_watcher ble ending with signal from close()");
                                        } else {
                                            log(TAG, "rfcomm_to_tcp m_conn_state_watcher ble ending with exception: " + Log.getStackTraceString(e));
                                            try {
                                                if (m_rfcomm_to_tcp_callbacks != null)
                                                    m_rfcomm_to_tcp_callbacks.on_rfcomm_disconnected();
                                            } catch (Exception ee) {
                                            }
                                        }
                                        break;
                                    }
                                }
                            }
                        };
                        m_conn_state_watcher.start();
                    }
                }
            } else {
                //connect gatt failed - set to null
                log("gatt scan failed: "+status+" - closing connection ");
                close_gatt();
            }
        }




        @Override
        public void onCharacteristicRead(@NonNull BluetoothGatt gatt, @NonNull BluetoothGattCharacteristic characteristic, int status) {
            super.onCharacteristicRead(gatt, characteristic, status);

            if (status == BluetoothGatt.GATT_SUCCESS && qstarz_chrc_tx_uuid.equals(characteristic.getUuid())) {
                // Read the data from the TX characteristic
                byte[] data = characteristic.getValue();
                if (data == null) {
                    data = new byte[]{};
                }
                //Log.d(TAG, "onCharacteristicRead data len: " + data.length);
            }
        }

        ArrayList<byte[]> last_qstarz_packet_buffers = new ArrayList();
        @Override
        public void onCharacteristicChanged(@NonNull BluetoothGatt gatt, @NonNull BluetoothGattCharacteristic characteristic) {
            super.onCharacteristicChanged(gatt, characteristic);

            if (qstarz_chrc_tx_uuid.equals(characteristic.getUuid())) {
                // Read the data from the TX characteristic
                byte[] data = characteristic.getValue();
                if (data == null) {
                    data = new byte[]{};
                }
                try {
                    bluetooth_gnss_service.curInstance.log_bt_rx(data);
                } catch (Exception e) {
                    log(TAG, "chrc data log_bt_rx exception: "+Log.getStackTraceString(e));
                }
                //Log.d(TAG, "onCharacteristicChanged data len: " + data.length + " data_hex: "+toHexString(data));
                last_qstarz_packet_buffers.add(data);
                while (last_qstarz_packet_buffers.size() > 4) {
                    last_qstarz_packet_buffers.remove(0);
                }
                if (last_qstarz_packet_buffers.size() == 4) {
                    byte[] first_pkt = last_qstarz_packet_buffers.get(0);
                    byte[] second_pkt = last_qstarz_packet_buffers.get(1);
                    byte[] third_pkt = last_qstarz_packet_buffers.get(2);
                    byte[] fourth_pkt = last_qstarz_packet_buffers.get(3);
                    if (
                            first_pkt.length == 20 && (first_pkt[0] == 1 || first_pkt[0] == 2 || first_pkt[0] == 3) /* fix quality is only 1, 2 or 3 */
                            && (third_pkt.length >= 18 && (third_pkt[16] == 0) && (third_pkt[17] == 0))
                    ) {
                        try {
                            ByteArrayOutputStream pkt = new ByteArrayOutputStream();
                            pkt.write(first_pkt);
                            pkt.write(second_pkt);
                            pkt.write(third_pkt);
                            if (third_pkt.length == 20 && (third_pkt[18] == 0) && (third_pkt[19] == 0)) {
                                pkt.write(fourth_pkt);
                                last_qstarz_packet_buffers.clear();
                            } else {
                                last_qstarz_packet_buffers.remove(0);
                                last_qstarz_packet_buffers.remove(0);
                                last_qstarz_packet_buffers.remove(0);
                            }
                            byte[] pkt_bytes = pkt.toByteArray();
                            //Log.d(TAG, "got qstarz pkt len: "+pkt.size()+" pkt hex: "+toHexString(pkt_bytes));
                            String ret_json = parse_qstarz_pkt(pkt_bytes);
                            //Log.d(TAG, "got parse_qstarz_pkt ret: "+ret_json);
                            JSONObject object = new JSONObject(ret_json);
                            m_rfcomm_to_tcp_callbacks.on_read_object(object);

                        } catch (Exception e) {
                            Log.d(TAG, "WARNING: assemble qstarz packet exception: "+Log.getStackTraceString(e));
                        }
                    }
                }
            }
        }
    };

}
