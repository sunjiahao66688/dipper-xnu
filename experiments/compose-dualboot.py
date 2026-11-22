#!/usr/bin/env python3
"""Rebuild the dipper dual-boot image with a new UEFI FD (one-off lab tool)."""
import argparse, hashlib, struct, subprocess, zlib
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument('--candidate', type=Path, required=True)
ap.add_argument('--firmware', type=Path, required=True)
ap.add_argument('--out', type=Path, required=True)
ap.add_argument('--boot-partition-bytes', type=int, default=0x4000000)
a = ap.parse_args()

orig = a.candidate.read_bytes()
assert orig[:8] == b'ANDROID!'
page = struct.unpack_from('<I', orig, 36)[0]
ks = struct.unpack_from('<I', orig, 8)[0]
rs = struct.unpack_from('<I', orig, 16)[0]
assert page == 4096 and struct.unpack_from('<I', orig, 40)[0] == 1

dec = zlib.decompressobj(31)
plain = dec.decompress(orig[page:page + ks])
assert dec.eof
dtb = dec.unused_data
assert dtb[:4] == bytes.fromhex('d00dfeed')

L = struct.unpack_from('<Q', plain, 48)[0]
assert plain[L + 0x28:L + 0x2c] == b'_FVH', 'FD not where _KernelSize says'
fd = a.firmware.read_bytes()
assert len(fd) == 0x700000, 'FD must stay 0x700000 bytes'
payload = plain[L + 0x700000:]
assert payload[:4] == b'XNUP'

plain = bytearray(plain[:L] + fd + payload)
struct.pack_into('<Q', plain, 16, len(plain))

compressed = subprocess.run(['libdeflate-gzip', '-12', '-c'], input=bytes(plain),
                            capture_output=True, check=True).stdout
assert zlib.decompressobj(31).decompress(compressed) == bytes(plain)

ramstart = page + ((ks + page - 1) // page) * page
ram = orig[ramstart:ramstart + rs]
kernel = compressed + dtb
header = bytearray(orig[:page])
struct.pack_into('<I', header, 8, len(kernel))
digest = hashlib.sha1(kernel + struct.pack('<I', len(kernel)) + ram +
                      struct.pack('<III', rs, 0, 0)).digest()
header[576:608] = digest + bytes(12)

image = header + kernel + bytes(-len(kernel) % page) + ram + bytes(-len(ram) % page)
assert 0 < len(image) <= a.boot_partition_bytes, (len(image), a.boot_partition_bytes)
a.out.parent.mkdir(parents=True, exist_ok=True)
a.out.write_bytes(image)
print('image', len(image), 'sha256', hashlib.sha256(image).hexdigest())
print('L', hex(L), 'ram', len(ram), 'dtb', len(dtb), 'kernel', len(kernel))
