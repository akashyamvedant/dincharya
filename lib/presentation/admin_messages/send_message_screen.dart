// lib/presentation/admin_messages/send_message_screen.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';

import '../../services/admin_message_service.dart';

class SendMessageScreen extends StatefulWidget {
  const SendMessageScreen({super.key});

  @override
  State<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends State<SendMessageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminMessageService _service = AdminMessageService();

  /// When set, the Compose tab pre-fills from this data (edit mode).
  Map<String, dynamic>? _editingMessage;

  /// Key to trigger History tab refresh from Compose tab.
  final GlobalKey<_HistoryTabState> _historyKey = GlobalKey<_HistoryTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Called from History tab to load a message into the Compose tab for editing.
  void _startEditing(Map<String, dynamic> message) {
    setState(() => _editingMessage = Map<String, dynamic>.from(message));
    _tabController.animateTo(0); // Switch to Compose tab
  }

  /// Called after Compose tab saves — refresh History data.
  void _onComposeSaved() {
    _historyKey.currentState?._loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('📣 Admin Messages'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Compose'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ComposeTab(
            service: _service,
            editingMessage: _editingMessage,
            onEditComplete: () => setState(() => _editingMessage = null),
            onSaved: _onComposeSaved,
          ),
          _HistoryTab(
            key: _historyKey,
            service: _service,
            onEdit: _startEditing,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMPOSE TAB — with trigger pages, starts_at, max_impressions, action_label
// ============================================================
class _ComposeTab extends StatefulWidget {
  final AdminMessageService service;
  final Map<String, dynamic>? editingMessage;
  final VoidCallback onEditComplete;
  final VoidCallback onSaved;

  const _ComposeTab({
    required this.service,
    this.editingMessage,
    required this.onEditComplete,
    required this.onSaved,
  });

  @override
  State<_ComposeTab> createState() => _ComposeTabState();
}

class _ComposeTabState extends State<_ComposeTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _titleHindiController = TextEditingController();
  final _bodyHindiController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _actionValueController = TextEditingController();
  final _actionLabelController = TextEditingController();

  String _type = 'popup';
  String _actionType = 'none';
  String _targetAudience = 'all';
  int _priority = 5;
  bool _showOnce = true;
  bool _hasExpiry = false;
  DateTime? _expiresAt;
  bool _isSending = false;

  // ── NEW FIELDS ──
  Set<String> _selectedPages = {'dashboard'}; // default
  int _maxImpressions = 1;
  bool _hasStartDate = false;
  DateTime? _startsAt;

  // Track if we're editing vs creating
  String? _editingId;
  bool _editingIsActive = true; // preserve original active state during edit

  static const Map<String, String> _pageLabels = {
    'dashboard': '🏠 Dashboard',
    'guided': '🧘 Guided',
    'journal': '📓 Journal',
    'profile': '👤 Profile',
    'payment': '💳 Payment',
  };

  static const Map<int, String> _impressionLabels = {
    1: '1 time',
    2: '2 times',
    3: '3 times',
    5: '5 times',
    0: 'Unlimited',
  };

  @override
  void didUpdateWidget(covariant _ComposeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != null &&
        widget.editingMessage != oldWidget.editingMessage) {
      _loadMessageForEditing(widget.editingMessage!);
    }
  }

  void _loadMessageForEditing(Map<String, dynamic> msg) {
    _editingId = msg['id'];
    _editingIsActive = msg['is_active'] == true;
    _titleController.text = msg['title'] ?? '';
    _bodyController.text = msg['body'] ?? '';
    _titleHindiController.text = msg['title_hindi'] ?? '';
    _bodyHindiController.text = msg['body_hindi'] ?? '';
    _imageUrlController.text = msg['image_url'] ?? '';
    _actionValueController.text = msg['action_value'] ?? '';
    _actionLabelController.text = msg['action_label'] ?? '';

    // Parse trigger pages
    final rawPages = msg['trigger_pages'];
    if (rawPages is List) {
      _selectedPages = rawPages.map((e) => e.toString()).toSet();
    } else if (rawPages is String) {
      _selectedPages = rawPages
          .replaceAll('{', '')
          .replaceAll('}', '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    if (_selectedPages.isEmpty) _selectedPages = {'dashboard'};

    setState(() {
      _type = msg['type'] ?? 'popup';
      _actionType = msg['action_type'] ?? 'none';
      _targetAudience = msg['target_audience'] ?? 'all';
      _priority = msg['priority'] ?? 5;
      _showOnce = msg['show_once'] ?? true;
      _maxImpressions = msg['max_impressions'] ?? 1;

      // Expiry
      final expiresStr = msg['expires_at'];
      if (expiresStr != null) {
        _hasExpiry = true;
        _expiresAt = DateTime.tryParse(expiresStr);
      } else {
        _hasExpiry = false;
        _expiresAt = null;
      }

      // Start date
      final startsStr = msg['starts_at'];
      if (startsStr != null) {
        _hasStartDate = true;
        _startsAt = DateTime.tryParse(startsStr);
      } else {
        _hasStartDate = false;
        _startsAt = null;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleHindiController.dispose();
    _bodyHindiController.dispose();
    _imageUrlController.dispose();
    _actionValueController.dispose();
    _actionLabelController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one target page'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSending = true);

    final data = {
      'title': _titleController.text.trim(),
      'body': _bodyController.text.trim(),
      'title_hindi': _titleHindiController.text.trim().isEmpty
          ? null
          : _titleHindiController.text.trim(),
      'body_hindi': _bodyHindiController.text.trim().isEmpty
          ? null
          : _bodyHindiController.text.trim(),
      'type': _type,
      'image_url': _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      'action_type': _actionType,
      'action_value': _actionValueController.text.trim().isEmpty
          ? null
          : _actionValueController.text.trim(),
      'action_label': _actionLabelController.text.trim().isEmpty
          ? null
          : _actionLabelController.text.trim(),
      'target_audience': _targetAudience,
      'priority': _priority,
      'show_once': _showOnce,
      'is_active': _editingId != null ? _editingIsActive : true,
      'trigger_pages': _selectedPages.toList(),
      'max_impressions': _maxImpressions,
      'expires_at': _hasExpiry && _expiresAt != null
          ? _expiresAt!.toUtc().toIso8601String()
          : null,
      'starts_at': _hasStartDate && _startsAt != null
          ? _startsAt!.toUtc().toIso8601String()
          : null,
    };

    bool success;
    if (_editingId != null) {
      // Update existing message
      success = await widget.service.updateMessage(_editingId!, data);
    } else {
      // Create new message
      success = await widget.service.createMessage(data);
    }

    setState(() => _isSending = false);

    if (success && mounted) {
      widget.onSaved(); // Refresh History tab
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(_editingId != null ? 'Message updated! ✅' : 'Message sent! 🎉'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _resetForm();
      widget.onEditComplete();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Operation failed ❌'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _resetForm() {
    _titleController.clear();
    _bodyController.clear();
    _titleHindiController.clear();
    _bodyHindiController.clear();
    _imageUrlController.clear();
    _actionValueController.clear();
    _actionLabelController.clear();
    setState(() {
      _editingId = null;
      _editingIsActive = true;
      _type = 'popup';
      _actionType = 'none';
      _targetAudience = 'all';
      _priority = 5;
      _showOnce = true;
      _hasExpiry = false;
      _expiresAt = null;
      _selectedPages = {'dashboard'};
      _maxImpressions = 1;
      _hasStartDate = false;
      _startsAt = null;
    });
  }

  void _previewMessage() {
    final previewData = {
      'id': 'preview',
      'title': _titleController.text.trim().isEmpty
          ? 'Preview Title'
          : _titleController.text.trim(),
      'body': _bodyController.text.trim().isEmpty
          ? 'Preview body content'
          : _bodyController.text.trim(),
      'type': _type,
      'image_url': _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      'action_type': _actionType,
      'action_value': _actionValueController.text.trim(),
      'action_label': _actionLabelController.text.trim(),
    };

    switch (_type) {
      case 'banner':
        final overlay = Overlay.of(context);
        late OverlayEntry entry;
        entry = OverlayEntry(
          builder: (ctx) => Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: EdgeInsets.all(3.w),
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.campaign, color: Theme.of(context).colorScheme.primary),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(previewData['title'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(previewData['body'] as String, style: TextStyle(fontSize: 13.sp, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    GestureDetector(onTap: () => entry.remove(), child: const Icon(Icons.close, size: 20)),
                  ],
                ),
              ),
            ),
          ),
        );
        overlay.insert(entry);
        Future.delayed(const Duration(seconds: 4), () {
          if (entry.mounted) entry.remove();
        });
        break;

      case 'bottomsheet':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _buildPreviewBottomSheet(ctx, previewData),
        );
        break;

      case 'popup':
      default:
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (ctx, a1, a2) => const SizedBox(),
          transitionBuilder: (ctx, a1, a2, child) {
            return ScaleTransition(
              scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
              child: FadeTransition(
                opacity: a1,
                child: _buildPreviewPopup(ctx, previewData),
              ),
            );
          },
        );
        break;
    }
  }

  Widget _buildPreviewPopup(BuildContext context, Map<String, dynamic> data) {
    return Center(
      child: Container(
        width: 85.w,
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('👁️ PREVIEW', style: TextStyle(fontSize: 12.sp, color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 2.h),
              Text(data['title'] as String, style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              SizedBox(height: 1.h),
              Text(data['body'] as String, style: TextStyle(fontSize: 15.sp, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)), textAlign: TextAlign.center),
              if ((data['action_label'] as String?)?.isNotEmpty == true) ...[
                SizedBox(height: 2.h),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(data['action_label'] as String),
                ),
              ],
              SizedBox(height: 1.h),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close Preview')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBottomSheet(BuildContext context, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.all(5.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 1.h),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('👁️ PREVIEW', style: TextStyle(fontSize: 12.sp, color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: 2.h),
          Text(data['title'] as String, style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          SizedBox(height: 1.h),
          Text(data['body'] as String, style: TextStyle(fontSize: 15.sp, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)), textAlign: TextAlign.center),
          SizedBox(height: 3.h),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close Preview')),
          SizedBox(height: 2.h),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(4.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Edit mode banner ──
            if (_editingId != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.amber, size: 20),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Editing campaign — changes apply immediately',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: Colors.amber.shade800),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _resetForm();
                        widget.onEditComplete();
                      },
                      child: Icon(Icons.close, size: 18, color: Colors.amber.shade800),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
            ],

            // ── English Content ──
            _buildSectionHeader('📝 Message Content (English)', 'Required'),
            SizedBox(height: 1.h),
            _buildTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'e.g., New Feature Update!',
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
              maxLines: 1,
            ),
            SizedBox(height: 1.5.h),
            _buildTextField(
              controller: _bodyController,
              label: 'Body',
              hint: 'Write your message here...',
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Body is required' : null,
              maxLines: 4,
            ),

            SizedBox(height: 2.5.h),

            // ── Hindi Content ──
            _buildSectionHeader('🇮🇳 Hindi Content', 'Optional'),
            SizedBox(height: 1.h),
            _buildTextField(controller: _titleHindiController, label: 'Title (Hindi)', hint: 'e.g., नया फीचर अपडेट!', maxLines: 1),
            SizedBox(height: 1.5.h),
            _buildTextField(controller: _bodyHindiController, label: 'Body (Hindi)', hint: 'हिंदी में संदेश लिखें...', maxLines: 3),

            SizedBox(height: 2.5.h),

            // ── Display Type ──
            _buildSectionHeader('🎨 Display Type', ''),
            SizedBox(height: 1.h),
            _buildChipSelector<String>(
              options: const {'popup': '💬 Popup', 'banner': '📢 Banner', 'bottomsheet': '📋 Bottom Sheet'},
              selected: _type,
              onSelected: (v) => setState(() => _type = v),
            ),

            SizedBox(height: 2.5.h),

            // ══════════════════════════════════════════════════════
            // ── NEW: Target Pages (Multi-select chips) ──
            // ══════════════════════════════════════════════════════
            _buildSectionHeader('📍 Target Pages', '${_selectedPages.length} selected'),
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: _pageLabels.entries.map((e) {
                final isSelected = _selectedPages.contains(e.key);
                return FilterChip(
                  label: Text(e.value, style: TextStyle(fontSize: 13.sp)),
                  selected: isSelected,
                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  checkmarkColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPages.add(e.key);
                      } else {
                        _selectedPages.remove(e.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            SizedBox(height: 2.5.h),

            // ══════════════════════════════════════════════════════
            // ── NEW: Max Impressions (Dropdown) ──
            // ══════════════════════════════════════════════════════
            _buildSectionHeader('👁️ Max Impressions', _impressionLabels[_maxImpressions] ?? ''),
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _maxImpressions,
                  isExpanded: true,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  style: TextStyle(fontSize: 15.sp, color: Theme.of(context).colorScheme.onSurface),
                  items: _impressionLabels.entries.map((e) {
                    return DropdownMenuItem(value: e.key, child: Text(e.value));
                  }).toList(),
                  onChanged: (v) => setState(() => _maxImpressions = v ?? 1),
                ),
              ),
            ),

            SizedBox(height: 2.5.h),

            // ── Image URL ──
            _buildSectionHeader('🖼️ Image', 'Optional'),
            SizedBox(height: 1.h),
            _buildTextField(controller: _imageUrlController, label: 'Image URL', hint: 'https://example.com/image.png', maxLines: 1),

            SizedBox(height: 2.5.h),

            // ── Action ──
            _buildSectionHeader('🔗 Action Button', ''),
            SizedBox(height: 1.h),
            _buildChipSelector<String>(
              options: const {
                'none': '❌ None',
                'url': '🔗 URL',
                'route': '📱 App Route',
                'premium': '⭐ Premium',
              },
              selected: _actionType,
              onSelected: (v) => setState(() => _actionType = v),
            ),
            if (_actionType == 'url' || _actionType == 'route') ...[
              SizedBox(height: 1.5.h),
              _buildTextField(
                controller: _actionValueController,
                label: _actionType == 'url' ? 'URL' : 'Route Name',
                hint: _actionType == 'url' ? 'https://play.google.com/...' : '/guided-sessions-hub',
                maxLines: 1,
              ),
            ],
            if (_actionType != 'none') ...[
              SizedBox(height: 1.5.h),
              _buildTextField(
                controller: _actionLabelController,
                label: 'Button Label',
                hint: 'e.g., Upgrade Now, Learn More, Open App',
                maxLines: 1,
              ),
            ],

            SizedBox(height: 2.5.h),

            // ── Target Audience ──
            _buildSectionHeader('🎯 Target Audience', ''),
            SizedBox(height: 1.h),
            _buildChipSelector<String>(
              options: const {
                'all': '👥 All Users',
                'free': '🆓 Free Only',
                'premium': '⭐ Premium Only',
                'new_users': '🆕 New Users',
              },
              selected: _targetAudience,
              onSelected: (v) => setState(() => _targetAudience = v),
            ),

            SizedBox(height: 2.5.h),

            // ── Priority ──
            _buildSectionHeader('⚡ Priority', '$_priority/10'),
            Slider(
              value: _priority.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: _priority.toString(),
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => setState(() => _priority = v.round()),
            ),

            // ── Show Once ──
            SwitchListTile(
              title: Text('Show Once', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500)),
              subtitle: Text('Message disappears after user sees it', style: TextStyle(fontSize: 13.sp)),
              value: _showOnce,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => setState(() => _showOnce = v),
              contentPadding: EdgeInsets.zero,
            ),

            // ══════════════════════════════════════════════════════
            // ── NEW: Start Date ──
            // ══════════════════════════════════════════════════════
            SwitchListTile(
              title: Text('Schedule Start Date', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500)),
              subtitle: Text(
                _hasStartDate && _startsAt != null
                    ? 'Starts: ${DateFormat('dd MMM yyyy, hh:mm a').format(_startsAt!)}'
                    : 'Campaign starts immediately',
                style: TextStyle(fontSize: 13.sp),
              ),
              value: _hasStartDate,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) async {
                if (v) {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null && mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    setState(() {
                      _hasStartDate = true;
                      _startsAt = DateTime(date.year, date.month, date.day, time?.hour ?? 9, time?.minute ?? 0);
                    });
                  }
                } else {
                  setState(() {
                    _hasStartDate = false;
                    _startsAt = null;
                  });
                }
              },
              contentPadding: EdgeInsets.zero,
            ),

            // ── Expiry ──
            SwitchListTile(
              title: Text('Set Expiry Date', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500)),
              subtitle: Text(
                _hasExpiry && _expiresAt != null
                    ? 'Expires: ${DateFormat('dd MMM yyyy, hh:mm a').format(_expiresAt!)}'
                    : 'Message will stay forever',
                style: TextStyle(fontSize: 13.sp),
              ),
              value: _hasExpiry,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) async {
                if (v) {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null && mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 23, minute: 59),
                    );
                    setState(() {
                      _hasExpiry = true;
                      _expiresAt = DateTime(date.year, date.month, date.day, time?.hour ?? 23, time?.minute ?? 59);
                    });
                  }
                } else {
                  setState(() {
                    _hasExpiry = false;
                    _expiresAt = null;
                  });
                }
              },
              contentPadding: EdgeInsets.zero,
            ),

            SizedBox(height: 3.h),

            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _previewMessage,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_editingId != null ? Icons.save : Icons.send),
                    label: Text(_isSending
                        ? 'Saving...'
                        : _editingId != null
                            ? 'Update Campaign'
                            : 'Send Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        if (trailing.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(trailing, style: TextStyle(fontSize: 12.sp, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(fontSize: 15.sp, color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      ),
    );
  }

  Widget _buildChipSelector<T>({
    required Map<T, String> options,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 2.w,
      runSpacing: 1.h,
      children: options.entries.map((e) {
        final isSelected = e.key == selected;
        return ChoiceChip(
          label: Text(e.value, style: TextStyle(fontSize: 13.sp)),
          selected: isSelected,
          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          checkmarkColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surface,
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          onSelected: (_) => onSelected(e.key),
        );
      }).toList(),
    );
  }
}

