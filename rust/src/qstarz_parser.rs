use binrw::BinRead;
use serde_json::{json, Value};
use std::io::Cursor;

/// Qstarz BLE packet parsed using binrw (little-endian).
/// Replaces the previous kampu-based implementation with identical JSON output.
#[derive(Debug, BinRead)]
#[br(little)]
pub struct QstarzBlePacket {
    pub fix_status: u8,
    pub rcr: u8,
    pub millisecond: u16,
    pub latitude: f64,
    pub longitude: f64,
    pub timestamp_s: u32,
    pub float_speed_kmh: f32,
    pub float_height_m: f32,
    pub heading_degrees: f32,
    pub g_sensor_x: i16,
    pub g_sensor_y: i16,
    pub g_sensor_z: i16,
    pub max_snr: u16,
    pub hdop: f32,
    pub vdop: f32,
    pub satellite_count_view: u8,
    pub satellite_count_used: u8,
    pub fix_quality: u8,
    pub battery_percent: u8,
    pub dummy: u16,
    #[br(try)]
    pub tail: Option<QstarzBlePacketTail>,
}

#[derive(Debug, BinRead)]
#[br(little)]
pub struct QstarzBlePacketTail {
    pub series_number: u8,
    #[br(count = 3)]
    pub gsv_fields: Vec<QstarzGsvField>,
}

#[derive(Debug, BinRead)]
#[br(little)]
pub struct QstarzGsvField {
    pub prn: u8,
    pub elevation: u16,
    pub azimuth: u16,
    pub snr: u8,
}

/// Convert DDDMM.MMMM format to decimal degrees.
/// Formula: floor(value/100) + (value - floor(value/100)*100) / 60.0
fn dddmm_to_decimal(value: f64) -> f64 {
    let tmp = (value / 100.0).floor();
    tmp + (value - tmp * 100.0) / 60.0
}

fn fix_status_match(val: u8) -> Option<&'static str> {
    match val {
        1 => Some("Fix not available"),
        2 => Some("2D"),
        3 => Some("3D"),
        _ => None,
    }
}

fn fix_quality_match(val: u8) -> Option<&'static str> {
    match val {
        0 => Some("invalid"),
        1 => Some("GPS fix (SPS)"),
        2 => Some("DGPS fix"),
        3 => Some("PPS fix"),
        4 => Some("Real Time Kinematic"),
        5 => Some("Float RTK"),
        6 => Some("estimated (dead reckoning) (2.3 feature)"),
        7 => Some("Manual input mode"),
        8 => Some("Simulation mode"),
        _ => None,
    }
}

impl QstarzBlePacket {
    pub fn to_json(&self) -> Value {
        let lat = dddmm_to_decimal(self.latitude);
        let lon = dddmm_to_decimal(self.longitude);

        let mut obj = json!({
            "fix_status": self.fix_status,
            "rcr": self.rcr,
            "millisecond": self.millisecond,
            "latitude": lat,
            "longitude": lon,
            "timestamp_s": self.timestamp_s,
            "float_speed_kmh": self.float_speed_kmh,
            "float_height_m": self.float_height_m,
            "heading_degrees": self.heading_degrees,
            "g_sensor_x": self.g_sensor_x as f64 / 256.0,
            "g_sensor_y": self.g_sensor_y as f64 / 256.0,
            "g_sensor_z": self.g_sensor_z as f64 / 256.0,
            "max_snr": self.max_snr,
            "hdop": self.hdop,
            "vdop": self.vdop,
            "satellite_count_view": self.satellite_count_view,
            "satellite_count_used": self.satellite_count_used,
            "fix_quality": self.fix_quality,
            "battery_percent": self.battery_percent,
            "dummy": self.dummy,
        });

        if let Some(fs_matched) = fix_status_match(self.fix_status) {
            obj["fix_status_matched"] = Value::from(fs_matched);
        }
        if let Some(fq_matched) = fix_quality_match(self.fix_quality) {
            obj["fix_quality_matched"] = Value::from(fq_matched);
        }

        if let Some(tail) = &self.tail {
            obj["series_number"] = Value::from(tail.series_number);
            let gsv: Vec<Value> = tail.gsv_fields.iter().map(|g| {
                json!({
                    "prn": g.prn,
                    "elevation": g.elevation,
                    "azimuth": g.azimuth,
                    "snr": g.snr,
                })
            }).collect();
            obj["gsv_fields"] = Value::from(gsv);
        }

        obj
    }
}

