## MODIFIED Requirements

### Requirement: Multi-format flight storage and open standard compatibility
The storage engine SHALL store all recorded flights in standard FAI IGC format compliant with XContest validation rules, as well as structured JSON and CSV formats. All numerical fields, including sub-sea-level negative altitudes, SHALL conform strictly to FAI IGC fixed-width byte field specifications without producing malformed character strings.

#### Scenario: Flight log file export
- **WHEN** a flight is finalized or exported by the user
- **THEN** the system generates a valid FAI IGC file containing mandatory A, H, I, B, and G/L records
- **AND** allows exporting the corresponding JSON and CSV representations

#### Scenario: Negative altitude export formatting
- **WHEN** a flight contains fixes recorded at altitudes below mean sea level
- **THEN** the generated IGC B-records SHALL format pressure and GNSS altitudes with a leading minus sign and zero-padded magnitude (e.g. `-0050` for -50m) within the standard 5-character field width
- **AND** ensure exported files are accepted by standard IGC parsers without numeric parsing errors

### Requirement: Manual flight import
The application SHALL allow pilots to manually upload/import existing IGC format or JSON flight files and choose whether to assign them to "My Flights" or "Planned Flights". The parser SHALL handle edge cases including negative altitudes and flights crossing midnight UTC without distorting timestamps or calculating negative durations.

#### Scenario: Importing an external flight track
- **WHEN** the user selects "Import Flight" and picks an IGC format or JSON file
- **THEN** the app prompts the user to select destination category ("My Flights" or "Planned Flights")
- **AND** parses the flight points, generates metadata, and adds it to the chosen list

#### Scenario: Importing sub-sea-level flight track
- **WHEN** an imported IGC file contains negative altitude B-records
- **THEN** the parser SHALL preserve the negative altitude values in the parsed flight model instead of resetting them to zero

#### Scenario: Importing flight crossing midnight UTC
- **WHEN** an imported flight track records fixes that roll over from 23:59:xx to 00:00:xx UTC
- **THEN** the parser SHALL increment the calendar date by 1 day for post-midnight fixes
- **AND** calculate a strictly positive elapsed flight duration and maintain positive inter-point time deltas for dynamic telemetry derivations
