#![forbid(unsafe_code)]

use std::io::{Read, Write};

/// Magic header bytes for flight frame recording.
pub const RECORDER_MAGIC: [u8; 4] = *b"BFR1";

/// Maximum permitted payload size for an append record (64 KB).
pub const MAX_RECORD_PAYLOAD_SIZE: usize = 65536;

/// Precomputed IEEE 802.3 CRC32 lookup table (256 entries).
const CRC32_TABLE: [u32; 256] = {
    let mut table = [0u32; 256];
    let mut i = 0usize;
    while i < 256 {
        let mut crc = i as u32;
        let mut j = 0;
        while j < 8 {
            if (crc & 1) != 0 {
                crc = (crc >> 1) ^ 0xEDB8_8320;
            } else {
                crc >>= 1;
            }
            j += 1;
        }
        table[i] = crc;
        i += 1;
    }
    table
};

/// Calculate IEEE 802.3 CRC32 checksum without external dependencies.
#[must_use]
pub fn calculate_crc32(data: &[u8]) -> u32 {
    let mut crc: u32 = 0xFFFF_FFFF;
    for &byte in data {
        let index = ((crc ^ u32::from(byte)) & 0xFF) as usize;
        crc = (crc >> 8) ^ CRC32_TABLE[index];
    }
    !crc
}

/// A versioned length-delimited record frame.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FlightRecordFrame {
    pub record_type: u8,
    pub payload: Vec<u8>,
}

impl FlightRecordFrame {
    #[must_use]
    pub fn new(record_type: u8, payload: Vec<u8>) -> Self {
        Self {
            record_type,
            payload,
        }
    }

    /// Serializes the frame into bytes:
    /// [Magic: 4B][RecordType: 1B][Reserved: 1B][Length: 2B][CRC32: 4B][Payload: NB]
    #[must_use]
    pub fn encode(&self) -> Vec<u8> {
        let payload_len = self.payload.len();
        assert!(
            payload_len <= MAX_RECORD_PAYLOAD_SIZE,
            "Payload exceeds max allowed size"
        );

        let crc = calculate_crc32(&self.payload);
        let mut bytes = Vec::with_capacity(12 + payload_len);
        bytes.extend_from_slice(&RECORDER_MAGIC);
        bytes.push(self.record_type);
        bytes.push(0); // reserved
        bytes.extend_from_slice(&(payload_len as u16).to_be_bytes());
        bytes.extend_from_slice(&crc.to_be_bytes());
        bytes.extend_from_slice(&self.payload);
        bytes
    }
}

/// Bounded buffered append-only writer for flight records.
#[derive(Debug)]
pub struct DurableFlightRecorder<W: Write> {
    writer: W,
    buffer: Vec<u8>,
    max_buffer_capacity: usize,
    records_written: u64,
    bytes_flushed: u64,
}

impl<W: Write> DurableFlightRecorder<W> {
    pub fn new(writer: W, max_buffer_capacity: usize) -> Self {
        Self {
            writer,
            buffer: Vec::with_capacity(max_buffer_capacity),
            max_buffer_capacity,
            records_written: 0,
            bytes_flushed: 0,
        }
    }

    pub fn append(&mut self, frame: &FlightRecordFrame) -> std::io::Result<()> {
        let encoded = frame.encode();
        if self.buffer.len() + encoded.len() > self.max_buffer_capacity {
            self.flush_buffer()?;
        }
        self.buffer.extend_from_slice(&encoded);
        self.records_written += 1;
        Ok(())
    }

    pub fn flush_buffer(&mut self) -> std::io::Result<()> {
        if !self.buffer.is_empty() {
            self.writer.write_all(&self.buffer)?;
            self.writer.flush()?;
            self.bytes_flushed += self.buffer.len() as u64;
            self.buffer.clear();
        }
        Ok(())
    }

    #[must_use]
    pub const fn records_written(&self) -> u64 {
        self.records_written
    }

    #[must_use]
    pub const fn bytes_flushed(&self) -> u64 {
        self.bytes_flushed
    }
}

/// Report resulting from recovery scan of a durable append file.
#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct RecoveryReport {
    pub valid_records: Vec<FlightRecordFrame>,
    pub discarded_tail_bytes: usize,
    pub had_incomplete_tail: bool,
}

