package com.clearevo.bluetooth_gnss;

import android.content.Context;
import android.content.Intent;
import android.util.Log;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.HashMap;


public class nmea_parser {

    public interface nmea_parser_callbacks {
        public void on_updated_nmea_params(HashMap<String, Object> params_map);
    }

    void set_callbacks(nmea_parser_callbacks cb){
        m_cb = cb;
    }

    nmea_parser_callbacks m_cb;
    final String TAG = "btgnss_nmea_p";
    final String NMEA_PREFIX = "$G";
    Context m_context;

    public static final String BROADCAST_ACTION_NMEA = "com.clearevo.bluetooth_gnss.NMEA";
    HashMap<String, Object> m_parsed_params_hashmap = new HashMap<String, Object>();

    void parse(String read_line) {
        String nmea = read_line;
        if (nmea != null && nmea.startsWith(NMEA_PREFIX)) {
            Intent intent = new Intent();
            intent.setAction(BROADCAST_ACTION_NMEA);
            intent.putExtra("NMEA",nmea);
            m_context.sendBroadcast(intent);

            //try parse this nmea and update our states
            try {
                if (is_gga(nmea)) {
                    int ret = parse_lat_lon(nmea);
                    if (ret == 0) {
                        if (m_cb != null) {
                            m_cb.on_updated_nmea_params(m_parsed_params_hashmap);
                        }
                    }
                }
            } catch (Exception e) {
                Log.d(TAG, "parse/update nmea params/callbacks exception: "+Log.getStackTraceString(e));
            }
        }
    }

    public boolean is_gga(String sentence) {
        if (sentence.length() > 5 && sentence.substring(3).startsWith("GGA"))
            return true;
        return false;
    }


    public int parse_lat_lon(String sentence) {
        int ret = -1;
        if (is_gga(sentence)) {
            String[] strValues = sentence.split(",");
            double latitude = Double.parseDouble(strValues[2])*.01;
            if (strValues[3].charAt(0) == 'S') {
                latitude = -latitude;
            }
            double longitude = Double.parseDouble(strValues[4])*.01;
            if (strValues[5].charAt(0) == 'W') {
                longitude = -longitude;
            }
            //double course = Double.parseDouble(strValues[8]);
            Log.d(TAG, "latitude="+latitude+" ; longitude="+longitude);

            m_parsed_params_hashmap.put("gga_lat", latitude);
            m_parsed_params_hashmap.put("gga_lon", longitude);
            m_parsed_params_hashmap.put("gga_ts", System.currentTimeMillis());

            ret = 0;
        }
        return ret;
    }

}
