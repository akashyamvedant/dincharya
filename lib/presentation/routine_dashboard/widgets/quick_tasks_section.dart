// lib/presentation/routine_dashboard/widgets/quick_tasks_section.dart
// Collapsible card showing local-only quick tasks.
// No Supabase — purely device-local via QuickTaskService.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../services/quick_task_service.dart';

class QuickTasksSection extends StatefulWidget {
  const QuickTasksSection({super.key});

  @override
  State<QuickTasksSection> createState() => _QuickTasksSectionState();
}

class _QuickTasksSectionState extends State<QuickTasksSection> {
  final QuickTaskService _service = QuickTaskService();
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();
  List<QuickTask> _tasks = [];
  bool _isExpanded = true;
  bool _isAdding = false;
  bool _isSubmitting = false; // Guard against rapid double-submit

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final tasks = await _service.getTasks();
    if (mounted) setState(() => _tasks = tasks);
  }

  Future<void> _addTask() async {
    final title = _addController.text.trim();
    if (title.isEmpty || _isSubmitting) return;

    _isSubmitting = true;
    await _service.addTask(title);
    _addController.clear();
    await _loadTasks();
    _isSubmitting = false;

    // Keep focus for rapid entry
    _addFocusNode.requestFocus();
  }

  Future<void> _toggleComplete(String id) async {
    await _service.toggleComplete(id);
    await _loadTasks();
  }

  Future<void> _deleteTask(String id) async {
    await _service.deleteTask(id);
    await _loadTasks();
  }

  Future<void> _clearCompleted() async {
    await _service.clearCompleted();
    await _loadTasks();
  }

  int get _completedCount => _tasks.where((t) => t.isCompleted).length;
  int get _totalCount => _tasks.length;

  @override
  Widget build(BuildContext context) {
    // Don't show section if no tasks and not actively adding
    if (_tasks.isEmpty && !_isAdding) {
      return _buildEmptyState();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header — tap to expand/collapse
          _buildHeader(),

          // Content
          if (_isExpanded) ...[
            const Divider(height: 1, color: Color(0x33E8D5C4)),

            // Task list
            ..._buildTaskList(),

            // Add task inline
            _buildInlineAdd(),

            // Clear completed button
            if (_completedCount > 0) _buildClearCompletedButton(),

            SizedBox(height: 0.5.h),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isAdding = true;
            _isExpanded = true;
          });
          Future.delayed(const Duration(milliseconds: 200), () {
            _addFocusNode.requestFocus();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.add_task,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: 3.w),
              Text(
                'Add a quick task...',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.push_pin_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ),
            SizedBox(width: 2.5.w),
            Text(
              'Quick Tasks',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(width: 2.w),
            if (_totalCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _completedCount == _totalCount
                      ? const Color(0xFF43A047).withOpacity(0.12)
                      : const Color(0xFF8B6914).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_completedCount/$_totalCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _completedCount == _totalCount
                        ? const Color(0xFF43A047)
                        : const Color(0xFF8B6914),
                  ),
                ),
              ),
            const Spacer(),
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTaskList() {
    // Show incomplete first, then completed
    final sorted = List<QuickTask>.from(_tasks);
    sorted.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return a.createdAt.compareTo(b.createdAt);
    });

    return sorted.map((task) => _buildTaskItem(task)).toList();
  }

  Widget _buildTaskItem(QuickTask task) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Quick haptic-style confirmation — allow dismiss
        return true;
      },
      onDismissed: (_) => _deleteTask(task.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 5.w),
        decoration: const BoxDecoration(
          color: Color(0xFFFFEBEE),
          borderRadius: BorderRadius.zero,
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Color(0xFFE53935),
          size: 22,
        ),
      ),
      child: GestureDetector(
        onTap: () => _toggleComplete(task.id),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
          child: Row(
            children: [
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? const Color(0xFF43A047)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: task.isCompleted
                        ? const Color(0xFF43A047)
                        : Theme.of(context).colorScheme.outline,
                    width: 1.5,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              SizedBox(width: 3.w),
              // Title
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: task.isCompleted
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Time ago
              Text(
                _timeAgo(task.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineAdd() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Row(
        children: [
          // Plus icon
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: Icon(
              Icons.add,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: 3.w),
          // Text field
          Expanded(
            child: TextField(
              controller: _addController,
              focusNode: _addFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addTask(),
              onTap: () {
                setState(() => _isAdding = true);
              },
              cursorColor: const Color(0xFF8B6914),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Add a quick task...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          // Send button (visible when typing)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _addController,
            builder: (context, value, _) {
              if (value.text.trim().isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: _addTask,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClearCompletedButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: GestureDetector(
        onTap: _clearCompleted,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 0.8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cleaning_services_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: 6),
              Text(
                'Clear $_completedCount completed',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
