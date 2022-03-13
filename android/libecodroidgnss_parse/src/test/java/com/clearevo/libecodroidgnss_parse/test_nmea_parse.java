package com.clearevo.libecodroidgnss_parse;

import android.os.SystemClock;

import net.sf.marineapi.nmea.parser.SentenceFactory;
import net.sf.marineapi.nmea.sentence.GGASentence;
import net.sf.marineapi.nmea.sentence.MWVSentence;
import net.sf.marineapi.nmea.sentence.TalkerId;
import net.sf.marineapi.nmea.util.Position;

import org.junit.Test;

import java.util.HashMap;
import java.util.List;

import static com.clearevo.libecodroidgnss_parse.gnss_sentence_parser.toHexString;
import static org.junit.Assert.*;

/**
 * Example local unit test, which will execute on the development machine (host).
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
public class test_nmea_parse {

    @Test
    public void test() throws Exception {

        SentenceFactory sf = SentenceFactory.getInstance();
        String example_nmea_gga = "$GNGGA,045115.00,0000.000,N,00000.000,E,1,12,0.60,3.0,M,-13.0,M,,*6F";
        System.out.println("gga sentence: "+example_nmea_gga);        ;
        GGASentence gga = (GGASentence) sf.createParser(example_nmea_gga);
        gga.setPosition(new Position(0, 0));
        gga.setAltitude(3);
        System.out.println("gga.toString():"+ gga.toString());
        //the strings below are not collected from same device/time so the will not match logcally like upx n sats used wont match gsa etc...
        //the strings below hold some originally ubx messages but since they are in java strings now THEY ARE NOT CORRECT UBX ANYMORE see test_java_strings_must_not_be_used_to_store_binary_data.java unittest - we leave them here just to auto test filtering out by the parser func but they cannot be used to test ubx pkt parsing
        String[] nmeas = {
                example_nmea_gga,
                "$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\n",
                "$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\n",
                "�b\u00010\u0004\u0001�e�\u0011\u0015\u0004\u0000\u0000\n" +
                        "\u0002\n" +
                        "\u0007\"\u001FZ\u0001W���\u0003\u0006\n" +
                        "\u0007\"?,\u0000����\b\f\n" +
                        "\u0007 \n" +
                        "�\u0000����\u0004\n" +
                        "\n" +
                        "\u0007\u001B\u0014D\u0001\u0015���\u0000\u000F\n" +
                        "\u0007\"\u000E\u001F\u0001����\u0001\u0011\n" +
                        "\u0007&.�\u0000����\u0007\u0013\n" +
                        "\u0004\u0014=�\u0000L���\u000E\u0018\n" +
                        "\u0007\u001D\"�\u0000�\u0003\u0000\u0000\u0002\u001C\n" +
                        "\u0007\u001F\u001Ca\u0000U���\u0011\u001E\n" +
                        "\u0007\u001A\u000B \u0000�\u0002\u0000\u0000\u000B�\n" +
                        "\u0007\u001C\u001CD\u0000�\u0007\u0000\u0000\n" +
                        "�\f\u0004\u0014\u00043\u0001z\u0003\u0000\u0000\t�\n" +
                        "\u0007\u001D\u0010G\u0001!\u0001\u0000\u0000\f�\u0010\u0001\u0000�\u0000\u0000\u0000\u0000\u0000\u0000��\f\u0000\u0000DS\u0001\u0000\u0000\u0000\u0000\u0006�\n" +
                        "\u0007\u001F%�\u0000.\u0000\u0000\u0000\u000F�\n" +
                        "\u0007$D�\u0000A\u0000\u0000\u0000��\u0004\u0000\u0000\u0004�\u0000\u0000\u0000\u0000\u0000\u0012�\u0004\u0004\u0010\f[\u0001\u0000\u0000\u0000\u0000\u0005�\n" +
                        "\u0007\"X_\u0000%\u0001\u0000\u0000\u0010�\n" +
                        "\u0007\u001F8 \u0001e���ٰ�b\u0001\u0003\u0010\u0000�e�\u0011\u0003�\u0000\b��\u0000\u0000=�\u0012\u0000N�$GNRMC,095520.00,A,2733.35607,S,15302.15703,E,0.042,,240719,,,A,V*0A\n",

                "03:01:42  $GNGSA,A,3,17,05,12,19,09,28,02,06,,,,,1.10,0.49,0.99,1*03\n",
                "03:01:42  $GNGSA,A,3,81,67,66,79,78,,,,,,,,1.10,0.49,0.99,2*06\n",
                "03:01:42  $GNGSA,A,3,04,33,19,31,24,12,,,,,,,1.10,0.49,0.99,3*05\n",
                "03:01:42  $GNGSA,A,3,23,28,27,08,10,07,13,16,09,,,,1.10,0.49,0.99,4*05\n",
                "$GNGSA,A,3,26,31,10,32,14,16,25,20,18,22,41,,1.34,0.74,1.12*16\n",

                "03:52:31  $GPGSV,3,1,12,02,30,352,41,05,67,295,38,06,18,039,28,09,03,049,37,1*68\n",
                "03:52:31  $GPGSV,3,2,12,12,44,295,46,13,32,171,31,15,12,204,32,17,34,106,31,1*6B\n",
                "03:52:31  $GPGSV,3,3,12,19,43,089,27,24,06,235,,25,08,315,,28,06,154,,1*6C\n",

                "03:52:31  $GPGSV,3,1,12,02,30,352,,05,67,295,23,06,18,039,35,09,03,049,,6*68\n",
                "03:52:31  $GPGSV,3,2,12,12,44,295,35,13,32,171,,15,12,204,23,17,34,106,25,6*6F\n",
                "03:52:31  $GPGSV,3,3,12,19,43,089,,24,06,235,,25,08,315,,28,06,154,,6*6E\n",

                "03:52:31  $GLGSV,3,1,10,66,14,029,43,67,66,046,39,68,51,193,,69,03,202,,1*76\n",
                "03:52:31  $GLGSV,3,2,10,78,05,173,,79,23,220,28,80,16,275,,81,26,053,34,1*71\n",
                "03:52:31  $GLGSV,3,3,10,82,20,360,32,88,08,097,,1*73\n",
                "03:52:31  $GLGSV,3,1,10,66,14,029,33,67,66,046,09,68,51,193,,69,03,202,,3*70\n",
                "03:52:31  $GLGSV,3,2,10,78,05,173,,79,23,220,21,80,16,275,,81,26,053,27,3*78\n",
                "03:52:31  $GLGSV,3,3,10,82,20,360,26,88,08,097,,3*74\n",
                "03:52:31  $GAGSV,3,1,10,01,14,165,18,04,53,180,30,09,07,208,22,11,05,307,,7*72\n",
                "03:52:31  $GAGSV,3,2,10,12,29,354,41,19,52,068,24,24,29,280,43,26,00,093,11,7*75\n",
                "03:52:31  $GAGSV,3,3,10,31,40,214,28,33,26,051,30,7*7A\n",
                "03:52:31  $GAGSV,3,1,10,01,14,165,,04,53,180,25,09,07,208,,11,05,307,,2*7A\n",
                "03:52:31  $GAGSV,3,2,10,12,29,354,33,19,52,068,23,24,29,280,33,26,00,093,,2*75\n",
                "03:52:31  $GAGSV,3,3,10,31,40,214,15,33,26,051,,2*72\n",
                "03:52:31  $GBGSV,5,1,18,01,45,099,,02,68,253,,03,77,122,,04,23,094,,1*79\n",
                "03:52:31  $GBGSV,5,2,18,05,40,264,,06,54,132,10,07,42,177,30,08,28,020,30,1*7F\n",
                "03:52:31  $GBGSV,5,3,18,09,43,169,,10,55,209,27,13,33,352,39,16,53,145,37,1*7F\n",
                "03:52:31  $GBGSV,5,4,18,18,37,350,,20,16,216,,23,08,156,,27,38,003,39,1*79\n",
                "03:52:31  $GBGSV,5,5,18,28,37,072,35,30,04,321,,1*75\n",
                "03:52:31  $GBGSV,5,1,18,01,45,099,,02,68,253,,03,77,122,,04,23,094,,3*7B\n",
                "03:52:31  $GBGSV,5,2,18,05,40,264,,06,54,132,26,07,42,177,29,08,28,020,37,3*77\n",
                "03:52:31  $GBGSV,5,3,18,09,43,169,,10,55,209,24,13,33,352,39,16,53,145,26,3*7E\n",
                "03:52:31  $GBGSV,5,4,18,18,37,350,,20,16,216,,23,08,156,,27,38,003,,3*71\n",
                "03:52:31  $GBGSV,5,5,18,28,37,072,,30,04,321,,3*71\n",
                "03:52:31  $GNGLL,0641.64673,N,10137.05675,E,035231.00,A,A*77\n",
                "03:52:31  $PUBX,00,035231.00,0641.64673,N,10137.05675,E,19.144,G3,1.2,2.2,0.015,0.00,0.037,,0.51,0.93,0.58,26,0,0*6D\n",
                "03:52:31  $PUBX,03,32,2,U,352,30,41,064,5,U,295,67,38,064,6,U,039,18,28,064,9,e,049,03,,000,12,U,295,44,46,064,13,U,171,32,31,061,15,U,204,12,32,064,17,U,106,34,31,007,19,U,089,43,27,003,24,-,235,06,,000,25,-,315,08,,000,28,e,154,06,,000,30,-,123,-2,,000,211,e,165,14,18,000,214,U,180,53,30,020,219,-,208,07,,000,221,-,307,05,,000,222,U,354,29,41,064,229,U,068,52,24,000,234,U,280,29,43,064,236,e,093,00,,000,241,U,214,40,28,026,243,U,051,26,30,064,159,-,099,45,,000,160,-,253,68,,000,161,-,122,77,,000,162,-,094,23,,000,163,-,264,40,,000,33,e,132,54,10,000,34,U,177,42,30,020,35,U,020,28,30,064,36,e,169,43,,000*38\n" ,
                "03:52:31  $PUBX,04,035231.00,140919,532351.00,2070,18,541289,165.421,08*1A\n",
                "$GNVTG,,T,,M,0.206,N,0.382,K,A*30",
                "chad_yak_pai_wangkeaw_leaw"+example_nmea_gga
        };

        gnss_sentence_parser parser = new gnss_sentence_parser();
        for (String nmea : nmeas) {
            parser.parse(nmea.getBytes("ascii"));
        }

        HashMap<String, Object> params = parser.get_params();
        for (String key : params.keySet()) {
            System.out.println("param key: "+key+" val: "+params.get(key));
        }

        assertTrue(2 == (int) params.get("GN_GGA_count"));
        assertTrue(1 == (int) params.get("GN_RMC_count"));
        assertTrue(2 <= (int) params.get("GA_GSV_count"));

        System.out.println("GP_n_sats_in_view: "+params.get("GP_n_sats_in_view"));
        System.out.println("GP_n_sats_used: "+params.get("GP_n_sats_used"));
        assertTrue(11 == (int) params.get("GP_n_sats_used"));
        assertTrue(12 == (int) params.get("GP_n_sats_in_view"));
        assertTrue(12 == ((List)params.get("GP_sats_in_view_snr_list_signal_id_1")).size());

        System.out.println("GL_n_sats_used: "+params.get("GL_n_sats_used"));
        assertTrue(5 == (int) params.get("GL_n_sats_used"));

        System.out.println("GA_n_sats_used: "+params.get("GA_n_sats_used"));
        assertTrue(6 == (int) params.get("GA_n_sats_used"));

        System.out.println("GB_n_sats_in_view: "+params.get("GB_n_sats_in_view"));
        System.out.println("GB_n_sats_used: "+params.get("GB_n_sats_used"));
        assertTrue(9 == (int) params.get("GB_n_sats_used"));
        assertTrue(18 == (int) params.get("GB_n_sats_in_view"));
        assertTrue(18 == ((List)params.get("GB_sats_in_view_snr_list_signal_id_1")).size());

        System.out.println("UBX_POSITION_numSvs: "+params.get("UBX_POSITION_numSvs"));
        assertTrue(26 == Integer.parseInt((String) params.get("UBX_POSITION_numSvs")));
        String[] plist = new String[] {"lat", "lon", "gga_alt", "gga_alt_units", "geoidal_height", "geoidal_height_units", "ellipsoidal_height"};
        for (String pi : plist) {
            System.out.println(pi+": "+params.get("GN_"+pi));
        }
        assertTrue(params.get("GN_lat").toString().startsWith("0."));
        assertTrue(params.get("GN_lat_str").toString().startsWith("0."));
        assertTrue(params.get("GN_lon").toString().startsWith("0."));
    }
}
