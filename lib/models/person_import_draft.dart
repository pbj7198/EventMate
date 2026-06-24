// Temporary person draft produced from OCR sign-in sheet scans.
class PersonImportDraft {
  const PersonImportDraft({
    required this.name,
    this.phoneNumber,
    required this.sourceLine,
  });

  final String name;
  final String? phoneNumber;
  final String sourceLine;
}
