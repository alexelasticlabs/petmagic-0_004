String stripQuery(String value) {
  final queryIndex = value.indexOf('?');
  if (queryIndex < 0) {
    return value;
  }

  return value.substring(0, queryIndex);
}

bool isPrivateIpv4(String address) {
  final octets = address.split('.');
  if (octets.length != 4) {
    return false;
  }

  final first = int.tryParse(octets[0]);
  final second = int.tryParse(octets[1]);
  if (first == null || second == null) {
    return false;
  }

  final isClassA = first == 10;
  final isClassB = first == 172 && second >= 16 && second <= 31;
  final isClassC = first == 192 && second == 168;

  return isClassA || isClassB || isClassC;
}
