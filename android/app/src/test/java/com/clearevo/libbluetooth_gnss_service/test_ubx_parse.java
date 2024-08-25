package com.clearevo.libbluetooth_gnss_service;

import net.sf.marineapi.nmea.parser.SentenceFactory;
import net.sf.marineapi.nmea.sentence.GGASentence;
import net.sf.marineapi.nmea.sentence.TalkerId;
import net.sf.marineapi.nmea.util.Position;

import org.junit.Test;

import static com.clearevo.libbluetooth_gnss_service.gnss_sentence_parser.fromHexString;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.util.HashMap;

public class test_ubx_parse {

    @Test
    public void test() throws Exception {


        String[] test_hex_strings = {
                "B5 62 05 01 02 00 06 01 0F 38 B5 62 0A 04 A0 00 52 4F 4D 20 43 4F 52 45 20 33 2E 30 31 20 28 31 30 37 38 38 38 29 00 00 00 00 00 00 00 00 30 30 30 38 30 30 30 30 00 00 46 57 56 45 52 3D 53 50 47 20 33 2E 30 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 50 52 4F 54 56 45 52 3D 31 38 2E 30 30 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 47 50 53 3B 47 4C 4F 3B 47 41 4C 3B 42 44 53 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 53 42 41 53 3B 49 4D 45 53 3B 51 5A 53 53 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 41 D2 B5 62 0A 28 08 00 00 0F 03 05 03 00 00 00 54 20 24 47 4E 52 4D 43 2C 31 32 32 36 33 30 2E 30 30 2C 41 2C 30 36 34 31 2E 36 34 33 32 30 2C 4E 2C 31 30 31 33 37 2E 30 35 38 38 36 2C 45 2C 30 2E 30 34 33 2C 2C 32 33 30 39 31 39 2C 2C 2C 41 2C 56 2A 31 30 0D 0A"
        };

        int[] assert_consumed_les = {
                194,
        };

        int i = 0;
        for (String ori_hex_in : test_hex_strings) {

            //test pure ubx buffer parse
            byte[] example_line_buffer = fromHexString(ori_hex_in);
            System.out.println("start ubx_parse: " + ori_hex_in);
            int n_ubx_consumed = ubx_parser.ubx_parse_get_n_bytes_consumed(example_line_buffer);
            System.out.println("n_ubx_consumed: " + n_ubx_consumed);
            assertTrue(n_ubx_consumed == assert_consumed_les[i]);

            if (i == 0) {
                assertTrue(0x24 == example_line_buffer[194]);
                HashMap<String, Object> parsed = new gnss_sentence_parser().parse(example_line_buffer);
                System.out.println("parsed: " + parsed);
                assertEquals("$GNRMC,122630.00,A,0641.64320,N,10137.05886,E,0.043,,230919,,,A,V*10",
                        parsed.get("contents")
                );
            }

            i++;
        }

    }
}
