"""Check 64-bit native ELF alignment in an APK/AAB using only Python stdlib."""
import json
import struct
import sys
import zipfile

results = []
with zipfile.ZipFile(sys.argv[1]) as archive:
    for name in archive.namelist():
        if not name.endswith('.so') or not any(abi in name.split('/') for abi in ('arm64-v8a', 'x86_64')):
            continue
        data = archive.read(name)
        if data[:6] != b'\x7fELF\x02\x01':
            raise ValueError('Expected little-endian ELF64: ' + name)
        offset = struct.unpack_from('<Q', data, 32)[0]
        size, count = struct.unpack_from('<HH', data, 54)
        alignment = [struct.unpack_from('<Q', data, offset + i * size + 48)[0]
                     for i in range(count) if struct.unpack_from('<I', data, offset + i * size)[0] == 1]
        valid = bool(alignment) and min(alignment) >= 16384
        results.append({'library': name, 'min_load_alignment': min(alignment, default=0), 'supports_16kb': valid})
if not results:
    raise ValueError('No 64-bit native libraries found')
print(json.dumps({'libraries': results, 'passed': all(row['supports_16kb'] for row in results)}, indent=2))
sys.exit(0 if all(row['supports_16kb'] for row in results) else 1)
