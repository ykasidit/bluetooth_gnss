package com.clearevo.libecodroidbluetooth;
import org.junit.Test;

import java.io.ByteArrayInputStream;
import java.io.InputStream;

import static junit.framework.TestCase.assertTrue;


public class test_bytes_readline {

    public static final byte[] fromHexString(final String s) {
        String[] v = s.split(" ");
        byte[] arr = new byte[v.length];
        int i = 0;
        for(String val: v) {
            arr[i++] =  Integer.decode("0x" + val).byteValue();

        }
        return arr;
    }

    public static String toHexString(byte[] a) {
        StringBuilder sb = new StringBuilder(a.length * 2);
        for(byte b: a)
            sb.append(String.format("%02X ", b));
        return sb.toString().trim();
    }


    @Test
    public void test() throws Exception {

        String ori_hex_str = "00 0D 0A 0D 0A B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A FF EF";
        String[] assert_result_hex_strs = {
                "00 0D 0A",
                "0D 0A",
                "B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A",
                "B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A",
        };

        byte[] ori_buffer = fromHexString(ori_hex_str);
        InputStream is = new ByteArrayInputStream(ori_buffer);

        int buffer_count = 0;
        while (true) {
            byte[] read_buff = inputstream_to_queue_reader_thread.bytes_readline(is, new byte[inputstream_to_queue_reader_thread.MAX_READ_BUF_SIZE]);
            if (read_buff == null) {
                assertTrue(buffer_count == assert_result_hex_strs.length);
                break;
            }
            String read_buff_hex = toHexString(read_buff);
            System.out.println("buffer_count "+buffer_count+" read_buff_hex: "+read_buff_hex+" assert same as: "+assert_result_hex_strs[buffer_count]);
            assertTrue(read_buff_hex.equals(assert_result_hex_strs[buffer_count]));
            buffer_count++;
        }


    }
}
