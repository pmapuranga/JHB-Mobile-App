class Book {
  final String id;
  final String idCode; // Код вроде "47-0412"
  String title;
  final String filePath;
  final DateTime addedDate;
  final String location; // Местоположение
  final String duration; // Длительность
  int currentPage;
  int totalPages;
  String? customCoverPath;
  final bool isPreloaded;
  final String? sourceAssetPath;

  Book({
    required this.id,
    required this.idCode,
    required this.title,
    required this.filePath,
    required this.addedDate,
    this.location = '',
    this.duration = '',
    this.currentPage = 1,
    this.totalPages = 0,
    this.customCoverPath,
    this.isPreloaded = false,
    this.sourceAssetPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idCode': idCode,
      'title': title,
      'filePath': filePath,
      'addedDate': addedDate.toIso8601String(),
      'location': location,
      'duration': duration,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'customCoverPath': customCoverPath,
      'isPreloaded': isPreloaded,
      'sourceAssetPath': sourceAssetPath,
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'],
      idCode: json['idCode'] ?? '',
      title: json['title'],
      filePath: json['filePath'],
      addedDate: DateTime.parse(json['addedDate']),
      location: json['location'] ?? '',
      duration: json['duration'] ?? '',
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 0,
      customCoverPath: json['customCoverPath'],
      isPreloaded: json['isPreloaded'] ?? false,
      sourceAssetPath: json['sourceAssetPath'],
    );
  }

  double get readingProgress {
    if (totalPages <= 0) return 0.0;
    return currentPage / totalPages;
  }
}
