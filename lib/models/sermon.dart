class Sermon {
  const Sermon({
    required this.id,
    required this.code,
    required this.title,
    required this.preacher,
    required this.sermonDate,
    required this.place,
    required this.language,
    required this.durationSeconds,
    required this.audioFile,
    required this.isDownloaded,
    required this.bookId,
    required this.category,
  });

  final int id;
  final String code;
  final String title;
  final String preacher;
  final String sermonDate;
  final String place;
  final String language;
  final int durationSeconds;
  final String audioFile;
  final bool isDownloaded;
  final String bookId;
  final String category;

  factory Sermon.fromMap(Map<String, Object?> map) {
    return Sermon(
      id: map['sermon_id'] as int,
      code: map['code']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      preacher: map['preacher']?.toString() ?? '',
      sermonDate: map['sermon_date']?.toString() ?? '',
      place: map['place']?.toString() ?? '',
      language: map['language']?.toString() ?? 'en',
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      audioFile: map['audio_file']?.toString() ?? '',
      isDownloaded: (map['is_downloaded'] as int? ?? 0) == 1,
      bookId: map['book_id']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
    );
  }
}
