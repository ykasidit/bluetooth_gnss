package com.clearevo.libecodroidbluetooth;
import android.util.Log;

import org.junit.Test;

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Properties;

import okhttp3.Call;
import okhttp3.Credentials;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

import static com.clearevo.libecodroidbluetooth.ntrip_conn_mgr.TAG;
import static junit.framework.TestCase.assertTrue;


public class test_ntrip_conn_mgr implements ntrip_conn_callbacks{


    @Test
    public void test() throws Exception {

        /*

        Easy ntrip server account test with curl:
        ========================================


        List mount points - just use root path: /
        ------------------------------------------
        curl -v http://igs-ip.net:2101/ --header "Ntrip-Version: Ntrip/2.0" --header "User-Agent: NTRIP curl"



        Stream data from a specified mount point - use /<mount_point>
        --------------------------------------------------------------
        curl -v http://igs-ip.net:2101/ABMF0 -u user:password --header "Ntrip-Version: Ntrip/2.0" --header "User-Agent: NTRIP curl"
        (credit to https://gist.github.com/kralo/e3463c5432ab8d8251d0560858f28680 )

         */


        String host = null;
        int port = 0;
        String user = null;
        String pass = null;

        //make sure you write /etc/test_ntrip_conn_mgr.properties in a format like https://www.mkyong.com/java/java-properties-file-examples/

        boolean no_ntrip_cred = false;
        try (InputStream input = new FileInputStream("/etc/libbluetooth_gnss_test/test_ntrip_conn_mgr.properties")) {

            Properties prop = new Properties();
            prop.load(input);

            // get the property value and print it out
            host = prop.getProperty("host");
            port = Integer.parseInt(prop.getProperty("port"));
            user = prop.getProperty("user");
            pass = prop.getProperty("pass");

        } catch (IOException ex) {
            no_ntrip_cred = true;
            //host = "www.igs-ip.net";
            host = "caster.centipede.fr";
            port = 2101;

        }

        String first_mount_point = null;

        //test get mount point list with user/pass and without user/pass
        {
            ArrayList<String> mpl = null;
            ntrip_conn_mgr mgr = null;
            String[] test_mpl_users = {user};
            String[] test_mpl_passes = {pass};
            for (String mpl_user : test_mpl_users)
                for (String mpl_pass : test_mpl_passes) {
                    try {
                        mgr = new ntrip_conn_mgr(host, port, "", mpl_user, mpl_pass, this);
                        mpl = mgr.get_mount_point_list();
                        for (String mp : mpl) {
                            if (mp.startsWith("STR;")) {
                                first_mount_point = mp.split(";")[1];
                            }
                        }
                    } finally {
                        if (mgr != null)
                            mgr.close();
                    }
                    Log.d(TAG, "got mpl: " + mpl);
                    Log.d(TAG, "got mpl len: " + mpl.size());
                    assertTrue(mpl != null);
                    assertTrue(mpl.size() > 0);
                }
        }

        //test get mpl to wrong site must fail or timeout
        {
            ntrip_conn_mgr mgr = null;
            try {
                //use port+10 to use as a wrong server/port that would timeout
                mgr = new ntrip_conn_mgr(host, port+10, "", null, null, this);
                ArrayList<String> mpl = mgr.get_mount_point_list();
                throw new Exception("must not reach here - failed");
            } catch (java.net.SocketTimeoutException se) {
                //ok - correct
                System.out.println("ok wrong port timeed out correctly...");
            }
            catch (java.net.ConnectException ce) {
                //ok - correct
                System.out.println("ok connectexception...");
            } finally {
                if (mgr != null)
                    mgr.close();
            }

        }

        if (no_ntrip_cred)
            return;

        System.out.println("connecting to first_mount_point: "+first_mount_point);
        assertTrue(first_mount_point != null);
        //test conn to correct site
        {
            ntrip_conn_mgr mgr = null;
            try {
                mgr = new ntrip_conn_mgr(host, port, first_mount_point, user, pass, this);
                mgr.connect();

                Thread.sleep(5000);

            } finally {
                if (mgr != null)
                    mgr.close();
            }

            assertTrue(m_got_on_read_cb_count > 0);
        }

        //test conn to wrong site must fail or timeout


    }

    int m_got_on_read_cb_count = 0;

    @Override
    public void on_read(byte[] read_buff) {
        try {
            System.out.println("on_read: "+new String(read_buff, "ascii"));
        } catch (Exception e) {
            System.out.println("on_readline exception: "+ Log.getStackTraceString(e));
        }
        if (read_buff != null) {
            m_got_on_read_cb_count += 1;
        }
    }
    
    @Override
    public void on_target_tcp_connected() {
        System.out.println("on_target_tcp_connected");
    }

    @Override
    public void on_target_tcp_disconnected() {
        System.out.println("on_target_tcp_disconnected");
    }
}
