package com.clearevo.libbluetooth_gnss_service;
import java.util.HashMap;
import java.util.Map;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;
public class QstarzUtils {
    private static final Map<String, String> QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP = new HashMap<>();
    static {
        QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP.put("B", "POI");
        QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP.put("T", "time");
        QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP.put("D", "distance");
        QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP.put("S", "speed");
    }

    public static String getQstarzRCRLogType(Integer asciiCode) {
        if (asciiCode == null) {
            return "";
        }
        char character = (char) asciiCode.intValue();
        String chStr = String.valueOf(character);
        String lt = QSTARZ_RCR_CHAR_TO_LOGTYPE_MAP.get(chStr);
        return lt == null ? chStr : chStr + " (" + lt + ")";
    }

    public static String getQstarzDatetime(long timestampS, long millisecond) {
        long totalMillis = timestampS * 1000L + millisecond;
        Date date = new Date(totalMillis);

        // Use UTC to match Dart's default behavior
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US);
        sdf.setTimeZone(TimeZone.getTimeZone("UTC"));
        String formatted = sdf.format(date);

        return formatted + "." + String.format(Locale.US, "%03d", millisecond);
    }
}
