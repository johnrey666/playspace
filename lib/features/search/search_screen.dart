import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../shared/models/game_catalog.dart';
import '../../shared/models/post_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../games/game_lobby_screen.dart';
import '../profile/profile_screen.dart';

/// Global search across people, posts and games. Opened from the home search
/// bar. Tapping a person opens their full profile (details + recent posts).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  String _query = '';
  bool _loading = false;
  List<UserModel> _people = [];
  List<PostModel> _posts = [];
  final Map<String, UserModel> _postAuthors = {};
  List<GameInfo> _games = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => _run(value));
  }

  Future<void> _run(String value) async {
    final q = value.trim();
    setState(() => _query = q);
    if (q.isEmpty) {
      setState(() {
        _people = [];
        _posts = [];
        _games = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);

    // Games are matched locally and instantly.
    final lower = q.toLowerCase();
    final games = GameCatalog.all
        .where((g) =>
            g.name.toLowerCase().contains(lower) ||
            g.description.toLowerCase().contains(lower))
        .toList();

    final fs = context.read<FirestoreService>();
    try {
      final people = await fs.searchUsers(q);
      final posts = await fs.searchPosts(q);
      final authorIds =
          posts.map((p) => p.uid).toSet().toList(growable: false);
      final authors = await fs.getUsers(authorIds);
      if (!mounted) return;
      setState(() {
        _people = people;
        _posts = posts;
        _games = games;
        _postAuthors
          ..clear()
          ..addEntries(authors.map((u) => MapEntry(u.uid, u)));
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _games = games;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasResults =
        _people.isNotEmpty || _posts.isNotEmpty || _games.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search people, posts, games',
            border: InputBorder.none,
            filled: false,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      _run('');
                      _focus.requestFocus();
                    },
                  ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? _Hint(colors: colors)
              : !hasResults
                  ? _Hint(colors: colors, empty: true, query: _query)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        if (_people.isNotEmpty) ...[
                          const _SectionLabel('People'),
                          ..._people.map(_personTile),
                          const SizedBox(height: 16),
                        ],
                        if (_games.isNotEmpty) ...[
                          const _SectionLabel('Games'),
                          ..._games.map(_gameTile),
                          const SizedBox(height: 16),
                        ],
                        if (_posts.isNotEmpty) ...[
                          const _SectionLabel('Posts'),
                          ..._posts.map(_postTile),
                        ],
                      ],
                    ),
    );
  }

  Widget _personTile(UserModel u) {
    final myUid = context.read<AuthProvider>().uid;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: AvatarWidget(
          photoUrl: u.photoUrl,
          displayName: u.displayName,
          isOnline: u.isPresent,
        ),
        title: Text(u.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('@${u.username}'),
        trailing: u.uid == myUid
            ? const Text('You')
            : const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(uid: u.uid),
        )),
      ),
    );
  }

  Widget _gameTile(GameInfo g) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: g.colors),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(g.icon, color: Colors.white),
        ),
        title:
            Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(g.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GameLobbyScreen(game: g),
        )),
      ),
    );
  }

  Widget _postTile(PostModel p) {
    final author = _postAuthors[p.uid];
    final preview = p.text.isEmpty ? '(photo)' : p.text;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: p.hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SmartImage(src: p.imageUrl, width: 46, height: 46),
              )
            : AvatarWidget(
                photoUrl: author?.photoUrl,
                displayName: author?.displayName ?? '',
                size: 46,
              ),
        title: Text(author?.displayName ?? 'Player',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$preview · ${timeago.format(p.createdAt)}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(uid: p.uid),
        )),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.colors, this.empty = false, this.query = ''});
  final ColorScheme colors;
  final bool empty;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(empty ? Icons.search_off_rounded : Icons.search_rounded,
                size: 56, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              empty
                  ? 'No results for "$query"'
                  : 'Search for friends, posts and games',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
