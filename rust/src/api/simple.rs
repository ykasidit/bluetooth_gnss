#![allow(warnings)]

use crate::{CONTEXT, feed_and_parse};
use crate::protocol::ProtocolHint;

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Reset the parser state. Call before starting a new connection.
#[flutter_rust_bridge::frb(sync)]
pub fn parser_reset() {
    CONTEXT.lock().unwrap().reset();
}

/// Feed raw bytes to the parser and get back a JSON array string of parsed objects.
/// protocol_hint: 0 = AutoDetectStream (NMEA/UBX), 1 = QstarzBleChunk
#[flutter_rust_bridge::frb(sync)]
pub fn parser_feed(data: Vec<u8>, protocol_hint: i32) -> String {
    let hint = ProtocolHint::from_i32(protocol_hint).unwrap_or(ProtocolHint::AutoDetectStream);
    let mut ctx = CONTEXT.lock().unwrap();
    feed_and_parse(&mut ctx, &data, hint)
}
