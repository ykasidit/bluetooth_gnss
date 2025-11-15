package com.clearevo.libbluetooth_gnss_service;

//from https://stackoverflow.com/questions/36787449/how-to-mock-method-e-in-log


import android.content.Context;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;
import java.time.temporal.ChronoField;
import java.util.Date;
import java.util.Locale;


public class Log {

    public static final String TAG = "btgnnss_log";

    public interface LogObserver {
        void onLog(Date d, String livel, String tag, String msg);
    }

    public static LogObserver logObserver = null;
    public static volatile OutputStream m_log_operations_fos;
    public static File traceFile;
    public static final long MAX_TRACE_FILE_SIZE_MB = 100;
    public static final long MAX_TRACE_FILE_SIZE_BYTES = MAX_TRACE_FILE_SIZE_MB*1_000_000;

    public static File getLogsDir(Context context)
    {
        File dir = context.getExternalFilesDir(null);
        if (!dir.isDirectory()) {
            dir.mkdirs();
        }
        return dir;
    }

    public static File getTraceLog(Context context)
    {
        return new File(getLogsDir(context), "app_trace.txt");
    }

    //IMPORTANT: DO NOT USE Log.d here - it will be recursive call to self, use android.util.Log.d instead

    public static void initTraceFile(Context context)
    {
        android.util.Log.d(TAG, "initTraceFile");
        if (traceFile == null) {
            traceFile = getTraceLog(context);
            if (traceFile.isFile()) {
                try {
                    if (traceFile.length() > MAX_TRACE_FILE_SIZE_BYTES) {
                        android.util.Log.d(TAG, "WARNING: traceFile.length() " + traceFile.length() + " > MAX_TRACE_FILE_SIZE_BYTES " + MAX_TRACE_FILE_SIZE_BYTES + " delete now");
                        traceFile.delete();
                    }
                } catch (Exception e) {}
            }
        }
        if (m_log_operations_fos == null) {
            try {
                m_log_operations_fos = new FileOutputStream(traceFile, true);
                android.util.Log.d(TAG, "open tracefile success: "+traceFile.getAbsolutePath());
            } catch (Throwable tr) {
                android.util.Log.d(TAG, "WARNING: open tracefile failed: "+Log.getStackTraceString(tr));
            }
        }
    }

    public static synchronized boolean clearTraceFile(Context context)
    {
        android.util.Log.d(TAG, "clearTraceFile start");
        try {
            if (m_log_operations_fos != null) {
                try { m_log_operations_fos.close(); } catch (Exception e) {}
                m_log_operations_fos = new FileOutputStream(traceFile, false);
                return true;
            }
        } catch (Exception e) {
            android.util.Log.d(TAG, "clearTracefileException: "+android.util.Log.getStackTraceString(e));
        } finally {
            android.util.Log.d(TAG, "clearTraceFile done");
        }
        return false;
    }

    public static String getStackTraceString(Throwable ex) {
        StringBuilder retb = new StringBuilder(ex.toString()+": stack_trace:\n");
        for (StackTraceElement t : ex.getStackTrace()) {
            retb.append("\tat "+t.toString()+"\n");
        }
        return retb.toString();
    }

    static final String DATETIME_PATTERN = "yyyy-MM-dd HH:mm:ss";
    static final DateTimeFormatter mDateParser = new DateTimeFormatterBuilder()
            .appendPattern(DATETIME_PATTERN)
            .appendFraction(ChronoField.NANO_OF_SECOND, 0, 9, true)
            .toFormatter(Locale.US);
    static final DateTimeFormatter mDateFormatter = new DateTimeFormatterBuilder()
            .appendPattern(DATETIME_PATTERN)
            .appendFraction(ChronoField.NANO_OF_SECOND, 3, 9, true)
            .toFormatter(Locale.US);
    static final ZoneId systemDefaultTz = ZoneId.systemDefault();
    public static Date parse(String s) {
        LocalDateTime ldt = LocalDateTime.parse(s, mDateParser);
        Instant instant = ldt.atZone(systemDefaultTz).toInstant();
        return Date.from(instant);
    }
    public static String format(Date dateTime) {
        return mDateFormatter.format(dateTime.toInstant().atZone(systemDefaultTz));
    }
    public static String format(long dateTime) {
        return mDateFormatter.format(new Date(dateTime).toInstant().atZone(systemDefaultTz));
    }

    static void _log(String level, String tag, String msg) {
        Date d = new Date();
        String s = format(d)+":"+level+":" + tag + ": " + msg.trim();
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
                android.util.Log.d(tag, "WARNING: append_logfile failed exception: "+Log.getStackTraceString(tr));
            }
        }
    }


    public static int d(String tag, String msg) {
        _log("D", tag, msg);
        return 0;
    }

    public static int i(String tag, String msg) {
        _log("I", tag, msg);
        return 0;
    }

    public static int w(String tag, String msg) {
        _log("W", tag, msg);
        return 0;
    }

    public static int e(String tag, String msg) {
        _log("E", tag, msg);
        return 0;
    }

    // add other methods if required...
}
