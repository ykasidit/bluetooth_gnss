/// Protocol hint passed from Java to tell Rust how to interpret incoming bytes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum ProtocolHint {
    /// NMEA/UBX byte stream (RFCOMM or BLE NUS NMEA) — feed into queue_and_parse
    AutoDetectStream = 0,
    /// Qstarz BLE chunk — accumulate 3-4 chunks then parse as Qstarz packet
    QstarzBleChunk = 1,
}

impl ProtocolHint {
    pub fn from_i32(val: i32) -> Option<ProtocolHint> {
        match val {
            0 => Some(ProtocolHint::AutoDetectStream),
            1 => Some(ProtocolHint::QstarzBleChunk),
            _ => None,
        }
    }
}
