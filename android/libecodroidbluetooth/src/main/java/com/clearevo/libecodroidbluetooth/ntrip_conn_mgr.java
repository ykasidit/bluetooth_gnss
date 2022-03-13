package com.clearevo.libecodroidbluetooth;
import android.util.Log;

import java.io.Closeable;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedQueue;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;


public class ntrip_conn_mgr {

    static final int CONNECT_TIMEOUT_MILLIS = 10*1000;
    static final int CONNECTED_SOCKET_OPERATION_TIMEOUT_MILLIS = 20*1000;
    static final int HTTP_HEADER_READ_TIMEOUT_MILLIS = 10*1000;
    static final int SOURCETABLE_READ_TIMEOUT_MILLIS = 10*1000;

    static final String SOURCETABLE_STR = " 200 OK";
    static final String END_SOURCETABLE_STR = "ENDSOURCETABLE";
    static final String ICY_STR = "ICY 200 OK";
    static final String HTTP_RESPONSE_HEADER_END_FLAG = "\r\n"; //CRLF on its own line signals end of header
    static final String HTTP_200_OK_STR = "200 OK";
    static final int MAX_HTTP_HEADER_LINES = 100;
    static final int MAX_SOURCETABLE_LINES = 10*1000;

    String m_tcp_server_host;
    int m_tcp_server_port;

    InputStream m_sock_is;
    OutputStream m_sock_os;
    Socket m_tcp_server_sock;
    List<Closeable> m_cleanup_closables;
    Thread m_conn_state_watcher;
    ArrayList<String> m_http_response_header_lines;
    String m_http_response_header_str;
    ConcurrentLinkedQueue<byte[]> m_incoming_buffers;
    static final String TAG = "btgnss_ntripmgr";
    volatile private boolean closed = false;

    ntrip_conn_callbacks m_cb;
    String m_user;
    String m_pass;
    String m_mount_point;

    public ntrip_conn_mgr(String tcp_server_host, final int tcp_server_port, String mount_point, String user, String pass, ntrip_conn_callbacks cb) throws Exception
    {
        m_cb = cb;

        m_tcp_server_host = tcp_server_host;
        m_tcp_server_port = tcp_server_port;

        m_user = user;
        m_pass = pass;

        if (mount_point == null)
            throw new Exception("mount_point must not be null - use empty string for get_mount_point_list() target use cases");

        m_mount_point = mount_point;

        m_cleanup_closables = new ArrayList<Closeable>();
        m_incoming_buffers = new ConcurrentLinkedQueue<byte[]>();
    }

    public ArrayList<String> get_mount_point_list() throws Exception
    {
        m_mount_point = ""; //use empty for get sourcetable
        ArrayList<String> mpl = connect_or_get_mount_point_list(true);
        return mpl;
    }

    public void connect() throws Exception
    {
        connect_or_get_mount_point_list(false);
    }

    public void send_buff_to_server(byte[] buff) throws Exception
    {
        m_sock_os.write(buff);
    }

