import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../models/chat_user.dart';
import '../../services/chat_service.dart';
import '../../utils/responsive.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<ChatUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await context.read<ChatViewmodel>().listAllUsers();
      if (mounted) setState(() => _users = users);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleRole(ChatUser user) async {
    final newRole = user.isAdmin ? 'member' : 'admin';
    await ChatService.setUserRole(user.uid, newRole);
    await _loadUsers();
    if (mounted) {
      // Refresh own profile in case we changed our own role
      context.read<TaskViewmodel>().refreshProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = Responsive(context);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Manage Users',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text('No other users found',
                      style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView(
                  padding: EdgeInsets.symmetric(vertical: r.s(8)),
                  children: [
                    Container(
                      margin: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(12)),
                      padding: EdgeInsets.all(r.s(14)),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(r.s(14)),
                        border: Border.all(
                            color: cs.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: r.icon(20), color: cs.primary),
                          SizedBox(width: r.s(12)),
                          Expanded(
                            child: Text(
                              'Change user roles below. Admins can assign tasks and manage other users.',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    ..._users.map((user) {
                      final initial = user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?';
                      return Container(
                        margin: EdgeInsets.symmetric(
                            horizontal: r.s(16), vertical: r.s(4)),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(r.s(16)),
                          border: Border.all(
                              color: cs.outline.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(14), vertical: r.s(12)),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: r.s(22),
                                backgroundColor: user.isAdmin
                                    ? cs.tertiary
                                    : cs.primaryContainer,
                                foregroundColor: user.isAdmin
                                    ? cs.onTertiary
                                    : cs.onPrimaryContainer,
                                child: Text(initial,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(user.fullName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(user.email,
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                decoration: BoxDecoration(
                                  color: user.isAdmin
                                      ? cs.tertiaryContainer
                                          .withValues(alpha: 0.6)
                                      : cs.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: user.isAdmin
                                        ? cs.tertiary
                                            .withValues(alpha: 0.4)
                                        : cs.outline
                                            .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: user.isAdmin
                                        ? 'admin'
                                        : 'member',
                                    isDense: true,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    icon: Icon(
                                        Icons
                                            .keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: user.isAdmin
                                            ? cs.onTertiaryContainer
                                            : cs.onSurfaceVariant),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: user.isAdmin
                                          ? cs.onTertiaryContainer
                                          : cs.onSurface,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'member',
                                        child: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Icon(
                                                Icons.person_rounded,
                                                size: 16),
                                            SizedBox(width: 6),
                                            Text('Member'),
                                          ],
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'admin',
                                        child: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Icon(
                                                Icons.shield_rounded,
                                                size: 16),
                                            SizedBox(width: 6),
                                            Text('Admin'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      final currentRole =
                                          user.isAdmin
                                              ? 'admin'
                                              : 'member';
                                      if (value != currentRole) {
                                        _toggleRole(user);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
