package com.clearevo.libbluetooth_gnss_service;

import java.io.BufferedInputStream;
import java.io.Closeable;
import java.io.File;
import java.io.InputStream;
import java.util.concurrent.ConcurrentLinkedQueue;


public class inputstream_to_queue_reader_thread extends Thread implements Closeable {

    int n_read;
    InputStream m_is;
    ConcurrentLinkedQueue<byte[]> m_queue;

    final String TAG = "btgnss_istqrt";

    public static final int MAX_READ_BUF_SIZE = 100_000;
    byte[] m_read_buffer = new byte[MAX_READ_BUF_SIZE];

    String wk = "kasidit_yak_pai_wangkeaw_leaw_na";
    private File debug_file_flag = new File("/sdcard/debug_"+this.getClass().getSimpleName());
    boolean m_debug_mode = debug_file_flag.exists();


    //read to queue mode
    public inputstream_to_queue_reader_thread(InputStream is, ConcurrentLinkedQueue<byte[]> queue) throws Exception
    {
        assert is != null;
        m_is = is;
        m_queue = queue;

    }

    public void close()
    {
        Log.d(TAG,"close()");
        try {
            m_is.close();
        } catch (Exception e) {
        }
        m_is = null;

        this.interrupt();
        m_queue = null;
    }


    @Override
    public void run()
    {
        Log.d(TAG, "thread start");
        try {

            boolean read_buff_mode = true;
            Log.d(TAG, "read_buff_mode: "+read_buff_mode);

            {
                m_queue = null;
            }

            int loop = 0;

            while (true) {

                if (read_buff_mode) {

                    /*
                    DONT use 'readers' that do readline() as they return strings and this 'encodes' our raw packets which are changed when we do .getbytes('ascii') later
                    so use pusbackinputstreams and read until we get 0d 0a instead...
                    */
                    //Log.d(TAG, "loop: "+loop+" m_is avail: "+m_is.available()+" m_bis avail: "+m_bis.available());

                    byte[] cb_read_buff = null;
                    cb_read_buff = bytes_read(m_is, m_read_buffer);

                    if (cb_read_buff == null) {
                        //Log.d(TAG, "read got null - means read from socket failed - break now - m_bis available len: "+m_bis.available());
                        break;
                    } else {
                        try {
                            //Log.d(TAG, "read not null len: " + cb_read_buff.length + " m_bis available len: " + m_bis.available());
                        } catch (Exception e) {}
                    }

                    if (m_debug_mode) {
                        try {
                            Log.d(TAG, new String(cb_read_buff, "ascii"));
                        } catch (Exception e) {
                            Log.d(TAG, "log.d exception: " + Log.getStackTraceString(e));
                        }
                    }

                } else {
                    byte[] read_tmp_buff = new byte[MAX_READ_BUF_SIZE];
                    n_read = m_is.read(read_tmp_buff);
                    if (n_read > 0) {
                        byte[] buf = new byte[n_read];
                        System.arraycopy(read_tmp_buff, 0, buf, 0, n_read);

                        if (m_debug_mode) {
                            try {
                                Log.d(TAG, new String(buf, "ascii"));
                            }catch (Exception e) {Log.d(TAG, "log.d exception: "+Log.getStackTraceString(e));}
                        }


                        if (m_queue != null) {
                            m_queue.add(buf);
                        }
                    }
                    if (n_read <= 0) {
                        throw new Exception("invalid n_read reading from input stream: " + n_read);
                    }
                }

                loop++;
            }
        } catch (Exception e) {
            if (m_queue != null) { //dont log exception if close() already
                Log.d(TAG, "inputstream_to_queue_reader_thread ending with exception: " + Log.getStackTraceString(e));
            }
        } finally {
            close();
        }
        Log.d(TAG, "thread ended");
    }

    static public byte[] bytes_read(InputStream bis, byte[] tmp_read_buffer) throws Exception
    {
        int n_read = bis.read(tmp_read_buffer);
        if (n_read > 0) {
            byte[] buf = new byte[n_read];
            System.arraycopy(tmp_read_buffer, 0, buf, 0, n_read);
            return buf;
        }
        return null;
    }
}
