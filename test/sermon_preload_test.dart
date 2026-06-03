import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_reader_app/screens/sermon_reader_screen.dart';
import 'package:pdf_reader_app/services/sermon_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads preloaded sermon text by saved id, code, or title', () async {
    final service = SermonDatabaseService.instance;

    final byId = await service.preloadedContentForBookId(
      'preloaded:11-1230-marriage-is-honourable',
    );
    final byCode = await service.preloadedContentForBookId('11-1230');
    final byTitle =
        await service.preloadedContentForBookId('Marriage Is Honourable');

    expect(byId, isNotNull);
    expect(byCode, isNotNull);
    expect(byTitle, isNotNull);
    expect(byId!.key.title, 'Marriage Is Honourable');
    expect(byId.value, isNotEmpty);
    expect(byId.value.first.text.trim(), isNotEmpty);
  });

  testWidgets('reader renders preloaded sermon text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SermonReaderScreen(
          bookId: 'preloaded:11-1230-marriage-is-honourable',
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sermon text not found'), findsNothing);
    expect(find.textContaining('Marriage Is Honourable'), findsWidgets);
  });

  test('preloaded sermons include real durations', () async {
    final raw = await rootBundle.loadString('assets/preload/books.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final books = (json['books'] as List<dynamic>).cast<Map<String, dynamic>>();

    expect(books, isNotEmpty);
    for (final book in books) {
      expect(book['duration'], isNot('TIME: 0:00'));
      expect(book['language'], 'SHO');
    }
  });
}
