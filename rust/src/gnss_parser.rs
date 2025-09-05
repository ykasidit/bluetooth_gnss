extern crate jni;
use anyhow::{anyhow, format_err, Result};
use jni::objects::JClass;
use jni::sys::{jbyteArray, jstring};
use jni::JNIEnv;
use kampu::utils::hex_to_bin;
use lazy_static::lazy_static;
use serde_json::{json, Map, Value};
use std::collections::{HashMap, VecDeque};
use std::ops::{Deref, DerefMut};
use std::sync::Mutex;
use nmea::{Error, Nmea, ParseResult, SentenceType};
use nmea;

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
    let parsed_result = queue_and_parse(byte_vec);
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


fn queue_and_parse(read_buf: Vec<u8>) -> Result<Vec<Value>>
{
    let mut queue = INPUT_BUFFER.lock().unwrap();
    queue.extend(read_buf);

    let mut parsed_objects: Vec<Value> = vec![];
    loop {
        let val = parse_queue_get_next_object(&mut queue);
        if (val.is_ok()) {
            parsed_objects.push(Value::from(val.unwrap()));
        } else { break; }
    }
    Ok(parsed_objects)
}

fn parse_queue_get_next_object(buf: &mut VecDeque<u8>) -> Result<Map<String, Value>> {
    if buf.is_empty() {
        return Err(anyhow!("buffer is empty"));
    }
    //get next valid nmea or ubx buffer
    let gnss_pkt = next_gnss_packet(buf).ok_or(anyhow!("no more packets"))?;
    match gnss_pkt {
        GnssPacket::Nmea(nmea_packet) => {
            let nmea_str = String::from_utf8(nmea_packet)?;
            let mut ret:Map<String, Value> = Map::new();
            let pr = nmea::parse_str(&nmea_str).map_err(|e| {anyhow!("{e}")})?;
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
                ParseResult::GGA(gga) => {

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
                ParseResult::RMC(_) => {}
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
            let sentence_type = parser.parse(nmea_str.as_str()).map_err(|e| anyhow!("{e}"))?;
            ret.insert("sentence_type".to_string(),  Value::from(format!("{:?}",sentence_type)));
            match sentence_type {
                SentenceType::RMC => {
                    let n = NMEA_PARSER.lock().unwrap().clone();
                    let v:Value = serde_json::to_value(&n)?;
                    ret.insert(
                        "parser_state".to_string(),
                        v
                    );
                }
                _ => {}
            }
            Ok(ret)
        }
        GnssPacket::Ubx(ubx_packet) => {
            let mut ret:Map<String, Value> = Map::new();
            ret.insert("sentence_type".to_string(),  Value::from(format!("{}","ubx")));
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
        }

        // ---------- NMEA path ----------
        // Find LF; accept CRLF or bare LF
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

        // Include LF; keep CR if present just before LF.
        // We return the line including its terminator(s).
        let line_len = end_idx + 1;
        let line: Vec<u8> = buf.drain(0..line_len).collect();
        return Some(GnssPacket::Nmea(line));
    }
}


#[test]
fn test_gnss_pkt()
{
    let data = hex_to_bin("00 0D 0A 0D 0A B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A B5 62 06 01 03 00 F1 00 01 FC 13 31 34 30 0D 0A FF EF");
    let parsed_pkts = queue_and_parse(data).unwrap();
    println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
    assert_eq!(parsed_pkts.len(), 2);
}
