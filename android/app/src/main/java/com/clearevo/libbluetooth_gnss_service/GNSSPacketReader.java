package com.clearevo.libbluetooth_gnss_service;

import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;

public final class GNSSPacketReader {
    public static final int DEFAULT_BUF_SIZE = 100_000;
    private static final byte CR = 13, LF = 10;
    private static final int UBX1 = 0xB5, UBX2 = 0x62;

    private final InputStream in;
    private final boolean nonBlocking;
    private final byte[] buf;
    private int start = 0, end = 0;
    static final String TAG = "btgnss_gnpr";

    public GNSSPacketReader(InputStream in) { this(in, DEFAULT_BUF_SIZE, false); }
    public GNSSPacketReader(InputStream in, int bufferSize, boolean nonBlocking) {
        this.in = in;
        this.buf = new byte[bufferSize];
        this.nonBlocking = nonBlocking;
    }

    /** Returns next NMEA line (with CRLF) or UBX frame; null if EOF (or no data yet in nonBlocking mode). */
    public byte[] read() throws IOException {
        for (;;) {
            // 1) Try parse from what we already have
            byte[] rec = tryParseOne();
            if (rec != null) return rec;

            // 2) Need more bytes — compact, then fill
            compactIfNeeded();

            int room = buf.length - end;
            if (room == 0) {
                // Buffer full but no frame found → drop one byte (desync protection) and continue
                start++;
                continue;
            }

            if (nonBlocking) {
                int avail;
                try { avail = in.available(); } catch (IOException e) { avail = 0; }
                if (avail <= 0) return null; // don't block
                room = Math.min(room, avail);
            }

            Log.d(TAG, "in.read start");
            int n = in.read(buf, end, room);
            Log.d(TAG, "in.read done n: "+n);
            if (n == -1) {
                throw new IOException("EOF");
            }
            end += n;
        }
    }

    // ====== internals ======

    private void compactIfNeeded() {
        if (start > 0 && (start == end || start > buf.length / 2)) {
            int len = end - start;
            if (len > 0) System.arraycopy(buf, start, buf, 0, len);
            start = 0;
            end = len;
        }
    }

    private byte[] tryParseOne() {
        int i = start;
        while (i < end) {
            int b = u8(buf[i]);

            // UBX candidate at i
            if (b == UBX1 && i + 1 < end && u8(buf[i + 1]) == UBX2) {
                // Need header: B5 62 CLASS ID LENL LENH
                if (i + 6 > end) return null; // need more
                int len = (u8(buf[i + 5]) << 8) | u8(buf[i + 4]);
                int total = 6 + len + 2; // hdr + payload + CK_A + CK_B
                if (i + total > end) return null; // need more

                if (ubxChecksumOk(buf, i, len)) {
                    byte[] out = Arrays.copyOfRange(buf, i, i + total);
                    start = i + total;
                    return out;
                } else {
                    // Bad sync/checksum → skip this byte and continue scanning
                    i++;
                    continue;
                }
            }

            // NMEA CRLF search from i to end
            int eol = indexOfCRLF(buf, i, end);
            if (eol != -1) {
                byte[] out = Arrays.copyOfRange(buf, i, eol + 1); // include LF
                start = eol + 1;
                return out;
            }

            // Neither UBX here nor CRLF visible yet → advance
            i++;
        }
        return null;
    }

    private static boolean ubxChecksumOk(byte[] a, int off, int payloadLen) {
        // sum over CLASS, ID, LENL, LENH, then payload
        int ckA = 0, ckB = 0;
        int from = off + 2;
        int to   = off + 6 + payloadLen; // exclusive end of payload
        for (int p = from; p < to; p++) {
            ckA = (ckA + (a[p] & 0xFF)) & 0xFF;
            ckB = (ckB + ckA) & 0xFF;
        }
        int gotA = a[to]     & 0xFF;
        int gotB = a[to + 1] & 0xFF;
        return ckA == gotA && ckB == gotB;
    }

    private static int indexOfCRLF(byte[] a, int from, int to) {
        for (int j = Math.max(from + 1, 1); j < to; j++) {
            if ((a[j] == LF) && (a[j - 1] == CR)) return j;
        }
        return -1;
    }

    private static int u8(byte x) { return x & 0xFF; }
}