/// Recovers valid records from a stream, discarding and reporting any incomplete or corrupt tail.
pub fn recover_flight_records<R: Read>(mut reader: R) -> std::io::Result<RecoveryReport> {
    let mut raw_data = Vec::new();
    reader.read_to_end(&mut raw_data)?;

    let mut valid_records = Vec::new();
    let mut cursor = 0;
    let total_len = raw_data.len();

    while cursor < total_len {
        let remaining = total_len - cursor;
        if remaining < 12 {
            // Incomplete header tail
            return Ok(RecoveryReport {
                valid_records,
                discarded_tail_bytes: remaining,
                had_incomplete_tail: true,
            });
        }

        let magic = &raw_data[cursor..cursor + 4];
        if magic != RECORDER_MAGIC {
            // Corrupt or unrecognized boundary: remainder is discarded tail
            return Ok(RecoveryReport {
                valid_records,
                discarded_tail_bytes: remaining,
                had_incomplete_tail: true,
            });
        }

        let record_type = raw_data[cursor + 4];
        let payload_len = u16::from_be_bytes([raw_data[cursor + 6], raw_data[cursor + 7]]) as usize;
        let expected_crc = u32::from_be_bytes([
            raw_data[cursor + 8],
            raw_data[cursor + 9],
            raw_data[cursor + 10],
            raw_data[cursor + 11],
        ]);

        let frame_total_len = 12 + payload_len;
        if remaining < frame_total_len {
            // Incomplete payload tail
            return Ok(RecoveryReport {
                valid_records,
                discarded_tail_bytes: remaining,
                had_incomplete_tail: true,
            });
        }

        let payload = &raw_data[cursor + 12..cursor + frame_total_len];
        let actual_crc = calculate_crc32(payload);
        if actual_crc != expected_crc {
            // Corrupt payload checksum: remainder is discarded
            return Ok(RecoveryReport {
                valid_records,
                discarded_tail_bytes: remaining,
                had_incomplete_tail: true,
            });
        }

        valid_records.push(FlightRecordFrame {
            record_type,
            payload: payload.to_vec(),
        });
        cursor += frame_total_len;
    }

    Ok(RecoveryReport {
        valid_records,
        discarded_tail_bytes: 0,
        had_incomplete_tail: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn crc32_matches_standard_vectors() {
        assert_eq!(calculate_crc32(b""), 0x0000_0000);
        assert_eq!(calculate_crc32(b"123456789"), 0xCBF4_3926);
    }

    #[test]
    fn frame_encoding_and_clean_recovery() {
        let mut buffer = Vec::new();
        let mut recorder = DurableFlightRecorder::new(&mut buffer, 1024);

        let frame1 = FlightRecordFrame::new(1, b"SAMPLE_BARO_DATA_1".to_vec());
        let frame2 = FlightRecordFrame::new(2, b"SAMPLE_GPS_DATA_2".to_vec());
        let frame3 = FlightRecordFrame::new(3, b"SAMPLE_VARIO_DATA_3".to_vec());

        recorder.append(&frame1).unwrap();
        recorder.append(&frame2).unwrap();
        recorder.append(&frame3).unwrap();
        recorder.flush_buffer().unwrap();

        let report = recover_flight_records(&buffer[..]).unwrap();
        assert_eq!(report.valid_records.len(), 3);
        assert_eq!(report.valid_records[0], frame1);
        assert_eq!(report.valid_records[1], frame2);
        assert_eq!(report.valid_records[2], frame3);
        assert_eq!(report.discarded_tail_bytes, 0);
        assert!(!report.had_incomplete_tail);
    }

    #[test]
    fn termination_at_each_write_boundary_recovers_exact_data() {
        let mut full_bytes = Vec::new();
        let mut recorder = DurableFlightRecorder::new(&mut full_bytes, 4096);

        let frames = vec![
            FlightRecordFrame::new(1, b"RECORD_ONE_PAYLOAD".to_vec()),
            FlightRecordFrame::new(2, b"RECORD_TWO_LONGER_PAYLOAD_HERE".to_vec()),
            FlightRecordFrame::new(3, b"RECORD_THREE_FINAL_DATA".to_vec()),
        ];

        for f in &frames {
            recorder.append(f).unwrap();
        }
        recorder.flush_buffer().unwrap();

        let frame1_len = frames[0].encode().len();
        let frame2_len = frames[1].encode().len();
        let total_len = full_bytes.len();

        // Truncate at EVERY byte offset from 0 to total_len
        for truncate_len in 0..=total_len {
            let truncated_slice = &full_bytes[..truncate_len];
            let report = recover_flight_records(truncated_slice).unwrap();

            let expected_recovered_count = if truncate_len < frame1_len {
                0
            } else if truncate_len < frame1_len + frame2_len {
                1
            } else if truncate_len < total_len {
                2
            } else {
                3
            };

            assert_eq!(
                report.valid_records.len(),
                expected_recovered_count,
                "Failed at truncate_len {}",
                truncate_len
            );

            let expected_discarded = if expected_recovered_count == 0 {
                truncate_len
            } else if expected_recovered_count == 1 {
                truncate_len - frame1_len
            } else if expected_recovered_count == 2 {
                truncate_len - (frame1_len + frame2_len)
            } else {
                0
            };

            assert_eq!(
                report.discarded_tail_bytes, expected_discarded,
                "Discarded bytes mismatch at truncate_len {}",
                truncate_len
            );
        }
    }
}
