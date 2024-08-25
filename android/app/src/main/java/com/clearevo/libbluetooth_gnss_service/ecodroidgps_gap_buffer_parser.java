package com.clearevo.libbluetooth_gnss_service;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.TimeZone;

public class ecodroidgps_gap_buffer_parser {

    //see python bleson based advertiser example - https://github.com/ykasidit/ecodroidgps/blob/master/edg_beacon.py

    //header
    public static final int EDDYSTONE_HEADER_N_BYTES = 11;
    public static final int EDDYSTONE_EID_FRAME_TYPE_N_BYTES = 1;
    public static final int TXPOW_N_BYTES = 1;
    public static final int TOTAL_HEADER_N_BYTES = EDDYSTONE_HEADER_N_BYTES + EDDYSTONE_EID_FRAME_TYPE_N_BYTES + TXPOW_N_BYTES;

    //payload
    public static final int ECODROIDGPS_FLAG_AND_VER_N_BYTES = 1;
    public static final int LAT_N_BYTES = 4;
    public static final int LON_N_BYTES = 4;
    public static final int TS_N_BYTES = 4;
    public static final int TOTAL_PAYLOAD_N_BYTES = ECODROIDGPS_FLAG_AND_VER_N_BYTES + LAT_N_BYTES + LON_N_BYTES + TS_N_BYTES;

    public static double LAT_LON_MULTIPLIER = Math.pow(10, 7);
    public static final byte ECODROIDGPS_EID_BROADCAST_FLAG_AND_VERISON_BYTE_VERSION1 = (byte) 0xE1;
    public static long y2k_ts_millis = get_y2k_ts_millis();
    public static SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

    public static long get_y2k_ts_millis()
    {
        Calendar c = Calendar.getInstance();
        c.set(2000,0,1, 0,0,0);
        return c.getTimeInMillis();
    }

    public static Date get_date_from_edg_gap_ts(long ts)
    {
        Calendar c = Calendar.getInstance();
        c.setTimeInMillis(get_y2k_ts_millis() + (ts * 1000));
        return c.getTime();
    }

    public static String get_date_str_from_edg_gap_ts(long ts)
    {
        return sdf.format(get_date_from_edg_gap_ts(ts));
    }

    public static class ecodroidgps_broadcasted_location {
        public ecodroidgps_broadcasted_location(byte flag_and_version, double lat, double lon, long timestamp) {
            this.lat = lat;
            this.lon = lon;
            this.timestamp = timestamp;
            this.timestamp_str = get_date_str_from_edg_gap_ts(timestamp);
            this.flag_and_version = flag_and_version;

        }
        public byte flag_and_version;
        public double lat;
        public double lon;
        public long timestamp;
        public String timestamp_str;
    }

    static ecodroidgps_broadcasted_location parse(byte[] gap_buffer) throws Exception
    {
        if (gap_buffer == null) {
            throw new Exception("gap_buffer is null");
        }
        if (gap_buffer.length < TOTAL_HEADER_N_BYTES + TOTAL_PAYLOAD_N_BYTES) {
            throw new Exception("gap_buffer too short");
        }

        //02 01 1A 04 09 45 44 47 03 03 AA FE 12 16 AA FE 30 00 E1 6A 6D FD 03 10 9B 91 3C 38 50 32 28 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
        int pos = -1;
        for (int i = 4; i < gap_buffer.length; i++) {
            //System.out.println("gap_buffer[i] "+gap_buffer[i]);
            //System.out.println("gap_buffer[i-3] "+gap_buffer[i-3]);
            //System.out.println("gap_buffer[i-4] "+gap_buffer[i-4]);
            if (gap_buffer[i] == ECODROIDGPS_EID_BROADCAST_FLAG_AND_VERISON_BYTE_VERSION1 && gap_buffer[i-3] == (byte) 0xFE && gap_buffer[i-4] == (byte) 0xAA) {
                pos = i;
                break;
            }
        }

        if (pos == -1) {
            throw new Exception("failed to find ECODROIDGPS_EID_BROADCAST_FLAG_AND_VERISON_BYTE");
        }

        byte flag_and_version = gap_buffer[pos++];

        if (flag_and_version != ECODROIDGPS_EID_BROADCAST_FLAG_AND_VERISON_BYTE_VERSION1) {
            throw new Exception("invalid/unknown flag");
        }

        ByteBuffer bb = null;

        bb = ByteBuffer.wrap(gap_buffer, pos, 4);
        pos += 4;
        bb.order(ByteOrder.LITTLE_ENDIAN);
        int lat_raw = bb.getInt();
        double lat = ((double) lat_raw) / LAT_LON_MULTIPLIER;

        bb = ByteBuffer.wrap(gap_buffer, pos, 4);
        pos += 4;
        bb.order(ByteOrder.LITTLE_ENDIAN);
        int lon_raw = bb.getInt();
        double lon = ((double) lon_raw) / LAT_LON_MULTIPLIER;

        bb = ByteBuffer.wrap(gap_buffer, pos, 4);
        pos += 4;
        bb.order(ByteOrder.LITTLE_ENDIAN);
        int ts = bb.getInt();

        ecodroidgps_broadcasted_location ret = new ecodroidgps_broadcasted_location(flag_and_version, lat, lon, ts);
        return ret;
    }


}
