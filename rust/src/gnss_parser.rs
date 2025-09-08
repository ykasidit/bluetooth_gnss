extern crate jni;
use anyhow::{anyhow, format_err, Result};
use jni::objects::JClass;
use jni::sys::{jbyteArray, jstring};
use jni::JNIEnv;
use kampu::utils::hex_to_bin;
use lazy_static::lazy_static;
use serde_json::{json, Map, Value};
use std::collections::{HashMap, VecDeque};
use std::fmt::format;
use std::ops::{Deref, DerefMut};
use std::sync::Mutex;
use nmea::{parse_nmea_sentence, parse_str, Error, Nmea, NmeaSentence, ParseResult, SentenceType};

const eof_error: &str = "eof";

lazy_static! {
    static ref INPUT_BUFFER: Mutex<VecDeque<u8>> = Mutex::new(VecDeque::with_capacity(1024));
    static ref OUTPUT_STATE_PARAMS_MAP: Mutex<HashMap<String, Value>> = Mutex::new(HashMap::new());
    static ref NMEA_PARSER: Mutex<Vec<Nmea>> = Mutex::new(vec![Nmea::default()]);
}

#[no_mangle]
pub extern "C" fn Java_com_clearevo_libbluetooth_1gnss_1service_NativeParser_on_1gnss_1pkt(
    env: JNIEnv,
    _class: JClass,
    byte_array: jbyteArray
) -> jstring {
    let byte_vec: Vec<u8> = env.convert_byte_array(byte_array).unwrap();

    //////////////
    let parsed_result = queue_and_parse(byte_vec.as_slice());
    let mut json_str = String::new();
    match parsed_result {
        Ok(parsed_objects) => {
            json_str = serde_json::to_string(&parsed_objects).unwrap();
        }
        Err(e) => {
            json_str = serde_json::to_string(&json!({"error": e.to_string()})).unwrap();
        }
    }

    //////////////////
    let output = env.new_string(json_str).unwrap();
    output.into_inner()
}

pub extern "C" fn Java_com_clearevo_libbluetooth_1gnss_1service_NativeParser_reset_1gnss_1parser(
    env: JNIEnv,
    _class: JClass,
) {
    let mut p = NMEA_PARSER.lock().unwrap();
    p.clear();
    p.push(Nmea::default());
    OUTPUT_STATE_PARAMS_MAP.lock().unwrap().clear();
}


fn queue_and_parse(read_buf: &[u8]) -> Result<Vec<Value>>
{
    let mut queue = INPUT_BUFFER.lock().unwrap();
    queue.extend(read_buf);

    let mut parsed_objects: Vec<Value> = vec![];
    loop {
        let val = parse_queue_get_next_object(&mut queue);
        match val {
            Ok(obj) => {
                parsed_objects.push(Value::from(obj));
            }
            Err(err) => {
                if err.to_string() == eof_error {
                    break;
                }
                println!("WARNING: parse_queue_get_next_object got err: {}", err);
                continue;
            }
        }
    }
    Ok(parsed_objects)
}

