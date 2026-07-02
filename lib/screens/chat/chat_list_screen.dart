import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../models/conversation.dart';
import '../../utils/logout_helper.dart';
import '../../utils/responsive.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatVm = context.watch<ChatViewmodel>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final conversations = chatVm.conversations;
    final r = Responsive(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary,
              cs.primary.withValues(alpha: 0.65),
              cs.surface,
            ],
            stops: const [0.0, 0.2, 0.45],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(r.s(20), r.s(8), r.s(8), r.s(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Messages',
                          style: tt.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: r.fs(26))),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      icon: const Icon(Icons.logout_rounded,
                          color: Colors.white70),
                      onPressed: () => logoutWithAlert(context),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(r.s(28))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(r.s(28))),
                    child: conversations.isEmpty
                        ? _emptyState(context, cs)
                        : _conversationList(
                            context, chatVm, cs, conversations),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'chat_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UserSearchScreen()),
        ),
        icon: const Icon(Icons.edit_square),
        label: const Text('New Chat'),
      ),
    );
  }

  Widget _emptyState(BuildContext context, ColorScheme cs) {
    final r = Responsive(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(r.s(24)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer.withValues(alpha: 0.4),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: r.icon(56), color: cs.primary),
          ),
          SizedBox(height: r.s(16)),
          Text('No conversations yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tap below to start a new message',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _conversationList(BuildContext context, ChatViewmodel chatVm,
      ColorScheme cs, List<Conversation> conversations) {
    final currentUserId = chatVm.currentUserId ?? '';
    final r = Responsive(context);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(88)),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final convo = conversations[index];
        final name = convo.otherParticipantName(currentUserId);
        final unread = convo.unreadCountFor(currentUserId);
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 250 + (index * 30)),
          curve: Curves.easeOut,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
                offset: Offset(0, (1 - v) * 12), child: child),
          ),
          child: Container(
            margin: EdgeInsets.only(bottom: r.s(8)),
            decoration: BoxDecoration(
              color: unread > 0
                  ? cs.primaryContainer.withValues(alpha: 0.25)
                  : cs.surface,
              borderRadius: BorderRadius.circular(r.s(18)),
              border: Border.all(
                  color: unread > 0
                      ? cs.primary.withValues(alpha: 0.2)
                      : cs.outline.withValues(alpha: 0.08)),
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
                  EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(6)),
              leading: CircleAvatar(
                radius: r.s(24),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                child: Text(initial,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: r.fs(18))),
              ),
              title: Text(
                name,
                style: TextStyle(
                  fontWeight:
                      unread > 0 ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              subtitle: convo.lastMessage.isNotEmpty
                  ? Text(
                      convo.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            unread > 0 ? FontWeight.w600 : FontWeight.normal,
                        color: unread > 0
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                    )
                  : null,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (convo.lastMessageTime != null)
                    Text(
                      _formatRelativeTime(convo.lastMessageTime!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            unread > 0 ? FontWeight.w600 : FontWeight.normal,
                        color: unread > 0
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  if (unread > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$unread',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimary)),
                    ),
                  ],
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversationId: convo.id,
                      otherUserName: name,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    }
    return '${time.day}/${time.month}';
  }
}
