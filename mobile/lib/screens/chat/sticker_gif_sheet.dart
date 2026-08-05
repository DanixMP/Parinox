import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Result from the sticker / GIF picker sheet.
sealed class StickerGifPick {}

class StickerPick extends StickerGifPick {
  StickerPick(this.emoji);
  final String emoji;
}

class GifUrlPick extends StickerGifPick {
  GifUrlPick({required this.url, required this.title});
  final String url;
  final String title;
}

/// Bottom sheet: Stickers (emoji packs) + GIFs (Giphy search / curated).
Future<StickerGifPick?> showStickerGifSheet(BuildContext context) {
  return showModalBottomSheet<StickerGifPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => const _StickerGifSheet(),
  );
}

class _StickerGifSheet extends StatefulWidget {
  const _StickerGifSheet();

  @override
  State<_StickerGifSheet> createState() => _StickerGifSheetState();
}

class _StickerGifSheetState extends State<_StickerGifSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _gifQuery = TextEditingController();
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  List<_GifItem> _gifs = _fallbackGifs;
  bool _gifLoading = false;
  String? _gifError;

  static const _packs = <_StickerPack>[
    _StickerPack('Smileys', [
      '😀', '😂', '🤣', '😊', '😍', '🥰', '😘', '😎', '🤔', '😴', '😭', '😤',
      '🥳', '🤯', '😇', '🤗', '😏', '🥺', '😩', '🫡', '🫠', '🫢',
    ]),
    _StickerPack('Gestures', [
      '👍', '👎', '👏', '🙌', '🤝', '✌️', '🤞', '🤟', '👋', '🤙', '💪', '🙏',
      '👀', '💯', '🔥', '✨', '💫', '⭐', '❤️', '💔', '🖤', '💜',
    ]),
    _StickerPack('Animals', [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮',
      '🐷', '🐸', '🐵', '🦄', '🐝', '🦋', '🐢', '🐙', '🦉', '🐧',
    ]),
    _StickerPack('Fun', [
      '🎉', '🎊', '🎈', '🎁', '🏆', '🎮', '🎵', '🎬', '🍕', '🍔', '☕', '🍩',
      '🌈', '☀️', '🌙', '⚡', '🌸', '🌹', '🍀', '🎂', '🚀', '✈️',
    ]),
  ];

  static const _fallbackGifs = <_GifItem>[
    _GifItem(
      title: 'Yes',
      url: 'https://media0.giphy.com/media/111ebonMs90YLu/giphy.gif',
    ),
    _GifItem(
      title: 'Clap',
      url: 'https://media1.giphy.com/media/7rj2ZgttXUyu4/giphy.gif',
    ),
    _GifItem(
      title: 'Dance',
      url: 'https://media2.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
    ),
    _GifItem(
      title: 'Wow',
      url: 'https://media3.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif',
    ),
    _GifItem(
      title: 'Love',
      url: 'https://media0.giphy.com/media/l0HlvtIPzPdt2usKs/giphy.gif',
    ),
    _GifItem(
      title: 'Lol',
      url: 'https://media1.giphy.com/media/10JhviFuU2gWD6/giphy.gif',
    ),
    _GifItem(
      title: 'Hi',
      url: 'https://media2.giphy.com/media/xT9IgG50Fb7Mi0prBC/giphy.gif',
    ),
    _GifItem(
      title: 'OK',
      url: 'https://media3.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchGifs('');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _gifQuery.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  Future<void> _searchGifs(String query) async {
    setState(() {
      _gifLoading = true;
      _gifError = null;
    });
    try {
      final giphyKey = const String.fromEnvironment(
        'GIPHY_API_KEY',
        defaultValue: 'dc6zaTOxFJmzC',
      );
      final path = query.trim().isEmpty ? 'trending' : 'search';
      final res = await _dio.get<Map<String, dynamic>>(
        'https://api.giphy.com/v1/gifs/$path',
        queryParameters: {
          'api_key': giphyKey,
          'limit': 24,
          'rating': 'g',
          if (query.trim().isNotEmpty) 'q': query.trim(),
        },
      );
      final list = (res.data?['data'] as List?) ?? const [];
      final items = <_GifItem>[];
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final images = m['images'] as Map<String, dynamic>?;
        final fixed = images?['fixed_height'] as Map<String, dynamic>?;
        final original = images?['original'] as Map<String, dynamic>?;
        final url = (fixed?['url'] ?? original?['url']) as String?;
        if (url == null || url.isEmpty) continue;
        final title = (m['title'] as String?)?.trim();
        items.add(_GifItem(title: (title == null || title.isEmpty) ? 'GIF' : title, url: url));
      }
      if (!mounted) return;
      setState(() {
        _gifs = items.isEmpty ? _fallbackGifs : items;
        _gifLoading = false;
        if (items.isEmpty) _gifError = 'Showing saved GIFs';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gifs = _fallbackGifs;
        _gifLoading = false;
        _gifError = 'Showing saved GIFs';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.62;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: cs.onSurface,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: cs.primary,
            tabs: const [
              Tab(text: 'Stickers'),
              Tab(text: 'GIFs'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: _packs.length,
                  itemBuilder: (context, i) {
                    final pack = _packs[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                          child: Text(
                            pack.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pack.emojis.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                          itemBuilder: (context, j) {
                            final e = pack.emojis[j];
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.pop(context, StickerPick(e)),
                              child: Center(
                                child: Text(e, style: const TextStyle(fontSize: 32)),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: TextField(
                        controller: _gifQuery,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _searchGifs,
                        decoration: InputDecoration(
                          hintText: 'Search GIFs',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Search',
                            onPressed: () => _searchGifs(_gifQuery.text),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (_gifError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _gifError!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ),
                    Expanded(
                      child: _gifLoading
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                              itemCount: _gifs.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1.2,
                              ),
                              itemBuilder: (context, i) {
                                final g = _gifs[i];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.pop(
                                    context,
                                    GifUrlPick(url: g.url, title: g.title),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ColoredBox(
                                      color: cs.surfaceContainerHighest,
                                      child: CachedNetworkImage(
                                        imageUrl: g.url,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => const Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickerPack {
  const _StickerPack(this.name, this.emojis);
  final String name;
  final List<String> emojis;
}

class _GifItem {
  const _GifItem({required this.title, required this.url});
  final String title;
  final String url;
}

/// True when a text message should render as a large sticker-like emoji.
bool isStickerLikeMessage(String? content) {
  if (content == null) return false;
  final t = content.trim();
  if (t.isEmpty) return false;
  if (t.runes.length > 4) return false;
  return !RegExp(r'[A-Za-z0-9]').hasMatch(t);
}
