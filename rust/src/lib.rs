//! Omnissa Beta Token Utility — Rust port of the Python / Swift core.
//!
//! Experimental alongside the Python CLI and SwiftUI app. Same security model:
//! system `openssl` for key/cert and `.p7m` decrypt, fabricated credentials in tests only.

pub mod abm;
pub mod cli;
pub mod credentials;
pub mod oauth;
pub mod render;
pub mod servertoken;

pub use credentials::{BetaToken, Credentials, ToolError};
