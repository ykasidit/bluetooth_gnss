package com.clearevo.libbluetooth_gnss_service;

import net.sf.marineapi.nmea.parser.SentenceFactory;
import net.sf.marineapi.nmea.sentence.GGASentence;
import net.sf.marineapi.nmea.sentence.TalkerId;
import net.sf.marineapi.nmea.util.Position;

import org.junit.Test;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.util.HashMap;

import static org.junit.Assert.assertTrue;

/**
 * Example local unit test, which will execute on the development machine (host).
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
public class test_nmea_parse_case1 {

    @Test
    public void test_badelf_gps_pro_plus() throws Exception {
        String[] nmeas = {
                "$GPRMC,074955.000,A,0641.0037,N,10139.4031,E,0.14,118.40,101223,,,D*60",
        };

        gnss_sentence_parser parser = new gnss_sentence_parser();
        for (String nmea : nmeas) {
            parser.parse(nmea.getBytes("ascii"));
        }

        HashMap<String, Object> params = parser.get_params();
        for (String key : params.keySet()) {
            System.out.println("param key: "+key+" val: "+params.get(key));
        }


    }
    @Test
    public void test() throws Exception {
        String[] nmeas = {
                "$GNGSA,A,3,26,31,10,32,14,16,25,20,18,22,41,,1.34,0.74,1.12*16\n",
                "$GNGSA,A,3,73,80,70,,,,,,,,,,1.34,0.74,1.12*10",
                "$GNRMC,020125.00,A,1845.82207,N,09859.94984,E,0.027,,101219,,,F,V*1A",
        };


        gnss_sentence_parser parser = new gnss_sentence_parser();
        String fp = "/home/kasidit/Downloads/2022-02-21_10-00-31_rx_log.txt";
        File f = new File(fp);
        if (f.exists()) {
            FileInputStream fin = new FileInputStream(f);
            BufferedReader br = new BufferedReader(new InputStreamReader(fin));
            String nmea;
            while (true) {
                nmea = br.readLine();
                if (nmea == null)
                    break;
                parser.parse(nmea.getBytes("ascii"));
            }
            HashMap<String, Object> params = parser.get_params();
            for (String key : params.keySet()) {
                System.out.println("param key: "+key+" val: "+params.get(key));
            }
            double speed = (double) params.get("GN_speed");
            System.out.println("speed: "+speed);

            String[] SATS_USED_KEYS = new String[]{"GP_n_sats_used", "GL_n_sats_used", "GA_n_sats_used", "GB_n_sats_used", "GQ_n_sats_used"};
            for (String key : SATS_USED_KEYS) {
                System.out.println("satkey "+key+" val "+params.get(key));
            }
            //assertTrue(speed == 0.0);
        }


        for (String nmea : nmeas) {
            parser.parse(nmea.getBytes("ascii"));
        }

        HashMap<String, Object> params = parser.get_params();
        for (String key : params.keySet()) {
            System.out.println("param key: "+key+" val: "+params.get(key));
        }


    }
}
