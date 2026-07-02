import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../models/chat_user.dart';
import '../../utils/responsive.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  List<ChatUser> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(query);
    });
  }

  Future<void> _loadAllUsers() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await context.read<ChatViewmodel>().listAllUsers();
      if (mounted) {
        setState(() {
          _results = results;
          _searched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searched = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadAllUsers();
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results =
          await context.read<ChatViewmodel>().searchUsers(query);
      if (mounted) {
        setState(() {
          _results = results;
          _searched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searched = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startConversation(ChatUser user) async {
    final chatVm = context.read<ChatViewmodel>();
    final conversationId = await chatVm.startConversation(user);
    if (conversationId != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserName: user.displayName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = Responsive(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('New Message',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      body: Container(
        color: cs.surface,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(4)),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(r.s(16)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon:
                        Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(14)),
                  ),
                ),
              ),
            ),
            if (_loading)
              LinearProgressIndicator(
                backgroundColor: cs.primaryContainer.withValues(alpha: 0.3),
              ),

            Expanded(
              child: _errorMessage != null
                  ? _errorState(cs)
                  : _results.isEmpty
                      ? _emptyState(cs)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final user = _results[index];
                            return _UserTile(
                              user: user,
                              onTap: () => _startConversation(user),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.errorContainer.withValues(alpha: 0.3),
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 40, color: cs.error),
            ),
            const SizedBox(height: 16),
            Text('Search failed',
                style: TextStyle(
                    color: cs.error, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _searched
                ? Icons.person_off_outlined
                : Icons.person_search_outlined,
            size: 48,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            _searched
                ? 'No users found'
                : 'Search for users to start a conversation',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});
  final ChatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = Responsive(context);
    final initial =
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(4)),
        leading: CircleAvatar(
          radius: r.s(22),
          backgroundColor: cs.primaryContainer,
          child: Text(initial,
              style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600)),
        ),
        title: Text(user.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(user.email,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
