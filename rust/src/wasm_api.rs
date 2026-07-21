//! WASM bindings for the GNSS parser - used by www.clearevo.com/gnss (web serial decoder).
//! Build: wasm-pack build --target web --no-default-features --features wasm
use wasm_bindgen::prelude::*;

use crate::parser::feed_and_parse;
use crate::protocol::ProtocolHint;
use crate::State;

#[wasm_bindgen]
pub struct GnssParser {
    state: State,
}

#[wasm_bindgen]
impl GnssParser {
    #[wasm_bindgen(constructor)]
    pub fn new() -> GnssParser {
        GnssParser { state: State::new() }
    }

    /// Feed raw NMEA/UBX stream bytes; returns a JSON array string of parsed objects.
    pub fn feed(&mut self, data: &[u8]) -> String {
        feed_and_parse(&mut self.state, data, ProtocolHint::AutoDetectStream)
    }

    /// Feed a Qstarz BLE chunk; returns a JSON array string.
    pub fn feed_qstarz(&mut self, data: &[u8]) -> String {
        feed_and_parse(&mut self.state, data, ProtocolHint::QstarzBleChunk)
    }

    /// Accumulated parameter map (lat/lon/alt/dops/sats/...) as a JSON object string.
    pub fn params(&self) -> String {
        serde_json::to_string(&self.state.params).unwrap_or_else(|_| "{}".into())
    }

    pub fn reset(&mut self) {
        self.state.reset();
    }
}
