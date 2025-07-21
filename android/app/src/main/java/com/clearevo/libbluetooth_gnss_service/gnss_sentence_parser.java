package com.clearevo.libbluetooth_gnss_service;

import net.sf.marineapi.nmea.parser.DataNotAvailableException;
import net.sf.marineapi.nmea.parser.SentenceFactory;
import net.sf.marineapi.nmea.sentence.GGASentence;
import net.sf.marineapi.nmea.sentence.GSASentence;
import net.sf.marineapi.nmea.sentence.GSVSentence;
import net.sf.marineapi.nmea.sentence.RMCSentence;
import net.sf.marineapi.nmea.sentence.Sentence;
import net.sf.marineapi.nmea.sentence.TalkerId;
import net.sf.marineapi.nmea.sentence.VTGSentence;
import net.sf.marineapi.nmea.util.Date;
import net.sf.marineapi.nmea.util.Position;
import net.sf.marineapi.nmea.util.SatelliteInfo;
import net.sf.marineapi.nmea.util.Units;

import java.nio.charset.StandardCharsets;
import java.util.*;

import static com.clearevo.libbluetooth_gnss_service.ubx_parser.ubx_parse_get_n_bytes_consumed;


public class gnss_sentence_parser {


    static final String TAG = "btgnss_nmea_p";
    public static final TimeZone TZ_UTC = TimeZone.getTimeZone("UTC");
    final String[] KNOWN_NMEA_PREFIX_LIST = {
            "$"+ TalkerId.GN, //combined
            "$"+ TalkerId.GP, //GPS
            "$"+ TalkerId.GL, //GLONASS
            "$"+ TalkerId.GA, //Galileo
            "$"+ TalkerId.GB, //BeiDou
            "$"+ TalkerId.GQ, //QZSS
            "$PUBX",
    };
    public static final String TALKER_ID_ANY = "ANY";
    gnss_parser_callbacks m_cb;
    SentenceFactory m_sf = SentenceFactory.getInstance();

    public HashMap<String, Object> getM_parsed_params_hashmap() {
        return m_parsed_params_hashmap;
    }
    HashMap<String, Object> m_parsed_params_hashmap = new HashMap<String, Object>();
    public gnss_parser_callbacks get_callback() {
        return m_cb;
    }
    public ArrayList m_gsv_talker_signal_id_list = new ArrayList<Object[]>();

    //returns valid parsed nmea or null if parse failed
    public HashMap<String, Object> parse(byte[] read_line_raw_bytes) throws Exception {

        if (read_line_raw_bytes == null)
            return null;

        //parse ubx messages if came in this same line first

        //Log.d(TAG, "pre ubx parse: "+toHexString(read_line_raw_bytes));
        int pos_after_ubx_parse = ubx_parse_get_n_bytes_consumed(read_line_raw_bytes);
        int len_remain = read_line_raw_bytes.length - pos_after_ubx_parse;
        //Log.d(TAG, "post ubx parse: pos_after_ubx_parse: "+pos_after_ubx_parse+" len_remain: "+len_remain);
        if (len_remain <= 0)
            return null;

        //String nmea = new String(read_line_raw_bytes, pos_after_ubx_parse, len_remain, "ascii"); //parse from remaining bytes
        String nmea = new String(read_line_raw_bytes, pos_after_ubx_parse, len_remain, StandardCharsets.US_ASCII); //parse nmea from all bytes just to be sure

        /* this should not happen - the case was because a wrong crlf raw buff reader code
        final String NMEA_SPLIT_STR_REGEX = "\\$";
        final String NMEA_SPLIT_STR = "$";
        final int MIN_NMEA_STR_LEN = 5;

        //if multiple sentences in one line
        if (nmea.indexOf(NMEA_SPLIT_STR) != nmea.lastIndexOf(NMEA_SPLIT_STR)) {
            String ret = null;
            String[] parts = nmea.split(NMEA_SPLIT_STR_REGEX);
            System.out.println("parts: " + parts.length);
            for (String part : parts) {
                if (part.length() < MIN_NMEA_STR_LEN)
                    continue;
                String try_sentence = NMEA_SPLIT_STR + part;
                try {
                    String try_ret = parse_nmea_string(try_sentence);
                    if (try_ret != null)
                        ret = try_ret;
                } catch (Exception e) {
                    Log.d(TAG, "multi sentence in one line exception: "+Log.getStackTraceString(e));
                }
            }
            return ret;
        }
        */
        //normal case
        return parse_nmea_string(nmea);
    }


