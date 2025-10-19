package com.clearevo.libbluetooth_gnss_service;

public class NativeParser {

    static {
        System.loadLibrary("rust_lib_bluetooth_gnss");
    }

    public static native String on_gnss_pkt(byte[] byteArray);
    public static native void reset_gnss_parser();

    public static native String parse_qstarz_pkt(byte[] byteArray);
}
