#![allow(warnings)]
pub mod api;
mod frb_generated;
mod qstarz_parser;
mod gnss_parser;
mod nmea_parser;
mod utils;
mod protocol;
mod ubx_parser;
mod unified_parser;

extern crate jni;

use std::collections::{HashMap, VecDeque};
use lazy_static::lazy_static;
use serde_json::{json, Value};
use std::sync::Mutex;
use nmea::Nmea;
use crate::protocol::ProtocolHint;
use crate::unified_parser::{unified_feed_and_parse, clear_qstarz_ble_buffer};
use jni::JNIEnv;
use jni::objects::{JClass};
use jni::sys::{jbyteArray, jint, jstring};

lazy_static! {
    static ref INPUT_BUFFER: Mutex<VecDeque<u8>> = Mutex::new(VecDeque::with_capacity(1024));
    static ref OUTPUT_STATE_PARAMS_MAP: Mutex<HashMap<String, Value>> = Mutex::new(HashMap::new());
    static ref NMEA_PARSER: Mutex<Vec<Nmea>> = Mutex::new(vec![Nmea::default()]);
}

#[no_mangle]
pub extern "C" fn Java_com_clearevo_libbluetooth_1gnss_1service_NativeParser_feed_1bytes(
    env: JNIEnv,
    _class: JClass,
    byte_array: jbyteArray,
    nread: jint,
    protocol_hint: jint,
) -> jstring {
    let byte_vec: Vec<u8> = env.convert_byte_array(byte_array).unwrap();
    let data = &byte_vec[0..nread as usize];
    let hint = ProtocolHint::from_i32(protocol_hint).unwrap_or(ProtocolHint::AutoDetectStream);
    let json_str = unified_feed_and_parse(data, hint);
    let output = env.new_string(json_str).unwrap();
    output.into_inner()
}

#[no_mangle]
pub extern "C" fn Java_com_clearevo_libbluetooth_1gnss_1service_NativeParser_reset(
    _env: JNIEnv,
    _class: JClass,
) {
    let mut p = NMEA_PARSER.lock().unwrap();
    p.clear();
    p.push(Nmea::default());
    OUTPUT_STATE_PARAMS_MAP.lock().unwrap().clear();
    clear_qstarz_ble_buffer();
}