    public ArrayList<String> connect_or_get_mount_point_list(boolean get_mount_point_list) throws Exception
    {
        Log.d(TAG, "connect() start");

        if (closed) {
            throw new Exception("this instance was already closed - please used a new() instance");
        }



        try {

            //for a doc on an example of the spec - see http://www.wsrn3.org/CONTENT/Reference/Reference_NTRIP-V1-Tech-paper.pdf
            //An example implementation can be studied from: https://github.com/OneStopTransport/api-ntrip-java-client/blob/master/NTRIPLib/src/com/ntrip/NTRIPService.java - I hereby give full credit and respect to its authors...

            //open client socket to target tcp server
            Log.d(TAG, "start opening tcp socket to host: " + m_tcp_server_host + " port: " + m_tcp_server_port);

            InetSocketAddress sock_addr = new InetSocketAddress(m_tcp_server_host, m_tcp_server_port);
            if (m_tcp_server_port == 443) {
                Log.d(TAG, "using ssl conn for specified port 443");
                SSLSocketFactory sslsocketfactory = (SSLSocketFactory) SSLSocketFactory.getDefault();
                SSLSocket sslsocket = (SSLSocket) sslsocketfactory.createSocket(m_tcp_server_host, m_tcp_server_port);
                m_tcp_server_sock = sslsocket;
            } else {
                m_tcp_server_sock = new Socket();
                m_tcp_server_sock.connect(sock_addr, CONNECT_TIMEOUT_MILLIS);
            }
            if (!m_tcp_server_sock.isConnected())
                throw new Exception("connect failed");
            try {
                if (m_cb != null) {
                    m_cb.on_target_tcp_connected();
                }
            } catch (Exception e) {
                Log.d(TAG, "callback on_tcp_connected exception: "+Log.getStackTraceString(e));
            }

            //now we're connected
            m_tcp_server_sock.setSoTimeout(CONNECTED_SOCKET_OPERATION_TIMEOUT_MILLIS);

            m_sock_is = m_tcp_server_sock.getInputStream();
            m_sock_os = m_tcp_server_sock.getOutputStream();
            m_cleanup_closables.add(m_sock_is);
            m_cleanup_closables.add(m_sock_os);
            Log.d(TAG, "done opening tcp socket to host: " + m_tcp_server_host + " port: " + m_tcp_server_port +" m_mount_point: "+m_mount_point);


            String request_msg = gen_http_request_msg(m_mount_point, m_user, m_pass);
            Log.d(TAG, "request_msg: "+request_msg);
            m_sock_os.write(request_msg.getBytes("ascii"));

            //read HTTP Response header
            ArrayList<String> http_response_header_lines = read_is_get_lines_until(m_sock_is, HTTP_RESPONSE_HEADER_END_FLAG, MAX_HTTP_HEADER_LINES, HTTP_HEADER_READ_TIMEOUT_MILLIS);
            if (http_response_header_lines.size() ==  0) {
                throw new Exception("failed to read http response header...");
            }
            m_http_response_header_lines = http_response_header_lines;
            m_http_response_header_str = array_list_string_concat(m_http_response_header_lines);

            //if control reaches here means http_response_header_lines.size() > 0 so get directly
            String resp_header_first_line = http_response_header_lines.get(0);

            //handle the read http response headers...
            boolean resp_header_first_line_says_ok = resp_header_first_line.contains(HTTP_200_OK_STR) || resp_header_first_line.contains(ICY_STR);
            if (resp_header_first_line_says_ok) {
                Log.d(TAG, "resp_header_first_line_says_ok");
            } else {
                throw new Exception("non-successful ntrip server resp_header_first_line: " + resp_header_first_line);
            }

            //From here on the inputstream is pointing at the HTTP BODY

            if (get_mount_point_list) {

                //read sourcetable and return here in this if block
                if (!resp_header_first_line.contains(SOURCETABLE_STR))
                    throw new Exception("get_mount_point_list failed as server resp_header_first_line: ["+resp_header_first_line+"] does not contain: ["+SOURCETABLE_STR+"] - resp_header_first_line: " + resp_header_first_line);

                ArrayList<String> sourcetable_lines = read_is_get_lines_until(m_sock_is, END_SOURCETABLE_STR, MAX_SOURCETABLE_LINES, SOURCETABLE_READ_TIMEOUT_MILLIS);
                Collections.sort(sourcetable_lines);
                return sourcetable_lines;

            } else {

                //follow through to start inputstream_to_queue_reader_thread which will return data buffers read via callbacks...
                if (!resp_header_first_line.contains(ICY_STR))
                    throw new Exception("connect to mount_point failed as server resp_header_first_line does not contain: ["+ICY_STR+"] - resp_header_first_line: " + resp_header_first_line);

            }

            // if control reaches here means we are in mountpoint connect mode...

            //start thread to read from socket to incoming_buffer
            inputstream_to_queue_reader_thread incoming_thread = new inputstream_to_queue_reader_thread(m_sock_is, m_cb);
            m_cleanup_closables.add(incoming_thread);
            incoming_thread.start();

            if (incoming_thread.isAlive() == false)
                throw new Exception("incoming_thread died - not opening client socket...");

            final inputstream_to_queue_reader_thread sock_is_reader_thread = incoming_thread;

            //watch ntrip socket state and both threads above
            m_conn_state_watcher = new Thread() {
                public void run() {
                    while (m_conn_state_watcher == this) {
                        try {

                            Thread.sleep(3000);

                            if (closed)
                                break; //if close() was called then dont notify on_bt_disconnected or on_target_tcp_disconnected

                            if (sock_is_reader_thread != null && sock_is_reader_thread.isAlive() == false) {
                                throw new Exception("sock_is_reader_thread died");
                            }
                        } catch (Exception e) {
                            if (e instanceof InterruptedException) {
                                Log.d(TAG, "m_conn_state_watcher ending with signal from close()");
                            } else {
                                Log.d(TAG, "m_conn_state_watcher ending with exception: " + Log.getStackTraceString(e));
                                try {
                                    if (m_cb != null) {
                                        m_cb.on_target_tcp_disconnected();
                                    }
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
        return null;
    }


    static String to_base64(String src) throws Exception
    {
        return Base64.encodeToString(src.getBytes("ascii"), Base64.CRLF);
    }


    public static String gen_http_request_msg(String get_path, String user, String pass) throws Exception
    {
        String request_msg = "GET /" + get_path + " HTTP/1.0\r\n";
        request_msg += "User-Agent: NTRIP Bluetooth-GNSS-Android-App-1.0\r\n";
        request_msg += "Accept: */*\r\n";
        request_msg += "Connection: close\r\n";
        if (user != null && pass != null) {
            String user_pass = user + ":" + pass;
            String user_pass_base64 = to_base64(user_pass);
            Log.d(TAG, "using auth base64: "+user_pass_base64);
            request_msg += "Authorization: Basic " + user_pass_base64;
        } else {
            Log.d(TAG, "not using Authrorization as no user or pass specified...");
        }
        request_msg += "\r\n";
        return request_msg;
    }

    public static ArrayList<String> read_is_get_lines_until(InputStream is, String end_flag, int max_lines_throw_thereafter, int timeout_millis) throws Exception
    {
        byte[] tmp_read_buf = new byte[inputstream_to_queue_reader_thread.MAX_READ_BUF_SIZE];
        ArrayList<String> lines = new ArrayList<String>();
        byte[] resp_line_bytes = null;
        while ((resp_line_bytes = inputstream_to_queue_reader_thread.bytes_readline(is, tmp_read_buf)) != null) {
            String read_line = new String(resp_line_bytes,  StandardCharsets.UTF_8);
            Log.d(TAG, "read_is_get_lines_until: "+read_line+" end_flag: "+end_flag);

            if (read_line.trim().endsWith(HTTP_200_OK_STR)) {
                lines.add(read_line);
                break;
            }

            if (read_line.equals(end_flag)) {
                break;
            }
            if (lines.size() > max_lines_throw_thereafter) {
                throw new Exception("invalid response - n lines > max_lines_throw_thereafter: "+max_lines_throw_thereafter);
            }

            lines.add(read_line);
        }

        return lines;
    }

    public static String array_list_string_concat(ArrayList<String> lines)
    {
        StringBuffer sb = new StringBuffer();
        for (String line: lines) {
            sb.append(line);
        }
        return sb.toString();
    }

    public boolean is_connected()
    {
        if (closed) {
            return false;
        }
        Log.d(TAG, "is_connected() m_conn_state_watcher: "+m_conn_state_watcher);
        Log.d(TAG, "is_connected() m_tcp_server_sock: "+m_tcp_server_sock);
        if (m_tcp_server_sock != null) {
            Log.d(TAG, "is_connected() m_tcp_server_sock.isConnected(): "+m_tcp_server_sock.isConnected());
        }
        if (m_conn_state_watcher != null) {
            Log.d(TAG, "is_connected() m_conn_state_watcher.isAlive(): "+m_conn_state_watcher.isAlive());
        }
        //return (m_conn_state_watcher != null && m_conn_state_watcher.isAlive() && m_tcp_server_sock != null && m_tcp_server_sock.isConnected());
        return (m_tcp_server_sock != null && m_tcp_server_sock.isConnected() && m_conn_state_watcher != null && m_conn_state_watcher.isAlive());
    }


    public void close()
    {
        Log.d(TAG, "close()");
        closed = true;

        if (m_conn_state_watcher != null) {
            try {
                m_conn_state_watcher.interrupt();
                m_conn_state_watcher = null;
            } catch (Exception e) {
            }
        }

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
