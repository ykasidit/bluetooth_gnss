use std::io::Write;

use serde_json::Value;

use crate::gnss_parser::queue_and_parse;
use crate::protocol::ProtocolHint;
use crate::qstarz_parser::parse_qstarz_pkt;
use crate::State;

/// Unified entry point: accepts raw bytes + protocol hint, returns JSON array string.
pub fn feed_and_parse(ctx: &mut State, data: &[u8], hint: ProtocolHint) -> String {
    match hint {
        ProtocolHint::AutoDetectStream => feed_nmea_ubx_stream(ctx, data),
        ProtocolHint::QstarzBleChunk => feed_qstarz_ble_chunk(ctx, data),
    }
}

/// Feed NMEA/UBX bytes into the existing queue_and_parse pipeline.
fn feed_nmea_ubx_stream(ctx: &mut State, data: &[u8]) -> String {
    let parsed_result = queue_and_parse(
        &mut ctx.buffer,
        &mut ctx.params,
        &mut ctx.nmea,
        data,
    );
    match parsed_result {
        Ok(parsed_objects) => serde_json::to_string(&parsed_objects).unwrap(),
        Err(e) => {
            serde_json::to_string(&serde_json::json!({"error": e.to_string()})).unwrap()
        }
    }
}

/// Accumulate Qstarz BLE chunks (3-4 per packet), assemble, and parse.
/// Mirrors the Java pattern-matching logic from rfcomm_conn_mgr.onCharacteristicChanged.
fn feed_qstarz_ble_chunk(ctx: &mut State, data: &[u8]) -> String {
    let buf = &mut ctx.qstarz_buf;
    buf.push(data.to_vec());

    // Keep at most 4 chunks
    while buf.len() > 4 {
        buf.remove(0);
    }

    if buf.len() == 4 {
        let first_pkt = &buf[0];
        let third_pkt = &buf[2];
        let fourth_pkt = &buf[3];

        // Check pattern: first chunk starts with fix_status 1/2/3, third chunk has zeros at [16],[17]
        if first_pkt.len() == 20
            && (first_pkt[0] == 1 || first_pkt[0] == 2 || first_pkt[0] == 3)
            && third_pkt.len() >= 18
            && third_pkt[16] == 0
            && third_pkt[17] == 0
        {
            // Assemble the full packet
            let mut pkt = Vec::new();
            pkt.extend_from_slice(&buf[0]);
            pkt.extend_from_slice(&buf[1]);
            pkt.extend_from_slice(&buf[2]);

            // 4-chunk packet: third chunk is 20 bytes with zeros at [18],[19]
            if third_pkt.len() == 20 && third_pkt[18] == 0 && third_pkt[19] == 0 {
                pkt.extend_from_slice(&buf[3]);
                buf.clear();
            } else {
                // 3-chunk packet: remove first 3, keep fourth for next round
                buf.remove(0);
                buf.remove(0);
                buf.remove(0);
            }

            let result_json = parse_qstarz_pkt(pkt);
            if result_json.is_empty() {
                return "[]".to_string();
            }
            // Wrap single Qstarz result in JSON array
            return format!("[{}]", result_json);
        }
    }

    // Not enough chunks yet or pattern didn't match
    "[]".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::protocol::ProtocolHint;

    fn hex_to_bytes(hex: &str) -> Vec<u8> {
        let hex_clean: String = hex.chars().filter(|c| c.is_ascii_hexdigit()).collect();
        (0..hex_clean.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&hex_clean[i..i + 2], 16).unwrap())
            .collect()
    }

    #[test]
    fn test_feed_nmea_stream() {
        let mut ctx = State::new();
        // Simple NMEA sentence through unified parser
        let nmea = b"$GNGGA,045115.00,0000.000,N,00000.000,E,1,12,0.60,3.0,M,-13.0,M,,*6F\n";
        let result = feed_and_parse(&mut ctx, nmea, ProtocolHint::AutoDetectStream);
        assert!(!result.is_empty());
        assert!(result.starts_with('['));
    }

    // ---- Qstarz BLE 4-chunk assembly (mirrors old Java onCharacteristicChanged logic) ----

    #[test]
    fn test_feed_qstarz_4_chunk_gps_not_fixed() {
        let mut ctx = State::new();

        // GPS not fixed: 4 chunks, chunk3 has zeros at [18],[19] => 4-chunk packet
        let chunk1 = hex_to_bytes("01547801 00000000 00000080 00000000 00000080");
        let chunk2 = hex_to_bytes("85f2de60 61a6fd3f 00000000 14aeca42 6800a9ff");
        let chunk3 = hex_to_bytes("46001400 00000000 00000000 0d00003c 00000000");
        let chunk4 = hex_to_bytes("05460300 3b000041 0c001300 00551100 b00000");

        // First 3 chunks should return empty array
        assert_eq!(feed_and_parse(&mut ctx, &chunk1, ProtocolHint::QstarzBleChunk), "[]");
        assert_eq!(feed_and_parse(&mut ctx, &chunk2, ProtocolHint::QstarzBleChunk), "[]");
        assert_eq!(feed_and_parse(&mut ctx, &chunk3, ProtocolHint::QstarzBleChunk), "[]");

        // Fourth chunk triggers parse
        let r4 = feed_and_parse(&mut ctx, &chunk4, ProtocolHint::QstarzBleChunk);
        assert!(r4.starts_with('['));
        let arr: Vec<serde_json::Value> = serde_json::from_str(&r4).unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["fix_status"], 1);
        assert_eq!(arr[0]["fix_status_matched"], "Fix not available");
        assert_eq!(arr[0]["millisecond"], 376);
        assert_eq!(arr[0]["battery_percent"], 60);
        // Verify GSV fields are present (4-chunk packet includes tail)
        assert!(arr[0]["gsv_fields"].is_array());
        assert_eq!(arr[0]["gsv_fields"].as_array().unwrap().len(), 3);
    }

    #[test]
    fn test_feed_qstarz_3_chunk_gps_fixed_wo_gsv() {
        let mut ctx = State::new();

        // GPS fixed without GSV: 3 chunks, chunk3 is shorter (no zeros at [18],[19])
        let chunk1 = hex_to_bytes("0354c800 cd94d6df 8a91a340 821e6adb 2eadc740");
        let chunk2 = hex_to_bytes("86f2de60 3a924340 10c89943 ec51c842 610077ff");
        let chunk3 = hex_to_bytes("72001300 b81ee53f ec51783f 0d05013c 0000");

        assert_eq!(feed_and_parse(&mut ctx, &chunk1, ProtocolHint::QstarzBleChunk), "[]");
        assert_eq!(feed_and_parse(&mut ctx, &chunk2, ProtocolHint::QstarzBleChunk), "[]");
        assert_eq!(feed_and_parse(&mut ctx, &chunk3, ProtocolHint::QstarzBleChunk), "[]");

        // Need a 4th chunk to trigger the check. Send next packet's first chunk.
        // The pattern matcher sees chunk1=0x03 (valid fix_status), chunk3 has [16]=0,[17]=0,
        // but chunk3 is only 18 bytes so no [18],[19] => 3-chunk packet assembled from first 3.
        // Actually we need to re-read the logic: the buffer keeps 4 and checks pattern.
        // Let's send a dummy 4th chunk that will cause the 3-chunk assembly path.
        let dummy_chunk = hex_to_bytes("0354c800 cd94d6df 8a91a340 821e6adb 2eadc740");
        let r4 = feed_and_parse(&mut ctx, &dummy_chunk, ProtocolHint::QstarzBleChunk);
        let arr: Vec<serde_json::Value> = serde_json::from_str(&r4).unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["fix_status"], 3);
        assert_eq!(arr[0]["fix_status_matched"], "3D");
        assert_eq!(arr[0]["fix_quality"], 1);
        assert_eq!(arr[0]["fix_quality_matched"], "GPS fix (SPS)");
        assert_eq!(arr[0]["satellite_count_used"], 5);
        // 3-chunk packet has no series_number/gsv_fields
        assert!(arr[0].get("series_number").is_none());
    }

    #[test]
    fn test_feed_qstarz_4_chunk_gps_fixed_w_gsv() {
        let mut ctx = State::new();

        // GPS fixed with GSV: 4 chunks
        let chunk1 = hex_to_bytes("03549001 faf202ec 8b91a340 69519fe4 2eadc740");
        let chunk2 = hex_to_bytes("86f2de60 40de4b40 aec79943 5c8fd442 480082ff");
        let chunk3 = hex_to_bytes("52001100 b81ee53f ec51783f 0d05013c 00000000");
        let chunk4 = hex_to_bytes("05460300 3b000041 0c001300 00551100 b00000");

        assert_eq!(feed_and_parse(&mut ctx, &chunk1, ProtocolHint::QstarzBleChunk), "[]");
        assert_eq!(feed_and_parse(&mut ctx, &chunk2, ProtocolHint::QstarzBleChunk), "[]");
        assert_eq!(feed_and_parse(&mut ctx, &chunk3, ProtocolHint::QstarzBleChunk), "[]");

        let r4 = feed_and_parse(&mut ctx, &chunk4, ProtocolHint::QstarzBleChunk);
        let arr: Vec<serde_json::Value> = serde_json::from_str(&r4).unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["fix_status"], 3);
        assert_eq!(arr[0]["latitude"], 25.079554750000003);
        assert_eq!(arr[0]["longitude"], 121.37277253333332);
        assert!(arr[0]["gsv_fields"].is_array());
        assert_eq!(arr[0]["gsv_fields"].as_array().unwrap().len(), 3);
        assert_eq!(arr[0]["series_number"], 0);
    }

    #[test]
    fn test_feed_qstarz_consecutive_packets() {
        let mut ctx = State::new();

        // Send two consecutive 4-chunk packets, verify both are parsed correctly
        // Packet 1: GPS not fixed
        let p1_chunks = [
            hex_to_bytes("01547801 00000000 00000080 00000000 00000080"),
            hex_to_bytes("85f2de60 61a6fd3f 00000000 14aeca42 6800a9ff"),
            hex_to_bytes("46001400 00000000 00000000 0d00003c 00000000"),
            hex_to_bytes("05460300 3b000041 0c001300 00551100 b00000"),
        ];

        for i in 0..3 {
            assert_eq!(feed_and_parse(&mut ctx, &p1_chunks[i], ProtocolHint::QstarzBleChunk), "[]");
        }
        let r1 = feed_and_parse(&mut ctx, &p1_chunks[3], ProtocolHint::QstarzBleChunk);
        let arr1: Vec<serde_json::Value> = serde_json::from_str(&r1).unwrap();
        assert_eq!(arr1[0]["fix_status"], 1);

        // Packet 2: GPS fixed with GSV
        let p2_chunks = [
            hex_to_bytes("03549001 faf202ec 8b91a340 69519fe4 2eadc740"),
            hex_to_bytes("86f2de60 40de4b40 aec79943 5c8fd442 480082ff"),
            hex_to_bytes("52001100 b81ee53f ec51783f 0d05013c 00000000"),
            hex_to_bytes("05460300 3b000041 0c001300 00551100 b00000"),
        ];

        for i in 0..3 {
            assert_eq!(feed_and_parse(&mut ctx, &p2_chunks[i], ProtocolHint::QstarzBleChunk), "[]");
        }
        let r2 = feed_and_parse(&mut ctx, &p2_chunks[3], ProtocolHint::QstarzBleChunk);
        let arr2: Vec<serde_json::Value> = serde_json::from_str(&r2).unwrap();
        assert_eq!(arr2[0]["fix_status"], 3);
        assert_eq!(arr2[0]["latitude"], 25.079554750000003);
    }

    #[test]
    fn test_feed_qstarz_invalid_first_byte_ignored() {
        let mut ctx = State::new();

        // Send 4 chunks where first chunk has invalid fix_status (0x00)
        // Should NOT trigger assembly
        let bad_chunk1 = hex_to_bytes("00547801 00000000 00000080 00000000 00000080");
        let chunk2 = hex_to_bytes("85f2de60 61a6fd3f 00000000 14aeca42 6800a9ff");
        let chunk3 = hex_to_bytes("46001400 00000000 00000000 0d00003c 00000000");
        let chunk4 = hex_to_bytes("05460300 3b000041 0c001300 00551100 b00000");

        assert_eq!(feed_and_parse(&mut ctx, &bad_chunk1, ProtocolHint::QstarzBleChunk), "[]");
        assert_eq!(feed_and_parse(&mut ctx, &chunk2, ProtocolHint::QstarzBleChunk), "[]");
        assert_eq!(feed_and_parse(&mut ctx, &chunk3, ProtocolHint::QstarzBleChunk), "[]");
        // Should still be [] because first chunk has invalid fix_status
        assert_eq!(feed_and_parse(&mut ctx, &chunk4, ProtocolHint::QstarzBleChunk), "[]");
    }

    // ---- NMEA stream segmentation through feed_bytes ----

    #[test]
    fn test_feed_nmea_partial_then_complete() {
        let mut ctx = State::new();

        // Feed partial NMEA sentence, then the rest
        // This tests the input_buffer accumulation in queue_and_parse
        let part1 = b"$GNGGA,045115.00,0000.000,N,0";
        let part2 = b"0000.000,E,1,12,0.60,3.0,M,-13.0,M,,*6F\n";

        let r1 = feed_and_parse(&mut ctx, part1, ProtocolHint::AutoDetectStream);
        let arr1: Vec<serde_json::Value> = serde_json::from_str(&r1).unwrap();
        assert_eq!(arr1.len(), 0); // not enough data yet

        let r2 = feed_and_parse(&mut ctx, part2, ProtocolHint::AutoDetectStream);
        let arr2: Vec<serde_json::Value> = serde_json::from_str(&r2).unwrap();
        assert_eq!(arr2.len(), 1);
        assert_eq!(arr2[0]["name"], "GGA");
        assert_eq!(arr2[0]["type"], "nmea");
    }

    #[test]
    fn test_feed_nmea_multiple_sentences_in_one_call() {
        let mut ctx = State::new();

        // Feed multiple NMEA sentences at once
        let multi = b"$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\n$GNVTG,,T,,M,0.206,N,0.382,K,A*30\n";
        let result = feed_and_parse(&mut ctx, multi, ProtocolHint::AutoDetectStream);
        let arr: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(arr.len(), 2);
        assert_eq!(arr[0]["name"], "GSV");
        assert_eq!(arr[1]["name"], "VTG");
    }

    #[test]
    fn test_feed_nmea_with_garbage_prefix() {
        let mut ctx = State::new();

        // Binary garbage before a valid NMEA sentence (common with RFCOMM initial bytes)
        let mut data = vec![0xFF, 0xFE, 0x00, 0x01, 0xB5, 0x99]; // garbage
        data.extend_from_slice(b"$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\n");
        let result = feed_and_parse(&mut ctx, &data, ProtocolHint::AutoDetectStream);
        let arr: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["name"], "GSV");
    }

    #[test]
    fn test_feed_nmea_crlf_and_lf() {
        let mut ctx = State::new();

        // NMEA with \r\n termination
        let crlf = b"$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\r\n";
        let result = feed_and_parse(&mut ctx, crlf, ProtocolHint::AutoDetectStream);
        let arr: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["name"], "GSV");
    }
}
