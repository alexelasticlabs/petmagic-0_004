class UploadMediaPolicy {
  const UploadMediaPolicy._();

  static const int avatarMaxBytes = 8 * 1024 * 1024;
  static const int petPhotoMaxBytes = 25 * 1024 * 1024;
  static const int supportImageMaxBytes = 10 * 1024 * 1024;
  static const int supportVideoMaxBytes = 50 * 1024 * 1024;
}
