class PdfTabData {
  const PdfTabData({
    required this.id,
    required this.filePath,
    required this.fileName,
    this.pageIndex = 0,
  });

  final String id;
  final String filePath;
  final String fileName;
  final int pageIndex;

  PdfTabData copyWith({int? pageIndex}) {
    return PdfTabData(
      id: id,
      filePath: filePath,
      fileName: fileName,
      pageIndex: pageIndex ?? this.pageIndex,
    );
  }
}
