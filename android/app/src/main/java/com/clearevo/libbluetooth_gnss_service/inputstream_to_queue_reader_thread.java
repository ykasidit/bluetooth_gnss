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

    public static final int MAX_READ_BUF_SIZE = 500_000;
    byte[] m_read_buffer = new byte[MAX_READ_BUF_SIZE];
    public static final int BUFFERED_INPUTSTREAM_SIZE = 10 * MAX_READ_BUF_SIZE;
    public static final byte[] CRLF = {0x0D, 0x0A};

    readline_callbacks m_readline_cb;
    read_buff_callbacks m_read_buff_cb;

    BufferedInputStream m_bis;
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

    //readline to callback mode
    public inputstream_to_queue_reader_thread(InputStream is, readline_callbacks cb)
    {
        assert is != null;
        m_is = is;

        m_readline_cb = cb;
    }

    //read_buff to callback mode
    public inputstream_to_queue_reader_thread(InputStream is, read_buff_callbacks cb)
    {
        assert is != null;
        m_is = is;

        m_read_buff_cb = cb;
    }

    public void close()
    {
        Log.d(TAG,"close()");
        try {
            m_is.close();
        } catch (Exception e) {
        }
        m_is = null;

        try {
            if (m_bis != null) {
                m_bis.close();
            }
        } catch (Exception e) {
        }
        m_bis = null;

        this.interrupt();
        m_queue = null;
    }


    @Override
    public void run()
    {
        Log.d(TAG, "thread start");
        try {

            boolean readline_mode = false;
            boolean read_buff_mode = false;
            if (m_readline_cb != null) {
                readline_mode = true;
            } else if (m_read_buff_cb != null) {
                read_buff_mode = true;
            }
            Log.d(TAG, "readline_mode: "+readline_mode);
            Log.d(TAG, "read_buff_mode: "+read_buff_mode);

            if (readline_mode || read_buff_mode) {
                m_queue = null;
                m_bis = new BufferedInputStream(m_is, BUFFERED_INPUTSTREAM_SIZE);
            }

            int loop = 0;

            while (true) {

                if (readline_mode || read_buff_mode) {

                    /*
                    DONT use 'readers' that do readline() as they return strings and this 'encodes' our raw packets which are changed when we do .getbytes('ascii') later
                    so use pusbackinputstreams and read until we get 0d 0a instead...
                    */
                    //Log.d(TAG, "loop: "+loop+" m_is avail: "+m_is.available()+" m_bis avail: "+m_bis.available());

                    byte[] cb_read_buff = null;
                    if (readline_mode)
                        cb_read_buff = bytes_readline(m_bis, m_read_buffer);
                    else
                        cb_read_buff = bytes_read(m_bis, m_read_buffer);

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

                    if (readline_mode)
                        m_readline_cb.on_readline(cb_read_buff); //if buffer is full then this thread will end and exception logged, conn closed so conn watcher would trigger disconnected stage so user would know somethings wrong anyway...
                    else {
                        if (m_read_buff_cb != null) {
                            m_read_buff_cb.on_read(cb_read_buff);
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


    static public byte[] bytes_readline(InputStream bis, byte[] tmp_read_buffer) throws Exception
    {
        final int read_buffer_max_len = tmp_read_buffer.length;
        int read;
        for (int i = 0; i < read_buffer_max_len; i++) {
            read = bis.read();
            if (read == -1) {
                return null;
            }
            tmp_read_buffer[i] = (byte) read;
            if (i > 0 && tmp_read_buffer[i] == CRLF[1] && tmp_read_buffer[i-1] == CRLF[0]) {
                //ok we got CRLF now so copy and return a new array until this position
                final int total_read_bytes = i+1;
                byte[] readline_buffer = new byte[total_read_bytes];
                System.arraycopy(tmp_read_buffer, 0, readline_buffer, 0, total_read_bytes);
                return readline_buffer;
            }
        }
        return null;
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


    /* too complex and seems to have a performance bug and skipping data too - dont use it

    //NOTE: below func can fail with a full pushback buffer full - handle its exception accordingly
    public static byte[] bytes_readline(PushbackInputStream pb_is, byte[] read_buffer) throws Exception
    {
        return bytes_read_until_sequence(pb_is, CRLF, read_buffer);
    }


    public static byte[] bytes_read_until_sequence(PushbackInputStream pb_is, byte[] suffix_sequence, byte[] read_buffer) throws Exception
    {
        if (suffix_sequence.length == 0) {
            throw new Exception("invalid suffix_sequence.length == 0 supplied");
        }

        int nread = pb_is.read(read_buffer);

        try {
            Log.d("btgnssitq", "bytes_read_until_sequence read_buffer string: " + new String(read_buffer, 0, nread, "ascii"));
        } catch (Exception e) {}

        int crlf_end_pos = -1;
        int suffix_seq_len = suffix_sequence.length;
        for (int i = 0; i < nread; i++) {

            if (i >= suffix_seq_len-1) {
                for (int j = 0; j < suffix_seq_len; j++) {
                    if (read_buffer[i-j] == suffix_sequence[suffix_seq_len-1-j]) {
                        if (j == suffix_seq_len-1) {
                            crlf_end_pos = i;
                            break;
                        } else {
                            continue;
                        }
                    } else {
                        break;
                    }
                }
                if (crlf_end_pos != -1)
                    break;
            }
        }

        //System.out.println("crlf_end_pos: "+crlf_end_pos);
        //if cant find crlf the unread this buffer
        if (crlf_end_pos == -1) {
            if (read_buffer != null) {
                pb_is.unread(read_buffer);
            }
            return null;
        }

        //if read pos is last in buffer already so no need to push back - just deliver whole buffer
        if (crlf_end_pos == read_buffer.length-1) {
            return read_buffer;
        } else {
            //read pos is not last so deliver up to and including crlf and push back the rest
            int readline_buffer_len = crlf_end_pos+1;  //yes, length is offset+1
            byte[] readline_buffer = new byte[readline_buffer_len];
            System.arraycopy(read_buffer, 0, readline_buffer, 0, readline_buffer_len); //yes, length is offset+1
            int remainder_len = read_buffer.length - readline_buffer_len;
            //recheck just to be sure and future proof...
            if (remainder_len > 0) {
                byte[] pushback_buffer = new byte[remainder_len];
                System.arraycopy(read_buffer, crlf_end_pos+1, pushback_buffer, 0, remainder_len);
                pb_is.unread(pushback_buffer);
            }
            return readline_buffer;
        }
    }

     */
}
