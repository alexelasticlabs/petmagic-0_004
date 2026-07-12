/// Classifies structured log fields that may contain credentials, stable
/// identifiers, user data or transport payloads.
final class LogFieldPolicy {
  const LogFieldPolicy._();

  static String normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool isSensitive(String key) {
    final normalizedKey = normalizeKey(key);
    return normalizedKey.contains('authorization') ||
        normalizedKey.contains('token') ||
        normalizedKey.contains('jwt') ||
        normalizedKey.contains('cookie') ||
        normalizedKey.contains('credential') ||
        normalizedKey.contains('signature') ||
        normalizedKey.contains('secret') ||
        normalizedKey.contains('verificationdata') ||
        normalizedKey.contains('password') ||
        normalizedKey.contains('receipt') ||
        normalizedKey.contains('card') ||
        normalizedKey.contains('cvc') ||
        normalizedKey.contains('cvv') ||
        normalizedKey.contains('phone') ||
        normalizedKey.contains('email') ||
        normalizedKey.contains('signedurl') ||
        isSensitiveNavigationUrl(key) ||
        normalizedKey == 'ticket' ||
        normalizedKey == 'authticket' ||
        normalizedKey == 'externalauthticket' ||
        normalizedKey == 'sessionid' ||
        normalizedKey == 'checkoutsessionid' ||
        normalizedKey == 'stripesessionid' ||
        normalizedKey == 'purchasetoken' ||
        normalizedKey == 'purchaseid' ||
        normalizedKey == 'paymentintentid' ||
        normalizedKey == 'setupintentid' ||
        normalizedKey == 'customerid' ||
        normalizedKey == 'subscriptionid' ||
        normalizedKey == 'externalpaymentid' ||
        normalizedKey == 'externalsubscriptionid' ||
        normalizedKey == 'signedtransactioninfo';
  }

  static bool isStableIdentifier(String key) {
    final normalizedKey = normalizeKey(key);
    return normalizedKey == 'userid' ||
        normalizedKey == 'profileuserid' ||
        normalizedKey == 'owneruserid' ||
        normalizedKey == 'subjectid' ||
        normalizedKey == 'accountid' ||
        normalizedKey == 'accountscope' ||
        normalizedKey == 'userscope' ||
        normalizedKey == 'scope' ||
        normalizedKey == 'petid' ||
        normalizedKey == 'petphotoid' ||
        normalizedKey == 'generationid' ||
        normalizedKey == 'templateid' ||
        normalizedKey == 'assignmentid' ||
        normalizedKey == 'conversationid' ||
        normalizedKey == 'messageid' ||
        normalizedKey == 'ticketid' ||
        normalizedKey == 'attachmentid' ||
        normalizedKey == 'feedbackid' ||
        normalizedKey == 'reportid' ||
        normalizedKey == 'moderationid' ||
        normalizedKey == 'orderid' ||
        _isCompoundStableDomainIdentifier(normalizedKey);
  }

  static bool _isCompoundStableDomainIdentifier(String normalizedKey) {
    if (normalizedKey == 'requestid' ||
        normalizedKey == 'correlationid' ||
        normalizedKey == 'traceid') {
      return false;
    }
    return (normalizedKey.contains('user') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('account') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('pet') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('generation') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('template') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('assignment') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('conversation') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('message') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('ticket') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('attachment') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('purchase') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('subscription') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('feedback') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('report') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('moderation') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('order') && normalizedKey.endsWith('id')) ||
        _isCompoundStableDomainIdentifierList(normalizedKey);
  }

  static bool _isCompoundStableDomainIdentifierList(String normalizedKey) {
    if (normalizedKey == 'requestids' ||
        normalizedKey == 'correlationids' ||
        normalizedKey == 'traceids') {
      return false;
    }
    return (normalizedKey.contains('user') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('account') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('pet') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('generation') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('template') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('assignment') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('conversation') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('message') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('ticket') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('attachment') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('purchase') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('subscription') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('feedback') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('report') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('moderation') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('order') && normalizedKey.endsWith('ids'));
  }

  static bool isEmail(String key) => normalizeKey(key).contains('email');

