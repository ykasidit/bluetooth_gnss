pub mod api;
mod frb_generated;
mod qstarz_parser;
mod gnss_parser;
mod nmea_parser;

extern crate jni;

use std::collections::{HashMap, VecDeque};
use lazy_static::lazy_static;
use serde_json::{json, Value};
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};
use nmea::Nmea;
use crate::qstarz_parser::parse_qstarz_pkt;
use crate::gnss_parser::queue_and_parse;
use jni::JNIEnv;
use jni::objects::{JClass};
use jni::sys::{jbyteArray, jstring};

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
    let mut param_state = OUTPUT_STATE_PARAMS_MAP.lock().unwrap();
    let mut nmea_parser_state_vec = NMEA_PARSER.lock().unwrap();
    let nmea_parser_state = nmea_parser_state_vec.first_mut().unwrap();
    let parsed_result = queue_and_parse(&mut param_state, nmea_parser_state, byte_vec.as_slice());
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




const TALKER_ID_ANY:&str = "ANY";
const SUFFIX_COUNT:&str = "count";
const SUFFIX_TIMESTAMP:&str = "ts";
const TALKER_NONE:&str = "";

pub fn get_current_time_millis() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_millis() as u64
}

pub fn put_param(params_state: &mut HashMap<String, Value>, talker_id: String, param_name: String, val: Value)
{
    let key = if talker_id.is_empty() {param_name.clone()} else {format!("{}_{}", talker_id, param_name)};
    let key_any = format!("{}_{}", TALKER_ID_ANY, param_name);
    let key_ts = format!("{}_{}", key, SUFFIX_TIMESTAMP);
    let key_counter = format!("{}_{}", key, SUFFIX_COUNT);
    let pm = params_state;
    pm.insert(key, val.clone());
    pm.insert(key_any, val);
    pm.insert(key_ts, Value::from(get_current_time_millis()));
    let new_count = pm.get(&key_counter).unwrap_or(&Value::from(0u64)).as_u64().unwrap() + 1;
    pm.insert(key_counter, Value::from(new_count));
}

pub fn inc_param(talker_id: String, param_name: String)
{
    let key = format!("{}_{}", talker_id, param_name);
}