// ============================================================
// HISTORY TAB — with Edit, Duplicate, trigger page badges
// ============================================================
class _HistoryTab extends StatefulWidget {
  final AdminMessageService service;
  final ValueChanged<Map<String, dynamic>> onEdit;

  const _HistoryTab({super.key, required this.service, required this.onEdit});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final messages = await widget.service.getAllMessages();
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 60, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            SizedBox(height: 2.h),
            Text('No messages yet', style: TextStyle(fontSize: 15.sp, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            SizedBox(height: 1.h),
            Text('Compose a message to get started', style: TextStyle(fontSize: 14.sp, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: _messages.length,
        itemBuilder: (_, i) => _buildMessageCard(_messages[i]),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> msg) {
    final isActive = msg['is_active'] == true;
    final readCount = msg['read_count'] ?? 0;
    final actionCount = msg['action_count'] ?? 0;
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');
    final expiresAt = msg['expires_at'] != null ? DateTime.tryParse(msg['expires_at']) : null;
    final startsAt = msg['starts_at'] != null ? DateTime.tryParse(msg['starts_at']) : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final isScheduled = startsAt != null && startsAt.isAfter(DateTime.now());
    final maxImpressions = msg['max_impressions'] ?? 1;

    // Parse trigger pages
    final rawPages = msg['trigger_pages'];
    List<String> triggerPages = ['dashboard'];
    if (rawPages is List) {
      triggerPages = rawPages.map((e) => e.toString()).toList();
    } else if (rawPages is String) {
      triggerPages = rawPages.replaceAll('{', '').replaceAll('}', '').split(',').map((e) => e.trim()).toList();
    }

    final typeIcons = {'popup': '💬', 'banner': '📢', 'bottomsheet': '📋'};

    // Page emoji map
    const pageEmoji = {
      'dashboard': '🏠',
      'guided': '🧘',
      'journal': '📓',
      'profile': '👤',
      'payment': '💳',
    };

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive && !isExpired && !isScheduled
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: isActive && !isExpired
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(typeIcons[msg['type']] ?? '💬', style: const TextStyle(fontSize: 20)),
                SizedBox(width: 2.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          color: isActive && !isExpired
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          if (createdAt != null)
                            Text(
                              DateFormat('dd MMM, HH:mm').format(createdAt.toLocal()),
                              style: TextStyle(fontSize: 12.sp, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red.withOpacity(0.1)
                        : isScheduled
                            ? Colors.blue.withOpacity(0.1)
                            : isActive
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isExpired
                        ? 'Expired'
                        : isScheduled
                            ? 'Scheduled'
                            : isActive
                                ? 'Active'
                                : 'Paused',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isExpired
                          ? Colors.red
                          : isScheduled
                              ? Colors.blue
                              : isActive
                                  ? Colors.green
                                  : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body preview
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            child: Text(
              msg['body'] ?? '',
              style: TextStyle(fontSize: 14.sp, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Trigger page badges + impressions ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            child: Row(
              children: [
                // Page badges
                ...triggerPages.take(5).map((p) => Padding(
                      padding: EdgeInsets.only(right: 1.w),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${pageEmoji[p] ?? '📄'} $p',
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    )),
                const Spacer(),
                // Max impressions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    maxImpressions == 0 ? '∞ imp' : '${maxImpressions}x imp',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: Colors.purple),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 0.5.h),

          // Stats + action row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            child: Row(
              children: [
                _buildStatChip(Icons.visibility, '$readCount reads', Colors.blue),
                SizedBox(width: 2.w),
                _buildStatChip(Icons.touch_app, '$actionCount clicks', Colors.green),
                SizedBox(width: 2.w),
                _buildStatChip(Icons.priority_high, 'P${msg['priority'] ?? 5}', Colors.orange),
                const Spacer(),

                // Edit button
                IconButton(
                  onPressed: () => widget.onEdit(msg),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: Theme.of(context).colorScheme.primary,
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),

                // Duplicate button
                IconButton(
                  onPressed: () async {
                    final success = await widget.service.duplicateMessage(msg['id']);
                    if (success) {
                      _loadMessages();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Campaign duplicated (paused) ✅'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  color: Colors.teal,
                  tooltip: 'Duplicate',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),

                // Toggle active
                IconButton(
                  onPressed: () async {
                    final success = await widget.service.toggleActive(msg['id'], !isActive);
                    if (success) _loadMessages();
                  },
                  icon: Icon(isActive ? Icons.pause_circle : Icons.play_circle, size: 22),
                  color: isActive ? Colors.orange : Colors.green,
                  tooltip: isActive ? 'Pause' : 'Activate',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),

                // Delete
                IconButton(
                  onPressed: () => _confirmDelete(msg['id']),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red,
                  tooltip: 'Delete',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 1.w),
          Text(text, style: TextStyle(fontSize: 12.sp, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _confirmDelete(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This will permanently delete this message and all read receipts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await widget.service.deleteMessage(messageId);
              if (success) _loadMessages();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
