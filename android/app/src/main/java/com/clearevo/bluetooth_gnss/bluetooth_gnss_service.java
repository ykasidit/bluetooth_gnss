package com.clearevo.bluetooth_gnss;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.Intent;
import android.os.Binder;
import android.os.IBinder;
import android.util.Log;
import android.widget.Toast;
import com.clearevo.libecodroidbluetooth.*;


public class bluetooth_gnss_service extends Service implements rfcomm_conn_callbacks {

    static final String TAG = "btgnss_service";

    rfcomm_conn_mgr g_rfcomm_mgr = null;
    public nmea_parser m_nmea_parser = new nmea_parser();

    final String EDG_DEVICE_PREFIX = "EcoDroidGPS";

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // If we get killed, after returning from here, restart
        Log.d(TAG, "onStartCommand");

        if (intent != null) {
            String bdaddr = intent.getStringExtra("bdaddr");
            if (bdaddr == null) {
                String msg = "Target Bluetooth device not specifed - cannot connect...";
                Log.d(TAG, msg);
                toast(msg);
            } else {
                Log.d(TAG, "onStartCommand got bdaddr");
                int start_ret = connect(bdaddr);
                if (start_ret == 0) {
                    start_foreground();
                }
            }
        } else {
            String msg = "Target Bluetooth device not specifed - null intent - cannot connect...";
            Log.d(TAG, msg);
            toast(msg);
        }
        return START_REDELIVER_INTENT;
    }

    Thread m_connecting_thread = null;

    int connect(String bdaddr)
    {
        int ret = -1;

        try {

            if (m_connecting_thread != null && m_connecting_thread.isAlive()) {
                toast("connection already ongoing - please wait...");
                return 1;
            } else if (g_rfcomm_mgr != null && g_rfcomm_mgr.is_bt_connected()) {
                toast("already connected - press Back to disconnect and exit...");
                return 2;
            } else {
                toast("connecting to: "+bdaddr);
                if (g_rfcomm_mgr != null) {
                    g_rfcomm_mgr.close();
                }
                BluetoothDevice dev = BluetoothAdapter.getDefaultAdapter().getRemoteDevice(bdaddr);
                if (dev == null) {
                    toast("Please pair your Bluetooth GPS Receiver in phone Bluetooth Settings...");
                    throw new Exception("no paired bluetooth devices...");
                } else {
                    //ok
                }
                Log.d(TAG, "using dev: " + dev.getAddress());
                g_rfcomm_mgr = new rfcomm_conn_mgr(dev, this);

                m_connecting_thread = new Thread() {
                    public void run() {
                        try {
                            g_rfcomm_mgr.connect();
                        } catch (Exception e) {
                            Log.d(TAG, "g_rfcomm_mgr connect exception: "+Log.getStackTraceString(e));
                        }
                    }
                };

                m_connecting_thread.start();

            }
            ret = 0;
        } catch (Exception e) {
            String emsg = Log.getStackTraceString(e);
            Log.d(TAG, "connect() exception: "+emsg);
            toast("Connect failed: "+emsg);
        }

        return ret;
    }

    void close()
    {
        if (g_rfcomm_mgr != null) {
            g_rfcomm_mgr.close();
        }
    }

    void toast(String msg)
    {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
        Log.d(TAG, "toast msg: "+msg);
    }

    public void on_rfcomm_connected()
    {
        Log.d(TAG, "on_rfcomm_connected()");
    }

    public void on_rfcomm_disconnected()
    {
        Log.d(TAG, "on_rfcomm_disconnected()");
    }

    public void on_readline(String readline)
    {
        Log.d(TAG, "on_readline()");
        m_nmea_parser.parse(readline);
    }

    public void on_readline_stream_connected()
    {
        Log.d(TAG, "on_readline_stream_connected()");
    }

    public void on_readline_stream_closed()
    {
        Log.d(TAG, "on_readline_stream_closed()");
    }

    public void on_target_tcp_connected(){}
    public void on_target_tcp_disconnected(){}


    @Override
    public void onCreate() {
        super.onCreate();
    }

    void start_foreground()
    {
        Log.d(TAG, "start_forgroud 0");
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent =
                PendingIntent.getActivity(this, 0, notificationIntent, 0);

        String channel_id = "BLUETOOTH_GNSS_CHANNEL_ID";
        NotificationManager mNotificationManager =
                (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(channel_id,
                    "BLUETOOTH_GNSS",
                    NotificationManager.IMPORTANCE_DEFAULT);
            channel.setDescription("Bluetooth GNSS Status");
            mNotificationManager.createNotificationChannel(channel);
        }

        Notification notification =
                new Notification.Builder(this, channel_id)
                        .setContentTitle("Bluetooth GNSS")
                        .setContentText("text")
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentIntent(pendingIntent)
                        .setTicker("ticker")
                        .build();

        startForeground(1, notification);
        Log.d(TAG, "start_forgroud end");
    }


    // Binder given to clients
    private final IBinder m_binder = new LocalBinder();

    /**
     * Class used for the client Binder.  Because we know this service always
     * runs in the same process as its clients, we don't need to deal with IPC.
     */
    public class LocalBinder extends Binder {
        bluetooth_gnss_service getService() {
            // Return this instance of LocalService so clients can call public methods
            return bluetooth_gnss_service.this;
        }
    }


    @Override
    public IBinder onBind(Intent intent) {
        // We don't provide binding, so return null
        return m_binder;
    }

    @Override
    public void onDestroy() {
        close();
        Toast.makeText(this, "Bluetooth GNSS stopped...", Toast.LENGTH_SHORT).show();
    }
}