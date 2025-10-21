package com.clearevo.libbluetooth_gnss_service;

import static com.clearevo.libbluetooth_gnss_service.NativeParser.parse_qstarz;
import static com.clearevo.libbluetooth_gnss_service.QstarzUtils.getQstarzRCRLogType;
import static org.junit.Assert.assertEquals;

import org.junit.Test;


public class test_qstarz_utils {
    @Test
    public void test_qstarz_parse_rcr() throws Exception {
        String ret = getQstarzRCRLogType(84);
        assertEquals("T (time)", ret);
    }
    @Test
    public void test_qstarz_parse() throws Exception {
        String ret = getQstarzRCRLogType(84);
        assertEquals("T (time)", ret);

        //String s = parse_qstarz_pkt(new byte[]{});
    }
}
