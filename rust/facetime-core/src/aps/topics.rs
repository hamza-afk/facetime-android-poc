//! SHA-1 hash constants for standard FaceTime and IDS APNS topics.

use sha1::{Digest, Sha1};

pub const TOPIC_MADRID: &str = "com.apple.madrid";
pub const TOPIC_ESS: &str = "com.apple.ess";
pub const TOPIC_FACETIME_MULTI: &str = "com.apple.private.alloy.facetime.multi";
pub const TOPIC_FACETIME_VIDEO: &str = "com.apple.private.alloy.facetime.video";
pub const TOPIC_QUICKRELAY: &str = "com.apple.private.alloy.quickrelay";

pub fn hash_topic(topic: &str) -> [u8; 20] {
    let mut hasher = Sha1::new();
    hasher.update(topic.as_bytes());
    hasher.finalize().into()
}

pub fn standard_facetime_topics() -> Vec<[u8; 20]> {
    vec![
        hash_topic(TOPIC_MADRID),
        hash_topic(TOPIC_ESS),
        hash_topic(TOPIC_FACETIME_MULTI),
        hash_topic(TOPIC_FACETIME_VIDEO),
        hash_topic(TOPIC_QUICKRELAY),
    ]
}
