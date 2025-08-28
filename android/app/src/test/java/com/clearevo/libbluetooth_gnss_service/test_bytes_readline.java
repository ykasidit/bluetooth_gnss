package com.clearevo.libbluetooth_gnss_service;
import org.junit.Assert;
import org.junit.Test;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.PipedInputStream;
import java.io.PipedOutputStream;
import java.io.PushbackInputStream;

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
        inputstream_to_queue_reader_thread.debug_break_on_avail_0 = true;
        try {
            String ori_hex_str = "00 0D 0A 0D 0A B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A FF EF";
            String[] assert_result_hex_strs = {
                    "00 0D 0A",
                    "0D 0A",
                    "B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A",
                    "B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A",
            };

            byte[] ori_buffer = fromHexString(ori_hex_str);
            InputStream is = new ByteArrayInputStream(ori_buffer);
            byte[] tmp_buffer = new byte[inputstream_to_queue_reader_thread.MAX_READ_BUF_SIZE];
            int buffer_count = 0;
            while (true) {
                byte[] read_buff = inputstream_to_queue_reader_thread.bytes_readline(is, tmp_buffer);
                if (read_buff == null) {
                    assertTrue(buffer_count == assert_result_hex_strs.length);
                    break;
                }
                String read_buff_hex = toHexString(read_buff);
                System.out.println("buffer_count " + buffer_count + " read_buff_hex: " + read_buff_hex + " assert same as: " + assert_result_hex_strs[buffer_count]);
                assertTrue(read_buff_hex.equals(assert_result_hex_strs[buffer_count]));
                buffer_count++;
            }

            //readline without pushback will not carry on
            byte[] b0 = new byte[]{0x1, 0x2, 0x0d};
            byte[] b1 = new byte[]{0x0a, 0x3, 0x0d, 0x0a};
            InputStream is0 = new ByteArrayInputStream(b0);
            byte[] rb0 = inputstream_to_queue_reader_thread.bytes_readline(is0, tmp_buffer);
            Assert.assertTrue(is0.available() == 0);
            Assert.assertTrue(rb0 == null);


            System.out.println("=============");
            PipedOutputStream pos = new PipedOutputStream();
            PipedInputStream pis = new PipedInputStream(pos, 500_000);
            PushbackInputStream pbis = new PushbackInputStream(pis, 500_000);
            pos.write(b0);
            pos.flush();
            rb0 = inputstream_to_queue_reader_thread.bytes_readline(pbis, tmp_buffer);

            System.out.println("first read bytes: " + rb0);
            Assert.assertTrue(rb0 == null);
            Assert.assertTrue(pbis.available() == b0.length);
            pos.write(b1);
            rb0 = inputstream_to_queue_reader_thread.bytes_readline(pbis, tmp_buffer);
            Assert.assertTrue(rb0 != null);
            Assert.assertArrayEquals(new byte[]{0x1, 0x2, 0x0d, 0x0a}, rb0);

            System.out.println("second read bytes: " + toHexString(rb0));
            rb0 = inputstream_to_queue_reader_thread.bytes_readline(pbis, tmp_buffer);
            Assert.assertTrue(rb0 != null);
            Assert.assertArrayEquals(new byte[]{0x3, 0x0d, 0x0a}, rb0);

            System.out.println("third read bytes: " + toHexString(rb0));
            rb0 = inputstream_to_queue_reader_thread.bytes_readline(pbis, tmp_buffer);
            Assert.assertTrue(rb0 == null);
            pos.close();
        } finally {
            inputstream_to_queue_reader_thread.debug_break_on_avail_0 = false;
        }


    }
}
