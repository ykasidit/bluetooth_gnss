package com.clearevo.libbluetooth_gnss_service;

public class NativeParser {

    static {
        System.loadLibrary("rust_lib_bluetooth_gnss");
    }

    // Declare the native function
    public static native String parse_qstarz_pkt(byte[] byteArray);


    public static native String parse_gnss_dev_buffer(byte[] byteArray);

}
