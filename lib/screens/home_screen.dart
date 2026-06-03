import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../generated/l10n.dart';
import '../models/book.dart';
import '../models/sermon_search_result.dart';
import '../providers/book_provider.dart';
import '../providers/settings_provider.dart';
import '../services/sermon_database_service.dart';
import '../widgets/book_card.dart';
import 'pdf_reader_screen.dart';
import 'sermon_reader_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;
  Book? _selectedBook;
  int _activeIndexTab = 0;
  bool _isSearchPanelOpen = false;
  int _searchScopeIndex = 0;
  bool _matchWholePhrase = false;
  List<SermonSearchResult> _sermonSearchResults = [];
  bool _sermonDatabaseReady = false;
  bool _isSearchRunning = false;
  int _searchRunId = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSermonDatabase();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: Consumer<BookProvider>(
        builder: (context, bookProvider, child) {
          if (bookProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (bookProvider.books.isEmpty) {
            return _buildEmptyState(s);
          }

          return _buildMobileIndex(bookProvider);
        },
      ),
    );
  }

  Widget _buildMobileIndex(BookProvider bookProvider) {
    final books = _mobileBooks(bookProvider.books);

    return SafeArea(
      child: Column(
        children: [
          _buildMobileTopBar(),
          if (_isSearchPanelOpen)
            Expanded(child: _buildSearchPanel(bookProvider))
          else ...[
            _buildMobileIconTabs(),
            _buildMobileSearchField(),
            _buildScrollTargetBar(books),
            Expanded(
              child: books.isEmpty
                  ? _buildDarkNoResults()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: books.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFF2A2A2A),
                      ),
                      itemBuilder: (context, index) {
                        return _buildSermonRow(books[index], index);
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  void _openBook(Book book) {
    setState(() => _selectedBook = book);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => book.isPreloaded
            ? SermonReaderScreen(bookId: book.id)
            : PDFReaderScreen(book: book),
      ),
    );
  }

  Widget _buildMobileTopBar() {
    return Container(
      height: 48,
      color: const Color(0xFF202020),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Library',
            icon: const Icon(Icons.menu_book_outlined, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search, color: Colors.white70),
            onPressed: () {
              setState(() => _isSearchPanelOpen = true);
              _runDatabaseSearch();
            },
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.language, size: 16, color: Colors.white70),
            label: const Text(
              'SHO',
              style:
                  TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: _isSearchPanelOpen ? 'Close search' : 'Settings',
            icon: Icon(
              _isSearchPanelOpen ? Icons.close : Icons.settings_outlined,
              color: Colors.white70,
            ),
            onPressed: _isSearchPanelOpen
                ? () => setState(() {
                      _isSearchPanelOpen = false;
                      _searchQuery = '';
                      _sermonSearchResults = [];
                    })
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(BookProvider bookProvider) {
    final results = _sermonSearchResults;

    return Column(
      children: [
        Container(
          height: 34,
          color: const Color(0xFF505050),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _buildSearchScopeTab('ALL', 0),
              const SizedBox(width: 8),
              _buildSearchScopeTab('CURRENT SERMON', 1),
            ],
          ),
        ),
        Container(
          color: const Color(0xFF3D3D3D),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search words or phrase',
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Color(0xFFBDBDBD)),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              _runDatabaseSearch();
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _runDatabaseSearch();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 44,
                height: 48,
                color: const Color(0xFFE1E1E1),
                child: const Icon(Icons.search, color: Color(0xFF777777)),
              ),
            ],
          ),
        ),
        Container(
          color: const Color(0xFF303030),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              const Text(
                'MATCH:',
                style: TextStyle(
                  color: Color(0xFFCFCFCF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _buildMatchButton(Icons.format_quote, 'Phrase', true),
              const SizedBox(width: 6),
              _buildMatchButton(Icons.manage_search, 'Any words', false),
            ],
          ),
        ),
        Expanded(
          child: _searchQuery.trim().isEmpty
              ? const Center(
                  child: Text(
                    'Type to search sermons',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : !_sermonDatabaseReady || _isSearchRunning
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : results.isEmpty
                      ? const Center(
                          child: Text(
                            'No matches found',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: results.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFF252525),
                          ),
                          itemBuilder: (context, index) {
                            return _buildSearchResultRow(results[index], index);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildSearchScopeTab(String label, int index) {
    final selected = _searchScopeIndex == index;

    return InkWell(
      onTap: () {
        setState(() => _searchScopeIndex = index);
        _runDatabaseSearch();
      },
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        color: selected ? const Color(0xFF242424) : const Color(0xFF4B4B4B),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildMatchButton(IconData icon, String tooltip, bool phrase) {
    final selected = _matchWholePhrase == phrase;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() => _matchWholePhrase = phrase);
          _runDatabaseSearch();
        },
        child: Container(
          width: 34,
          height: 28,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF56A9D9) : const Color(0xFF585858),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultRow(SermonSearchResult result, int index) {
    final rowColor =
        index.isEven ? const Color(0xFF4A4A4A) : const Color(0xFF3F3F3F);
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    final book = bookProvider.getBookById(result.bookId);
    final heading = [
      result.code,
      result.title,
      if (result.paragraphNumber.isNotEmpty) result.paragraphNumber,
    ].where((part) => part.trim().isNotEmpty).join(' ');

    return Material(
      color: rowColor,
      child: InkWell(
        onTap: book == null
            ? null
            : () {
                _openBook(book);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              _highlightSearchText(result.text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileIconTabs() {
    final tabs = [
      (Icons.calendar_month, 'Year / date'),
      (Icons.sort_by_alpha, 'Title'),
      (Icons.hourglass_bottom, 'Length'),
      (Icons.library_books_outlined, 'Other books'),
      (Icons.public, 'Preached places'),
    ];

    return Container(
      height: 58,
      color: const Color(0xFF2C2C2C),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (index) {
          final selected = _activeIndexTab == index;
          final tab = tabs[index];

          return Tooltip(
            message: tab.$2,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => setState(() => _activeIndexTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? const Color(0xFF4FA3D1)
                      : const Color(0xFF6D6D6D),
                  border: Border.all(
                    color: selected ? const Color(0xFF9BD9FF) : Colors.white24,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Icon(tab.$1, color: Colors.black87, size: 24),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMobileSearchField() {
    return Container(
      color: const Color(0xFF3A3A3A),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search title, date, or location',
          hintStyle: const TextStyle(color: Color(0xFF9F9F9F)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFBDBDBD)),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFBDBDBD)),
                  onPressed: () => setState(() => _searchQuery = ''),
                ),
          filled: true,
          fillColor: const Color(0xFFEDEDED),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildScrollTargetBar(List<Book> books) {
    final target = _scrollTargetLabel(books);

    return Container(
      height: 38,
      color: const Color(0xFF4A4A4A),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'SCROLL TO:',
            style: TextStyle(
              color: Color(0xFFC7C7C7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            target,
            style: const TextStyle(
              color: Color(0xFF60B2E3),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 22),
        ],
      ),
    );
  }

  Widget _buildSermonRow(Book book, int index) {
    final rowColor =
        index.isEven ? const Color(0xFF474747) : const Color(0xFF3B3B3B);
    final duration = book.duration.replaceAll('TIME:', '').trim();
    final idCode = book.idCode.isEmpty ? _fallbackCode(book) : book.idCode;
    final location = book.location.isEmpty ? 'Preloaded' : book.location;

    return Material(
      color: rowColor,
      child: InkWell(
        onTap: () {
          _openBook(book);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFECECEC),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chat_bubble_outline,
                            color: Colors.white70, size: 14),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      idCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF54A7D8),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 122,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Time: $duration',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFECECEC),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC7C7C7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkNoResults() {
    final message =
        _activeIndexTab == 3 ? 'No other books yet' : 'No matching sermons';

    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }

  List<Book> _mobileBooks(List<Book> source) {
    final query = _searchQuery.trim().toLowerCase();
    final books = source.where((book) {
      if (_activeIndexTab == 3 && book.isPreloaded) {
        return false;
      }

      if (query.isEmpty) return true;
      return book.title.toLowerCase().contains(query) ||
          book.idCode.toLowerCase().contains(query) ||
          book.location.toLowerCase().contains(query) ||
          book.duration.toLowerCase().contains(query);
    }).toList();

    switch (_activeIndexTab) {
      case 1:
        books.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 2:
        books.sort(
            (a, b) => _durationSortValue(b).compareTo(_durationSortValue(a)));
        break;
      case 3:
        books.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 4:
        books.sort((a, b) {
          final place =
              a.location.toLowerCase().compareTo(b.location.toLowerCase());
          if (place != 0) return place;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case 0:
      default:
        books.sort((a, b) => b.idCode.compareTo(a.idCode));
        break;
    }

    return books;
  }

  Future<void> _initializeSermonDatabase() async {
    try {
      await SermonDatabaseService.instance.database;
      if (!mounted) return;
      setState(() => _sermonDatabaseReady = true);
      _runDatabaseSearch();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sermonDatabaseReady = true);
    }
  }

  Future<void> _runDatabaseSearch() async {
    final query = _searchQuery.trim();
    final runId = ++_searchRunId;

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _sermonSearchResults = [];
        _isSearchRunning = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isSearchRunning = true);

    final scopedBookId = _searchScopeIndex == 1 ? _selectedBook?.id : null;
    if (_searchScopeIndex == 1 && scopedBookId == null) {
      if (!mounted || runId != _searchRunId) return;
      setState(() {
        _sermonSearchResults = [];
        _isSearchRunning = false;
      });
      return;
    }

    try {
      final results = await SermonDatabaseService.instance.search(
        query: query,
        bookId: scopedBookId,
        wholePhrase: _matchWholePhrase,
      );
      if (!mounted || runId != _searchRunId) return;
      setState(() {
        _sermonSearchResults = results;
        _isSearchRunning = false;
      });
    } catch (_) {
      if (!mounted || runId != _searchRunId) return;
      setState(() {
        _sermonSearchResults = [];
        _isSearchRunning = false;
      });
    }
  }

  Widget _highlightSearchText(String value) {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      return Text(
        value,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }

    final lowerValue = value.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];

    if (_matchWholePhrase) {
      _appendHighlightedSpans(value, lowerValue, lowerQuery, spans);
    } else {
      var remaining = value;
      var consumed = 0;
      final terms = query
          .split(RegExp(r'\s+'))
          .where((term) => term.isNotEmpty)
          .map((term) => term.toLowerCase())
          .toList();

      while (remaining.isNotEmpty) {
        final lowerRemaining = remaining.toLowerCase();
        var bestIndex = -1;
        var bestTerm = '';
        for (final term in terms) {
          final index = lowerRemaining.indexOf(term);
          if (index >= 0 && (bestIndex == -1 || index < bestIndex)) {
            bestIndex = index;
            bestTerm = term;
          }
        }

        if (bestIndex == -1) {
          spans.add(TextSpan(text: remaining));
          break;
        }

        if (bestIndex > 0) {
          spans.add(TextSpan(text: remaining.substring(0, bestIndex)));
        }
        spans.add(TextSpan(
          text: remaining.substring(bestIndex, bestIndex + bestTerm.length),
          style: const TextStyle(
            color: Color(0xFF00B7FF),
            fontWeight: FontWeight.w800,
          ),
        ));
        consumed += bestIndex + bestTerm.length;
        remaining = value.substring(consumed);
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.25),
        children: spans,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _appendHighlightedSpans(
    String value,
    String lowerValue,
    String lowerQuery,
    List<TextSpan> spans,
  ) {
    var start = 0;
    while (true) {
      final index = lowerValue.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: value.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: value.substring(start, index)));
      }
      spans.add(TextSpan(
        text: value.substring(index, index + lowerQuery.length),
        style: const TextStyle(
          color: Color(0xFF00B7FF),
          fontWeight: FontWeight.w800,
        ),
      ));
      start = index + lowerQuery.length;
    }
  }

  String _scrollTargetLabel(List<Book> books) {
    if (books.isEmpty) {
      switch (_activeIndexTab) {
        case 1:
          return 'TITLE';
        case 2:
          return 'LENGTH';
        case 3:
          return 'BOOK';
        case 4:
          return 'PLACE';
        case 0:
        default:
          return 'YEAR';
      }
    }

    switch (_activeIndexTab) {
      case 1:
        return books.first.title.characters.first.toUpperCase();
      case 2:
        return 'LENGTH';
      case 3:
        return 'BOOK';
      case 4:
        return books.first.location.isEmpty
            ? 'PLACE'
            : books.first.location.toUpperCase();
      case 0:
      default:
        return books.first.addedDate.year.toString();
    }
  }

  int _durationSortValue(Book book) {
    final value = book.duration.replaceAll('TIME:', '').trim();
    final parts =
        value.split(':').map((part) => int.tryParse(part.trim()) ?? 0).toList();
    if (parts.length == 1) return parts.first;
    if (parts.length == 2) return parts.first * 60 + parts.last;
    if (parts.length >= 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    return 0;
  }

  String _fallbackCode(Book book) {
    final compactDate =
        '${book.addedDate.year.toString().padLeft(4, '0').substring(2)}-${book.addedDate.month.toString().padLeft(2, '0')}${book.addedDate.day.toString().padLeft(2, '0')}';
    return compactDate;
  }

  Widget _buildPlaceholder(S s) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surface),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 88,
              color: colorScheme.primary.withOpacity(0.45),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose a book from the index',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(S s) {
    return AppBar(
      title: Text(
        s.appTitle,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _isSearching = true),
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar(S s) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => setState(() {
          _isSearching = false;
          _searchQuery = '';
        }),
      ),
      title: TextField(
        autofocus: true,
        decoration: InputDecoration(
          hintText: s.searchInBook,
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: (query) => setState(() => _searchQuery = query),
      ),
      actions: [
        if (_searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _searchQuery = ''),
          ),
      ],
    );
  }

  Widget _buildEmptyState(S s) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox.expand(
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 68,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                s.noBooksTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                s.noBooksSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                'Sermons are loaded from the internal library database.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryHeader(BookProvider bookProvider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: colorScheme.outlineVariant.withOpacity(0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Library',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${bookProvider.totalBooks} books saved',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '${bookProvider.inProgressBooks}',
                    'In progress',
                    Icons.bookmark_outline,
                    colorScheme.secondary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '${bookProvider.completedBooks}',
                    'Completed',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '${(bookProvider.averageProgress * 100).round()}%',
                    'Average',
                    Icons.trending_up,
                    colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRecentBooksGrid(BookProvider bookProvider, S s) {
    final recentBooks = bookProvider.getRecentBooks();
    final filteredBooks = _filterBooks(recentBooks);

    if (filteredBooks.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoSearchResults(s);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.66,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        return BookCard(book: filteredBooks[index]);
      },
    );
  }

  Widget _buildAllBooksGrid(
    BookProvider bookProvider,
    SettingsProvider settingsProvider,
    S s,
  ) {
    final sortedBooks = bookProvider.getSortedBooks(
      settingsProvider.sortType,
      settingsProvider.sortAscending,
    );
    final filteredBooks = _filterBooks(sortedBooks);

    if (filteredBooks.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoSearchResults(s);
    }

    return Column(
      children: [
        _buildSortPanel(settingsProvider, s),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.66,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: filteredBooks.length,
            itemBuilder: (context, index) {
              return BookCard(book: filteredBooks[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSortPanel(SettingsProvider settingsProvider, S s) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.65)),
      ),
      child: Row(
        children: [
          Text(s.sortBy, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 8),
          DropdownButton<BookSortType>(
            value: settingsProvider.sortType,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(16),
            onChanged: (BookSortType? newValue) {
              if (newValue != null) {
                settingsProvider.setSortType(newValue);
              }
            },
            items: [
              DropdownMenuItem(
                  value: BookSortType.name, child: Text(s.sortByName)),
              DropdownMenuItem(
                  value: BookSortType.dateAdded, child: Text(s.sortByDate)),
              DropdownMenuItem(
                  value: BookSortType.progress, child: Text(s.sortByProgress)),
            ],
          ),
          const Spacer(),
          IconButton.filledTonal(
            icon: Icon(
              settingsProvider.sortAscending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
            ),
            onPressed: () {
              settingsProvider
                  .setSortAscending(!settingsProvider.sortAscending);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults(S s) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 72, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text('No results', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _filterBooks(List<dynamic> books) {
    if (_searchQuery.isEmpty) return books;

    return books.where((book) {
      return book.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }
}
