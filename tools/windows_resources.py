"""Read ICO frames and PE icon resources without executing Windows tools (stdlib)."""
import hashlib
from pathlib import Path
import struct


def ico_frames(path):
    data = Path(path).read_bytes()
    reserved, kind, count = struct.unpack_from('<HHH', data)
    if reserved or kind != 1 or count != 6:
        raise RuntimeError('Expected six-size ICO')
    result = {}
    for index in range(count):
        w, h, _, _, _, _, size, offset = struct.unpack_from('<4B2H2I', data, 6+index*16)
        if w != h or offset+size > len(data):
            raise RuntimeError('Invalid ICO frame')
        result[w or 256] = hashlib.sha256(data[offset:offset+size]).hexdigest()
    if set(result) != {16, 32, 48, 64, 128, 256}:
        raise RuntimeError('Missing ICO size')
    return result


def pe_icon_frames(path):
    data = Path(path).read_bytes()
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    if data[:2] != b'MZ' or data[pe:pe+4] != b'PE\0\0':
        raise RuntimeError('Not a PE executable')
    sections = struct.unpack_from('<H', data, pe+6)[0]
    optional_size = struct.unpack_from('<H', data, pe+20)[0]
    optional = pe+24
    magic = struct.unpack_from('<H', data, optional)[0]
    if magic not in [0x10b, 0x20b]:
        raise RuntimeError('Unsupported PE optional header')
    directories = optional+(112 if magic == 0x20b else 96)
    resource_rva = struct.unpack_from('<I', data, directories+16)[0]
    spans = []
    for index in range(sections):
        entry = optional+optional_size+index*40
        virtual_size, rva, raw_size, raw = struct.unpack_from('<4I', data, entry+8)
        spans.append((rva, max(virtual_size, raw_size), raw))
    def offset(rva):
        for start, size, raw in spans:
            if start <= rva < start+size:
                return raw+rva-start
        raise RuntimeError('Unmapped PE resource RVA')
    base = offset(resource_rva)
    resources = {}
    def walk(relative, keys):
        if len(keys) > 3:
            raise RuntimeError('Invalid PE resource depth')
        named, numbered = struct.unpack_from('<HH', data, base+relative+12)
        for index in range(named+numbered):
            name, target = struct.unpack_from('<II', data, base+relative+16+index*8)
            path = keys+(name,)
            if target & 0x80000000:
                walk(target & 0x7fffffff, path)
            else:
                rva, size = struct.unpack_from('<II', data, base+target)
                start = offset(rva)
                if start+size > len(data):
                    raise RuntimeError('Truncated PE resource')
                resources[path] = data[start:start+size]
    walk(0, ())
    groups = [(key, value) for key, value in resources.items() if key[0] == 14]
    if len(groups) != 1:
        raise RuntimeError('Expected one Windows icon group')
    key, group = groups[0]
    reserved, kind, count = struct.unpack_from('<HHH', group)
    if reserved or kind != 1 or count != 6:
        raise RuntimeError('Missing six-size Windows icon group')
    frames = {}
    for index in range(count):
        w, h, _, _, _, _, size, identifier = struct.unpack_from('<4B2HIH', group, 6+index*14)
        payload = resources.get((3, identifier, key[2]))
        if payload is None or len(payload) != size or w != h:
            raise RuntimeError('Broken Windows icon resource reference')
        frames[w or 256] = hashlib.sha256(payload).hexdigest()
    return frames


def verify_icon(executable, expected):
    # JSON manifests stringify numeric keys.
    if pe_icon_frames(executable) != {int(key): value for key, value in expected.items()}:
        raise RuntimeError('EXE icon differs from the game ICO: '+str(executable))
