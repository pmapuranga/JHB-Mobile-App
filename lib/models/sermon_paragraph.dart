class SermonParagraph {
  const SermonParagraph({
    required this.id,
    required this.sermonId,
    required this.number,
    required this.sortOrder,
    required this.text,
    this.startMs,
    this.endMs,
  });

  final int id;
  final int sermonId;
  final String number;
  final int sortOrder;
  final String text;
  final int? startMs;
  final int? endMs;

  factory SermonParagraph.fromMap(Map<String, Object?> map) {
    return SermonParagraph(
      id: map['paragraph_id'] as int,
      sermonId: map['sermon_id'] as int,
      number: map['paragraph_no']?.toString() ?? '',
      sortOrder: map['paragraph_no'] as int? ?? 0,
      text: map['text']?.toString() ?? '',
      startMs: map['start_time_ms'] as int?,
      endMs: map['end_time_ms'] as int?,
    );
  }
}
