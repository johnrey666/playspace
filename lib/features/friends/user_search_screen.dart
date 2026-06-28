import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../profile/profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserModel> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final fs = context.read<FirestoreService>();
      final res = await fs.searchByUsername(value);
      if (mounted) {
        setState(() {
          _results = res;
          _loading = false;
          _searched = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AuthProvider>().uid;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search by username',
            border: InputBorder.none,
            filled: false,
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_searched && _results.isEmpty)
              ? const EmptyStateWidget(
                  message: 'No users found.',
                  icon: Icons.search_off_rounded)
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final u = _results[i];
                    return ListTile(
                      leading: AvatarWidget(
                        photoUrl: u.photoUrl,
                        displayName: u.displayName,
                        isOnline: u.isOnline,
                      ),
                      title: Text(u.displayName),
                      subtitle: Text('@${u.username}'),
                      trailing: u.uid == myUid ? const Text('You') : null,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProfileScreen(uid: u.uid),
                      )),
                    );
                  },
                ),
    );
  }
}
