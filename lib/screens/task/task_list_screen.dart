import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../services/chat_service.dart';
import '../../services/quotes_service.dart';
import '../../services/storage_service.dart';
import '../../models/task.dart';
import '../../utils/logout_helper.dart';
import '../../utils/responsive.dart';
import '../task/assign_task_screen.dart';
import '../admin/manage_users_screen.dart';
import '../common/full_screen_image_viewer.dart';

enum _TaskFilter { total, done, pending, testing }

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  _TaskFilter _filter = _TaskFilter.total;

  Future<void> _openTaskEditor(
    BuildContext context,
    TaskViewmodel viewModel, {
    Task? task,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskEditorSheet(viewModel: viewModel, task: task),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskViewmodel viewModel,
    Task task,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.delete_outline_rounded, color: cs.error, size: 32),
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (shouldDelete == true) {
      viewModel.deleteTask(task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Task deleted')));
      }
    }
  }

  Future<void> _showQuoteDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final quote = await QuotesService.fetchQuote(
          categories: const ['success', 'courage']);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          icon: const Icon(Icons.auto_awesome_rounded),
          title: const Text('Quote of the Day'),
          content:
              Text(quote, style: const TextStyle(fontStyle: FontStyle.italic)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Nice!'))
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskViewmodel>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = Responsive(context);
    final tasks = vm.tasks;
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final doneTasks = tasks.where((t) => t.isCompleted).toList();
    final pendingTasks = tasks
        .where((t) => !t.isCompleted && t.status == TaskStatus.todo)
        .toList();
    final testingTasks = tasks
      .where((t) => !t.isCompleted && t.status == TaskStatus.testing)
      .toList();

    final displayedTasks = switch (_filter) {
      _TaskFilter.total => activeTasks,
      _TaskFilter.done => doneTasks,
      _TaskFilter.pending => pendingTasks,
      _TaskFilter.testing => testingTasks,
    };

    final emptyLabel = switch (_filter) {
      _TaskFilter.total => 'No active tasks yet',
      _TaskFilter.done => 'No completed tasks yet',
      _TaskFilter.pending => 'No pending tasks yet',
      _TaskFilter.testing => 'No testing tasks yet',
    };

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.primary, cs.primary.withValues(alpha: 0.65), cs.surface],
            stops: const [0.0, 0.22, 0.48],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(r.s(20), r.s(8), r.s(8), 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text('My Tasks',
                                overflow: TextOverflow.ellipsis,
                                style: tt.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: r.fs(26))),
                          ),
                          if (vm.isAdmin) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Admin',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (vm.isAdmin)
                      PopupMenuButton<String>(
                        tooltip: 'Admin actions',
                        icon: const Icon(Icons.admin_panel_settings_rounded,
                            color: Colors.white),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        offset: const Offset(0, 44),
                        onSelected: (value) {
                          switch (value) {
                            case 'assign':
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const AssignTaskScreen()));
                              break;
                            case 'manage':
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const ManageUsersScreen()));
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'assign',
                            child: Row(
                              children: [
                                Icon(Icons.person_add_alt_1_rounded,
                                    size: 20, color: cs.primary),
                                const SizedBox(width: 12),
                                const Text('Assign Task',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'manage',
                            child: Row(
                              children: [
                                Icon(Icons.group_rounded,
                                    size: 20, color: cs.primary),
                                const SizedBox(width: 12),
                                const Text('Manage Users',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    IconButton(
                      tooltip: 'Add task',
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          color: Colors.white),
                      onPressed: () => _openTaskEditor(context, vm),
                    ),
                    IconButton(
                      tooltip: vm.isAdmin
                          ? 'Switch to Member (testing)'
                          : 'Switch to Admin (testing)',
                      icon: Icon(
                        vm.isAdmin
                            ? Icons.shield_rounded
                            : Icons.shield_outlined,
                        color: vm.isAdmin
                            ? Colors.amberAccent
                            : Colors.white70,
                      ),
                      onPressed: () async {
                        final userId = vm.currentUserId;
                        if (userId == null) return;
                        final newRole =
                            vm.isAdmin ? 'member' : 'admin';
                        await ChatService.setUserRole(
                            userId, newRole);
                        await vm.refreshProfile();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(
                                'Switched to ${newRole == 'admin' ? 'Admin' : 'Member'}'),
                            duration:
                                const Duration(seconds: 1),
                          ));
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Quote of the day',
                      icon: const Icon(Icons.auto_awesome,
                          color: Colors.white70),
                      onPressed: () => _showQuoteDialog(context),
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

              Padding(
                padding: EdgeInsets.only(top: r.s(10), bottom: r.s(16)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.symmetric(horizontal: r.s(20)),
                  child: Row(
                    children: [
                      _StatChip(
                        Icons.format_list_numbered_rounded,
                        '${activeTasks.length}',
                        'Total',
                        selected: _filter == _TaskFilter.total,
                        onTap: () =>
                            setState(() => _filter = _TaskFilter.total),
                      ),
                      SizedBox(width: r.s(10)),
                      _StatChip(
                        Icons.check_circle_outline,
                        '${doneTasks.length}',
                        'Done',
                        selected: _filter == _TaskFilter.done,
                        onTap: () =>
                            setState(() => _filter = _TaskFilter.done),
                      ),
                      SizedBox(width: r.s(10)),
                      _StatChip(
                        Icons.pending_actions_rounded,
                        '${pendingTasks.length}',
                        'Pending',
                        selected: _filter == _TaskFilter.pending,
                        onTap: () =>
                            setState(() => _filter = _TaskFilter.pending),
                      ),
                      SizedBox(width: r.s(10)),
                      _StatChip(
                        Icons.science_outlined,
                        '${testingTasks.length}',
                        'Testing',
                        selected: _filter == _TaskFilter.testing,
                        onTap: () =>
                            setState(() => _filter = _TaskFilter.testing),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
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
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        const TaskQuoteCard(),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: displayedTasks.isEmpty
                                ? _emptyState(context, cs, label: emptyLabel)
                                : _taskList(context, vm, cs, displayedTasks,
                                    key: ValueKey('list_${_filter.name}')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, ColorScheme cs,
      {required String label}) {
    return Center(
      key: const ValueKey('empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer.withValues(alpha: 0.4),
            ),
            child: Icon(Icons.task_alt_rounded, size: 56, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tap + to add your first task',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _taskList(BuildContext context, TaskViewmodel vm, ColorScheme cs,
      List<Task> tasks,
      {Key? key}) {
    final r = Responsive(context);
    return ListView.builder(
      key: key ?? const ValueKey('list'),
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(4), r.s(16), r.s(88)),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 40)),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child:
                Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
          ),
          child: _ExpandableTaskItem(
            task: task,
            vm: vm,
            isAdmin: vm.isAdmin,
            onEdit: () => _openTaskEditor(context, vm, task: task),
            onDelete: () => _confirmDelete(context, vm, task),
          ),
        );
      },
    );
  }
}

class _ExpandableTaskItem extends StatefulWidget {
  final Task task;
  final TaskViewmodel vm;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpandableTaskItem({
    required this.task,
    required this.vm,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ExpandableTaskItem> createState() => _ExpandableTaskItemState();
}

class _ExpandableTaskItemState extends State<_ExpandableTaskItem>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  final _commentCtrl = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _imagePicker = ImagePicker();
  bool _isUploadingPhoto = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAndAttachPhoto() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1920,
    );
    if (file == null) return;
    final userId = widget.vm.currentUserId;
    if (userId == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await StorageService.uploadFile(
        file: File(file.path),
        folder: 'task_attachments',
        userId: userId,
        ext: '.jpg',
      );
      if (mounted) setState(() => _isUploadingPhoto = false);

      if (url != null && mounted) {
        final text = _commentCtrl.text.trim();
        await widget.vm.addComment(widget.task.id, text.isEmpty ? '' : text, imageUrl: url);
        if (mounted) _commentCtrl.clear();
      }
    } catch (e) {
      debugPrint('Task photo attach error: $e');
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case TaskStatus.todo:
        return cs.outline;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.testing:
        return Colors.orange;
      case TaskStatus.complete:
        return Colors.green;
      default:
        return cs.outline;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case TaskStatus.todo:
        return Icons.circle_outlined;
      case TaskStatus.inProgress:
        return Icons.play_circle_outline_rounded;
      case TaskStatus.testing:
        return Icons.bug_report_outlined;
      case TaskStatus.complete:
        return Icons.check_circle_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = Responsive(context);
    final task = widget.task;
    final vm = widget.vm;
    final sColor = _statusColor(task.status, cs);

    return Container(
      margin: EdgeInsets.only(bottom: r.s(10)),
      decoration: BoxDecoration(
        color: task.isCompleted
            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
            : cs.surface,
        borderRadius: BorderRadius.circular(r.s(18)),
        border: Border.all(
            color: _expanded
                ? sColor.withValues(alpha: 0.4)
                : cs.outline.withValues(alpha: task.isCompleted ? 0.12 : 0.08)),
        boxShadow: task.isCompleted
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(r.s(18)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: r.s(4)),
                    child: Icon(
                      _statusIcon(task.status),
                      size: r.icon(22),
                      color: sColor,
                    ),
                  ),
                  SizedBox(width: r.s(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? cs.onSurface.withValues(alpha: 0.5)
                                : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topLeft,
                          child: Text(
                            task.description,
                            maxLines: _expanded ? 10 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: task.isCompleted
                                  ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (task.isAssigned) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                task.assignedTo == vm.currentUserId
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 13,
                                color: cs.tertiary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  task.assignedTo == vm.currentUserId
                                      ? 'Assigned by ${task.assignedByName ?? 'admin'}'
                                      : 'Assigned to ${task.assignedToName ?? 'user'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: cs.tertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _TaskTag(
                              label: TaskStatus.label(task.status),
                              color: sColor,
                              icon: _statusIcon(task.status),
                            ),
                            if (task.priority == 'important')
                              _TaskTag(
                                label: 'Important',
                                color: Colors.redAccent,
                                icon: Icons.priority_high_rounded,
                              ),
                            _TaskTag(
                              label: task.difficulty[0].toUpperCase() +
                                  task.difficulty.substring(1),
                              color: task.difficulty == 'easy'
                                  ? Colors.green
                                  : task.difficulty == 'medium'
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                            if (task.deadline != null)
                              _TaskTag(
                                label:
                                    DateFormat('MMM d').format(task.deadline!),
                                color: task.isOverdue ? Colors.red : cs.primary,
                                icon: Icons.schedule_rounded,
                              ),
                            if (task.estimatedMinutes != null)
                              _TaskTag(
                                label: task.estimatedDurationLabel,
                                color: cs.secondary,
                                icon: Icons.timer_outlined,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isAdmin)
                        PopupMenuButton<String>(
                          tooltip: 'Task actions',
                          icon: Icon(Icons.more_vert_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          offset: const Offset(0, 40),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) {
                            if (value == 'edit') widget.onEdit();
                            if (value == 'delete') widget.onDelete();
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 18, color: cs.primary),
                                  const SizedBox(width: 10),
                                  const Text('Edit Task',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded,
                                      size: 18, color: cs.error),
                                  const SizedBox(width: 10),
                                  Text('Delete Task',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: cs.error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // AnimatedCrossFade can briefly clip/squash complex children (like
          // shadows). AnimatedSize gives a smoother expand/collapse.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _expanded ? 1 : 0,
                child: _buildExpandedContent(cs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(ColorScheme cs) {
    final task = widget.task;
    final vm = widget.vm;
    final r = Responsive(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(14), 0, r.s(14), r.s(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: cs.outline.withValues(alpha: 0.12), height: 1),
          SizedBox(height: r.s(12)),
          Text('Status',
              style: TextStyle(
                fontSize: r.fs(12),
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              )),
          SizedBox(height: r.s(8)),
          Row(
            children: TaskStatus.values.map((status) {
              final isSelected = task.status == status;
              final color = _statusColor(status, cs);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.s(2)),
                  child: GestureDetector(
                    onTap: () => vm.updateTaskStatus(task.id, status),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(vertical: r.s(8)),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : cs.outline.withValues(alpha: 0.2),
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(_statusIcon(status),
                              size: r.icon(18), color: color),
                          SizedBox(height: r.s(2)),
                          Text(
                            TaskStatus.label(status),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.fs(9),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: r.s(16)),
          Row(
            children: [
              Text('Comments',
                  style: TextStyle(
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  )),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear comments'),
                      content: const Text(
                          'Delete all comments on this task? This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    vm.clearComments(task.id);
                  }
                },
                icon: Icon(Icons.delete_sweep_rounded,
                    size: 16, color: cs.error),
                label: Text('Clear',
                    style: TextStyle(fontSize: 11, color: cs.error)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(8)),

          StreamBuilder<List<TaskComment>>(
            stream: vm.commentsStream(task.id),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];
              if (comments.isEmpty) {
                return Padding(
                  padding: EdgeInsets.only(bottom: r.s(8)),
                  child: Text(
                    'No comments yet.',
                    style: TextStyle(
                      fontSize: r.fs(12),
                      fontStyle: FontStyle.italic,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: r.s(200)),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: comments.length,
                  itemBuilder: (context, i) {
                    final c = comments[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                cs.primaryContainer.withValues(alpha: 0.6),
                            child: Text(
                              c.authorName.isNotEmpty
                                  ? c.authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.authorName.isNotEmpty
                                          ? c.authorName
                                          : 'Unknown',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatCommentTime(c.createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: cs.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                if (c.text.isNotEmpty) ...[                                
                                  const SizedBox(height: 2),
                                  Text(
                                    c.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ],
                                if (c.imageUrl != null && c.imageUrl!.isNotEmpty) ...[                          
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FullScreenImageViewer(
                                          imageUrl: c.imageUrl!,
                                        ),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: c.imageUrl!,
                                        width: 180,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          width: 180, height: 120,
                                          color: cs.surfaceContainerHighest,
                                          child: const Center(
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          width: 180, height: 80,
                                          color: cs.errorContainer,
                                          child: Icon(Icons.broken_image_rounded,
                                              color: cs.onErrorContainer),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),

          if (_isUploadingPhoto)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary),
                  ),
                  const SizedBox(width: 8),
                  Text('Uploading photo…',
                      style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),

          Row(
            children: [
              IconButton(
                onPressed: _isUploadingPhoto ? null : _pickAndAttachPhoto,
                icon: Icon(Icons.image_rounded,
                    color: cs.primary, size: r.icon(20)),
                tooltip: 'Attach image',
                style: IconButton.styleFrom(
                  backgroundColor: cs.primaryContainer.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(10))),
                  padding: EdgeInsets.all(r.s(8)),
                  minimumSize: Size(r.s(36), r.s(36)),
                ),
              ),
              SizedBox(width: r.s(6)),
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  focusNode: _commentFocusNode,
                  style: TextStyle(fontSize: r.fs(13)),
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    hintStyle: TextStyle(
                      fontSize: r.fs(13),
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.s(14), vertical: r.s(10)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.s(14)),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
              SizedBox(width: r.s(6)),
              IconButton(
                onPressed: _sendComment,
                icon: Icon(Icons.send_rounded, color: cs.primary, size: r.icon(20)),
                style: IconButton.styleFrom(
                  backgroundColor: cs.primaryContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(12))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    widget.vm.addComment(widget.task.id, text);
    _commentCtrl.clear();
    _commentFocusNode.requestFocus();
  }

  String _formatCommentTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String caption;
  final bool selected;
  final VoidCallback? onTap;
  const _StatChip(this.icon, this.value, this.caption,
      {this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.s(14)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(10)),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.26 : 0.15),
          borderRadius: BorderRadius.circular(r.s(14)),
          border: selected
              ? Border.all(color: Colors.white.withValues(alpha: 0.55))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: r.icon(18), color: selected ? Colors.white : Colors.white70),
            SizedBox(width: r.s(6)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: r.fs(16))),
                Text(caption,
                    style: TextStyle(
                        color: Colors.white.withValues(
                            alpha: selected ? 0.85 : 0.60),
                        fontSize: r.fs(11))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TaskActionMenu extends StatefulWidget {
  const TaskActionMenu({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  State<TaskActionMenu> createState() => _TaskActionMenuState();
}

class _TaskActionMenuState extends State<TaskActionMenu> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: _expanded ? 88 : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _expanded ? 1 : 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: Icon(Icons.edit_outlined,
                        color: cs.primary, size: 20),
                    onPressed: () {
                      setState(() => _expanded = false);
                      widget.onEdit();
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline,
                        color: cs.error, size: 20),
                    onPressed: () {
                      setState(() => _expanded = false);
                      widget.onDelete();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: _expanded ? 'Close' : 'Actions',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              _expanded ? Icons.close_rounded : Icons.more_horiz_rounded,
              key: ValueKey(_expanded),
              size: 22,
            ),
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
      ],
    );
  }
}

class TaskQuoteCard extends StatefulWidget {
  const TaskQuoteCard({super.key});
  @override
  State<TaskQuoteCard> createState() => _TaskQuoteCardState();
}

class _TaskQuoteCardState extends State<TaskQuoteCard> {
  bool _loading = true;
  String? _quote;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quote = await QuotesService.fetchQuote(
          categories: const ['success', 'courage']);
      if (!mounted) return;
      setState(() => _quote = quote);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final msg = e.toString().replaceFirst('Exception: ', '');
        _error = msg.isEmpty ? 'Could not load quote.' : msg;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = Responsive(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(6)),
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(14), r.s(8), r.s(12)),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          cs.primaryContainer.withValues(alpha: 0.35),
          cs.secondaryContainer.withValues(alpha: 0.2),
        ]),
        borderRadius: BorderRadius.circular(r.s(18)),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, color: cs.primary, size: r.icon(22)),
          SizedBox(width: r.s(10)),
          Expanded(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Text(
                    _error ?? _quote ?? 'No quote available.',
                    style: TextStyle(
                      color: _error != null ? cs.error : cs.onSurface,
                      fontStyle:
                          _error == null ? FontStyle.italic : FontStyle.normal,
                      fontSize: 13,
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Refresh quote',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loading ? null : _loadQuote,
          ),
        ],
      ),
    );
  }
}

class _TaskTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _TaskTag({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(7), vertical: r.s(2)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(r.s(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _TaskEditorSheet extends StatefulWidget {
  final TaskViewmodel viewModel;
  final Task? task;
  const _TaskEditorSheet({required this.viewModel, this.task});

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  final _formKey = GlobalKey<FormState>();

  late String _priority;
  late String _difficulty;
  DateTime? _deadline;
  int? _estimatedMinutes;

  static const _durOptions = <int?>[null, 15, 30, 60, 120, 240, 480];
  static const _durLabels = ['None', '15m', '30m', '1h', '2h', '4h', '8h'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task?.title ?? '');
    _descCtrl = TextEditingController(text: widget.task?.description ?? '');
    _priority = widget.task?.priority ?? 'normal';
    _difficulty = widget.task?.difficulty ?? 'easy';
    _deadline = widget.task?.deadline;
    _estimatedMinutes = widget.task?.estimatedMinutes;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? now),
    );
    setState(() {
      _deadline = DateTime(
        picked.year, picked.month, picked.day,
        time?.hour ?? 23, time?.minute ?? 59,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (widget.task == null) {
      widget.viewModel.addTask(
        title, desc,
        deadline: _deadline,
        estimatedMinutes: _estimatedMinutes,
        priority: _priority,
        difficulty: _difficulty,
      );
    } else {
      widget.viewModel.updateTask(
        id: widget.task!.id,
        title: title,
        description: desc,
        deadline: _deadline,
        estimatedMinutes: _estimatedMinutes,
        priority: _priority,
        difficulty: _difficulty,
      );
    }
    Navigator.of(context).pop();
  }

  Widget _tagChip(String label, bool selected, Color color,
      {IconData? icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3),
              width: selected ? 1.6 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isNew = widget.task == null;
    final r = Responsive(context);

    return Container(
      padding: EdgeInsets.fromLTRB(r.s(24), 0, r.s(24), bottomInset + r.s(24)),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(28))),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: r.s(40), height: r.s(4),
                  margin: EdgeInsets.symmetric(vertical: r.s(14)),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(isNew ? 'New Task' : 'Edit Task',
                  style: tt.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor:
                      cs.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                minLines: 2, maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 28),
                    child: Icon(Icons.notes_rounded),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor:
                      cs.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDeadline,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          color: cs.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _deadline != null
                              ? DateFormat('MMM d, yyyy – h:mm a')
                                  .format(_deadline!)
                              : 'Set deadline (optional)',
                          style: TextStyle(
                            fontSize: 14,
                            color: _deadline != null
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                            fontWeight: _deadline != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_deadline != null)
                        GestureDetector(
                          onTap: () => setState(() => _deadline = null),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text('Estimated Duration',
                  style: tt.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: List.generate(_durOptions.length, (i) {
                  final sel = _estimatedMinutes == _durOptions[i];
                  return ChoiceChip(
                    label: Text(_durLabels[i]),
                    selected: sel,
                    onSelected: (_) =>
                        setState(() => _estimatedMinutes = _durOptions[i]),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                      color:
                          sel ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(
                        color: sel
                            ? cs.primary
                            : cs.outline.withValues(alpha: 0.3)),
                    visualDensity: VisualDensity.compact,
                  );
                }),
              ),
              const SizedBox(height: 14),

              Text('Priority',
                  style: tt.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                _tagChip('Normal', _priority == 'normal', Colors.grey,
                    onTap: () => setState(() => _priority = 'normal')),
                const SizedBox(width: 8),
                _tagChip('Important', _priority == 'important',
                    Colors.redAccent,
                    icon: Icons.priority_high_rounded,
                    onTap: () => setState(() => _priority = 'important')),
              ]),
              const SizedBox(height: 14),

              Text('Difficulty',
                  style: tt.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                _tagChip('Easy', _difficulty == 'easy', Colors.green,
                    onTap: () => setState(() => _difficulty = 'easy')),
                const SizedBox(width: 8),
                _tagChip('Medium', _difficulty == 'medium', Colors.orange,
                    onTap: () => setState(() => _difficulty = 'medium')),
                const SizedBox(width: 8),
                _tagChip('Difficult', _difficulty == 'difficult',
                    Colors.red,
                    onTap: () =>
                        setState(() => _difficulty = 'difficult')),
              ]),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity, height: r.h(52),
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(isNew
                      ? Icons.add_rounded
                      : Icons.save_rounded),
                  label: Text(
                    isNew ? 'Add Task' : 'Save Changes',
                    style: TextStyle(
                        fontSize: r.fs(16), fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(16))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

