import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/book.dart';
import '../models/bookmark.dart';
import '../providers/book_provider.dart';
import '../providers/settings_provider.dart';
import '../generated/l10n.dart';
import '../widgets/bookmarks_bottom_sheet.dart';

class PDFReaderScreen extends StatefulWidget {
  final Book book;
  final bool isEmbedded;

  const PDFReaderScreen({
    Key? key,
    required this.book,
    this.isEmbedded = false,
  }) : super(key: key);

  @override
  _PDFReaderScreenState createState() => _PDFReaderScreenState();
}

class _PDFReaderScreenState extends State<PDFReaderScreen> {
  final PdfViewerController controller = PdfViewerController();
  int currentPage = 1;
  int totalPages = 0;
  bool isReady = false;
  bool showControls = true;
  bool isFullscreen = false;

  @override
  void initState() {
    super.initState();
    currentPage = widget.book.currentPage
        .clamp(1, widget.book.totalPages > 0 ? widget.book.totalPages : 1);
    totalPages = widget.book.totalPages;
    _hideSystemUI();
  }

  @override
  void dispose() {
    _showSystemUI();
    super.dispose();
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Consumer2<BookProvider, SettingsProvider>(
      builder: (context, bookProvider, settingsProvider, child) {
        return Scaffold(
          backgroundColor: widget.isEmbedded ? Colors.white : Colors.black,
          extendBodyBehindAppBar: false,
          appBar: _buildAppBar(s, bookProvider),
          body: Stack(
            children: [
              _buildPDFViewer(settingsProvider),
              if (!widget.isEmbedded) _buildGestureDetector(),
              if (showControls && !isFullscreen)
                _buildBottomControls(s, bookProvider),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(S s, BookProvider bookProvider) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFFD32F2F),
      elevation: 0,
      leading: widget.isEmbedded
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.menu_book_outlined, size: 28),
                const SizedBox(width: 12),
                const Icon(Icons.search, size: 28),
              ],
            )
          : null,
      leadingWidth: widget.isEmbedded ? 100 : null,
      title: Column(
        children: [
          const Text(
            'JHB Mobile App',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              fontFamily: 'Serif',
            ),
          ),
          Text(
            '${widget.book.idCode}  ${widget.book.title.toUpperCase()}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (widget.isEmbedded)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.public, size: 20),
                const SizedBox(width: 4),
                Text(
                  'SHO',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                Icon(Icons.keyboard_arrow_down,
                    color: Colors.grey[700], size: 18),
              ],
            ),
          )
        else
          IconButton(
            icon: Icon(
              bookProvider.hasBookmarkForPage(widget.book.id, currentPage)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            onPressed: () => _toggleBookmark(bookProvider, s),
          ),
      ],
    );
  }

