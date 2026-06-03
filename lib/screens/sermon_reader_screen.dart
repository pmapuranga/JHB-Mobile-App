import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/sermon.dart';
import '../models/sermon_paragraph.dart';
import '../models/sermon_search_result.dart';
import '../services/sermon_database_service.dart';
import 'home_screen.dart';

class SermonReaderScreen extends StatefulWidget {
  const SermonReaderScreen({
    Key? key,
    required this.bookId,
    this.initialParagraphId,
  }) : super(key: key);

  final String bookId;
  final int? initialParagraphId;

  @override
  State<SermonReaderScreen> createState() => _SermonReaderScreenState();
}

class _SermonReaderScreenState extends State<SermonReaderScreen> {
  Sermon? _sermon;
  List<SermonParagraph> _paragraphs = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _fullscreenMode = false;
  bool _isSearchOpen = false;
  bool _isSearchRunning = false;
  bool _matchWholePhrase = false;
  int _searchScopeIndex = 0;
  int _searchRunId = 0;
  String _searchQuery = '';
  List<SermonSearchResult> _searchResults = [];
  final Map<int, GlobalKey> _paragraphKeys = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  int? _targetParagraphId;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  Map<int, _ParagraphAudioRange> _estimatedParagraphRanges = {};
  bool _isAudioLoading = false;
  String? _loadedAudioAsset;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _bindAudioPlayer();
    _targetParagraphId = widget.initialParagraphId;
    _loadSermon();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SermonReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) {
      setState(() {
        _sermon = null;
        _paragraphs = [];
        _estimatedParagraphRanges = {};
        _isLoading = true;
        _paragraphKeys.clear();
        _targetParagraphId = widget.initialParagraphId;
      });
      _loadSermon();
    } else if (oldWidget.initialParagraphId != widget.initialParagraphId) {
      _targetParagraphId = widget.initialParagraphId;
      _scrollToTargetParagraph();
    }
  }

  Future<void> _loadSermon() async {
    try {
      Sermon? sermon;
      var paragraphs = <SermonParagraph>[];
      final preloaded =
          await SermonDatabaseService.instance.preloadedContentForBookId(
        widget.bookId,
      );

      if (preloaded != null) {
        sermon = preloaded.key;
        paragraphs = preloaded.value;
      } else {
        sermon =
            await SermonDatabaseService.instance.sermonForBookId(widget.bookId);
        paragraphs = sermon == null
            ? <SermonParagraph>[]
            : await SermonDatabaseService.instance
                .paragraphsForSermon(sermon.id);
      }

      if (!mounted) return;
      setState(() {
        _sermon = sermon;
        _paragraphs = paragraphs;
        _estimatedParagraphRanges = _buildEstimatedParagraphRanges(
          paragraphs,
          Duration(seconds: sermon?.durationSeconds ?? 0),
        );
        _isLoading = false;
      });
      unawaited(_loadAudioForSermon(sermon));
      _scrollToTargetParagraph();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sermon = null;
        _paragraphs = [];
        _isLoading = false;
      });
    }
  }

  void _bindAudioPlayer() {
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _audioPosition = position);
      _syncParagraphToAudio(position);
    });
    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() {
        _audioDuration = duration;
        _estimatedParagraphRanges = _buildEstimatedParagraphRanges(
          _paragraphs,
          duration,
        );
      });
    });
    _playerStateSubscription =
        _audioPlayer.playerStateStream.listen((playerState) {
      if (!mounted) return;
      setState(() {
        _isPlaying = playerState.playing;
        _isAudioLoading =
            playerState.processingState == ProcessingState.loading ||
                playerState.processingState == ProcessingState.buffering;
      });
      if (playerState.processingState == ProcessingState.completed) {
        unawaited(_audioPlayer.pause());
        unawaited(_audioPlayer.seek(Duration.zero));
      }
    });
  }

  Future<void> _loadAudioForSermon(Sermon? sermon) async {
    final audioAsset = sermon?.audioFile.trim() ?? '';
    if (audioAsset.isEmpty || audioAsset == _loadedAudioAsset) {
      if (mounted && sermon != null && _audioDuration == Duration.zero) {
        setState(() {
          _audioDuration = Duration(seconds: sermon.durationSeconds);
        });
      }
      return;
    }

    try {
      setState(() {
        _isAudioLoading = true;
        _isPlaying = false;
        _audioPosition = Duration.zero;
        _audioDuration = Duration(seconds: sermon?.durationSeconds ?? 0);
      });
      await _audioPlayer.stop();
      final duration = await _audioPlayer.setAsset(audioAsset);
      if (!mounted) return;
      setState(() {
        _loadedAudioAsset = audioAsset;
        _audioDuration =
            duration ?? Duration(seconds: sermon?.durationSeconds ?? 0);
        _estimatedParagraphRanges = _buildEstimatedParagraphRanges(
          _paragraphs,
          _audioDuration,
        );
        _isAudioLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedAudioAsset = null;
        _isAudioLoading = false;
        _isPlaying = false;
      });
    }
  }

  Future<void> _togglePlayback() async {
    final sermon = _sermon;
    if (sermon == null || sermon.audioFile.trim().isEmpty) {
      _showAudioMessage('Audio not available for this sermon');
      return;
    }

    if (_loadedAudioAsset != sermon.audioFile.trim()) {
      await _loadAudioForSermon(sermon);
    }

    if (_loadedAudioAsset == null) {
      _showAudioMessage('Could not load sermon audio');
      return;
    }

    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _seekBy(Duration offset) async {
    final duration = _effectiveAudioDuration;
    final target = _audioPosition + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > duration
            ? duration
            : target;
    await _audioPlayer.seek(clamped);
  }

  Future<void> _seekToSlider(double seconds) async {
    await _audioPlayer.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  Future<void> _playFromParagraph(SermonParagraph paragraph) async {
    final sermon = _sermon;
    if (sermon == null || sermon.audioFile.trim().isEmpty) {
      _showAudioMessage('Audio not available for this sermon');
      return;
    }

    if (_loadedAudioAsset != sermon.audioFile.trim()) {
      await _loadAudioForSermon(sermon);
    }

    if (_loadedAudioAsset == null) {
      _showAudioMessage('Could not load sermon audio');
      return;
    }

    final targetMs =
        paragraph.startMs ?? _estimatedParagraphRanges[paragraph.id]?.startMs;
    if (targetMs == null) {
      _showAudioMessage('Audio position not available for this paragraph');
      return;
    }

    final durationMs = _effectiveAudioDuration.inMilliseconds;
    final clampedMs = durationMs > 0
        ? targetMs.clamp(0, durationMs).toInt()
        : targetMs.clamp(0, 1 << 31).toInt();
    final position = Duration(milliseconds: clampedMs);

    if (mounted) {
      setState(() {
        _targetParagraphId = paragraph.id;
        _audioPosition = position;
      });
    }
    await _audioPlayer.seek(position);
    await _audioPlayer.play();
  }

  Duration get _effectiveAudioDuration {
    if (_audioDuration > Duration.zero) return _audioDuration;
    return Duration(seconds: _sermon?.durationSeconds ?? 0);
  }

  void _syncParagraphToAudio(Duration position) {
    final current = _paragraphForPosition(position);
    if (current == null || current.id == _targetParagraphId) return;
    setState(() => _targetParagraphId = current.id);
    _scrollToTargetParagraph();
  }

  SermonParagraph? _paragraphForPosition(Duration position) {
    final milliseconds = position.inMilliseconds;
    for (final paragraph in _paragraphs) {
      final start = paragraph.startMs;
      final end = paragraph.endMs;
      if (start == null || end == null) continue;
      if (milliseconds >= start && milliseconds < end) {
        return paragraph;
      }
    }

    if (_estimatedParagraphRanges.isEmpty) return null;
    for (final paragraph in _paragraphs) {
      final range = _estimatedParagraphRanges[paragraph.id];
      if (range == null) continue;
      if (milliseconds >= range.startMs && milliseconds < range.endMs) {
        return paragraph;
      }
    }
    if (milliseconds >= _effectiveAudioDuration.inMilliseconds &&
        _paragraphs.isNotEmpty) {
      return _paragraphs.last;
    }
    return null;
  }

  Map<int, _ParagraphAudioRange> _buildEstimatedParagraphRanges(
    List<SermonParagraph> paragraphs,
    Duration duration,
  ) {
    final totalMs = duration.inMilliseconds;
    if (paragraphs.isEmpty || totalMs <= 0) return {};

    final weights = <int>[];
    var totalWeight = 0;
    for (final paragraph in paragraphs) {
      final weight = paragraph.text.trim().length.clamp(24, 1200).toInt();
      weights.add(weight);
      totalWeight += weight;
    }
    if (totalWeight <= 0) return {};

    final ranges = <int, _ParagraphAudioRange>{};
    var cursor = 0;
    for (var index = 0; index < paragraphs.length; index += 1) {
      final paragraph = paragraphs[index];
      final isLast = index == paragraphs.length - 1;
      final span = isLast
          ? totalMs - cursor
          : (totalMs * (weights[index] / totalWeight)).round();
      final end = isLast
          ? totalMs + 1
          : (cursor + span).clamp(cursor + 1, totalMs).toInt();
      ranges[paragraph.id] = _ParagraphAudioRange(cursor, end);
      cursor = end;
      if (cursor >= totalMs) break;
    }
    return ranges;
  }

  void _showAudioMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _sermon == null
                      ? const Center(
                          child: Text(
                            'Sermon text not found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : _isSearchOpen
                          ? _buildSearchPanel()
                          : _buildReader(),
            ),
            if (!_isSearchOpen) _buildAudioBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 42,
      color: const Color(0xFF202020),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Library',
            icon: const Icon(Icons.menu_book_outlined, color: Colors.white70),
            onPressed: _openSermonListing,
          ),
          IconButton(
            tooltip: _isSearchOpen ? 'Close search' : 'Search',
            icon: Icon(
              _isSearchOpen ? Icons.close : Icons.search,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchQuery = '';
                  _searchResults = [];
                  _isSearchRunning = false;
                }
              });
              if (_isSearchOpen) {
                _runSearch();
              }
            },
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu, color: Colors.white70),
            onPressed: _showReaderMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildReader() {
    final sermon = _sermon!;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF151515),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            '${sermon.code} ${sermon.title.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9F9F9F),
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Text(
                _titleCase(sermon.title),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sermon.code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'serif',
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                sermon.place.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD8D8D8),
                  fontFamily: 'serif',
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 28),
              for (final paragraph in _paragraphs) _buildParagraph(paragraph),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParagraph(SermonParagraph paragraph) {
    final number = paragraph.number.trim();
    final text = paragraph.text.trim();
    final highlighted = paragraph.id == _targetParagraphId;

    return GestureDetector(
      key: _paragraphKeys.putIfAbsent(paragraph.id, GlobalKey.new),
      behavior: HitTestBehavior.translucent,
      onTap: () => unawaited(_playFromParagraph(paragraph)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: highlighted
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : EdgeInsets.zero,
        decoration: highlighted
            ? BoxDecoration(
                color: const Color(0xFF1F3A49),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Color(0xFFF1F1F1),
              fontFamily: 'serif',
              fontSize: 19,
              height: 1.45,
              letterSpacing: 0,
            ),
            children: [
              if (number.isNotEmpty)
                TextSpan(
                  text: '$number ',
                  style: const TextStyle(color: Color(0xFF9B9B9B)),
                ),
              TextSpan(text: text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.cancel,
                              color: Color(0xFFBDBDBD),
                            ),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              _runSearch();
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _runSearch();
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
              : _isSearchRunning
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _searchResults.isEmpty
                      ? const Center(
                          child: Text(
                            'No matches found',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFF252525),
                          ),
                          itemBuilder: (context, index) {
                            return _buildSearchResultRow(
                              _searchResults[index],
                              index,
                            );
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
        _runSearch();
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
          _runSearch();
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
    final heading = [
      result.code,
      result.title,
      if (result.paragraphNumber.isNotEmpty) result.paragraphNumber,
    ].where((part) => part.trim().isNotEmpty).join(' ');

    return Material(
      color: rowColor,
      child: InkWell(
        onTap: () => _openSearchResult(result),
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

  Widget _buildAudioBar() {
    final duration = _effectiveAudioDuration;
    final position = _audioPosition > duration ? duration : _audioPosition;
    final durationSeconds = duration.inMilliseconds / 1000;
    final positionSeconds = position.inMilliseconds / 1000;

    return Container(
      height: 72,
      color: const Color(0xFF242424),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _smallRoundButton('FRN', onTap: () {}),
              _roundIcon(
                Icons.replay_10,
                onTap: () => unawaited(_seekBy(const Duration(seconds: -10))),
              ),
              _playButton(),
              _roundIcon(
                Icons.forward_10,
                onTap: () => unawaited(_seekBy(const Duration(seconds: 10))),
              ),
              _roundIcon(Icons.headset, onTap: () {}),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _durationLabel(position.inSeconds),
                style: const TextStyle(
                  color: Color(0xFFBDBDBD),
                  fontSize: 10,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 0),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 0),
                  ),
                  child: Slider(
                    value: durationSeconds <= 0 ? 0 : positionSeconds,
                    max: durationSeconds <= 0 ? 1 : durationSeconds,
                    onChanged: _loadedAudioAsset == null ? null : _seekToSlider,
                    activeColor: const Color(0xFFBDBDBD),
                    inactiveColor: const Color(0xFF565656),
                  ),
                ),
              ),
              Text(
                _durationLabel(duration.inSeconds),
                style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _durationLabel(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _smallRoundButton(String label, {required VoidCallback onTap}) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: CircleAvatar(
        radius: 15,
        backgroundColor: const Color(0xFFC9C9C9),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFFC9C9C9),
        child: Icon(icon, color: Colors.black, size: 22),
      ),
    );
  }

  Widget _playButton() {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => unawaited(_togglePlayback()),
      child: CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xFFD5D5D5),
        child: _isAudioLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 30,
              ),
      ),
    );
  }

  Future<void> _runSearch() async {
    final query = _searchQuery.trim();
    final runId = ++_searchRunId;

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearchRunning = false;
      });
      return;
    }

    setState(() => _isSearchRunning = true);

    try {
      final results = await SermonDatabaseService.instance.search(
        query: query,
        bookId: _searchScopeIndex == 1 ? widget.bookId : null,
        wholePhrase: _matchWholePhrase,
      );
      if (!mounted || runId != _searchRunId) return;
      setState(() {
        _searchResults = results;
        _isSearchRunning = false;
      });
    } catch (_) {
      if (!mounted || runId != _searchRunId) return;
      setState(() {
        _searchResults = [];
        _isSearchRunning = false;
      });
    }
  }

  void _openSearchResult(SermonSearchResult result) {
    if (result.bookId == widget.bookId) {
      setState(() {
        _isSearchOpen = false;
        _searchQuery = '';
        _searchResults = [];
        _targetParagraphId = result.paragraphId;
      });
      _scrollToTargetParagraph();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SermonReaderScreen(
          bookId: result.bookId,
          initialParagraphId: result.paragraphId,
        ),
      ),
    );
  }

  void _openSermonListing() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _scrollToTargetParagraph() {
    final paragraphId = _targetParagraphId;
    if (paragraphId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _paragraphKeys[paragraphId]?.currentContext;
      if (context == null) return;

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    });
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

  void _showReaderMenu() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.black.withOpacity(0.22),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.white,
            child: SafeArea(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: double.infinity,
                child: _buildReaderMenuContent(context),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.18, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Widget _buildReaderMenuContent(BuildContext dialogContext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 24),
      child: ListView(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close, color: Color(0xFF444444), size: 36),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ),
          const SizedBox(height: 18),
          _menuSectionTitle('Current Sermon'),
          _menuItem('Download Current Sermon', () {
            Navigator.pop(dialogContext);
          }),
          _menuItem('Current Sermon Info & Notes', () {
            Navigator.pop(dialogContext);
          }),
          const SizedBox(height: 36),
          _menuSectionTitle('My Account'),
          _menuItem('Login', () {
            Navigator.pop(dialogContext);
          }),
          _menuItem('Alerts', () {
            Navigator.pop(dialogContext);
          }, hasAlert: true),
          _menuItem('My Highlights', () {
            Navigator.pop(dialogContext);
          }),
          _menuItem('My Notes', () {
            Navigator.pop(dialogContext);
          }),
          _menuItem('Play History', () {
            Navigator.pop(dialogContext);
          }),
          _menuItem('Audio Downloads', () {
            Navigator.pop(dialogContext);
          }),
          const SizedBox(height: 36),
          _menuSectionTitle('Options'),
          _menuItem('Look And Feel', () {
            Navigator.pop(dialogContext);
          }),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fullscreen Mode:',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 25,
                      height: 1.2,
                    ),
                  ),
                ),
                Switch(
                  value: _fullscreenMode,
                  activeColor: const Color(0xFF4A4A4A),
                  onChanged: (value) {
                    setState(() => _fullscreenMode = value);
                    if (value) {
                      SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.immersiveSticky,
                      );
                    } else {
                      SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.edgeToEdge,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuSectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF4B4B4B),
          fontSize: 34,
          fontWeight: FontWeight.w600,
          height: 1.15,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _menuItem(
    String label,
    VoidCallback onTap, {
    bool hasAlert = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (hasAlert) ...[
              Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                  color: Color(0xFFE73445),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF606060),
                  fontSize: 24,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
      if (word.length == 1) return word.toUpperCase();
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}

class _ParagraphAudioRange {
  const _ParagraphAudioRange(this.startMs, this.endMs);

  final int startMs;
  final int endMs;
}
