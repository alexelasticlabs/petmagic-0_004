const _supportedMp4Brands = {
  'mp41',
  'mp42',
  'isom',
  'iso2',
  'avc1',
  'm4v ',
  'm4a ',
};

const _supportedHeicBrands = {'heic', 'heix', 'hevc', 'hevx', 'heis', 'heim'};
const _supportedHeifBrands = {'mif1', 'msf1'};

String? detectAvatarUploadContentType(List<int> header) {
  if (startsWith(header, const [0xFF, 0xD8, 0xFF])) {
    return 'image/jpeg';
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
    return 'image/png';
  }
  if (header.length >= 12 &&
      asciiEquals(header, 0, 'RIFF') &&
      asciiEquals(header, 8, 'WEBP')) {
    return 'image/webp';
  }

  return null;
}

String? detectSupportAttachmentContentType(List<int> header) {
  final avatarContentType = detectAvatarUploadContentType(header);
  if (avatarContentType != null) {
    return avatarContentType;
  }

  final brand = isoBmffBrand(header);
  if (brand == 'qt  ') {
    return 'video/quicktime';
  }
  if (brand != null && _supportedMp4Brands.contains(brand)) {
    return 'video/mp4';
  }

  return null;
}

String? detectTemplateSourceImageContentType(List<int> header) {
  final avatarContentType = detectAvatarUploadContentType(header);
  if (avatarContentType != null) {
    return avatarContentType;
  }

  final brand = isoBmffBrand(header);
  if (brand != null && _supportedHeicBrands.contains(brand)) {
    return 'image/heic';
  }
  if (brand != null && _supportedHeifBrands.contains(brand)) {
    return 'image/heif';
  }

  return null;
}

String? detectSupportedMediaContentType(List<int> header) {
  final supportAttachmentContentType = detectSupportAttachmentContentType(
    header,
  );
  if (supportAttachmentContentType != null) {
    return supportAttachmentContentType;
  }
  if (asciiEquals(header, 0, 'GIF8')) {
    return 'image/gif';
  }

  return null;
}

bool hasSupportedMediaSignature(List<int> header) {
  return detectSupportedMediaContentType(header) != null;
}

String? isoBmffBrand(List<int> header) {
  if (header.length < 12 || !asciiEquals(header, 4, 'ftyp')) {
    return null;
  }

  return String.fromCharCodes(header.skip(8).take(4)).toLowerCase();
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
