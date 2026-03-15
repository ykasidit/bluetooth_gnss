use anyhow::{anyhow, Result};
use binrw::BinRead;
use serde_json::{Map, Value};
use std::io::Cursor;

/// UBX NAV-PVT message (class 0x01, id 0x07) — the primary position/velocity/time solution.
#[derive(Debug, BinRead)]
#[br(little)]
pub struct UbxNavPvt {
    pub i_tow: u32,        // GPS time of week (ms)
    pub year: u16,
    pub month: u8,
    pub day: u8,
    pub hour: u8,
    pub min: u8,
    pub sec: u8,
    pub valid: u8,          // validity flags
    pub t_acc: u32,         // time accuracy estimate (ns)
    pub nano: i32,          // fraction of second (ns)
    pub fix_type: u8,       // 0=no fix, 1=dead reckoning, 2=2D, 3=3D, 4=GNSS+DR, 5=time only
    pub flags: u8,
    pub flags2: u8,
    pub num_sv: u8,         // number of SVs used
    pub lon: i32,           // longitude (1e-7 deg)
    pub lat: i32,           // latitude (1e-7 deg)
    pub height: i32,        // height above ellipsoid (mm)
    pub h_msl: i32,         // height above MSL (mm)
    pub h_acc: u32,         // horizontal accuracy (mm)
    pub v_acc: u32,         // vertical accuracy (mm)
    pub vel_n: i32,         // NED north velocity (mm/s)
    pub vel_e: i32,         // NED east velocity (mm/s)
    pub vel_d: i32,         // NED down velocity (mm/s)
    pub g_speed: i32,       // ground speed (mm/s)
    pub head_mot: i32,      // heading of motion (1e-5 deg)
    pub s_acc: u32,         // speed accuracy (mm/s)
    pub head_acc: u32,      // heading accuracy (1e-5 deg)
    pub p_dop: u16,         // position DOP (0.01)
    pub flags3: u16,
    pub reserved0: u32,
    pub head_veh: i32,      // heading of vehicle (1e-5 deg)
    pub mag_dec: i16,       // magnetic declination (1e-2 deg)
    pub mag_acc: u16,       // magnetic declination accuracy (1e-2 deg)
}

fn fix_type_str(ft: u8) -> &'static str {
    match ft {
        0 => "no fix",
        1 => "dead reckoning",
        2 => "2D",
        3 => "3D",
        4 => "GNSS+dead reckoning",
        5 => "time only",
        _ => "unknown",
    }
}

impl UbxNavPvt {
    pub fn to_json(&self) -> Map<String, Value> {
        let mut m = Map::new();
        m.insert("type".to_string(), Value::from("ubx"));
        m.insert("ubx_type".to_string(), Value::from("NAV-PVT"));
        m.insert("fix_type".to_string(), Value::from(fix_type_str(self.fix_type)));
        m.insert("num_sv".to_string(), Value::from(self.num_sv));
        m.insert("lat".to_string(), Value::from(self.lat as f64 / 1e7));
        m.insert("lon".to_string(), Value::from(self.lon as f64 / 1e7));
        m.insert("height_mm".to_string(), Value::from(self.height));
        m.insert("h_msl_mm".to_string(), Value::from(self.h_msl));
        m.insert("h_acc_mm".to_string(), Value::from(self.h_acc));
        m.insert("v_acc_mm".to_string(), Value::from(self.v_acc));
        m.insert("g_speed_mm_s".to_string(), Value::from(self.g_speed));
        m.insert("head_mot_deg".to_string(), Value::from(self.head_mot as f64 / 1e5));
        m.insert("p_dop".to_string(), Value::from(self.p_dop as f64 / 100.0));
        m.insert("year".to_string(), Value::from(self.year));
        m.insert("month".to_string(), Value::from(self.month));
        m.insert("day".to_string(), Value::from(self.day));
        m.insert("hour".to_string(), Value::from(self.hour));
        m.insert("min".to_string(), Value::from(self.min));
        m.insert("sec".to_string(), Value::from(self.sec));
        m
    }
}