fn parse_queue_get_next_object(buf: &mut VecDeque<u8>) -> Result<Map<String, Value>> {
    if buf.is_empty() {
        return Err(anyhow!(eof_error));
    }
    //get next valid nmea or ubx buffer
    let gnss_pkt = next_gnss_packet(buf).ok_or(anyhow!(eof_error))?;
    match gnss_pkt {
        GnssPacket::Nmea(nmea_packet) => {
            let mut ret:Map<String, Value> = Map::new();
            ret.insert("type".to_string(), Value::from("nmea".to_string()));
            let nmea_str_pretrim = String::from_utf8(nmea_packet).map_err(|e| {anyhow!("from_utf8 {e}")})?;
            let nmea_str = nmea_str_pretrim.trim();
            //println!("nmea_str: {}", nmea_str);
            let sentence = parse_nmea_sentence(nmea_str).map_err(|e| {anyhow!("parse_nmea_sentence: {e}")})?;
            ret.insert("talker".to_string(), Value::from(sentence.talker_id.to_string()));
            ret.insert("message".to_string(), Value::from(sentence.message_id.to_string()));

            let pr = parse_str(nmea_str).map_err(|e| {anyhow!("{e}")})?;
            let mut is_rmc = false;
            match pr {
                ParseResult::AAM(_) => {}
                ParseResult::ALM(_) => {}
                ParseResult::APA(_) => {}
                ParseResult::BOD(_) => {}
                ParseResult::BWC(_) => {}
                ParseResult::BWW(_) => {}
                ParseResult::DBK(_) => {}
                ParseResult::DPT(_) => {}
                ParseResult::GBS(_) => {}
                ParseResult::GGA(_) => {

                }
                ParseResult::GLL(_) => {}
                ParseResult::GNS(_) => {}
                ParseResult::GSA(_) => {}
                ParseResult::GST(_) => {}
                ParseResult::GSV(_) => {}
                ParseResult::HDT(_) => {}
                ParseResult::MDA(_) => {}
                ParseResult::MTW(_) => {}
                ParseResult::MWV(_) => {}
                ParseResult::RMC(_) => {
                    is_rmc = true
                }
                ParseResult::TTM(_) => {}
                ParseResult::TXT(_) => {}
                ParseResult::VHW(_) => {}
                ParseResult::VTG(_) => {}
                ParseResult::WNC(_) => {}
                ParseResult::ZDA(_) => {}
                ParseResult::ZFO(_) => {}
                ParseResult::ZTG(_) => {}
                ParseResult::PGRMZ(_) => {}
                ParseResult::Unsupported(_) => {}
            }
            let mut parserv = NMEA_PARSER.lock().unwrap();
            let mut parser = parserv.first_mut().unwrap();
            let fix_type = parser.parse_for_fix(nmea_str).map_err(|e| anyhow!("{e}"))?;
            if is_rmc {
                println!("fix_type: {:?}", fix_type);
                let ft_v = serde_json::to_value(format!("{}", fix_type))?;
                ret.insert("fix_type".to_string(),  ft_v);

                println!("parser: {}", parser);
                parser.num_of_fix_satellites
                let v = serde_json::to_value(parser)?;
                ret.insert("parser".to_string(),  v);

            }
            Ok(ret)
        }
        GnssPacket::Ubx(ubx_packet) => {
            let mut ret:Map<String, Value> = Map::new();
            ret.insert("ubx_type".to_string(),  Value::from(format!("{}","todo")));
            Ok(ret)
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GnssPacket {
    Nmea(Vec<u8>), // Includes the trailing CRLF (or just LF if present)
    Ubx(Vec<u8>),  // B5 62 CLASS ID LENL LENH PAYLOAD CK_A CK_B
}

/// Try to extract the next GNSS packet from `buf`.
/// - Returns `Some(GnssPacket)` when a full NMEA or UBX packet is present.
/// - Returns `None` when more bytes are needed (buffer left unchanged except for leading garbage skips).
pub fn next_gnss_packet(buf: &mut VecDeque<u8>) -> Option<GnssPacket> {
    loop {
        // Make it contiguous for fast scanning.
        let slice = buf.make_contiguous();

        // If empty, we need more data.
        if slice.is_empty() {
            return None;
        }

        // Find the next plausible start: NMEA ('$' or '!') or UBX (0xB5 0x62).
        let mut i = 0usize;
        while i < slice.len() {
            let b = slice[i];
            if b == b'$' || b == b'!' {
                break; // candidate NMEA start
            }
            if b == 0xB5 {
                // Need at least one more byte to check UBX sync2
                if i + 1 < slice.len() && slice[i + 1] == 0x62 {
                    break; // candidate UBX start
                }
            }
            i += 1;
        }

        // If we only found garbage so far, drop it and loop.
        if i > 0 {
            buf.drain(0..i);
            continue;
        }

        // At this point, slice[0] is either '$'/'!' (NMEA) or 0xB5 possibly UBX.
        let slice = buf.make_contiguous();

        // ---------- UBX path ----------
        if slice[0] == 0xB5 {
            // Need at least 6 bytes for header (B5 62 CLASS ID LENL LENH)
            if slice.len() < 6 {
                return None; // need more bytes
            }
            if slice[1] != 0x62 {
                // False alarm; drop one byte and rescan.
                buf.pop_front();
                continue;
            }

            let len = (slice[4] as usize) | ((slice[5] as usize) << 8);
            let total = 6 + len + 2;
            if slice.len() < total {
                return None; // need more bytes
            }

            // Verify checksum over CLASS, ID, LENL, LENH, and payload.
            let mut ck_a: u8 = 0;
            let mut ck_b: u8 = 0;
            for &byte in &slice[2..(6 + len)] {
                ck_a = ck_a.wrapping_add(byte);
                ck_b = ck_b.wrapping_add(ck_a);
            }
            let got_a = slice[6 + len];
            let got_b = slice[6 + len + 1];

            if ck_a == got_a && ck_b == got_b {
                // Extract this UBX packet.
                let pkt: Vec<u8> = buf.drain(0..total).collect();
                return Some(GnssPacket::Ubx(pkt));
            } else {
                // Desync: drop the first byte and try again.
                buf.pop_front();
                continue;
            }
        } else if slice[0] == b'$' || slice[0] == b'!' {
            // ---------- NMEA path ----------
            // Find LF
            let mut lf_idx: Option<usize> = None;
            for (idx, &b) in slice.iter().enumerate() {
                if b == b'\n' {
                    lf_idx = Some(idx);
                    break;
                }
            }
            let Some(end_idx) = lf_idx else {
                return None; // no full line yet
            };

            // Include LF
            let line_len = end_idx + 1;
            let line: Vec<u8> = buf.drain(0..line_len).collect();

            // ----- validate NMEA -----
            // Must start with '$' or '!'
            if !(line.starts_with(b"$") || line.starts_with(b"!")) {
                continue; // not valid, drop and rescan
            }
            // Must end with '\n' (already ensured) and ideally CRLF
            if !(line.ends_with(b"\r\n") || line.ends_with(b"\n")) {
                continue; // invalid terminator
            }
            // Optional: check minimum length
            if line.len() < 6 {
                continue; // too short to be NMEA
            }

            return Some(GnssPacket::Nmea(line));
        }

    }
}


#[test]
fn test_nmea_parse_map_state()
{
    let example_nmea_gga = "$GNGGA,045115.00,0000.000,N,00000.000,E,1,12,0.60,3.0,M,-13.0,M,,*6F";
    let ex1 = format!("chad_yak_pai_wangkeaw_leaw{}", example_nmea_gga);
    let inputs = vec![
        "$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\n",
        "$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\r\n", //must support both crlf and lf
        "$GNRMC,095520.00,A,2733.35607,S,15302.15703,E,0.042,,240719,,,A,V*0A\n",
        "03:01:42  $GNGSA,A,3,17,05,12,19,09,28,02,06,,,,,1.10,0.49,0.99,1*03\n",
        "03:01:42  $GNGSA,A,3,81,67,66,79,78,,,,,,,,1.10,0.49,0.99,2*06\n",
        "03:01:42  $GNGSA,A,3,04,33,19,31,24,12,,,,,,,1.10,0.49,0.99,3*05\n",
        "03:01:42  $GNGSA,A,3,23,28,27,08,10,07,13,16,09,,,,1.10,0.49,0.99,4*05\n",
        "$GNGSA,A,3,26,31,10,32,14,16,25,20,18,22,41,,1.34,0.74,1.12*16\n",

        //can handle input trash/invalid prefix
        "03:52:31  $GPGSV,3,1,12,02,30,352,41,05,67,295,38,06,18,039,28,09,03,049,37,1*68\n",
        "03:52:31  $GPGSV,3,2,12,12,44,295,46,13,32,171,31,15,12,204,32,17,34,106,31,1*6B\n",
        "03:52:31  $GPGSV,3,3,12,19,43,089,27,24,06,235,,25,08,315,,28,06,154,,1*6C\n",

        "03:52:31  $GPGSV,3,1,12,02,30,352,,05,67,295,23,06,18,039,35,09,03,049,,6*68\n",
        "03:52:31  $GPGSV,3,2,12,12,44,295,35,13,32,171,,15,12,204,23,17,34,106,25,6*6F\n",
        "03:52:31  $GPGSV,3,3,12,19,43,089,,24,06,235,,25,08,315,,28,06,154,,6*6E\n",

        "03:52:31  $GLGSV,3,1,10,66,14,029,43,67,66,046,39,68,51,193,,69,03,202,,1*76\n",
        "03:52:31  $GLGSV,3,2,10,78,05,173,,79,23,220,28,80,16,275,,81,26,053,34,1*71\n",
        "03:52:31  $GLGSV,3,3,10,82,20,360,32,88,08,097,,1*73\n",
        "03:52:31  $GLGSV,3,1,10,66,14,029,33,67,66,046,09,68,51,193,,69,03,202,,3*70\n",
        "03:52:31  $GLGSV,3,2,10,78,05,173,,79,23,220,21,80,16,275,,81,26,053,27,3*78\n",
        "03:52:31  $GLGSV,3,3,10,82,20,360,26,88,08,097,,3*74\n",
        "03:52:31  $GAGSV,3,1,10,01,14,165,18,04,53,180,30,09,07,208,22,11,05,307,,7*72\n",
        "03:52:31  $GAGSV,3,2,10,12,29,354,41,19,52,068,24,24,29,280,43,26,00,093,11,7*75\n",
        "03:52:31  $GAGSV,3,3,10,31,40,214,28,33,26,051,30,7*7A\n",
        "03:52:31  $GAGSV,3,1,10,01,14,165,,04,53,180,25,09,07,208,,11,05,307,,2*7A\n",
        "03:52:31  $GAGSV,3,2,10,12,29,354,33,19,52,068,23,24,29,280,33,26,00,093,,2*75\n",
        "03:52:31  $GAGSV,3,3,10,31,40,214,15,33,26,051,,2*72\n",
        "03:52:31  $GBGSV,5,1,18,01,45,099,,02,68,253,,03,77,122,,04,23,094,,1*79\n",
        "03:52:31  $GBGSV,5,2,18,05,40,264,,06,54,132,10,07,42,177,30,08,28,020,30,1*7F\n",
        "03:52:31  $GBGSV,5,3,18,09,43,169,,10,55,209,27,13,33,352,39,16,53,145,37,1*7F\n",
        "03:52:31  $GBGSV,5,4,18,18,37,350,,20,16,216,,23,08,156,,27,38,003,39,1*79\n",
        "03:52:31  $GBGSV,5,5,18,28,37,072,35,30,04,321,,1*75\n",
        "03:52:31  $GBGSV,5,1,18,01,45,099,,02,68,253,,03,77,122,,04,23,094,,3*7B\n",
        "03:52:31  $GBGSV,5,2,18,05,40,264,,06,54,132,26,07,42,177,29,08,28,020,37,3*77\n",
        "03:52:31  $GBGSV,5,3,18,09,43,169,,10,55,209,24,13,33,352,39,16,53,145,26,3*7E\n",
        "03:52:31  $GBGSV,5,4,18,18,37,350,,20,16,216,,23,08,156,,27,38,003,,3*71\n",
        "03:52:31  $GBGSV,5,5,18,28,37,072,,30,04,321,,3*71\n",
        "03:52:31  $GNGLL,0641.64673,N,10137.05675,E,035231.00,A,A*77\n",
        "03:52:31  $PUBX,00,035231.00,0641.64673,N,10137.05675,E,19.144,G3,1.2,2.2,0.015,0.00,0.037,,0.51,0.93,0.58,26,0,0*6D\n",
        "03:52:31  $PUBX,03,32,2,U,352,30,41,064,5,U,295,67,38,064,6,U,039,18,28,064,9,e,049,03,,000,12,U,295,44,46,064,13,U,171,32,31,061,15,U,204,12,32,064,17,U,106,34,31,007,19,U,089,43,27,003,24,-,235,06,,000,25,-,315,08,,000,28,e,154,06,,000,30,-,123,-2,,000,211,e,165,14,18,000,214,U,180,53,30,020,219,-,208,07,,000,221,-,307,05,,000,222,U,354,29,41,064,229,U,068,52,24,000,234,U,280,29,43,064,236,e,093,00,,000,241,U,214,40,28,026,243,U,051,26,30,064,159,-,099,45,,000,160,-,253,68,,000,161,-,122,77,,000,162,-,094,23,,000,163,-,264,40,,000,33,e,132,54,10,000,34,U,177,42,30,020,35,U,020,28,30,064,36,e,169,43,,000*38\n" ,
        "03:52:31  $PUBX,04,035231.00,140919,532351.00,2070,18,541289,165.421,08*1A\n",
        "$GNVTG,,T,,M,0.206,N,0.382,K,A*30",
        ex1.as_str()
    ];

    for instr in inputs {
        let bb = instr.as_bytes();
        let parsed_pkts = queue_and_parse(bb).unwrap();
        println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
    }

    /* TODO: OUTPUT_STATE_PARAMS_MAP put in "state" key of jni func output or of queue_and_parse caller func
    assertTrue(2 == (int) params.get("GN_GGA_count"));
        assertTrue(1 == (int) params.get("GN_RMC_count"));
        assertTrue(2 <= (int) params.get("GA_GSV_count"));

        System.out.println("GP_n_sats_in_view: "+params.get("GP_n_sats_in_view"));
        System.out.println("GP_n_sats_used: "+params.get("GP_n_sats_used"));
        assertTrue(11 == (int) params.get("GP_n_sats_used"));
        assertTrue(12 == (int) params.get("GP_n_sats_in_view"));
        assertTrue(12 == ((List)params.get("GP_sats_in_view_snr_list_signal_id_1")).size());

        System.out.println("GL_n_sats_used: "+params.get("GL_n_sats_used"));
        assertTrue(5 == (int) params.get("GL_n_sats_used"));

        System.out.println("GA_n_sats_used: "+params.get("GA_n_sats_used"));
        assertTrue(6 == (int) params.get("GA_n_sats_used"));

        System.out.println("GB_n_sats_in_view: "+params.get("GB_n_sats_in_view"));
        System.out.println("GB_n_sats_used: "+params.get("GB_n_sats_used"));
        assertTrue(9 == (int) params.get("GB_n_sats_used"));
        assertTrue(18 == (int) params.get("GB_n_sats_in_view"));
        assertTrue(18 == ((List)params.get("GB_sats_in_view_snr_list_signal_id_1")).size());

        System.out.println("UBX_POSITION_numSvs: "+params.get("UBX_POSITION_numSvs"));
        assertTrue(26 == Integer.parseInt((String) params.get("UBX_POSITION_numSvs")));
        String[] plist = new String[] {"lat", "lon", "gga_alt", "gga_alt_units", "geoidal_height", "geoidal_height_units", "ellipsoidal_height"};
        for (String pi : plist) {
            System.out.println(pi+": "+params.get("GN_"+pi));
        }
        assertTrue(params.get("GN_lat").toString().startsWith("0."));
        assertTrue(params.get("GN_lon").toString().startsWith("0."));
    */
}

#[test]
fn test_nmea_pkt_parse()
{
    //GA-GSV
    let mut nmea = "$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\n".to_string();
    let bb = nmea.as_bytes();
    let parsed_pkts = queue_and_parse(bb).unwrap();
    println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
    assert_eq!(parsed_pkts.len(), 1);
    assert_eq!(
        parsed_pkts[0],
        json!({
            "type": "nmea",
            "talker": "GA",
            "message": "GSV"
        })
    );

    let s = concat!(
"�b\u{1}0\u{4}\u{1}�e�\u{11}\u{15}\u{4}\u{0}\u{0}\n",
"\u{2}\n",
"\u{7}\" \u{1F}Z\u{1}W���\u{3}\u{6}\n",
"\u{7}\"?,\u{0}����\u{8}\u{C}\n",
"\u{7} \n",
"�\u{0}����\u{4}\n",
"\n",
"\u{7}\u{1B}\u{14}D\u{1}\u{15}���\u{0}\u{F}\n",
"\u{7}\"\u{E}\u{1F}\u{1}����\u{1}\u{11}\n",
"\u{7}&.�\u{0}����\u{7}\u{13}\n",
"\u{4}\u{14}=�\u{0}L���\u{E}\u{18}\n",
"\u{7}\u{1D}\"�\u{0}�\u{3}\u{0}\u{0}\u{2}\u{1C}\n",
"\u{7}\u{1F}\u{1C}a\u{0}U���\u{11}\u{1E}\n",
"\u{7}\u{1A}\u{B} \u{0}�\u{2}\u{0}\u{0}\u{B}�\n",
"\u{7}\u{1C}\u{1C}D\u{0}�\u{7}\u{0}\u{0}\n",
"�\u{C}\u{4}\u{14}\u{4}3\u{1}z\u{3}\u{0}\u{0}\t�\n",
"\u{7}\u{1D}\u{10}G\u{1}!\u{1}\u{0}\u{0}\u{C}�\u{10}\u{1}\u{0}�\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}��\u{C}\u{0}\u{0}DS\u{1}\u{0}\u{0}\u{0}\u{0}\u{6}�\n",
"\u{7}\u{1F}%�\u{0}.\u{0}\u{0}\u{0}\u{F}�\n",
"\u{7}$D�\u{0}A\u{0}\u{0}\u{0}��\u{4}\u{0}\u{0}\u{4}�\u{0}\u{0}\u{0}\u{0}\u{0}\u{12}�\u{4}\u{4}\u{10}\u{C}[...\n",
"$GNRMC,095520.00,A,2733.35607,S,15302.15703,E,0.042,,240719,,,A,V*0A\n"
    );
    let bb = s.as_bytes();
    let parsed_pkts = queue_and_parse(bb).unwrap();
    println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
    assert_eq!(parsed_pkts.len(), 1);
    assert_eq!(
        parsed_pkts[0],
        json!({
            "type": "nmea",
            "talker": "GN",
            "message": "RMC",
            "fix_type": "Gps"
        })
    );
}

#[test]
fn test_ubx_pkt_parse()
{
    let data = hex_to_bin("00 0D 0A 0D 0A B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A FF EF");
    let parsed_pkts = queue_and_parse(&data).unwrap();
    println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
    assert_eq!(parsed_pkts.len(), 2);
}
