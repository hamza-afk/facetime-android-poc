//! Plist Serialization and Deserialization Models for Apple Directory (`id-query`).

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Outgoing request payload.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct LookupReq {
    pub uris: Vec<String>,
}

/// Root Apple Directory response payload.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct IDSLookupResp {
    pub status: u64,
    #[serde(default)]
    pub results: Option<HashMap<String, IDSLookupUser>>,
}

/// Enrolled Apple Account user descriptor.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub struct IDSLookupUser {
    #[serde(default)]
    pub identities: Vec<IDSDeliveryData>,
    pub sender_correlation_identifier: Option<String>,
}

/// Individual enrolled Apple device delivery data.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub struct IDSDeliveryData {
    pub client_data: ParsedClientData,
    #[serde(with = "crate::lookup::model::plist_data")]
    pub push_token: Vec<u8>,
    #[serde(with = "crate::lookup::model::plist_data")]
    pub session_token: Vec<u8>,
    #[serde(default)]
    pub session_token_expires_seconds: u64,
    #[serde(default)]
    pub session_token_refresh_seconds: u64,
}

/// Client cryptographic public keys and capability attributes.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub struct ParsedClientData {
    #[serde(with = "crate::lookup::model::plist_data")]
    pub public_message_identity_key: Vec<u8>,
    #[serde(default, with = "crate::lookup::model::plist_data_opt")]
    pub public_message_ngm_device_prekey_data_key: Option<Vec<u8>>,
    #[serde(default, with = "crate::lookup::model::plist_data_opt")]
    pub ngm_public_identity: Option<Vec<u8>>,
    #[serde(default)]
    pub supports_certified_delivery_v1: bool,
}

pub mod plist_data {
    use base64::Engine;
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S>(data: &[u8], serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        plist::Value::Data(data.to_vec()).serialize(serializer)
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
    where
        D: Deserializer<'de>,
    {
        let val = plist::Value::deserialize(deserializer)?;
        match val {
            plist::Value::Data(d) => Ok(d),
            plist::Value::String(s) => base64::engine::general_purpose::STANDARD
                .decode(s.as_bytes())
                .map_err(serde::de::Error::custom),
            other => Err(serde::de::Error::custom(format!("Expected plist Data, got {:?}", other))),
        }
    }
}

pub mod plist_data_opt {
    use base64::Engine;
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S>(data: &Option<Vec<u8>>, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        match data {
            Some(d) => plist::Value::Data(d.clone()).serialize(serializer),
            None => serializer.serialize_none(),
        }
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Option<Vec<u8>>, D::Error>
    where
        D: Deserializer<'de>,
    {
        let opt: Option<plist::Value> = Option::deserialize(deserializer)?;
        match opt {
            Some(plist::Value::Data(d)) => Ok(Some(d)),
            Some(plist::Value::String(s)) => {
                let bytes = base64::engine::general_purpose::STANDARD
                    .decode(s.as_bytes())
                    .map_err(serde::de::Error::custom)?;
                Ok(Some(bytes))
            }
            Some(_) => Ok(None),
            None => Ok(None),
        }
    }
}
