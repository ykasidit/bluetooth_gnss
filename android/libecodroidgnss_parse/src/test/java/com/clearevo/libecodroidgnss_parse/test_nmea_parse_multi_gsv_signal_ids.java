package com.clearevo.libecodroidgnss_parse;

import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.util.HashMap;

/**
 * Example local unit test, which will execute on the development machine (host).
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
public class test_nmea_parse_multi_gsv_signal_ids {

    @Test
    public void test() throws Exception {

        String[] nmeas = {
                "$GNRMC,034152.00,A,3607.9701510,S,14655.8342969,E,0.015,,191021,,,R,V*14",
                "$GPGSV,3,1,12,05,38,133,24,10,07,326,34,12,02,015,29,13,18,092,24,1*62",
                "$GPGSV,3,2,12,15,30,061,32,18,58,238,19,20,09,136,10,23,40,331,25,1*6F",
                "$GPGSV,3,3,12,25,27,352,42,26,32,243,26,29,69,092,27,50,43,328,37,1*66",
                "$GPGSV,2,1,05,10,07,326,23,23,40,331,25,25,27,352,34,26,32,243,19,6*6F",
                "$GPGSV,2,2,05,29,69,092,14,6*5C",
                "$GPGSV,1,1,02,16,07,216,,41,12,286,,0*68",
                "$GNRMC,034152.00,A,3607.9701510,S,14655.8342969,E,0.015,,191021,,,R,V*14"
        };
        gnss_sentence_parser parser = new gnss_sentence_parser();
        int n_sats = 0;

        //simulate first set
        for (String nmea : nmeas) {
            parser.parse(nmea.getBytes("ascii"));
        }
        HashMap<String, Object> params = parser.get_params();
        for (String key : params.keySet()) {
            System.out.println("param key: "+key+" val: "+params.get(key));
        }
        n_sats = (Integer) params.get("GP_n_sats_in_view");
        System.out.println("n_sats: "+n_sats);
        assertTrue(n_sats == 14);
        assertTrue(params.get("GP_gsv_signal_id_list_str").equals("[1, 6, 0]"));


        //simulate second set of less sats
        nmeas = new String[]{
                "$GNRMC,034152.00,A,3607.9701510,S,14655.8342969,E,0.015,,191021,,,R,V*14",
                "$GPGSV,3,1,12,05,38,133,24,10,07,326,34,12,02,015,29,13,18,092,24,1*62",
                "$GPGSV,3,2,12,15,30,061,32,18,58,238,19,20,09,136,10,23,40,331,25,1*6F",
                "$GPGSV,3,3,12,25,27,352,42,26,32,243,26,29,69,092,27,50,43,328,37,1*66",
                "$GPGSV,2,1,05,10,07,326,23,23,40,331,25,25,27,352,34,26,32,243,19,6*6F",
                "$GPGSV,2,2,05,29,69,092,14,6*5C",
                "$GNRMC,034152.00,A,3607.9701510,S,14655.8342969,E,0.015,,191021,,,R,V*14"
        };
        for (String nmea : nmeas) {
            parser.parse(nmea.getBytes("ascii"));
        }
        params = parser.get_params();
        n_sats = (Integer) params.get("GP_n_sats_in_view");
        System.out.println("n_sats: "+n_sats);
        assertTrue(n_sats == 12);
        assertTrue(params.get("GP_gsv_signal_id_list_str").equals("[1, 6]"));


        //geoff example 1 assert
        nmeas = new String[]{
                "$GPGSV,3,1,09,01,42,301,33,03,54,212,30,04,34,241,26,09,05,260,29,1*69",
                "$GPGSV,3,2,09,16,29,035,36,21,28,336,34,22,82,207,26,26,41,078,34,1*69",
                "$GPGSV,3,3,09,31,36,141,32,1*5F",
                "$GPGSV,2,1,06,01,42,301,31,03,54,212,30,04,34,241,26,09,05,260,27,6*6C",
                "$GPGSV,2,2,06,26,41,078,28,31,36,141,18,6*6B",
                "$GNRMC,034152.00,A,3607.9701510,S,14655.8342969,E,0.015,,191021,,,R,V*14"
        };
        for (String nmea : nmeas) {
            parser.parse(nmea.getBytes("ascii"));
        }
        params = parser.get_params();
        n_sats = (Integer) params.get("GP_n_sats_in_view");
        System.out.println("n_sats: "+n_sats);
        assertTrue(n_sats == 9);
        assertTrue(params.get("GP_gsv_signal_id_list_str").equals("[1, 6]"));


        //geoff example 2 assert
        nmeas = new String[]{
                "$GLGSV,3,1,09,65,36,103,20,66,43,186,17,67,08,228,31,75,29,145,27,1*74",
                "$GLGSV,3,2,09,76,70,067,21,77,33,353,26,81,17,281,26,82,12,233,27,1*7B",
                "$GLGSV,3,3,09,88,05,330,17,1*42",
                "$GLGSV,2,1,08,65,36,103,12,66,43,186,29,67,08,228,32,75,29,145,20,3*7E",
                "$GLGSV,2,2,08,76,70,067,25,77,33,353,29,81,17,281,25,82,12,233,17,3*72",
                "$GLGSV,1,1,01,72,00,072,,0*48",
                "$GNRMC,034152.00,A,3607.9701510,S,14655.8342969,E,0.015,,191021,,,R,V*14"
        };
        for (String nmea : nmeas) {
            parser.parse(nmea.getBytes("ascii"));
        }
        params = parser.get_params();
        n_sats = (Integer) params.get("GL_n_sats_in_view");
        System.out.println("GL n_sats: "+n_sats);
        assertTrue(n_sats == 10);
        assertTrue(params.get("GL_gsv_signal_id_list_str").equals("[1, 3, 0]"));


    }
}
