use anyhow::{anyhow, Result};
use nmea::Nmea;
use serde_json::{Map, Value};
use std::collections::{HashMap, VecDeque};

use crate::nmea_parser::parse_nmea_pkt;
use crate::ubx_parser::parse_ubx_pkt;
use crate::INPUT_BUFFER;
const EOF_ERROR: &str = "eof";


pub fn queue_and_parse(
    params_state: &mut HashMap<String, Value>,
    nmea_parser_state: &mut Nmea,
    read_buf: &[u8],
) -> Result<Vec<Value>> {
    let mut queue = INPUT_BUFFER.lock().unwrap();
    queue.extend(read_buf);
    println!("read_buf len: {}", read_buf.len());

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
        GnssPacket::Ubx(ubx_packet) => {
	    println!("got ubx");
            let ret = parse_ubx_pkt(&ubx_packet)?;
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


#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::VecDeque;

    /// Build a valid UBX frame with correct checksum.
    fn make_ubx_frame(class: u8, id: u8, payload: &[u8]) -> Vec<u8> {
        let len = payload.len() as u16;
        let mut frame = vec![0xB5, 0x62, class, id, (len & 0xFF) as u8, (len >> 8) as u8];
        frame.extend_from_slice(payload);
        let mut ck_a: u8 = 0;
        let mut ck_b: u8 = 0;
        for &b in &frame[2..] {
            ck_a = ck_a.wrapping_add(b);
            ck_b = ck_b.wrapping_add(ck_a);
        }
        frame.push(ck_a);
        frame.push(ck_b);
        frame
    }

    #[test]
    fn test_next_gnss_packet_nmea_simple() {
        let nmea = b"$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,47.0,M,,*47\n";
        let mut buf: VecDeque<u8> = nmea.iter().copied().collect();
        let pkt = next_gnss_packet(&mut buf);
        assert!(pkt.is_some());
        match pkt.unwrap() {
            GnssPacket::Nmea(data) => {
                assert!(data.starts_with(b"$GPGGA"));
                assert!(data.ends_with(b"\n"));
            }
            _ => panic!("expected NMEA packet"),
        }
        assert!(buf.is_empty());
    }

    #[test]
    fn test_next_gnss_packet_nmea_crlf() {
        let nmea = b"$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,47.0,M,,*47\r\n";
        let mut buf: VecDeque<u8> = nmea.iter().copied().collect();
        let pkt = next_gnss_packet(&mut buf);
        assert!(pkt.is_some());
        match pkt.unwrap() {
            GnssPacket::Nmea(data) => assert!(data.ends_with(b"\r\n")),
            _ => panic!("expected NMEA"),
        }
    }

    #[test]
    fn test_next_gnss_packet_nmea_with_garbage_prefix() {
        // Random bytes before a valid NMEA sentence — should skip garbage
        let mut data: Vec<u8> = vec![0xFF, 0xAB, 0x00, 0x13, 0x99];
        data.extend_from_slice(b"$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A\n");
        let mut buf: VecDeque<u8> = data.into_iter().collect();
        let pkt = next_gnss_packet(&mut buf);
        assert!(pkt.is_some());
        match pkt.unwrap() {
            GnssPacket::Nmea(d) => assert!(d.starts_with(b"$GPRMC")),
            _ => panic!("expected NMEA"),
        }
    }

    #[test]
    fn test_next_gnss_packet_nmea_incomplete() {
        // Incomplete NMEA — no newline yet
        let nmea = b"$GPGGA,123519,4807.038,N";
        let mut buf: VecDeque<u8> = nmea.iter().copied().collect();
        let pkt = next_gnss_packet(&mut buf);
        assert!(pkt.is_none());
        // Buffer should still contain the data, waiting for more
        assert_eq!(buf.len(), nmea.len());
    }

    #[test]
    fn test_next_gnss_packet_ubx_valid() {
        let payload = vec![0x01, 0x02, 0x03, 0x04];
        let frame = make_ubx_frame(0x01, 0x07, &payload);
        let mut buf: VecDeque<u8> = frame.into_iter().collect();
        let pkt = next_gnss_packet(&mut buf);
        assert!(pkt.is_some());
        match pkt.unwrap() {
            GnssPacket::Ubx(data) => {
                assert_eq!(data[0], 0xB5);
                assert_eq!(data[1], 0x62);
                assert_eq!(data[2], 0x01); // class
                assert_eq!(data[3], 0x07); // id
            }
            _ => panic!("expected UBX packet"),
        }
        assert!(buf.is_empty());
    }

    #[test]
    fn test_next_gnss_packet_ubx_incomplete() {
        let payload = vec![0x01, 0x02, 0x03, 0x04];
        let frame = make_ubx_frame(0x01, 0x07, &payload);
        // Send only partial frame (missing last 2 bytes = checksum)
        let partial = &frame[..frame.len() - 2];
        let mut buf: VecDeque<u8> = partial.iter().copied().collect();
        let pkt = next_gnss_packet(&mut buf);
        assert!(pkt.is_none());
    }

    #[test]
    fn test_next_gnss_packet_ubx_bad_checksum() {
        let payload = vec![0x01, 0x02, 0x03, 0x04];
        let mut frame = make_ubx_frame(0x01, 0x07, &payload);
        // Corrupt checksum
        let last = frame.len() - 1;
        frame[last] ^= 0xFF;
        let mut buf: VecDeque<u8> = frame.into_iter().collect();
        // Should skip the bad UBX and return None (no more data to parse)
        let pkt = next_gnss_packet(&mut buf);
        assert!(pkt.is_none());
    }

    #[test]
    fn test_next_gnss_packet_mixed_nmea_and_ubx() {
        // Mix NMEA + UBX in one stream
        let nmea = b"$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,47.0,M,,*47\n";
        let payload = vec![0xAA; 10];
        let ubx_frame = make_ubx_frame(0x01, 0x07, &payload);
        let nmea2 = b"$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A\n";

        let mut data = Vec::new();
        data.extend_from_slice(nmea);
        data.extend_from_slice(&ubx_frame);
        data.extend_from_slice(nmea2);

        let mut buf: VecDeque<u8> = data.into_iter().collect();

        // First packet: NMEA GGA
        let pkt1 = next_gnss_packet(&mut buf).unwrap();
        match pkt1 {
            GnssPacket::Nmea(d) => assert!(d.starts_with(b"$GPGGA")),
            _ => panic!("expected NMEA"),
        }

        // Second packet: UBX
        let pkt2 = next_gnss_packet(&mut buf).unwrap();
        match pkt2 {
            GnssPacket::Ubx(d) => {
                assert_eq!(d[0], 0xB5);
                assert_eq!(d[2], 0x01);
            }
            _ => panic!("expected UBX"),
        }

        // Third packet: NMEA RMC
        let pkt3 = next_gnss_packet(&mut buf).unwrap();
        match pkt3 {
            GnssPacket::Nmea(d) => assert!(d.starts_with(b"$GPRMC")),
            _ => panic!("expected NMEA"),
        }

        // No more packets
        assert!(next_gnss_packet(&mut buf).is_none());
    }

    #[test]
    fn test_next_gnss_packet_ubx_between_garbage() {
        // Garbage bytes, then UBX, then garbage
        let payload = vec![0x55; 4];
        let ubx_frame = make_ubx_frame(0x05, 0x01, &payload);
        let mut data: Vec<u8> = vec![0xFF, 0xFE, 0x00];
        data.extend_from_slice(&ubx_frame);
        data.extend_from_slice(&[0xAA, 0xBB]);

        let mut buf: VecDeque<u8> = data.into_iter().collect();
        let pkt = next_gnss_packet(&mut buf).unwrap();
        match pkt {
            GnssPacket::Ubx(d) => assert_eq!(d[2], 0x05),
            _ => panic!("expected UBX"),
        }
        // Remaining should be the trailing garbage
        assert_eq!(buf.len(), 2);
    }

    #[test]
    fn test_next_gnss_packet_empty_buffer() {
        let mut buf: VecDeque<u8> = VecDeque::new();
        assert!(next_gnss_packet(&mut buf).is_none());
    }

    #[test]
    fn test_next_gnss_packet_nmea_exclamation_mark() {
        // NMEA can start with '!' (e.g., AIS sentences like !AIVDM)
        let nmea = b"!AIVDM,1,1,,A,15MgK70P00G?Ow0NKB8P0?v4062D,0*4B\n";
        let mut buf: VecDeque<u8> = nmea.iter().copied().collect();
        let pkt = next_gnss_packet(&mut buf);
        assert!(pkt.is_some());
        match pkt.unwrap() {
            GnssPacket::Nmea(d) => assert!(d.starts_with(b"!AIVDM")),
            _ => panic!("expected NMEA"),
        }
    }

    #[test]
    fn test_queue_and_parse_ubx_nav_pvt() {
        // Test that a UBX NAV-PVT packet goes through queue_and_parse and produces JSON
        let mut payload = vec![0u8; 92];
        // fixType = 3 (3D)
        payload[20] = 3;
        // numSV = 8
        payload[23] = 8;
        // lon = 101.5 deg = 1015000000 (1e-7)
        payload[24..28].copy_from_slice(&1015000000i32.to_le_bytes());
        // lat = 13.75 deg = 137500000
        payload[28..32].copy_from_slice(&137500000i32.to_le_bytes());

        let frame = make_ubx_frame(0x01, 0x07, &payload);
        let mut params: HashMap<String, Value> = HashMap::new();
        let mut parser = Nmea::default();
        let result = queue_and_parse(&mut params, &mut parser, &frame).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["type"], "ubx");
        assert_eq!(result[0]["ubx_type"], "NAV-PVT");
        assert_eq!(result[0]["fix_type"], "3D");
        assert_eq!(result[0]["lat"], 13.75);
        assert_eq!(result[0]["lon"], 101.5);
    }
}
