//! Omnissa Beta Token Utility — Rust library for the CLI and egui macOS app.
//!
//! Security model: pinned system `openssl` for key/cert and `.p7m` decrypt,
//! `redirects(0)` for Apple HTTP, fabricated credentials in tests only.

pub mod abm;
pub mod cli;
pub mod credentials;
pub mod oauth;
pub mod render;
pub mod servertoken;

pub use credentials::{
    access_token_expired, parse_access_token_expiry, BetaToken, Credentials, ToolError,
};
