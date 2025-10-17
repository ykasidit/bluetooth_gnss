use anyhow::{anyhow, Result};
use nmea::Nmea;
use serde_json::{Map, Value};
use std::collections::{HashMap, VecDeque};

use crate::nmea_parser::parse_nmea_pkt;
use crate::INPUT_BUFFER;
const EOF_ERROR: &str = "eof";


pub fn queue_and_parse(
    params_state: &mut HashMap<String, Value>,
    nmea_parser_state: &mut Nmea,
    read_buf: &[u8],
) -> Result<Vec<Value>> {
    let mut queue = INPUT_BUFFER.lock().unwrap();
    queue.extend(read_buf);
    //println!("read_buf len: {}", read_buf.len());

    let mut parsed_objects: Vec<Value> = vec![];
    loop {
        let val = parse_queue_get_next_object(params_state, nmea_parser_state, &mut queue);
        match val {
            Ok(obj) => {
                parsed_objects.push(Value::from(obj));
            }
            Err(err) => {
                if err.to_string() == EOF_ERROR {
                    break;
                }
                println!("WARNING: parse_queue_get_next_object got err: {}", err);
                continue;
            }
        }
    }
    Ok(parsed_objects)
}

fn parse_queue_get_next_object(
    params_state: &mut HashMap<String, Value>,
    nmea_parser_state: &mut Nmea,
    buf: &mut VecDeque<u8>,
) -> Result<Map<String, Value>> {
    if buf.is_empty() {
        return Err(anyhow!(EOF_ERROR));
    }
    //println!("parse_queue_get_next_object0");
    //get next valid nmea or ubx buffer
    let gnss_pkt = next_gnss_packet(buf).ok_or(anyhow!(EOF_ERROR))?;
    //println!("parse_queue_get_next_object1");
    match gnss_pkt {
        GnssPacket::Nmea(nmea_packet) => {
	    println!("got nmea pkt");
            let ret = parse_nmea_pkt(params_state, nmea_parser_state, nmea_packet)?;
            Ok(ret)
        }
        GnssPacket::Ubx(_ubx_packet) => {
	    println!("got ubx");
            let mut ret: Map<String, Value> = Map::new();
            ret.insert("ubx_type".to_string(), Value::from(format!("{}", "todo")));
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
	//println!("slice len: {}", slice.len());
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
	//println!("candidate at i {i}");

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


