package com.clearevo.libbluetooth_gnss_service;

//from https://stackoverflow.com/questions/36787449/how-to-mock-method-e-in-log


import java.io.FileOutputStream;
import java.io.OutputStream;
import java.util.Date;



public class Log {

    public interface LogObserver {
        void onLog(Date d, String livel, String tag, String msg);
    }

    public static LogObserver logObserver = null;
    public static OutputStream m_log_operations_fos;

    public static String getStackTraceString(Throwable ex) {
        StringBuilder retb = new StringBuilder(ex.toString()+": stack_trace:\n");
        for (StackTraceElement t : ex.getStackTrace()) {
            retb.append("\tat "+t.toString()+"\n");
        }
        return retb.toString();
    }

    static void _log(String level, String tag, String msg) {
        Date d = new Date();
        String s = d+":"+level+": " + tag + ": " + msg;
        if (logObserver != null) {
            try {
                logObserver.onLog(d, level, tag, msg);
            } catch (Exception e) {
                System.out.println("WARNING: logObserver.onLog exception: "+ e.toString() +" stack: "+getStackTraceString(e));
            }
        }
        System.out.println(s);
        append_logfile(tag, s);
    }

    public static void append_logfile(String tag, String msg)
    {
        if (m_log_operations_fos != null) {
            try {
                m_log_operations_fos.write((msg+"\n").getBytes());
                m_log_operations_fos.flush();
            } catch (Throwable tr) {
                android.util.Log.d(tag, "WARNING: log curInstance failed exception: "+Log.getStackTraceString(tr));
            }
        }
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
