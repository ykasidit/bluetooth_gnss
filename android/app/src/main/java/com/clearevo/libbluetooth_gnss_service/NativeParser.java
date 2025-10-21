package com.clearevo.libbluetooth_gnss_service;

public class NativeParser {

    static {
        System.loadLibrary("rust_lib_bluetooth_gnss");
    }

    public static native String parse(byte[] byteArray, int nread);
    public static native void reset();

    public static native String parse_qstarz(byte[] byteArray);
}