  static bool isRawUserData(String key) {
    final normalizedKey = normalizeKey(key);
    return normalizedKey == 'name' ||
        normalizedKey == 'username' ||
        normalizedKey == 'displayname' ||
        normalizedKey == 'fullname' ||
        normalizedKey == 'firstname' ||
        normalizedKey == 'lastname' ||
        normalizedKey == 'sendername' ||
        normalizedKey == 'senderdisplayname' ||
        normalizedKey == 'recipientname' ||
        normalizedKey == 'recipientdisplayname' ||
        normalizedKey == 'contactname' ||
        normalizedKey == 'contactdisplayname' ||
        normalizedKey == 'address' ||
        normalizedKey == 'fulladdress' ||
        normalizedKey == 'streetaddress' ||
        normalizedKey == 'addressline' ||
        normalizedKey == 'addressline1' ||
        normalizedKey == 'addressline2' ||
        normalizedKey == 'city' ||
        normalizedKey == 'country' ||
        normalizedKey == 'region' ||
        normalizedKey == 'province' ||
        normalizedKey == 'postalcode' ||
        normalizedKey == 'zipcode';
  }

  static bool isUserFileName(String key) {
    final normalizedKey = normalizeKey(key);
    return normalizedKey == 'filename' ||
        normalizedKey == 'filenames' ||
        normalizedKey.endsWith('filename') ||
        normalizedKey.endsWith('filenames');
  }

  static bool isEndpoint(String key) {
    final normalizedKey = normalizeKey(key);
    return normalizedKey == 'path' ||
        normalizedKey == 'endpoint' ||
        normalizedKey == 'route' ||
        normalizedKey == 'baseurl' ||
        normalizedKey == 'apiurl' ||
        normalizedKey == 'apibaseurl' ||
        normalizedKey == 'publicbaseurl';
  }

  static bool isRemoteMediaUrl(String key) {
    final normalizedKey = normalizeKey(key);
    return normalizedKey == 'attachmenturl' ||
        normalizedKey == 'attachmenturls' ||
        normalizedKey == 'fileurl' ||
        normalizedKey == 'fileurls' ||
        normalizedKey == 'mediaurl' ||
        normalizedKey == 'mediaurls' ||
        normalizedKey == 'imageurl' ||
        normalizedKey == 'imageurls' ||
        normalizedKey == 'videourl' ||
        normalizedKey == 'videourls' ||
        normalizedKey == 'avatarurl' ||
        normalizedKey == 'avatarurls' ||
        normalizedKey == 'thumbnailurl' ||
        normalizedKey == 'thumbnailurls' ||
        normalizedKey == 'previewurl' ||
        normalizedKey == 'previewurls' ||
        normalizedKey == 'outputurl' ||
        normalizedKey == 'outputurls' ||
        normalizedKey == 'downloadurl' ||
        normalizedKey == 'downloadurls' ||
        normalizedKey == 'uploadurl' ||
        normalizedKey == 'uploadurls';
  }

  static bool isSensitiveNavigationUrl(String key) {
    final normalizedKey = normalizeKey(key);
    return normalizedKey == 'checkouturl' ||
        normalizedKey == 'paymenturl' ||
        normalizedKey == 'billingportalurl' ||
        normalizedKey == 'customerportalurl' ||
        normalizedKey == 'redirecturl' ||
        normalizedKey == 'callbackurl' ||
        normalizedKey == 'returnurl' ||
        normalizedKey == 'successurl' ||
        normalizedKey == 'cancelurl';
  }

  static bool isLocalFilePath(String key) {
    final normalizedKey = normalizeKey(key);
    return normalizedKey.contains('filepath') ||
        normalizedKey.contains('localpath') ||
        normalizedKey.contains('sourcepath') ||
        normalizedKey.contains('imagepath') ||
        normalizedKey.contains('videopath') ||
        normalizedKey.contains('avatarpath');
  }

  static bool isTransportPayload(String key) {
    final normalizedKey = normalizeKey(key);
    return normalizedKey == 'payload' ||
        normalizedKey == 'rawpayload' ||
        normalizedKey == 'apipayload' ||
        normalizedKey == 'providerpayload' ||
        normalizedKey == 'webhookpayload' ||
        normalizedKey == 'verificationdata' ||
        normalizedKey == 'serververificationdata' ||
        normalizedKey == 'localverificationdata' ||
        normalizedKey == 'signedtransactioninfo' ||
        normalizedKey == 'signedpayload' ||
        normalizedKey == 'body' ||
        normalizedKey == 'rawbody' ||
        normalizedKey == 'requestbody' ||
        normalizedKey == 'responsebody' ||
        normalizedKey == 'requestdata' ||
        normalizedKey == 'responsedata' ||
        normalizedKey == 'formdata' ||
        normalizedKey == 'headers' ||
        normalizedKey == 'requestheaders' ||
        normalizedKey == 'responseheaders';
  }
}