/// Parse a complete UBX packet (including B5 62 header, class, id, length, payload, checksum).
/// Returns a JSON map on success, or an error.
pub fn parse_ubx_pkt(pkt: &[u8]) -> Result<Map<String, Value>> {
    if pkt.len() < 8 {
        return Err(anyhow!("UBX packet too short: {} bytes", pkt.len()));
    }
    // pkt[0..2] = B5 62 (sync), pkt[2] = class, pkt[3] = id
    let class = pkt[2];
    let id = pkt[3];
    let payload_len = (pkt[4] as usize) | ((pkt[5] as usize) << 8);
    let payload = &pkt[6..6 + payload_len];

    match (class, id) {
        (0x01, 0x07) => {
            // NAV-PVT
            let mut cursor = Cursor::new(payload);
            let nav_pvt = UbxNavPvt::read(&mut cursor)
                .map_err(|e| anyhow!("NAV-PVT parse error: {e}"))?;
            Ok(nav_pvt.to_json())
        }
        _ => {
            let mut ret = Map::new();
            ret.insert("type".to_string(), Value::from("ubx"));
            ret.insert("ubx_type".to_string(), Value::from(format!("0x{:02X}-0x{:02X}", class, id)));
            Ok(ret)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hex_to_bytes(hex: &str) -> Vec<u8> {
        let hex_clean: String = hex.chars().filter(|c| c.is_ascii_hexdigit()).collect();
        (0..hex_clean.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&hex_clean[i..i + 2], 16).unwrap())
            .collect()
    }

    /// Build a valid UBX frame with correct checksum around a NAV-PVT payload.
    fn make_ubx_frame(class: u8, id: u8, payload: &[u8]) -> Vec<u8> {
        let len = payload.len() as u16;
        let mut frame = vec![0xB5, 0x62, class, id, (len & 0xFF) as u8, (len >> 8) as u8];
        frame.extend_from_slice(payload);
        // Calculate checksum over class, id, length, and payload
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
    fn test_ubx_nav_pvt_parse() {
        // Construct a minimal NAV-PVT payload (92 bytes)
        let mut payload = vec![0u8; 92];
        // iTOW at offset 0 (u32 LE) = 123456000
        payload[0..4].copy_from_slice(&123456000u32.to_le_bytes());
        // year at offset 4
        payload[4..6].copy_from_slice(&2025u16.to_le_bytes());
        // month at offset 6
        payload[6] = 3;
        // day at offset 7
        payload[7] = 15;
        // hour
        payload[8] = 12;
        // min
        payload[9] = 30;
        // sec
        payload[10] = 45;
        // valid
        payload[11] = 0x07;
        // tAcc at offset 12
        payload[12..16].copy_from_slice(&50u32.to_le_bytes());
        // nano at offset 16
        payload[16..20].copy_from_slice(&0i32.to_le_bytes());
        // fixType at offset 20
        payload[20] = 3; // 3D fix
        // flags
        payload[21] = 0x01;
        // flags2
        payload[22] = 0;
        // numSV
        payload[23] = 12;
        // lon at offset 24 (1e-7 deg) = 101.5 deg = 1015000000
        payload[24..28].copy_from_slice(&1015000000i32.to_le_bytes());
        // lat at offset 28 = 13.75 deg = 137500000
        payload[28..32].copy_from_slice(&137500000i32.to_le_bytes());
        // height at offset 32 (mm) = 50000 = 50m
        payload[32..36].copy_from_slice(&50000i32.to_le_bytes());
        // hMSL at offset 36
        payload[36..40].copy_from_slice(&49000i32.to_le_bytes());
        // hAcc at offset 40
        payload[40..44].copy_from_slice(&1500u32.to_le_bytes());
        // vAcc at offset 44
        payload[44..48].copy_from_slice(&2000u32.to_le_bytes());
        // gSpeed at offset 60
        payload[60..64].copy_from_slice(&1500i32.to_le_bytes());
        // headMot at offset 64 (1e-5 deg) = 180.0 deg = 18000000
        payload[64..68].copy_from_slice(&18000000i32.to_le_bytes());
        // pDOP at offset 76 (0.01) = 1.5 = 150
        payload[76..78].copy_from_slice(&150u16.to_le_bytes());

        let frame = make_ubx_frame(0x01, 0x07, &payload);
        let result = parse_ubx_pkt(&frame).unwrap();

        assert_eq!(result["type"], "ubx");
        assert_eq!(result["ubx_type"], "NAV-PVT");
        assert_eq!(result["fix_type"], "3D");
        assert_eq!(result["num_sv"], 12);
        assert_eq!(result["lat"], 13.75);
        assert_eq!(result["lon"], 101.5);
        assert_eq!(result["height_mm"], 50000);
        assert_eq!(result["p_dop"], 1.5);
    }

    #[test]
    fn test_ubx_unknown_message() {
        // Unknown class/id should return generic result
        let payload = vec![0u8; 10];
        let frame = make_ubx_frame(0x05, 0x01, &payload);
        let result = parse_ubx_pkt(&frame).unwrap();
        assert_eq!(result["type"], "ubx");
        assert_eq!(result["ubx_type"], "0x05-0x01");
    }
}
