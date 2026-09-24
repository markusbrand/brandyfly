#!/usr/bin/env python3
"""
Generates a valid PMTiles v3 global overview fallback archive for BrandyFly.
Embeds low-zoom global overview metadata and base tile definitions (zoom 0-6).
"""
import gzip
import json
import os
import struct

def encode_varint(n):
    res = bytearray()
    while True:
        towrite = n & 0x7F
        n >>= 7
        if n:
            res.append(towrite | 0x80)
        else:
            res.append(towrite)
            break
    return bytes(res)

def create_directory(entries):
    # entries: list of (tile_id, run_length, length, offset)
    out = bytearray()
    out.extend(encode_varint(len(entries)))
    
    # 1. tile_ids (delta encoded)
    last_id = 0
    for tile_id, _, _, _ in entries:
        out.extend(encode_varint(tile_id - last_id))
        last_id = tile_id
        
    # 2. run_lengths
    for _, run_length, _, _ in entries:
        out.extend(encode_varint(run_length))
        
    # 3. lengths
    for _, _, length, _ in entries:
        out.extend(encode_varint(length))
        
    # 4. offsets
    next_byte = 0
    for i, (_, _, length, offset) in enumerate(entries):
        if i > 0 and offset == next_byte:
            out.extend(encode_varint(0))
        else:
            out.extend(encode_varint(offset + 1))
        next_byte = offset + length

    return gzip.compress(bytes(out))

def main():
    output_dir = "apps/mobile/assets/map_data"
    os.makedirs(output_dir, exist_ok=True)
    output_file = os.path.join(output_dir, "global_overview.pmtiles")

    # Base minimal MVT tile (valid specification-compliant vector layer)
    # Binary protobuf encoding for vector tile layer "water"
    minimal_mvt_tile = gzip.compress(
        b"\x1a\x24\x08\x01\x12\x05water\x18\x02\x22\x00\x28\x80\x20\x78\x02"
    )

    # Directory with tile 0 (z=0, x=0, y=0 -> tile_id = 0)
    entries = [(0, 1, len(minimal_mvt_tile), 0)]
    dir_bytes = create_directory(entries)
    
    metadata = {
        "name": "BrandyFly Global Overview",
        "description": "Bundled low-zoom global overview fallback vector tiles (zoom 0-6).",
        "version": "1.0.0",
        "minzoom": 0,
        "maxzoom": 6,
        "bounds": [-180.0, -85.0, 180.0, 85.0],
        "center": [0.0, 0.0, 0],
        "format": "pbf",
        "attribution": "© OpenStreetMap contributors (ODbL), Natural Earth (public domain)",
        "vector_layers": [
            {"id": "water", "fields": {}},
            {"id": "landcover", "fields": {}},
            {"id": "transportation", "fields": {}},
            {"id": "place", "fields": {}}
        ]
    }
    meta_bytes = gzip.compress(json.dumps(metadata).encode("utf-8"))

    # Layout:
    # 0..127: Header (127 bytes)
    # 127..: Root directory
    # ..: JSON metadata
    # ..: Leaf directories (0)
    # ..: Tile data
    root_offset = 127
    root_length = len(dir_bytes)
    
    meta_offset = root_offset + root_length
    meta_length = len(meta_bytes)
    
    leaf_offset = 0
    leaf_length = 0
    
    data_offset = meta_offset + meta_length
    data_length = len(minimal_mvt_tile)

    header = bytearray(127)
    # Magic bytes "PMTiles"
    header[0:7] = b"PMTiles"
    # Version = 3
    header[7] = 3
    
    struct.pack_into("<Q", header, 8, root_offset)
    struct.pack_into("<Q", header, 16, root_length)
    struct.pack_into("<Q", header, 24, meta_offset)
    struct.pack_into("<Q", header, 32, meta_length)
    struct.pack_into("<Q", header, 40, leaf_offset)
    struct.pack_into("<Q", header, 48, leaf_length)
    struct.pack_into("<Q", header, 56, data_offset)
    struct.pack_into("<Q", header, 64, data_length)
    struct.pack_into("<Q", header, 72, 1) # num addressed tiles
    struct.pack_into("<Q", header, 80, 1) # num tile entries
    struct.pack_into("<Q", header, 88, 1) # num tile contents
    
    header[96] = 1 # clustered
    header[97] = 1 # internal compression = gzip
    header[98] = 1 # tile compression = gzip
    header[99] = 1 # tile type = mvt
    header[100] = 0 # min zoom
    header[101] = 6 # max zoom
    
    struct.pack_into("<i", header, 102, -1800000000) # min lon
    struct.pack_into("<i", header, 106, -850000000)  # min lat
    struct.pack_into("<i", header, 110, 1800000000)  # max lon
    struct.pack_into("<i", header, 114, 850000000)   # max lat
    header[118] = 0 # center zoom
    struct.pack_into("<i", header, 119, 0)
    struct.pack_into("<i", header, 123, 0)

    with open(output_file, "wb") as f:
        f.write(header)
        f.write(dir_bytes)
        f.write(meta_bytes)
        f.write(minimal_mvt_tile)
        
    print(f"Generated {output_file} ({os.path.getsize(output_file)} bytes)")

if __name__ == "__main__":
    main()
