import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../providers/book_provider.dart';
import 'sermon_list_item.dart';

class SermonIndexSidebar extends StatefulWidget {
  final Book? selectedBook;
  final Function(Book) onBookSelected;

  const SermonIndexSidebar({
    Key? key,
    this.selectedBook,
    required this.onBookSelected,
  }) : super(key: key);

  @override
  State<SermonIndexSidebar> createState() => _SermonIndexSidebarState();
}

class _SermonIndexSidebarState extends State<SermonIndexSidebar> {
  int _activeTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.7)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.library_books_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sermon Index',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildIconTabs(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search title, date, or location',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: Consumer<BookProvider>(
              builder: (context, provider, child) {
                final query = _searchQuery.toLowerCase().trim();
                final List<Book> books = provider.books.where((b) {
                  if (query.isEmpty) return true;
                  return b.title.toLowerCase().contains(query) ||
                      b.idCode.toLowerCase().contains(query) ||
                      b.location.toLowerCase().contains(query);
                }).toList();

                // Sorting based on active tab
                if (_activeTabIndex == 0) {
                  // Calendar tab: Sort by Sermon Date (idCode)
                  books.sort((a, b) => b.idCode.compareTo(a.idCode));
                } else if (_activeTabIndex == 1) {
                  // A-Z tab: Sort by Sermon Name
                  books.sort((a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()));
                } else if (_activeTabIndex == 2) {
                  // Hourglass tab: Sort by Length (Duration)
                  books.sort((a, b) {
                    // Simple parsing for "TIME: M:SS" or "TIME: HH:MM:SS"
                    String durA = a.duration.replaceAll('TIME: ', '').trim();
                    String durB = b.duration.replaceAll('TIME: ', '').trim();
                    return durB.compareTo(durA); // Longest first
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return SermonListItem(
                      book: book,
                      isSelected: widget.selectedBook?.id == book.id,
                      onTap: () => widget.onBookSelected(book),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconTabs() {
    final colorScheme = Theme.of(context).colorScheme;
    final List<IconData> icons = [
      Icons.calendar_month,
      Icons.sort_by_alpha,
      Icons.hourglass_empty,
      Icons.library_books,
      Icons.public,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(icons.length, (index) {
          final isSelected = _activeTabIndex == index;
          return Tooltip(
            message: 'View ${index + 1}',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _activeTabIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icons[index],
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
