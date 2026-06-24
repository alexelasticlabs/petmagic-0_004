bool hasSupportedMediaSignature(List<int> header) {
  if (startsWith(header, const [0xFF, 0xD8, 0xFF])) {
    return true;
  }
  if (startsWith(header, const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return true;
  }
  if (header.length >= 12 &&
      asciiEquals(header, 0, 'RIFF') &&
      asciiEquals(header, 8, 'WEBP')) {
    return true;
  }
  if (asciiEquals(header, 0, 'GIF8')) {
    return true;
  }
  if (header.length >= 12 && asciiEquals(header, 4, 'ftyp')) {
    return true;
  }
  return false;
}

bool startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) {
    return false;
  }
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) {
      return false;
    }
  }
  return true;
}

bool asciiEquals(List<int> bytes, int offset, String value) {
  if (bytes.length < offset + value.length) {
    return false;
  }
  for (var index = 0; index < value.length; index++) {
    if (bytes[offset + index] != value.codeUnitAt(index)) {
      return false;
    }
  }
  return true;
}
