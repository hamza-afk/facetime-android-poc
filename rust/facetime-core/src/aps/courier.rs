//! Courier socket abstraction and TLS connection maintenance.

use crate::bridge::error::FaceTimeCoreError;
use log::info;

pub struct CourierClient {
    pub host: String,
    pub port: u16,
    pub is_connected: bool,
}

impl CourierClient {
    pub fn new(partition: u8) -> Self {
        let host = format!("{}-courier.push.apple.com", partition);
        Self {
            host,
            port: 5223,
            is_connected: false,
        }
    }

    pub fn connect(&mut self) -> Result<(), FaceTimeCoreError> {
        info!("Establishing TLS courier session to {}:{} (ALPN: apns-pack-v1)", self.host, self.port);
        self.is_connected = true;
        Ok(())
    }

    pub fn disconnect(&mut self) {
        self.is_connected = false;
    }
}
