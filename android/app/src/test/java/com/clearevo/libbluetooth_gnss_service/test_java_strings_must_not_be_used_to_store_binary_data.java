package com.clearevo.libbluetooth_gnss_service;

import net.sf.marineapi.nmea.parser.SentenceFactory;
import net.sf.marineapi.nmea.sentence.GGASentence;
import net.sf.marineapi.nmea.sentence.TalkerId;
import net.sf.marineapi.nmea.util.Position;

import org.junit.Test;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStreamReader;

import static org.junit.Assert.assertTrue;

public class test_java_strings_must_not_be_used_to_store_binary_data {

    @Test
    public void test() throws Exception {


        //THIS TEST SHOWS THAT WE CANNOT RELIABLY STORE BINARY DATA IN JAVA STRINGS - ALWAYS STORE THEM IN BYTE ARRAYS

        String ori_hex_in = "B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A";  // a ubx packet + '140' ascii + crlf

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        baos.write(gnss_sentence_parser.fromHexString(ori_hex_in));
        byte[] baos_out = baos.toByteArray();
        System.out.println("baos_out hex: "+gnss_sentence_parser.toHexString(baos_out));
        System.out.println("baos_out[0]: "+String.format("%02X", baos_out[0]));
        System.out.println("baos_out[1]: "+String.format("%02X", baos_out[1]));
        assertTrue(baos_out[0] == (byte) 0xB5); //needs (byte) otherwise 0xb5 becomes negative int
        assertTrue(baos_out[1] == (byte) 0x62);

        BufferedReader br = new BufferedReader(new InputStreamReader(new ByteArrayInputStream(baos_out)));
        String read_line = br.readLine();
        byte[] buffer = read_line.getBytes("ascii");
        System.out.println("buffer[0]: "+String.format("%02X",buffer[0]));
        System.out.println("buffer[1]: "+String.format("%02X",buffer[1]));

        System.out.println("buffer[0] == (byte) 0xB5: "+(buffer[0] == (byte) 0xB5));
        System.out.println("buffer[1] == (byte) 0x62: "+(buffer[1] == (byte) 0x62));
    }
}
