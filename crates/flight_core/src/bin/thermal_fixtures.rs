//! Regenerates the thermal assistant golden parity fixtures.
//!
//! Usage (from the workspace root): `cargo run -p flight_core --bin thermal_fixtures`

use std::path::Path;

use flight_core::thermal_fixtures::{THERMAL_FIXTURE_DIR, render_all_thermal_fixtures};

fn main() -> std::io::Result<()> {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .join(THERMAL_FIXTURE_DIR);
    std::fs::create_dir_all(&dir)?;
    for (file, contents) in render_all_thermal_fixtures() {
        let path = dir.join(&file);
        std::fs::write(&path, contents)?;
        println!("wrote {}", path.display());
    }
    Ok(())
}
