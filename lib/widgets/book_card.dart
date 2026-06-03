import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../generated/l10n.dart';
import '../models/book.dart';
import '../providers/book_provider.dart';
import '../screens/pdf_reader_screen.dart';
import '../screens/sermon_reader_screen.dart';
import '../utils/pdf_thumbnail_generator.dart';

class BookCard extends StatelessWidget {
  final Book book;

  const BookCard({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final s = S.of(context);

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openBook(context),
        onLongPress: () => _showOptions(context, s),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border:
                Border.all(color: colorScheme.outlineVariant.withOpacity(0.7)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer.withOpacity(0.72),
                            colorScheme.secondaryContainer.withOpacity(0.50),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: FutureBuilder<String?>(
                        future: _getThumbnailPath(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                File(snapshot.data!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultPdfIcon(context);
                                },
                              ),
                            );
                          }

                          return _buildDefaultPdfIcon(context);
                        },
                      ),
                    ),
                    if (book.totalPages > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _ProgressPill(progress: book.readingProgress),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildMetaRow(context, s),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 13, color: colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(book.addedDate),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                    fontSize: 11,
                                  ),
                        ),
                      ],
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

  Widget _buildMetaRow(BuildContext context, S s) {
    final colorScheme = Theme.of(context).colorScheme;

    if (book.totalPages > 0) {
      return Row(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              s.readingProgress(
                (book.readingProgress * 100).toStringAsFixed(0),
                book.currentPage,
                book.totalPages,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.fiber_new_outlined,
            size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            s.notStarted,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultPdfIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSermon = book.isPreloaded && book.filePath.isEmpty;

    return Center(
      child: Container(
        width: 72,
        height: 88,
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.primary.withOpacity(0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSermon
                  ? Icons.menu_book_outlined
                  : Icons.picture_as_pdf_outlined,
              size: 34,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Text(
              isSermon ? 'SERMON' : 'PDF',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBook(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => book.isPreloaded
            ? SermonReaderScreen(bookId: book.id)
            : PDFReaderScreen(book: book),
      ),
    );
  }

  void _showOptions(BuildContext context, S s) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.picture_as_pdf_outlined,
                        color: colorScheme.primary),
                  ),
                  title: Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: book.totalPages > 0
                      ? Text('${book.currentPage} of ${book.totalPages} pages')
                      : Text(s.notStarted),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.open_in_new,
                  label: s.openBook,
                  onTap: () {
                    Navigator.pop(context);
                    _openBook(context);
                  },
                ),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Rename',
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameDialog(context);
                  },
                ),
                _ActionTile(
                  icon: Icons.image_outlined,
                  label: 'Change cover',
                  onTap: () {
                    Navigator.pop(context);
                    _pickCustomCover(context);
                  },
                ),
                _ActionTile(
                  icon: Icons.restart_alt,
                  label: 'Reset cover',
                  onTap: () {
                    Navigator.pop(context);
                    _resetToDefaultCover(context);
                  },
                ),
                _ActionTile(
                  icon: Icons.delete_outline,
                  label: s.delete,
                  destructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context, s);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _getThumbnailPath() async {
    if (book.isPreloaded && book.filePath.isEmpty) {
      return null;
    }

    if (book.customCoverPath != null && book.customCoverPath!.isNotEmpty) {
      final file = File(book.customCoverPath!);
      if (await file.exists()) {
        return book.customCoverPath;
      }
    }

    return PDFThumbnailGenerator.generateThumbnail(book.filePath, book.id);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).round()} weeks ago';
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: book.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename book'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Book title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isEmpty) return;

              Provider.of<BookProvider>(context, listen: false)
                  .updateBookTitle(book.id, title);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomCover(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        await Provider.of<BookProvider>(context, listen: false)
            .updateBookCover(book.id, result.files.single.path!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _resetToDefaultCover(BuildContext context) async {
    await Provider.of<BookProvider>(context, listen: false)
        .updateBookCover(book.id, null);
  }

  void _showDeleteConfirmation(BuildContext context, S s) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteBookTitle),
        content: Text(s.deleteBookMessage(book.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<BookProvider>(context, listen: false)
                  .removeBook(book.id);
            },
            child: Text(s.delete),
          ),
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final double progress;

  const _ProgressPill({required this.progress});

  @override
  Widget build(BuildContext context) {
    final color = _progressColor(progress);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '${(progress * 100).round()}',
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Color _progressColor(double progress) {
    if (progress < 0.3) return Colors.red;
    if (progress < 0.7) return Colors.orange;
    if (progress < 1.0) return Colors.blue;
    return Colors.green;
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? Colors.red : Theme.of(context).colorScheme.onSurface;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
