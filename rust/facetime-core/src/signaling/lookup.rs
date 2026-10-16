//! Recipient directory lookup via WebTunnel (`id-query`, Command 96).

use crate::bridge::error::FaceTimeCoreError;
use crate::bridge::types::RecipientCapabilities;
use crate::events::EventDispatcher;
use crate::lookup::DirectoryLookupClient;

pub struct RecipientResolver;

impl RecipientResolver {
    pub fn lookup(handle: &str, dispatcher: &EventDispatcher) -> Result<RecipientCapabilities, FaceTimeCoreError> {
        DirectoryLookupClient::lookup_recipient(handle, dispatcher)
    }
}

