#![allow(warnings)]
pub mod api;
mod frb_generated;
mod qstarz_parser;
mod gnss_parser;
mod nmea_parser;
mod utils;
mod protocol;
mod ubx_parser;
mod parser;

#[cfg(target_os = "android")]
extern crate jni;

use std::collections::{HashMap, VecDeque};
use serde_json::{json, Value};
use std::sync::{LazyLock, Mutex};
use nmea::Nmea;
use crate::protocol::ProtocolHint;
use crate::parser::feed_and_parse;

pub struct State {
    pub buffer: VecDeque<u8>,
    pub params: HashMap<String, Value>,
    pub nmea: Nmea,
    pub qstarz_buf: Vec<Vec<u8>>,
}

impl State {
    pub fn new() -> Self {
        Self {
            buffer: VecDeque::with_capacity(1024),
            params: HashMap::new(),
            nmea: Nmea::default(),
            qstarz_buf: Vec::new(),
        }
    }

    pub fn reset(&mut self) {
        self.buffer.clear();
        self.nmea = Nmea::default();
        self.params.clear();
        self.qstarz_buf.clear();
    }
}

pub static CONTEXT: LazyLock<Mutex<State>> = LazyLock::new(|| Mutex::new(State::new()));

// --- JNI entry points (Android only) ---

#[cfg(target_os = "android")]
mod jni_api {
    use jni::JNIEnv;
    use jni::objects::JClass;
    use jni::sys::{jbyteArray, jint, jstring};
    use crate::{CONTEXT, ProtocolHint, feed_and_parse};

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
        let mut ctx = CONTEXT.lock().unwrap();
        let json_str = feed_and_parse(&mut ctx, data, hint);
        let output = env.new_string(json_str).unwrap();
        output.into_inner()
    }

    #[no_mangle]
    pub extern "C" fn Java_com_clearevo_libbluetooth_1gnss_1service_NativeParser_reset(
        _env: JNIEnv,
        _class: JClass,
    ) {
        CONTEXT.lock().unwrap().reset();
    }
}