    public HashMap<String, Object> parse_nmea_string(String nmea) throws Exception{
        if (nmea == null) {
            nmea = "";
        }
        nmea = nmea.trim();
        HashMap<String, Object> ret = new HashMap<>();
        ret.put("tx", false);
        ret.put("contents", nmea);

        boolean found_and_filt_to_prefix = false;
        for (String NMEA_PREFIX : KNOWN_NMEA_PREFIX_LIST) {
            if (nmea != null && nmea.contains(NMEA_PREFIX)) {
                if (nmea.startsWith(NMEA_PREFIX)) {
                    //ok good
                } else {
                    int nmea_start_pos = nmea.indexOf(NMEA_PREFIX);
                    //get substring starting with it
                    String prefix_non_nmea = nmea.substring(0, nmea_start_pos);
                    //do something with the prefix_non_nmea if required here
                    nmea = nmea.substring(nmea_start_pos);
                    //System.out.println("nmea substring filt done: " + nmea);
                }
                nmea = nmea.trim(); //this api requires complete valid sentence - no newlines at end...
                found_and_filt_to_prefix = true;
                break;
            }
        }

        if (!found_and_filt_to_prefix) {
            return null;
        }

        //try parse this nmea and update our states
        boolean is_nmea = false;
        try {

            if (nmea.startsWith("$PUBX")) {
                ret.put("name", "PUBX");

                //proprietary messages handle here...
                //Log.d(TAG, "got PUBX: "+nmea);

                if (nmea.startsWith("$PUBX,00")) {
                    //ublox 31.3.2 POSITION (PUBX,00) - https://www.u-blox.com/sites/default/files/products/documents/u-blox8-M8_ReceiverDescrProtSpec_%28UBX-13003221%29_Public.pdf

                    //dont parase to numbers here in case it is empty and we want to continue to other params (would otherwise stop if exception is thrown)...
                    put_param("UBX", "POSITION_time", get_nmea_csv_offset_part(nmea, 2));
                    put_param("UBX", "POSITION_lat", get_nmea_csv_offset_part(nmea, 3));
                    put_param("UBX", "POSITION_NS", get_nmea_csv_offset_part(nmea, 4));
                    put_param("UBX", "POSITION_long", get_nmea_csv_offset_part(nmea, 5));
                    put_param("UBX", "POSITION_EW", get_nmea_csv_offset_part(nmea, 6));
                    put_param("UBX", "POSITION_altRef", get_nmea_csv_offset_part(nmea, 7));
                    put_param("UBX", "POSITION_navStat", get_nmea_csv_offset_part(nmea, 8));
                    put_param("UBX", "POSITION_hAcc", get_nmea_csv_offset_part(nmea, 9));
                    put_param("UBX", "POSITION_vAcc", get_nmea_csv_offset_part(nmea, 10));
                    put_param("UBX", "POSITION_SOG", get_nmea_csv_offset_part(nmea, 11));
                    put_param("UBX", "POSITION_COG", get_nmea_csv_offset_part(nmea, 12));
                    put_param("UBX", "POSITION_vVel", get_nmea_csv_offset_part(nmea, 13));
                    put_param("UBX", "POSITION_diffAge", get_nmea_csv_offset_part(nmea, 14));
                    put_param("UBX", "POSITION_HDOP", get_nmea_csv_offset_part(nmea, 15));
                    put_param("UBX", "POSITION_VDOP", get_nmea_csv_offset_part(nmea, 16));
                    put_param("UBX", "POSITION_TDOP", get_nmea_csv_offset_part(nmea, 17));
                    put_param("UBX", "POSITION_numSvs", get_nmea_csv_offset_part(nmea, 18));

                }


            } else {

                if (nmea.contains("$")) {
                    int li = nmea.lastIndexOf("$");
                    int fi = nmea.indexOf("$");
                    if (fi != li) {
                        //handle some strings coming like: $GNRMC,1$GPGGA,134...
                        nmea = nmea.substring(li);
                    }
                }
                ret.put("nmea", nmea);
                Sentence sentence = m_sf.createParser(nmea);
                String sentence_id = sentence.getSentenceId();
                ret.put("name", sentence_id);

                //sentence type counter
                String param_key = sentence_id + "_count";
                String talker_id = sentence.getTalkerId().name(); //sepcifies talker_id like GN for combined, GA for Galileo, GP for GPS
                inc_param(talker_id, param_key); //talker-to-sentence param

                //handle gsv multi freq signal_id list flush and clear
                if (!(sentence instanceof GSVSentence) && m_gsv_talker_signal_id_list.size() > 0) {
                    try {
                        //System.out.println("handle gsv multi freq signal_id list flush and clear");
                        HashMap<String, ArrayList<Integer>> talker_to_signal_id_list_map = new HashMap<String, ArrayList<Integer>>();
                        for (Object o : m_gsv_talker_signal_id_list) {
                            Object[] oarray = (Object[]) o;
                            String that_talker = (String) oarray[0];
                            int signal_id = (Integer) oarray[1];
                            if (!talker_to_signal_id_list_map.containsKey(that_talker)) {
                                talker_to_signal_id_list_map.put(that_talker, new ArrayList<Integer>());
                            }
                            talker_to_signal_id_list_map.get(that_talker).add(signal_id);
                        }
                        for (String that_talker : talker_to_signal_id_list_map.keySet()) {
                            ArrayList<Integer> signal_ids = talker_to_signal_id_list_map.get(that_talker);
                            put_param(that_talker, "gsv_signal_id_list", signal_ids);
                            //count total sats for that that_talker
                            Set<Integer> that_talker_sats_in_view_unique_id_list_all_signals = new HashSet<Integer>();
                            for (Integer signal_id : signal_ids) {
                                String key = that_talker+"_"+"sats_in_view_id_list"+"_signal_id_"+signal_id;
                                List<Integer> phm = (ArrayList<Integer>) m_parsed_params_hashmap.get(key);
                                if (phm != null) {
                                    that_talker_sats_in_view_unique_id_list_all_signals.addAll(phm);
                                }
                            }
                            put_param(that_talker, "n_sats_in_view", that_talker_sats_in_view_unique_id_list_all_signals.size());
                        }
                    } catch (Exception e) {
                        Log.d(TAG, "handle gsv multi freq signal_id list flush and clear exception: "+Log.getStackTraceString(e));
                    } finally {
                        m_gsv_talker_signal_id_list.clear();
                    }
                }

                /////////////////////// parse and put main params in hashmap
                //System.out.println("got parsed read_line: "+ret);
                if (sentence instanceof GGASentence) {
                    GGASentence gga = (GGASentence) sentence;
                    Position pos = gga.getPosition();

                    try {
                        put_param(talker_id, "lat", pos.getLatitude());
                        put_param(talker_id, "lon", pos.getLongitude());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        //Gets the position altitude from mean sea level - Altitude value in meters - ref https://ktuukkan.github.io/marine-api/0.8.0/javadoc/index.html?net/sf/marineapi/nmea/sentence/GGASentence.html
                        put_param(talker_id, "alt", pos.getAltitude());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        //Get antenna altitude above mean sea level.
                        put_param(talker_id, "gga_alt", gga.getAltitude());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }
                    try {
                        put_param(talker_id, "gga_alt_units", gga.getAltitudeUnits().toString());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }
                    try {
                        //Get height/separation of geoid above WGS84 ellipsoid, i.e. difference between WGS-84 earth ellipsoid and mean sea level.
                        put_param(talker_id, "geoidal_height", gga.getGeoidalHeight());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        put_param(talker_id, "geoidal_height_units", gga.getGeoidalHeightUnits().toString());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        Units alt_units = gga.getGeoidalHeightUnits();
                        Units geoidal_height_units = gga.getGeoidalHeightUnits();
                        if (alt_units == geoidal_height_units) {
                            put_param(talker_id, "ellipsoidal_height", gga.getAltitude() + gga.getGeoidalHeight());
                        }
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        put_param(talker_id, "gga_alt", gga.getAltitude());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }
                    try {
                        put_param(talker_id, "gga_alt_units", gga.getAltitudeUnits().toString());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        put_param(talker_id, "hdop", gga.getHorizontalDOP());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        put_param(talker_id, "dgps_age", gga.getDgpsAge());
                        put_param(talker_id, "dgps_station_id", gga.getDgpsStationId());
                    } catch (DataNotAvailableException dae) {

                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        put_param(talker_id, "fix_quality", gga.getFixQuality().toString());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        put_param(talker_id, "datum", pos.getDatum());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gga nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                } else if (sentence instanceof RMCSentence) {
                    RMCSentence rmc = (RMCSentence) sentence;
                    try {
                        net.sf.marineapi.nmea.util.Date nmeaDate = rmc.getDate();
                        net.sf.marineapi.nmea.util.Time nmeaTime = rmc.getTime();
                        Calendar cal = Calendar.getInstance(TZ_UTC);
                        cal.set(Calendar.YEAR, nmeaDate.getYear());
                        cal.set(Calendar.MONTH, nmeaDate.getMonth() - 1); // Calendar is 0-based
                        cal.set(Calendar.DAY_OF_MONTH, nmeaDate.getDay());
                        cal.set(Calendar.HOUR_OF_DAY, nmeaTime.getHour());
                        cal.set(Calendar.MINUTE, nmeaTime.getMinutes());
                        cal.set(Calendar.SECOND, (int) nmeaTime.getSeconds());
                        cal.set(Calendar.MILLISECOND, 0);
                        long gnss_ts = cal.getTimeInMillis();
                        put_param(talker_id, "rmc_ts", gnss_ts);
                        put_param(talker_id, "time", rmc.getTime().toISO8601());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put rmc nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        put_param(talker_id, "speed", rmc.getSpeed());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put rmc nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        put_param(talker_id, "course", rmc.getCourse());
                    } catch (DataNotAvailableException dae) {
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put rmc nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    try {
                        put_param(talker_id, "mode", rmc.getMode());
                    } catch (Exception pe) {
                        if (pe.toString().contains("No enum constant net.sf.marineapi.nmea.util.FaaMode.F")) {
                            put_param(talker_id, "mode", "FloatRTK");
                        } else if (pe.toString().contains("No enum constant net.sf.marineapi.nmea.util.FaaMode.R")) {
                            put_param(talker_id, "mode", "RTK");
                        } else if (pe.toString().contains("No enum constant net.sf.marineapi.nmea.util.FaaMode.P")) {
                            put_param(talker_id, "mode", "Precise");
                        } else {
                            Log.d(TAG, "parse/put rmc nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                        }
                    }

                    try {
                        put_param(talker_id, "status", rmc.getStatus());
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put rmc nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }

                    //update on RMC
                    if (m_cb != null) {
                        //Log.d(TAG, "calling m_cb callback with parsed params");
                        m_cb.onPositionUpdate(m_parsed_params_hashmap);
                    }
                } else if (sentence instanceof GSASentence) {
                    GSASentence gsa = (GSASentence) sentence;
                    try {
                        //Log.d(TAG, "gsa sentence:" +gsa.toString());
                        String[] sids = gsa.getSatelliteIds();
                        String gsa_talker_id = get_gsa_talker_id_from_gsa_nmea(nmea, sids);
                        //Log.d(TAG, "gsa_talker_id: "+gsa_talker_id);
                        if (gsa_talker_id != null && talker_id.equals(TalkerId.GN.toString())) {
                            //Log.d(TAG, "gsa_talker_id not null sids.length "+sids.length);
                            put_param(gsa_talker_id, "n_sats_used", sids.length);
                            put_param(gsa_talker_id, "sat_used_ids", str_list_to_csv(Arrays.asList(sids)));
                            put_param(gsa_talker_id, "gsa_hdop", gsa.getHorizontalDOP());
                            put_param(gsa_talker_id, "gsa_pdop", gsa.getPositionDOP());
                            put_param(gsa_talker_id, "gsa_vdop", gsa.getVerticalDOP());
                        } else {
                            //Log.d(TAG, "gsa_talker_id null sids.length "+sids.length);
                            put_param(talker_id, "n_sats_used", sids.length);
                            put_param(talker_id, "sats_used_ids", str_list_to_csv(Arrays.asList(sids)));
                            put_param(talker_id, "gsa_hdop", gsa.getHorizontalDOP());
                            put_param(talker_id, "gsa_pdop", gsa.getPositionDOP());
                            put_param(talker_id, "gsa_vdop", gsa.getVerticalDOP());
                        }
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gsa nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }
                } else if (sentence instanceof GSVSentence) {
                    GSVSentence gsv = (GSVSentence) sentence;
                    try {
                        String tmp_param_key_prefix = "tmp_" + talker_id + "_gsv_";
                        final String[] tmp_list_keys_to_flush = {
                                tmp_param_key_prefix + "sats_in_view_id_list",
                                tmp_param_key_prefix + "sats_in_view_snr_list",
                                tmp_param_key_prefix + "sats_in_view_elevation_list",
                                tmp_param_key_prefix + "sats_in_view_azimuth_list",
                                tmp_param_key_prefix + "sats_in_view_signal_id_list"
                        };
                        final int tmp_list_keys_to_flush_offset_id = 0;
                        final int tmp_list_keys_to_flush_offset_noise = 1;
                        final int tmp_list_keys_to_flush_offset_elevation = 2;
                        final int tmp_list_keys_to_flush_offset_azimuth = 3;
                        final int tmp_list_keys_to_flush_offset_signal_id = 4;

                        int signal_id = -1;
                        try {
                            int n_fields = gsv.getFieldCount();
                            boolean has_signal_id = false;
                            if ((n_fields - 7) % 4 == 1) { //ref: gsv number of fields = 7 + [0..4]*4 so if mod 4 == 1 means has extra field and that is signal_id identifying the freq
                                has_signal_id = true;
                            }
                            String signal_id_str = null;
                            String gsv_str = gsv.toString();
                            if (has_signal_id && gsv_str != null && gsv_str.contains(",")) {
                                String[] parts = gsv_str.split(",");
                                if (parts.length > 0) {
                                    String last_part = parts[parts.length - 1];
                                    if (last_part.contains("*")) {
                                        String[] lp_parts = last_part.split("\\*");
                                        if (lp_parts.length > 0) {
                                            signal_id_str = lp_parts[0].trim();
                                            if (!signal_id_str.isEmpty()) {
                                                signal_id = Integer.parseInt(signal_id_str);
                                            }
                                        }
                                    }
                                }
                            }
                            //System.out.println("gsv n_fields "+n_fields+" has_signal_id "+has_signal_id+" signal_id_str "+signal_id_str+" signal_id "+signal_id);
                        } catch (Exception e) {
                            Log.d(TAG, "extract signal_id from gsv exception: "+Log.getStackTraceString(e));
                        }

                        if (gsv.isFirst()) {
                            m_parsed_params_hashmap.put(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_id], new ArrayList<String>());
                            m_parsed_params_hashmap.put(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_noise], new ArrayList<Integer>());
                            m_parsed_params_hashmap.put(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_elevation], new ArrayList<Integer>());
                            m_parsed_params_hashmap.put(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_azimuth], new ArrayList<Integer>());
                            m_parsed_params_hashmap.put(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_signal_id], new ArrayList<Integer>());
                        }

                        //Log.d(TAG, "gsv talker " + talker_id + " page " + gsv.getSentenceIndex() + " n sats in view " + gsv.getSatelliteCount() + " n sat info: " + gsv.getSatelliteInfo().size());
                        for (SatelliteInfo si : gsv.getSatelliteInfo()) {
                            if (m_parsed_params_hashmap.get(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_id]) != null) {
                                ((List<String>) m_parsed_params_hashmap.get(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_id])).add(si.getId());
                                ((List<Integer>) m_parsed_params_hashmap.get(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_noise])).add(si.getNoise());
                                ((List<Integer>) m_parsed_params_hashmap.get(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_elevation])).add(si.getElevation());
                                ((List<Integer>) m_parsed_params_hashmap.get(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_azimuth])).add(si.getAzimuth());
                                ((List<Integer>) m_parsed_params_hashmap.get(tmp_list_keys_to_flush[tmp_list_keys_to_flush_offset_signal_id])).add(signal_id);
                            }
                        }

                        if (gsv.isLast()) {
                            m_gsv_talker_signal_id_list.add(new Object[] {talker_id, signal_id}); //will put_param and clear list on next non-gsv msg
                            put_param(talker_id, "n_sats_in_view"+"_signal_id_"+signal_id, gsv.getSatelliteCount());
                            for (String tmp_key : tmp_list_keys_to_flush) {
                                put_param(talker_id, tmp_key.replace(tmp_param_key_prefix, "")+"_signal_id_"+signal_id, m_parsed_params_hashmap.get(tmp_key));
                            }
                        }

                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gsv nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }
                } else if (sentence instanceof VTGSentence) {
                    VTGSentence vtg = (VTGSentence) sentence;
                    try {
                        put_param(talker_id, "true_course", vtg.getTrueCourse());
                    } catch (DataNotAvailableException dae) {
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gsa nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }
                    try {
                        put_param(talker_id, "magnetic_course", vtg.getMagneticCourse());
                    } catch (DataNotAvailableException dae) {
                    } catch (Exception pe) {
                        Log.d(TAG, "parse/put gsa nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(pe));
                    }
                }
            } //else of non-pubx
        } catch(Exception e){
            Log.d(TAG, "parse/update nmea params/callbacks nmea: [" + nmea + "] got exception: " + Log.getStackTraceString(e));
        }


        return ret;
    }

    // put into m_parsed_params_hashmap directly if is int/long/double/string else conv to string then put... also ass its <param>_ts timestamp
    public void put_param(String talker_id, String param_name, Object val)
    {
        if (val == null) {
            //Log.d(TAG, "put_param null so omit");
            return; //not supported
        }

        String _key = talker_id+"_"+param_name;
        String _key_any = TALKER_ID_ANY+"_"+param_name;
        if (talker_id.isEmpty())
            _key = param_name;
        for (String key : new String[] {_key, _key_any}) {
            if (val instanceof Double || val instanceof Integer || val instanceof Long || val instanceof List) {
                m_parsed_params_hashmap.put(key, val);
            } else {
                m_parsed_params_hashmap.put(key, val.toString());
            }
            m_parsed_params_hashmap.put(key + "_ts", System.currentTimeMillis());
        }
    }

    //for counters
    public void inc_param(String talker_id, String param_name)
    {
        String key = ""+talker_id+"_"+param_name;
        //Log.d(TAG, "inc_param: "+key);
        int cur_counter = 0;
        if (m_parsed_params_hashmap.containsKey(key)) {
            //Log.d(TAG, "inc_param: "+param_name+" exists");
            try {
                cur_counter = (int) m_parsed_params_hashmap.get(key);
            } catch (Exception e) {
                //in case same param key was somehow not an int...
                Log.d(TAG, "WARNING: inc_param prev value for key was likely not an integer - using 0 counter start instead - exception: "+Log.getStackTraceString(e));
            }
        } else {
            //Log.d(TAG, "inc_param: "+param_name+" not exists");
        }

        cur_counter++;
        put_param(talker_id, param_name, cur_counter);
    }



    public HashMap<String, Object> get_params()
    {
        return m_parsed_params_hashmap;
    }


    public boolean is_gga(String sentence) {
        if (sentence.length() > 5 && sentence.substring(3).startsWith("GGA"))
            return true;
        return false;
    }

    public static String get_gsa_talker_id_from_gsa_nmea(String nmea, String[] sids)
    {
        if (nmea.contains(",")) {
            String[] parts = nmea.split(",");
            //Log.d(TAG, "parts.length(): " + parts.length);
            final int GSA_SYSTEM_ID_NMEA_CSV_INDEX = 18;
            String part = get_nmea_csv_offset_part(nmea, GSA_SYSTEM_ID_NMEA_CSV_INDEX);
            if (part != null) {
                int gnss_system_id = Integer.parseInt(part);
                String gnss_system_id_talker_id = get_talker_id_for_gnss_system_id_int(gnss_system_id);
                return gnss_system_id_talker_id;
            } else {
                //part is null so likely no GSA_SYSTEM_ID_NMEA_CSV_INDEX so infer for sat ids
                //https://docs.novatel.com/OEM7/Content/Logs/GPGSA.htm

                boolean is_gps = false;
                boolean is_glonass = false;
                for (String sid: sids) {
                    try {
                        int isid = Integer.parseInt(sid);
                        //if ids are 1-32 so it is GPS
                        //if ids are 65 to 96 then it is GLONASS
                        if (isid >= 1 && isid <= 32) {
                            is_gps = true;
                        } else if (isid >= 65 && isid <= 96) {
                            is_glonass = true;
                        }
                    } catch (Exception e) {

                    }
                }
                if (is_gps) {
                    return TalkerId.GP.toString();
                }
                if (is_glonass) {
                    return TalkerId.GL.toString();
                }


            }
        }
        return null;
    }

    public static String get_nmea_csv_offset_part(String nmea, int offset)
    {
        String[] parts = nmea.split(",");
        if (parts.length > offset) {
            String part = parts[offset];
            if (part.contains("*")) {
                part = part.split("\\*")[0];
            }
            return part;
        }
        return null;
    }

    public static String get_talker_id_for_gnss_system_id_int(int gnss_system_id)
    {
        switch (gnss_system_id) {
            case 1:
                return TalkerId.GP.toString();
            case 2:
                return TalkerId.GL.toString();
            case 3:
                return TalkerId.GA.toString();
            case 4:
                return TalkerId.GB.toString();
            case 5:
                return TalkerId.GQ.toString();
        }
        return null;
    }

    public static String str_list_to_csv(List<String> names)
    {
        StringBuilder namesStr = new StringBuilder();
        for(String name : names)
        {
            namesStr = namesStr.length() > 0 ? namesStr.append(",").append(name) : namesStr.append(name);
        }
        return namesStr.toString();
    }


    public enum MessageType {
        NMEA,
        App,
        Ubx,
        Qstarz
    }

    public interface gnss_parser_callbacks {
        public void onPositionUpdate(HashMap<String, Object> params_map);
        public void onDeviceMessage(MessageType type, HashMap<String, Object> message_map);
    }


    public void set_callback(gnss_parser_callbacks cb){
        Log.d(TAG, "set_callback() "+cb);
        m_cb = cb;
    }

    public static final byte[] fromHexString(final String s) {
        String[] v = s.split(" ");
        byte[] arr = new byte[v.length];
        int i = 0;
        for(String val: v) {
            arr[i++] =  Integer.decode("0x" + val).byteValue();

        }
        return arr;
    }

    public static String toHexString(byte[] a) {
        return toHexString(a, 0, a.length);
    }

    public static String toHexString(byte[] a, int offset, int len) {
        StringBuilder sb = new StringBuilder(a.length * 2);
        byte b;
        for(int i = 0; i < len; i++) {
            b = a[offset + i];
            sb.append(String.format("%02X ", b));
        }
        return sb.toString().trim();
    }



}
