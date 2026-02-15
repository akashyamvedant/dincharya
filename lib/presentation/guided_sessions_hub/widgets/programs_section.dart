import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/guided_session_service.dart';
import 'program_card_widget.dart';

/// Horizontal scrollable section of curated programs
class ProgramsSection extends StatefulWidget {
  final VoidCallback? onProgramTap;

  const ProgramsSection({super.key, this.onProgramTap});

  @override
  State<ProgramsSection> createState() => _ProgramsSectionState();
}

class _ProgramsSectionState extends State<ProgramsSection> {
  final GuidedSessionService _service = GuidedSessionService();
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _enrollments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      final results = await Future.wait([
        _service.getPrograms(),
        _service.getEnrolledPrograms(),
      ]);
      if (mounted) {
        setState(() {
          _programs = results[0];
          _enrollments = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _getEnrollment(String programId) {
    try {
      return _enrollments.firstWhere(
        (e) => e['program_id'] == programId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleProgramTap(Map<String, dynamic> program) async {
    final programId = program['id']?.toString() ?? '';
    if (programId.isEmpty) return;

    final enrollment = _getEnrollment(programId);

    if (enrollment == null) {
      // Show enrollment confirmation
      final shouldEnroll = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            program['title'] ?? 'Program',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                program['description'] ?? '',
                style: TextStyle(color: Colors.grey[700], height: 1.4),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Icon(Icons.play_circle_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${program['total_sessions'] ?? 0} sessions over ${program['duration_days'] ?? 7} days',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Start Program'),
            ),
          ],
        ),
      );

      if (shouldEnroll == true) {
        await _service.enrollInProgram(programId);
        await _loadPrograms(); // Refresh
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Enrolled in ${program['title']}! 🎉'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Navigate to program detail
          final enrollment = _getEnrollment(programId);
          Navigator.pushNamed(
            context,
            '/program-detail',
            arguments: {'program': program, 'enrollment': enrollment},
          );
        }
      }
    } else {
      // Already enrolled — open program detail
      final result = await Navigator.pushNamed(
        context,
        '/program-detail',
        arguments: {'program': program, 'enrollment': enrollment},
      );
      // Refresh on return
      _loadPrograms();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 1.h),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_programs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              const Text(
                '📚',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Programs & Courses',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1810),
                ),
              ),
              const Spacer(),
              if (_enrollments.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_enrollments.length} active',
                    style: const TextStyle(
                      color: Color(0xFF8B4513),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 1.h),

        // Horizontal program cards
        SizedBox(
          height: 28.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            itemCount: _programs.length,
            itemBuilder: (context, index) {
              final program = _programs[index];
              final programId = program['id']?.toString() ?? '';

              return ProgramCardWidget(
                program: program,
                enrollment: _getEnrollment(programId),
                onTap: () => _handleProgramTap(program),
              );
            },
          ),
        ),
        SizedBox(height: 1.h),
      ],
    );
  }
}
