// Bound decoded dimensions before an untrusted upload reaches storage/review.
export function boundedImage(bytes: Uint8Array): boolean {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const allowed = (width: number, height: number) => width > 0 && height > 0 && width <= 4096 && height <= 4096;
  if (bytes.length >= 24 && bytes[0] === 137 && bytes[1] === 80 && bytes[2] === 78 && bytes[3] === 71 && bytes[12] === 73 && bytes[13] === 72 && bytes[14] === 68 && bytes[15] === 82) {
    return allowed(view.getUint32(16), view.getUint32(20));
  }
  if (bytes[0] !== 255 || bytes[1] !== 216) return false;
  for (let offset = 2; offset + 3 < bytes.length;) {
    if (bytes[offset++] !== 255) return false;
    while (bytes[offset] === 255) offset++;
    const marker = bytes[offset++];
    if (marker === 217 || marker === 218) return false;
    if (marker === 1 || (marker >= 208 && marker <= 215)) continue;
    if (offset + 2 > bytes.length) return false;
    const length = view.getUint16(offset);
    if (length < 2 || offset + length > bytes.length) return false;
    if ([192,193,194,195,197,198,199,201,202,203,205,206,207].includes(marker)) {
      return length >= 8 && allowed(view.getUint16(offset + 5), view.getUint16(offset + 3));
    }
    offset += length;
  }
  return false;
}
