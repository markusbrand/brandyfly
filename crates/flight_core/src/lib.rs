#![forbid(unsafe_code)]

/// Version of the public flight-core contract.
pub const CORE_API_VERSION: u16 = 1;

/// Returns the public contract version exposed by this crate.
#[must_use]
pub const fn core_api_version() -> u16 {
    CORE_API_VERSION
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_the_current_api_version() {
        assert_eq!(core_api_version(), 1);
    }
}
