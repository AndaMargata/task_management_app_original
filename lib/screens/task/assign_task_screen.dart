import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../models/chat_user.dart';
import '../../utils/responsive.dart';

class AssignTaskScreen extends StatefulWidget {
  const AssignTaskScreen({super.key});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  ChatUser? _selectedUser;
  List<ChatUser> _users = [];
  bool _loadingUsers = true;
  bool _submitting = false;

  DateTime? _deadline;
  int? _estimatedMinutes;
  String _priority = 'normal';
  String _difficulty = 'easy';

  static const _durationOptions = <int?>[
    null, 15, 30, 60, 120, 240, 480,
  ];
  static const _durationLabels = <String>[
    'None', '15m', '30m', '1h', '2h', '4h', '8h',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await context.read<ChatViewmodel>().listAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? now),
    );
    setState(() {
      _deadline = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  Future<void> _assignTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a user')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<TaskViewmodel>().assignTask(
            taskTitle: _titleCtrl.text.trim(),
            taskDescription: _descCtrl.text.trim(),
            assignee: _selectedUser!,
            deadline: _deadline,
            estimatedMinutes: _estimatedMinutes,
            priority: _priority,
            difficulty: _difficulty,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Task assigned to ${_selectedUser!.fullName}')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        title: Text('Assign Task',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(24)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign to',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_loadingUsers)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ))
              else if (_users.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('No users found',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.error)),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _selectedUser != null
                            ? cs.primary
                            : cs.outline.withValues(alpha: 0.3)),
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final selected = _selectedUser?.uid == user.uid;
                        final initial = user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?';
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor:
                              cs.primaryContainer.withValues(alpha: 0.3),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: selected
                                ? cs.primary
                                : cs.primaryContainer,
                            foregroundColor: selected
                                ? cs.onPrimary
                                : cs.onPrimaryContainer,
                            child: Text(initial,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          title: Text(user.fullName,
                              style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500)),
                          subtitle: Text(user.email,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant)),
                          trailing: selected
                              ? Icon(Icons.check_circle,
                                  color: cs.primary)
                              : null,
                          onTap: () =>
                              setState(() => _selectedUser = user),
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              Text('Task Details',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                minLines: 2,
                maxLines: 4,
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),

              const SizedBox(height: 20),

              Text('Deadline',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickDeadline,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          color: cs.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _deadline != null
                              ? DateFormat('MMM d, yyyy – h:mm a')
                                  .format(_deadline!)
                              : 'Tap to set deadline',
                          style: TextStyle(
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
                              size: 20, color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text('Estimated Duration',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_durationOptions.length, (i) {
                  final selected =
                      _estimatedMinutes == _durationOptions[i];
                  return ChoiceChip(
                    label: Text(_durationLabels[i]),
                    selected: selected,
                    onSelected: (_) => setState(
                        () => _estimatedMinutes = _durationOptions[i]),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w500,
                      color: selected
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(
                        color: selected
                            ? cs.primary
                            : cs.outline.withValues(alpha: 0.3)),
                  );
                }),
              ),

              const SizedBox(height: 20),

              Text('Priority',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTagChip(
                    label: 'Normal',
                    selected: _priority == 'normal',
                    color: Colors.grey,
                    onTap: () => setState(() => _priority = 'normal'),
                  ),
                  const SizedBox(width: 10),
                  _buildTagChip(
                    label: 'Important',
                    selected: _priority == 'important',
                    color: Colors.redAccent,
                    icon: Icons.priority_high_rounded,
                    onTap: () => setState(() => _priority = 'important'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text('Difficulty',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTagChip(
                    label: 'Easy',
                    selected: _difficulty == 'easy',
                    color: Colors.green,
                    onTap: () => setState(() => _difficulty = 'easy'),
                  ),
                  const SizedBox(width: 10),
                  _buildTagChip(
                    label: 'Medium',
                    selected: _difficulty == 'medium',
                    color: Colors.orange,
                    onTap: () => setState(() => _difficulty = 'medium'),
                  ),
                  const SizedBox(width: 10),
                  _buildTagChip(
                    label: 'Difficult',
                    selected: _difficulty == 'difficult',
                    color: Colors.red,
                    onTap: () => setState(() => _difficulty = 'difficult'),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: r.h(52),
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _assignTask,
                  icon: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.assignment_ind_rounded),
                  label: Text('Assign Task',
                      style: TextStyle(
                          fontSize: r.fs(16), fontWeight: FontWeight.w600)),
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

  Widget _buildTagChip({
    required String label,
    required bool selected,
    required Color color,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3),
              width: selected ? 1.8 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