  Widget _buildPDFViewer(SettingsProvider settingsProvider) {
    if (!File(widget.book.filePath).existsSync()) {
      return _buildFileNotFoundError();
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          PdfViewer.file(
            widget.book.filePath,
            controller: controller,
            initialPageNumber: currentPage,
            params: PdfViewerParams(
              enableTextSelection: true,
              maxScale: 8.0,
              onViewerReady: (document, controller) {
                setState(() {
                  totalPages = document.pages.length;
                  isReady = true;
                });
                print('PDF loaded: $totalPages pages, current: $currentPage');
                // Не вызываем _updateProgress здесь, так как это может вызвать setState во время сборки
              },
              onPageChanged: (page) {
                if (page != null) {
                  print('Page changed: $page / $totalPages');
                  setState(() {
                    currentPage = page;
                  });
                  _updateProgress();
                }
              },
              errorBannerBuilder: (context, error, stackTrace, documentRef) {
                print('PDF Error: $error');
                _showErrorDialog();
                return const SizedBox.shrink();
              },
            ),
          ),
          if (!isReady)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      S.of(context).loadingPdf,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          // Яркость overlay
          if (settingsProvider.brightness < 1.0)
            Container(
              color:
                  Colors.black.withOpacity(1.0 - settingsProvider.brightness),
            ),
        ],
      ),
    );
  }

  Widget _buildFileNotFoundError() {
    final s = S.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 100,
            color: Colors.white70,
          ),
          const SizedBox(height: 20),
          Text(
            s.fileNotFound,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.fileNotFoundMessage,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(S s, BookProvider bookProvider) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Прогресс бар
              Row(
                children: [
                  Text(
                    '$currentPage',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: totalPages > 0
                          ? currentPage.clamp(1, totalPages).toDouble()
                          : 1.0,
                      min: 1.0,
                      max: totalPages > 0 ? totalPages.toDouble() : 1.0,
                      onChanged: totalPages > 0
                          ? (value) {
                              _goToPage(value.round());
                            }
                          : null,
                      activeColor: Colors.blue,
                      inactiveColor: Colors.white30,
                    ),
                  ),
                  Text(
                    '$totalPages',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),

              // Кнопки управления
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: currentPage > 1 && totalPages > 0
                          ? () {
                              print('Previous button pressed!');
                              _previousPage();
                            }
                          : null,
                      icon: Icon(
                        Icons.skip_previous,
                        color: currentPage > 1 ? Colors.white : Colors.white30,
                      ),
                      iconSize: 32,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: totalPages > 0
                          ? () {
                              print('Bookmarks button pressed!');
                              _showBookmarksBottomSheet(bookProvider);
                            }
                          : null,
                      icon: const Icon(Icons.bookmarks, color: Colors.white),
                      iconSize: 28,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: totalPages > 0
                          ? () {
                              print('Navigation button pressed!');
                              _showGoToPageDialog();
                            }
                          : null,
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      iconSize: 28,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: totalPages > 0
                          ? () {
                              print('Bookmark toggle pressed!');
                              _toggleBookmark(bookProvider, s);
                            }
                          : null,
                      icon: Icon(
                        bookProvider.hasBookmarkForPage(
                                widget.book.id, currentPage)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: Colors.white,
                      ),
                      iconSize: 28,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: currentPage < totalPages && totalPages > 0
                          ? () {
                              print('Next button pressed!');
                              _nextPage();
                            }
                          : null,
                      icon: Icon(
                        Icons.skip_next,
                        color: currentPage < totalPages
                            ? Colors.white
                            : Colors.white30,
                      ),
                      iconSize: 32,
                    ),
                  ),
                ],
              ),

              // Информация о странице
              Text(
                '${(totalPages > 0 ? (currentPage / totalPages * 100) : 0).toStringAsFixed(1)}% • ${s.page} $currentPage ${s.ofPages} $totalPages',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGestureDetector() {
    return Positioned.fill(
      bottom: showControls ? 120 : 0, // Исключаем область кнопок
      child: GestureDetector(
        onTap: () {
          setState(() {
            showControls = !showControls;
          });
        },
        onDoubleTap: () {
          setState(() {
            isFullscreen = !isFullscreen;
            if (isFullscreen) {
              _hideSystemUI();
            } else {
              _showSystemUI();
            }
          });
        },
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }

  void _previousPage() async {
    print('Previous page clicked. Current: $currentPage, Total: $totalPages');
    if (currentPage > 1 && totalPages > 0) {
      try {
        controller.goToPage(pageNumber: currentPage - 1);
        print('Successfully navigated to page ${currentPage - 1}');
      } catch (e) {
        print('Error navigating to previous page: $e');
      }
    }
  }

  void _nextPage() async {
    print('Next page clicked. Current: $currentPage, Total: $totalPages');
    if (currentPage < totalPages && totalPages > 0) {
      try {
        controller.goToPage(pageNumber: currentPage + 1);
        print('Successfully navigated to page ${currentPage + 1}');
      } catch (e) {
        print('Error navigating to next page: $e');
      }
    }
  }

  void _goToPage(int page) async {
    if (totalPages > 0) {
      final safePage = page.clamp(1, totalPages);
      if (safePage != currentPage) {
        controller.goToPage(pageNumber: safePage);
      }
    }
  }

  void _updateProgress() {
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    bookProvider.updateBookProgress(widget.book.id, currentPage, totalPages);
  }

  void _toggleBookmark(BookProvider bookProvider, S s) async {
    if (bookProvider.hasBookmarkForPage(widget.book.id, currentPage)) {
      final bookmark =
          bookProvider.getBookmarkForPage(widget.book.id, currentPage);
      if (bookmark != null) {
        await bookProvider.removeBookmark(bookmark.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.bookmarkRemoved)),
        );
      }
    } else {
      await bookProvider.addBookmark(
        widget.book.id,
        currentPage,
        '${s.page} $currentPage',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.bookmarkAdded)),
      );
    }
  }

  void _handleMenuAction(String action, BookProvider bookProvider, S s) {
    switch (action) {
      case 'bookmarks':
        _showBookmarksBottomSheet(bookProvider);
        break;
      case 'goto':
        _showGoToPageDialog();
        break;
      case 'share':
        _shareBook();
        break;
      case 'fullscreen':
        setState(() {
          isFullscreen = !isFullscreen;
          if (isFullscreen) {
            _hideSystemUI();
          } else {
            _showSystemUI();
          }
        });
        break;
    }
  }

  void _showBookmarksBottomSheet(BookProvider bookProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => BookmarksBottomSheet(
        bookId: widget.book.id,
        onBookmarkTap: (bookmark) {
          Navigator.pop(context);
          _goToPage(bookmark.pageNumber);
        },
      ),
    );
  }

  void _showGoToPageDialog() {
    final s = S.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.goToPage),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: s.enterPageNumber,
            hintText: '1 - $totalPages',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= totalPages) {
                Navigator.pop(context);
                _goToPage(page);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.invalidPageNumber)),
                );
              }
            },
            child: Text(s.jumpToPage),
          ),
        ],
      ),
    );
  }

  void _shareBook() {
    Share.share(
      'Reading "${widget.book.title}" in JHB Mobile App',
      subject: widget.book.title,
    );
  }

  void _showErrorDialog() {
    final s = S.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.error),
        content: Text(s.pdfLoadError),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(s.ok),
          ),
        ],
      ),
    );
  }
}
