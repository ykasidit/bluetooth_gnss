use once_cell::sync::Lazy;
use serde_json::{json, Value};

extern crate jni;  // Ensure you have the `jni` crate in your Cargo.toml

use jni::JNIEnv;
use jni::objects::{JClass};
use jni::sys::{jbyteArray, jstring};

use kampu::forest::{is_tree_planted, parse_tree, plant_tree};
use kampu::utils::hex_to_bin;

pub fn parse_qstarz_pkt(payload: Vec<u8>) -> String {
    setup_parse_trees();
    if let Ok(ret) = parse_tree(QSTARZ_BLE_SCHEMA_TREE_ID, &payload) {
        return serde_json::to_string(&ret).unwrap();
    }
    return "".to_string();
}

// This is the Rust function exposed to Java using JNI.
#[no_mangle]
pub extern "C" fn Java_com_clearevo_libbluetooth_1gnss_1service_NativeParser_parse_1qstarz_1pkt(
    env: JNIEnv,
    _class: JClass,
    byte_array: jbyteArray
) -> jstring {
    // Step 1: Convert the incoming Java byte array to Rust Vec<u8>
    let byte_vec: Vec<u8> = env.convert_byte_array(byte_array).unwrap();

    // Step 2: Perform your processing (for demonstration, we'll convert the byte array to a String)
    let processed_str = parse_qstarz_pkt(byte_vec);

    // Step 3: Return the processed string back to Java as a jstring
    let output = env.new_string(processed_str).unwrap();
    output.into_inner()
}

////////////////// qstarz_ble tests
/*
ref formula:
int tmp_lat = dLat / 100;
int tmp_lon = dLon / 100;
dLat = tmp_lat + (dLat - tmp_lat * 100) / 60.0;
dLon = tmp_lon + (dLon - tmp_lon * 100) / 60.0;
*/
const QSTARZ_LAT_LON_DDDMM_MMMM_FORMULA_EVAL_STR:&str = r#"
    tmp_lat = floor(value_float / 100.0);
    tmp_lat + (value_float - (tmp_lat*100)) / 60.0
    "#;
const QSTARZ_G_SENSOR_EVAL_STR:&str = "value_int / 256.0";
const QSTARZ_BLE_SCHEMA_TREE_ID:u64 = 1;
const QSTARZ_BLE_TREE_SCHEMA: Lazy<Value> = Lazy::new(|| {
    json!({
                "branches": [
                    { "name": "fix_status", "type": "u8",
                        "match": {
                        "1": "Fix not available",
                        "2": "2D",
                        "3": "3D",
                    }
                    },
                    { "name": "rcr", "type": "u8" },
                    { "name": "millisecond", "type": "u16" },
                    { "name": "latitude", "type": "f64", "eval": QSTARZ_LAT_LON_DDDMM_MMMM_FORMULA_EVAL_STR },
                    { "name": "longitude", "type": "f64", "eval": QSTARZ_LAT_LON_DDDMM_MMMM_FORMULA_EVAL_STR },
                    { "name": "timestamp_s", "type": "u32" },
                    { "name": "float_speed_kmh", "type": "f32" },
                    { "name": "float_height_m", "type": "f32" },
                    { "name": "heading_degrees", "type": "f32" },
                    { "name": "g_sensor_x", "type": "i16", "eval": QSTARZ_G_SENSOR_EVAL_STR },
                    { "name": "g_sensor_y", "type": "i16", "eval": QSTARZ_G_SENSOR_EVAL_STR },
                    { "name": "g_sensor_z", "type": "i16", "eval": QSTARZ_G_SENSOR_EVAL_STR },
                    { "name": "max_snr", "type": "u16" },
                    { "name": "hdop", "type": "f32" },
                    { "name": "vdop", "type": "f32" },
                    { "name": "satellite_count_view", "type": "u8" },
                    { "name": "satellite_count_used", "type": "u8" },
                    { "name": "fix_quality", "type": "u8",
                        "match": {
                        "0": "invalid",
                        "1":  "GPS fix (SPS)",
                        "2": "DGPS fix",
                        "3": "PPS fix",
                        "4": "Real Time Kinematic",
                        "5": "Float RTK",
                        "6": "estimated (dead reckoning) (2.3 feature)",
                        "7": "Manual input mode",
                        "8": "Simulation mode"
                    }
                    },
                    { "name": "battery_percent", "type": "u8" },
                    { "name": "dummy", "type": "u16" },
                    { "name": "series_number", "type": "u8" },
                    {
                        "name": "gsv_fields",
                        "loop_count": 3,
                        "branches": [
                        { "name": "prn", "type": "u8" },
                        { "name": "elevation", "type": "u16" },
                        { "name": "azimuth", "type": "u16" },
                        { "name": "snr", "type": "u8" }
                        ]
                    }
            ]
            })
});

fn setup_parse_trees() {
    if !is_tree_planted(QSTARZ_BLE_SCHEMA_TREE_ID) {
        plant_tree(QSTARZ_BLE_SCHEMA_TREE_ID, QSTARZ_BLE_TREE_SCHEMA.clone());
    }
}


#[test]
fn test_qstarz_ble_packet_gps_not_fixed()
{
    setup_parse_trees();
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
    let parsed_json = parse_tree(QSTARZ_BLE_SCHEMA_TREE_ID, &data).unwrap();
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
                "timestamp_s": 1625223813,
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
    setup_parse_trees();
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
    let parsed_json = parse_tree(QSTARZ_BLE_SCHEMA_TREE_ID, &data).unwrap();
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
                "timestamp_s": 1625223814,
                "vdop": 0.9700000286102295
            })
    );

    //////////////////////////

}

#[test]
fn test_qstarz_ble_packet_gps_fixed_w_gsv()
{
    setup_parse_trees();
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
    let parsed_json = parse_tree(QSTARZ_BLE_SCHEMA_TREE_ID, &data).unwrap();
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
                "timestamp_s": 1625223814,
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
    setup_parse_trees();

    /*
INDEX	RCR	UTC DATE	UTC TIME	LOCAL DATE	LOCAL TIME	MS	VALID	LATITUDE	N/S	LONGITUDE	    E/W	HEIGHT (m)	SPEED (km/h)	HEADING	    G-sensor(X)	G-sensor(Y)	G-sensor(Z)	PDOP	HDOP	VDOP	NSAT	Max. SNR
1	   T	2025/1/13	0:21:43	    2025/1/13	8:21:43	    900	3D-Fix	25.06878535	N	121.5914897333	E	69	        2.019	        79.222996	-0.0039	    0.0078	    0.9922	2.3	2.3	0.2	6	39
    */
    let data = hex_to_bin(r#"
        03 54 84 03 45 F3 00 16 41 90 A3 40 98 89 22 A4 BE B3 C7 40 97 5C 84 67 0E 32 01 40 5E 7A 8B 42 8F 62 AB 43 FF FF 02 00 FE 00 27 00 8F C2 15 40 3D 0A 57 3E 0A 06 01 5A 00 00 00 00 00 00 00 00
        "#
    );
    let parsed_json = parse_tree(QSTARZ_BLE_SCHEMA_TREE_ID, &data).unwrap();
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
    let parsed_json = parse_tree(QSTARZ_BLE_SCHEMA_TREE_ID, &data).unwrap();
    println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_json).unwrap());
    assert_eq!("25.0687856", format!("{:.7}",parsed_json["latitude"].as_f64().unwrap()));
    assert_eq!("121.5914911833", format!("{:.10}",parsed_json["longitude"].as_f64().unwrap()));

    //////////////////////////

}
