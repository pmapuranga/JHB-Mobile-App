class SermonSearchResult {
  const SermonSearchResult({
    required this.sermonId,
    required this.bookId,
    required this.code,
    required this.title,
    required this.place,
    required this.paragraphId,
    required this.paragraphNumber,
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.rank,
  });

  final int sermonId;
  final String bookId;
  final String code;
  final String title;
  final String place;
  final int paragraphId;
  final String paragraphNumber;
  final String text;
  final int? startMs;
  final int? endMs;
  final double rank;

  factory SermonSearchResult.fromMap(Map<String, Object?> map) {
    return SermonSearchResult(
      sermonId: map['sermon_id'] as int,
      bookId: map['book_id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      place: map['place']?.toString() ?? '',
      paragraphId: map['paragraph_id'] as int,
      paragraphNumber: map['paragraph_no']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      startMs: map['start_time_ms'] as int?,
      endMs: map['end_time_ms'] as int?,
      rank: (map['rank'] as num?)?.toDouble() ?? 0,
    );
  }
}
