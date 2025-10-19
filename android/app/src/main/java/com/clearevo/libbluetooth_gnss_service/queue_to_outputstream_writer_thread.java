package com.clearevo.libbluetooth_gnss_service;


import java.io.Closeable;
import java.io.OutputStream;
import java.util.concurrent.ConcurrentLinkedQueue;


public class queue_to_outputstream_writer_thread extends Thread implements Closeable {

    ConcurrentLinkedQueue<byte[]> m_queue;
    OutputStream m_os;
    final String TAG = "btgnss_qtowt";
    public static final int SLEEP_IF_NO_DATA_MILLIS = 1;

    public queue_to_outputstream_writer_thread(ConcurrentLinkedQueue<byte[]> queue, OutputStream os)
    {
        m_queue = queue;
        m_os = os;
    }

    public void close()
    {
        Log.d(TAG,"close()");
        try {
            m_os.close();
        } catch (Exception e) {
        }
        m_os = null;
        m_queue = null;
        this.interrupt();

    }

    public void run()
    {
        Log.d(TAG, "queue_to_outputstream_writer_thread "+hashCode()+" start");
        try (this) {
            while (true) {
                //System.out.println("m_queue poll pre poll");
                byte[] out_buf = m_queue.poll();
                //Log.d(TAG,"queue_to_outputstream_writer_thread: m_queue poll buf:" + out_buf);
                if (out_buf != null && out_buf.length > 0) {
                    m_os.write(out_buf);
                }
            }
        } catch (Exception e) {
            if (m_queue != null) { //dont log exception if close() already
                Log.d(TAG, "queue_to_outputstream_writer_thread thread ending with exception: " + Log.getStackTraceString(e));
            }
        } finally {
            Log.d(TAG, "queue_to_outputstream_writer_thread "+hashCode()+" done");
        }
        Log.d(TAG, "inputstream_to_queue_reader_thread "+hashCode()+" end");
    }
}
