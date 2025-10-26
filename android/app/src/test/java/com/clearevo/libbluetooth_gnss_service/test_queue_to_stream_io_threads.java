package com.clearevo.libbluetooth_gnss_service;
import org.junit.Test;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.LinkedBlockingQueue;

import static junit.framework.TestCase.assertTrue;

public class test_queue_to_stream_io_threads {

    @Test
    public void test() throws Exception {

        LinkedBlockingQueue<byte[]> incoming_buffers = new LinkedBlockingQueue<byte[]>();
        LinkedBlockingQueue<byte[]> outgoing_buffers = new LinkedBlockingQueue<byte[]>();

        final int input_buf_size = 1000*1000*10;
        byte[] ibuf = new byte[input_buf_size];
        for (int i = 0; i < ibuf.length; i++)
            ibuf[i] = (byte) i;

        ByteArrayInputStream bais = new ByteArrayInputStream(ibuf);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();

        inputstream_to_queue_reader_thread incoming_thread = new inputstream_to_queue_reader_thread(bais, incoming_buffers);
        incoming_thread.start();
        for (int i = 0; i < 10; i++) {
            try {
                Thread.sleep(1);
            } catch (Exception e) {}
            System.out.println(i+" incoming_buffers size():"+ incoming_buffers.size());
        }

        queue_to_outputstream_writer_thread outgoing_thread = new queue_to_outputstream_writer_thread(incoming_buffers, baos);
        outgoing_thread.start();
        for (int i = 0; i < 10; i++) {
            try {
                Thread.sleep(50);
            } catch (Exception e) {}
            System.out.println(i+" baos size():"+ baos.size());
        }

        System.out.println("input_buf_size: "+input_buf_size);
        System.out.println("baos.size(): "+baos.size());
        assertTrue(input_buf_size == baos.size());
        assertTrue(incoming_buffers.size() == 0);

        outgoing_thread.close();
        System.out.println("incoming_thread.isAlive(): "+incoming_thread.isAlive());
        assertTrue(incoming_thread.isAlive() == false);

        try {
            Thread.sleep(10);
        } catch (Exception e){}
        System.out.println("outgoing_thread.isAlive(): "+outgoing_thread.isAlive());
        assertTrue(outgoing_thread.isAlive() == false);

    }
}
