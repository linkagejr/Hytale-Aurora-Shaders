"""Pillow stand-in: PNG decoding into RGBA for tools/prepare_shaders.py, build_emitters.py and
build_sss.py when Pillow (python3-pil) is not installed. Supports what they call: open, size,
width, height, convert("RGBA"), crop, getdata, and use as a context manager. Colour values come
out as stored (no gamma or colour-profile conversion), all PNG colour types and bit depths,
tRNS transparency and Adam7 interlacing."""
import builtins
import struct
import zlib

__all__ = ["open", "Image"]


class PngError(ValueError):
    pass


ADAM7 = ((0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4), (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2))

def _unfilter(data, pos, w, h, bpp, row_bytes):
    """Undoes the PNG row filters of a w x h (sub)image starting at data[pos]."""
    out = bytearray(row_bytes * h)
    prev = bytearray(row_bytes)
    for y in range(h):
        ft = data[pos]
        line = bytearray(data[pos + 1:pos + 1 + row_bytes])
        pos += 1 + row_bytes
        if len(line) < row_bytes:
            raise PngError('truncated image data')
        if ft == 1:
            for i in range(bpp, row_bytes):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif ft == 2:
            for i in range(row_bytes):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ft == 3:
            for i in range(row_bytes):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ft == 4:
            for i in range(row_bytes):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else b if pb <= pc else c
                line[i] = (line[i] + pred) & 0xFF
        elif ft != 0:
            raise PngError('bad filter type %d' % ft)
        out[y * row_bytes:(y + 1) * row_bytes] = line
        prev = line
    return out, pos


def png_rgba(png):
    """Decodes a PNG into (width, height, RGBA8 bytes, top row first): the colour values as stored,
    no gamma or colour-profile conversion (what the game uploads to its block atlas)."""
    if png[:8] != b'\x89PNG\r\n\x1a\n':
        raise PngError('not a PNG')
    pos, idat, plte, trns, ihdr = 8, [], None, None, None
    while pos + 8 <= len(png):
        length, ctype = struct.unpack('>I4s', png[pos:pos + 8])
        body = png[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b'IHDR':
            ihdr = struct.unpack('>IIBBBBB', body[:13])
        elif ctype == b'PLTE':
            plte = body
        elif ctype == b'tRNS':
            trns = body
        elif ctype == b'IDAT':
            idat.append(body)
        elif ctype == b'IEND':
            break
    if not ihdr:
        raise PngError('no IHDR')
    w, h, depth, color, _, _, interlace = ihdr
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color)
    if channels is None or depth not in (1, 2, 4, 8, 16) or (depth < 8 and color not in (0, 3)) \
            or (depth == 16 and color == 3) or w <= 0 or h <= 0 or w > 4096 or h > 4096:
        raise PngError('unsupported format (colour type %d, depth %d)' % (color, depth))
    if color == 3 and not plte:
        raise PngError('palette missing')
    raw = zlib.decompress(b''.join(idat))
    bits_pp = channels * depth
    bpp = max(1, bits_pp // 8)

    def samples(row, count):
        """The first `count` pixels' samples of an unfiltered row, as ints."""
        if depth == 8:
            return row[:count * channels]
        if depth == 16:
            return [(row[i] << 8) | row[i + 1] for i in range(0, count * channels * 2, 2)]
        per_byte = 8 // depth
        mask = (1 << depth) - 1
        vals = []
        for i in range(count):
            byte = row[i // per_byte]
            shift = 8 - depth * (i % per_byte + 1)
            vals.append((byte >> shift) & mask)
        return vals

    max_val = (1 << depth) - 1
    trns_gray = struct.unpack('>H', trns[:2])[0] if trns and color == 0 and len(trns) >= 2 else None
    trns_rgb = struct.unpack('>HHH', trns[:6]) if trns and color == 2 and len(trns) >= 6 else None
    pal_alpha = trns if trns and color == 3 else b''

    def to8(v):
        if depth == 16:
            return v >> 8
        if depth == 8:
            return v
        return v * 255 // max_val

    out = bytearray(w * h * 4)

    def put_pixels(row_vals, y, xs):
        for k, x in enumerate(xs):
            o = (y * w + x) * 4
            if color == 6:
                s = row_vals[k * 4:k * 4 + 4]
                out[o:o + 4] = bytes((to8(s[0]), to8(s[1]), to8(s[2]), to8(s[3])))
            elif color == 2:
                s = row_vals[k * 3:k * 3 + 3]
                a = 0 if trns_rgb is not None and tuple(s) == trns_rgb else 255
                out[o:o + 4] = bytes((to8(s[0]), to8(s[1]), to8(s[2]), a))
            elif color == 4:
                g, a = row_vals[k * 2], row_vals[k * 2 + 1]
                out[o:o + 4] = bytes((to8(g), to8(g), to8(g), to8(a)))
            elif color == 0:
                g = row_vals[k]
                a = 0 if trns_gray is not None and g == trns_gray else 255
                out[o:o + 4] = bytes((to8(g), to8(g), to8(g), a))
            else:
                i = row_vals[k]
                if 3 * i + 2 >= len(plte):
                    raise PngError('palette index out of range')
                a = pal_alpha[i] if i < len(pal_alpha) else 255
                out[o:o + 4] = bytes((plte[3 * i], plte[3 * i + 1], plte[3 * i + 2], a))

    passes = ADAM7 if interlace == 1 else ((0, 0, 1, 1),)
    pos = 0
    for x0, y0, dx, dy in passes:
        pw = (w - x0 + dx - 1) // dx
        ph = (h - y0 + dy - 1) // dy
        if pw <= 0 or ph <= 0:
            continue
        row_bytes = (pw * bits_pp + 7) // 8
        rows, pos = _unfilter(raw, pos, pw, ph, bpp, row_bytes)
        for j in range(ph):
            row = rows[j * row_bytes:(j + 1) * row_bytes]
            put_pixels(samples(row, pw), y0 + j * dy, range(x0, w, dx))
    return w, h, bytes(out)


class Image:
    """An RGBA8 image (rows top first)."""

    def __init__(self, width, height, data):
        self.width, self.height, self._data = width, height, data
        self.mode = "RGBA"

    @property
    def size(self):
        return (self.width, self.height)

    def convert(self, mode):
        if mode != "RGBA":
            raise ValueError("only RGBA conversion is supported without Pillow")
        return self

    def crop(self, box):
        left, top, right, bottom = (int(v) for v in box)
        if left < 0 or top < 0 or right > self.width or bottom > self.height or right < left or bottom < top:
            raise ValueError("crop box outside the image")
        stride, width = self.width * 4, right - left
        rows = [self._data[y * stride + left * 4:y * stride + right * 4] for y in range(top, bottom)]
        return Image(width, bottom - top, b"".join(rows))

    def getdata(self):
        d = self._data
        return [tuple(d[i:i + 4]) for i in range(0, len(d), 4)]

    def close(self):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def open(fp, mode="r"):
    if hasattr(fp, "read"):
        data = fp.read()
    else:
        with builtins.open(fp, "rb") as stream:
            data = stream.read()
    width, height, rgba = png_rgba(data)
    return Image(width, height, rgba)
