//! APS Courier binary and packed wire frame encoders and decoders.

use crate::bridge::error::FaceTimeCoreError;

pub const CMD_CONNECT: u8 = 0x07;
pub const CMD_CONNECT_RESPONSE: u8 = 0x08;
pub const CMD_FILTER: u8 = 0x09;
pub const CMD_NOTIFICATION: u8 = 0x0A;
pub const CMD_ACK: u8 = 0x0B;
pub const CMD_PING: u8 = 0x0C;
pub const CMD_PONG: u8 = 0x0D;
pub const CMD_SET_STATE: u8 = 0x14;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ApsFrame {
    pub command: u8,
    pub payload: Vec<u8>,
}

impl ApsFrame {
    pub fn new(command: u8, payload: Vec<u8>) -> Self {
        Self { command, payload }
    }

    /// Encodes a frame using raw binary framing: Command (1B) + Length (4B BE) + Payload.
    pub fn encode(&self) -> Vec<u8> {
        let mut buf = Vec::with_capacity(5 + self.payload.len());
        buf.push(self.command);
        let len = self.payload.len() as u32;
        buf.extend_from_slice(&len.to_be_bytes());
        buf.extend_from_slice(&self.payload);
        buf
    }

    /// Decodes a frame from an input buffer.
    pub fn decode(bytes: &[u8]) -> Result<(Self, usize), FaceTimeCoreError> {
        if bytes.len() < 5 {
            return Err(FaceTimeCoreError::ApsError {
                message: "Frame header truncated (< 5 bytes)".to_string(),
            });
        }
        let command = bytes[0];
        let len = u32::from_be_bytes([bytes[1], bytes[2], bytes[3], bytes[4]]) as usize;
        if bytes.len() < 5 + len {
            return Err(FaceTimeCoreError::ApsError {
                message: format!("Frame payload truncated (expected {}, got {})", len, bytes.len() - 5),
            });
        }
        let payload = bytes[5..5 + len].to_vec();
        Ok((Self { command, payload }, 5 + len))
    }
}
