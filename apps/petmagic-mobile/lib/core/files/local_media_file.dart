final class LocalMediaFile {
  const LocalMediaFile({required this.path, required this.name, this.mimeType});

  final String path;
  final String name;
  final String? mimeType;
}
