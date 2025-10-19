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
        m_queue = null;
        this.interrupt();
    }


    @Override
    public void run()
    {
        Log.d(TAG, "inputstream_to_queue_reader_thread "+hashCode()+" start");
        int loop = 0;
        try (this) {
            byte[] read_tmp_buff = new byte[MAX_READ_BUF_SIZE];

            while (true) {
                n_read = m_is.read(read_tmp_buff);
                if (n_read > 0) {
                    byte[] buf = new byte[n_read];
                    System.arraycopy(read_tmp_buff, 0, buf, 0, n_read);
                    if (m_debug_mode) {
                        try {
                            Log.d(TAG, new String(buf, "ascii"));
                        }catch (Exception e) {Log.d(TAG, "log.d exception: "+Log.getStackTraceString(e));}
                    }
                    m_queue.add(buf);
                }
                if (n_read <= 0) {
                    throw new Exception("invalid n_read reading from input stream: " + n_read);
                }
                loop++;
            }
        } catch (Exception e) {
            Log.d(TAG, "inputstream_to_queue_reader_thread loop "+loop+" ending with exception: " + Log.getStackTraceString(e));
        } finally {
            Log.d(TAG, "inputstream_to_queue_reader_thread "+hashCode()+" done");
        }
        Log.d(TAG, "inputstream_to_queue_reader_thread "+hashCode()+" end");
    }

}
