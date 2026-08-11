class PdfTabData {
  const PdfTabData({
    required this.id,
    required this.filePath,
    required this.fileName,
    String? displayName,
    this.pageIndex = 0,
  }) : displayName = displayName ?? fileName;

  final String id;
  final String filePath;
  final String fileName;
  final String displayName;
  final int pageIndex;

  PdfTabData copyWith({
    String? displayName,
    int? pageIndex,
  }) {
    return PdfTabData(
      id: id,
      filePath: filePath,
      fileName: fileName,
      displayName: displayName ?? this.displayName,
      pageIndex: pageIndex ?? this.pageIndex,
    );
  }
}
