package com.clearevo.libecodroidgnss_parse;

import android.util.Log;

import net.sf.marineapi.nmea.parser.SentenceFactory;
import net.sf.marineapi.nmea.sentence.GGASentence;
import net.sf.marineapi.nmea.sentence.TalkerId;
import net.sf.marineapi.nmea.util.Position;

import org.junit.Test;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStreamReader;

import static com.clearevo.libecodroidgnss_parse.gnss_sentence_parser.fromHexString;
import static com.clearevo.libecodroidgnss_parse.gnss_sentence_parser.toHexString;
import static org.junit.Assert.assertTrue;

public class test_ubx_mixed_nmea_parse {

    @Test
    public void test() throws Exception {

        SentenceFactory sf = SentenceFactory.getInstance();
        GGASentence gga = (GGASentence) sf.createParser(TalkerId.GN, "GGA");
        Position position = new Position(0.1, -0.2, 0.3);
        gga.setPosition(position);
        String example_nmea_gga = gga.toSentence();

        String[] test_hex_strings = {
                "B5 62 06 01 03 00 F1 00 01 FC 13",  // a ubx packet
                "B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A",  // a ubx packet + '140' ascii + crlf
                "B5 62 06 01 03 00 F1 00 01 FC 13 0D 0A B5 62 06 01 03 00 F1 00 01 FC 13",  // two ubx packets
                "B5 62 06 01 03 00 F1 00 01 FC 13 0A",  // two ubx packets + lf
                "31 34 30 0D 0A",
                toHexString(example_nmea_gga.getBytes("ascii"))
        };

        int[] assert_consumed_les = {
                11,
                11,
                24,
                11,
                0,
                0
        };

        int i = 0;
        for (String ori_hex_in : test_hex_strings) {

            //test pure ubx buffer parse
            byte[] example_line_buffer = fromHexString(ori_hex_in);
            int n_ubx_consumed = ubx_parser.ubx_parse_get_n_bytes_consumed(example_line_buffer);
            System.out.println("n_ubx_consumed: " + n_ubx_consumed);
            assertTrue(n_ubx_consumed == assert_consumed_les[i]);
            if (i == 5)
                assertTrue(example_nmea_gga.equals(new gnss_sentence_parser().parse(example_line_buffer)));
            else
                assertTrue(null == new gnss_sentence_parser().parse(example_line_buffer));

            //i == 5 is not ubx so below will fail
            if (i < 5) {
                System.out.println("start test ubx + nmea i: "+i);
                //test ubx buffer + valid nmea parse
                ByteArrayOutputStream baos = new ByteArrayOutputStream();
                baos.write(example_line_buffer);
                baos.write(example_nmea_gga.getBytes("ascii"));
                System.out.println("start test ubx + nmea i: "+i+"new parser");
                gnss_sentence_parser gp = new gnss_sentence_parser();
                System.out.println("start test ubx + nmea i: "+i+"new parser parse() start ====== ");
                assertTrue(example_nmea_gga.equals(gp.parse(baos.toByteArray()).trim()));
                System.out.println("start test ubx + nmea i: "+i+"new parser parse() done =======");
            }
            i++;
        }

    }
}
