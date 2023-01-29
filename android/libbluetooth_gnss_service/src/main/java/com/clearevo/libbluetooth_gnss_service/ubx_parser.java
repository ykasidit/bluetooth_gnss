package com.clearevo.libbluetooth_gnss_service;



import static com.clearevo.libbluetooth_gnss_service.gnss_sentence_parser.toHexString;

public class ubx_parser {

    public static final String TAG = "btgnssubx";

    public static int ubx_parse_get_n_bytes_consumed(byte[] buff)
    {
        int n_bytes_consumed = 0;
        int pos = 0;
        while (pos < buff.length) {
            //get ubx header: B5 62
            //Log.d(TAG, "ubx parse pos: "+pos + " val: "+String.format("%02x", buff[pos]));
            if (pos > 0 && buff[pos] == (byte) 0x62 && buff[pos-1] == (byte) 0xB5) {
                try {
                    pos++; //skip current 0x62 header byte
                    byte ubx_class = buff[pos++];
                    //Log.d(TAG, "ubx_class: "+String.format("%02x", ubx_class));
                    byte ubx_msg_id = buff[pos++];
                    //Log.d(TAG, "ubx_msg_id: "+String.format("%02x", ubx_msg_id));
                    int len0 = buff[pos++] & 0xFF; //conv to int will have 'signed' issues so mask only 0xFF to conv to unsigned val but as int
                    int len1 = buff[pos++] & 0xFF;
                    int payload_start_pos = pos;
                    int ubx_payload_len = (len1 << 8) | len0;
                    //Log.d(TAG, "len0: "+String.format("%02x", (byte) len0));
                    //Log.d(TAG, "len1: "+String.format("%02x", (byte) len1));
                    //Log.d(TAG, "ubx_payload_len: "+ubx_payload_len);
                    int checksum0_pos = pos + ubx_payload_len;
                    int checksum1_pos = checksum0_pos+1;
                    //Log.d(TAG, "checksum0_pos: "+checksum0_pos);
                    //Log.d(TAG, "checksum1_pos: "+checksum1_pos);
                    //Log.d(TAG, "checksum1: "+String.format("%02x", buff[checksum1_pos]));
                    if (checksum1_pos > 0 && checksum1_pos < buff.length) {
                        pos = checksum1_pos; //pos would be ++ below so leave pos at last 'consumed' position
                        n_bytes_consumed = checksum1_pos+1;

                        //try parse payload here
                        //Log.d(TAG, "ubx parse payload - start pos "+payload_start_pos+" ubx_payload_len "+ubx_payload_len+" payload:"+toHexString(buff, payload_start_pos, ubx_payload_len));
                        parse_ubx_payload(ubx_class, ubx_msg_id, payload_start_pos, ubx_payload_len, buff);
                    }
                } catch (Exception e) {
                    Log.d(TAG, "ubx_parse_get_offset_after_consumed_bytes exception: "+Log.getStackTraceString(e));
                }
            }

            pos++;
        }

        return n_bytes_consumed;
    }

    public static void parse_ubx_payload(byte ubx_class, byte ubx_msg_id, int payload_start_pos, int ubx_payload_len, byte[] buff)
    {
        if (ubx_class == (byte) 0x06) {
            if (ubx_msg_id == (byte) 0x01) {
                //32.10.14 UBX-CFG-MSG (0x06 0x01)
            }
        }
    }

}
