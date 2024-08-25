package com.clearevo.libbluetooth_gnss_service;

//from https://stackoverflow.com/questions/36787449/how-to-mock-method-e-in-log

import static com.clearevo.libbluetooth_gnss_service.bluetooth_gnss_service.append_logfile;

public class Log {
    public static String getStackTraceString(Throwable ex) {
        StringBuilder retb = new StringBuilder(ex.toString()+": stack_trace:\n");
        for (StackTraceElement t : ex.getStackTrace()) {
            retb.append("\tat "+t.toString()+"\n");
        }
        return retb.toString();
    }

    static void _log(String level, String tag, String msg) {
        String s = level+": " + tag + ": " + msg;
        System.out.println(s);
        append_logfile(tag, s);
    }

    public static int d(String tag, String msg) {
        _log("DEBUG", tag, msg);
        return 0;
    }

    public static int i(String tag, String msg) {
        _log("INFO", tag, msg);
        return 0;
    }

    public static int w(String tag, String msg) {
        _log("WARN", tag, msg);
        return 0;
    }

    public static int e(String tag, String msg) {
        _log("ERROR", tag, msg);
        return 0;
    }

    // add other methods if required...
}
