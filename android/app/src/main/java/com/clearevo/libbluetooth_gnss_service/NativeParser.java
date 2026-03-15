package com.clearevo.libbluetooth_gnss_service;

public class NativeParser {

    static {
        System.loadLibrary("rust_lib_bluetooth_gnss");
    }

    public static native void reset();

    public static native String feed_bytes(byte[] byteArray, int nread, int protocolHint);
}