pub fn parse_qstarz_pkt(payload: Vec<u8>) -> String {
    let mut cursor = Cursor::new(&payload);
    match QstarzBlePacket::read(&mut cursor) {
        Ok(pkt) => serde_json::to_string(&pkt.to_json()).unwrap(),
        Err(e) => {
            println!("WARNING: binrw parse_qstarz_pkt error: {e}");
            "".to_string()
        }
    }
}


////////////////// qstarz_ble tests
/*
ref formula:
int tmp_lat = dLat / 100;
int tmp_lon = dLon / 100;
dLat = tmp_lat + (dLat - tmp_lat * 100) / 60.0;
dLon = tmp_lon + (dLon - tmp_lon * 100) / 60.0;
*/

#[cfg(test)]
mod tests {
    use super::*;

    fn hex_to_bin(hex: &str) -> Vec<u8> {
        let hex_clean: String = hex.chars().filter(|c| c.is_ascii_hexdigit()).collect();
        (0..hex_clean.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&hex_clean[i..i + 2], 16).unwrap())
            .collect()
    }

    #[test]
    fn test_qstarz_ble_packet_gps_not_fixed()
    {
	/*
	19:03:33.506 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <01547801 00000000 00000080 00000000 00000080> 	01=GPS is not fixed
	19:03:33.506 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <85f2de60 61a6fd3f 00000000 14aeca42 6800a9ff>
	19:03:33.507 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <46001400 00000000 00000000 0d00003c 00000000>
	19:03:33.507 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <05460300 3b000041 0c001300 00551100 b00000> 	05=GSV #5
	 */
	let data = hex_to_bin(r#"
        01547801 00000000 00000080 00000000 00000080
        85f2de60 61a6fd3f 00000000 14aeca42 6800a9ff
        46001400 00000000 00000000 0d00003c 00000000
        05460300 3b000041 0c001300 00551100 b00000
        "#
	);
	let mut cursor = Cursor::new(&data);
	let pkt = QstarzBlePacket::read(&mut cursor).unwrap();
	let parsed_json = pkt.to_json();
	println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_json).unwrap());
	assert_eq!(
            parsed_json,
            json!( {
                "fix_status": 1,
                "fix_status_matched": "Fix not available",
                "rcr": 84,
                "millisecond": 376,
                "latitude": -0.0,
                "longitude": -0.0,
                "timestamp_s": 1625223813u64,
                "float_speed_kmh": 1.9816399812698364,
                "float_height_m": 0.0,
                "heading_degrees": 101.33999633789062,
                "g_sensor_x": 104.0/256.0,
                "g_sensor_y": -87.0/256.0,
                "g_sensor_z": 70.0/256.0,
                "max_snr": 20,
                "hdop": 0.0,
                "vdop": 0.0,
                "satellite_count_view": 13,
                "satellite_count_used": 0,
                "fix_quality": 0,
                "fix_quality_matched": "invalid",
                "battery_percent": 60,
                "dummy": 0,
                "series_number": 0,
                "gsv_fields": [
                    {
                        "prn": 0,
                        "elevation": 17925,
                        "azimuth": 3,
                        "snr": 59
                    },
                    {
                        "prn": 0,
                        "elevation": 16640,
                        "azimuth": 12,
                        "snr": 19
                    },
                    {
                        "prn": 0,
                        "elevation": 21760,
                        "azimuth": 17,
                        "snr": 176
                    }
                ]
            }
            )
	);
    }

    #[test]
    fn test_qstarz_ble_packet_gps_fixed_wo_gsv()
    {
	/*
	19:03:34.403 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <0354c800 cd94d6df 8a91a340 821e6adb 2eadc740>  	03=GPS is fixed
	19:03:34.403 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <86f2de60 3a924340 10c89943 ec51c842 610077ff>
	19:03:34.404 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <72001300 b81ee53f ec51783f 0d05013c 0000>
	 */
	let data = hex_to_bin(r#"
        0354c800 cd94d6df 8a91a340 821e6adb 2eadc740
        86f2de60 3a924340 10c89943 ec51c842 610077ff
        72001300 b81ee53f ec51783f 0d05013c 0000
        "#
	);
	let mut cursor = Cursor::new(&data);
	let pkt = QstarzBlePacket::read(&mut cursor).unwrap();
	let parsed_json = pkt.to_json();
	println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_json).unwrap());
	assert_eq!(
            parsed_json,
            json!({
                "battery_percent": 60,
                "dummy": 0,
                "fix_quality": 1,
                "fix_quality_matched": "GPS fix (SPS)",
                "fix_status": 3,
                "fix_status_matched": "3D",
                "float_height_m": 307.56298828125,
                "float_speed_kmh": 3.055799961090088,
                "g_sensor_x": 97.0/256.0,
                "g_sensor_y": -137.0/256.0,
                "g_sensor_z": 114.0/256.0,
                "hdop": 1.7899999618530273,
                "heading_degrees": 100.16000366210938,
                "latitude": 25.079520650000003,
                "longitude": 121.37276785,
                "max_snr": 19,
                "millisecond": 200,
                "rcr": 84,
                "satellite_count_used": 5,
                "satellite_count_view": 13,
                "timestamp_s": 1625223814u64,
                "vdop": 0.9700000286102295
            })
	);

	//////////////////////////

    }

    #[test]
    fn test_qstarz_ble_packet_gps_fixed_w_gsv()
    {
	/*
	19:03:34.555 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <03549001 faf202ec 8b91a340 69519fe4 2eadc740>  	03=GPS is fixed
	19:03:34.555 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <86f2de60 40de4b40 aec79943 5c8fd442 480082ff>
	19:03:34.555 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <52001100 b81ee53f ec51783f 0d05013c 00000000>
	19:03:34.555 - Characteristic (6E400004-B5A3-F393-E0A9-E50E24DCCA9E) notified: <05460300 3b000041 0c001300 00551100 b00000> 	05=GSV #5
	 */
	let data = hex_to_bin(r#"
        03549001 faf202ec 8b91a340 69519fe4 2eadc740
        86f2de60 40de4b40 aec79943 5c8fd442 480082ff
        52001100 b81ee53f ec51783f 0d05013c 00000000
        05460300 3b000041 0c001300 00551100 b00000
        "#
	);
	let mut cursor = Cursor::new(&data);
	let pkt = QstarzBlePacket::read(&mut cursor).unwrap();
	let parsed_json = pkt.to_json();
	println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_json).unwrap());
	assert_eq!(
            parsed_json,
            json!({
		"fix_status": 3,
                "fix_status_matched": "3D",
                "rcr": 84,
                "millisecond": 400,
                "latitude": 25.079554750000003,
                "longitude": 121.37277253333332,
                "timestamp_s": 1625223814u64,
                "float_speed_kmh": 3.1854400634765625,
                "float_height_m": 307.55999755859375,
                "heading_degrees": 106.27999877929688,
                "g_sensor_x":  0.28125,
                "g_sensor_y": -0.4921875,
                "g_sensor_z":  0.3203125,
                "max_snr": 17,
                "hdop": 1.7899999618530273,
                "vdop": 0.9700000286102295,
                "satellite_count_view": 13,
                "satellite_count_used": 5,
                "fix_quality": 1,
                "fix_quality_matched": "GPS fix (SPS)",
                "battery_percent": 60,
                "dummy": 0,
                "series_number": 0,
                "gsv_fields": [
                    {
                        "prn": 0,
                        "elevation": 17925,
                        "azimuth": 3,
                        "snr": 59
                    },
                    {
                        "prn": 0,
                        "elevation": 16640,
                        "azimuth": 12,
                        "snr": 19
                    },
                    {
                        "prn": 0,
                        "elevation": 21760,
                        "azimuth": 17,
                        "snr": 176
                    }
                ]
            }
            )
	);
	//////////////////////////

    }


    #[test]
    fn test_qstarz_ble_packet_250113_002143_csv()
    {
	/*
	INDEX	RCR	UTC DATE	UTC TIME	LOCAL DATE	LOCAL TIME	MS	VALID	LATITUDE	N/S	LONGITUDE	    E/W	HEIGHT (m)	SPEED (km/h)	HEADING	    G-sensor(X)	G-sensor(Y)	G-sensor(Z)	PDOP	HDOP	VDOP	NSAT	Max. SNR
	1	   T	2025/1/13	0:21:43	    2025/1/13	8:21:43	    900	3D-Fix	25.06878535	N	121.5914897333	E	69	        2.019	        79.222996	-0.0039	    0.0078	    0.9922	2.3	2.3	0.2	6	39
	 */
	let data = hex_to_bin(r#"
        03 54 84 03 45 F3 00 16 41 90 A3 40 98 89 22 A4 BE B3 C7 40 97 5C 84 67 0E 32 01 40 5E 7A 8B 42 8F 62 AB 43 FF FF 02 00 FE 00 27 00 8F C2 15 40 3D 0A 57 3E 0A 06 01 5A 00 00 00 00 00 00 00 00
        "#
	);
	let parsed_json_str = parse_qstarz_pkt(data.clone());
	let parsed_json: Value = serde_json::from_str(&parsed_json_str).unwrap();
	println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_json).unwrap());
	assert_eq!("25.06878535", format!("{:.8}",parsed_json["latitude"].as_f64().unwrap()));
	assert_eq!("121.5914897333", format!("{:.10}",parsed_json["longitude"].as_f64().unwrap()));
	//TODO: assert all other fields in csv

	/*
	INDEX	RCR	UTC DATE	UTC TIME	LOCAL DATE	LOCAL TIME	MS	VALID	LATITUDE	N/S	LONGITUDE	    E/W	HEIGHT (m)	SPEED (km/h)	HEADING	    G-sensor(X)	G-sensor(Y)	G-sensor(Z)	PDOP	HDOP	VDOP	NSAT	Max. SNR
	2	T	2025/1/13	0:21:44	2025/1/13	8:21:44	0	3D-Fix	25.0687856	N	121.5914911833	E	68	1.519	172.589507	-0.0039	0.0078	1.0039	2.5	2.3	1	6	39
	 */
	let data = hex_to_bin(r#"
        03 54 00 00 4A 44 F8 17 41 90 A3 40 AC 58 FC A6 BE B3 C7 40 98 5C 84 67 CC 62 C2 3F 62 50 88 42 33 D3 A8 43 FF FF 02 00 01 01 27 00 AE 47 11 40 00 00 80 3F 0A 06 01 5A 00 00 00 00 00 00 00 00
        "#
	);
	let parsed_json_str = parse_qstarz_pkt(data);
	let parsed_json: Value = serde_json::from_str(&parsed_json_str).unwrap();
	println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_json).unwrap());
	assert_eq!("25.0687856", format!("{:.7}",parsed_json["latitude"].as_f64().unwrap()));
	assert_eq!("121.5914911833", format!("{:.10}",parsed_json["longitude"].as_f64().unwrap()));

	//////////////////////////

    }
}
