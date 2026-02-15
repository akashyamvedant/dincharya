import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class CalendarWidget extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, Map<String, dynamic>> journalEntries;
  final Function(DateTime) onDateSelected;

  const CalendarWidget({
    super.key,
    required this.selectedDate,
    required this.journalEntries,
    required this.onDateSelected,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget>
    with SingleTickerProviderStateMixin {
  late DateTime _currentMonth;
  bool _isExpanded = false;
  late AnimationController _expandController;
  late ScrollController _weekScrollController;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _weekScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  @override
  void dispose() {
    _expandController.dispose();
    _weekScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate() {
    final dayOfMonth = widget.selectedDate.day;
    final scrollPosition = (dayOfMonth - 1) * 15.w;
    if (_weekScrollController.hasClients) {
      _weekScrollController.animateTo(
        scrollPosition.clamp(0.0, _weekScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  void _onDateTap(DateTime date) {
    HapticFeedback.selectionClick();
    widget.onDateSelected(date);
  }

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  bool _hasEntryForDate(DateTime date) {
    final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return widget.journalEntries.containsKey(key);
  }

  int _getMoodRatingForDate(DateTime date) {
    final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return widget.journalEntries[key]?['mood_rating'] as int? ?? 0;
  }

  Color _getMoodDotColor(int moodRating) {
    switch (moodRating) {
      case 1: return const Color(0xFF8B7355);
      case 2: return const Color(0xFFD4A574);
      case 3: return const Color(0xFF7CB342);
      case 4: return const Color(0xFFE67E22);
      case 5: return const Color(0xFFD35400);
      default: return const Color(0xFF7CB342);
    }
  }

  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  String _getShortMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    const warmBrown = Color(0xFF8B4513);
    const warmAmber = Color(0xFFD4A574);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            const Color(0xFFFFF8F0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: warmBrown.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          // Premium header with month + year
          _buildHeader(warmBrown, warmAmber),

          // Horizontal day strip
          _buildWeekStrip(warmBrown, warmAmber),

          // Expandable full calendar
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded ? _buildFullCalendar(warmBrown, warmAmber) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color warmBrown, Color warmAmber) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      child: Row(
        children: [
          // Previous month button
          _buildNavButton(Icons.chevron_left, _previousMonth, warmBrown),

          // Month / Year display + expand toggle
          Expanded(
            child: GestureDetector(
              onTap: _toggleExpand,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      warmBrown.withOpacity(0.08),
                      warmAmber.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: warmBrown.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                      style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                        color: warmBrown,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 1.5.w),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: warmBrown,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Next month button
          _buildNavButton(Icons.chevron_right, _nextMonth, warmBrown),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap, Color warmBrown) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: warmBrown.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: warmBrown.withOpacity(0.12),
          ),
        ),
        child: Icon(icon, color: warmBrown, size: 22),
      ),
    );
  }

  Widget _buildWeekStrip(Color warmBrown, Color warmAmber) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final days = List.generate(daysInMonth, (i) =>
      DateTime(_currentMonth.year, _currentMonth.month, i + 1)
    );

    return SizedBox(
      height: 10.5.h,
      child: ListView.builder(
        controller: _weekScrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
        itemCount: days.length,
        itemBuilder: (context, index) => _buildDayPill(days[index], warmBrown, warmAmber),
      ),
    );
  }

  Widget _buildDayPill(DateTime day, Color warmBrown, Color warmAmber) {
    final isSelected = day.day == widget.selectedDate.day &&
                       day.month == widget.selectedDate.month &&
                       day.year == widget.selectedDate.year;
    final isToday = day.day == DateTime.now().day &&
                    day.month == DateTime.now().month &&
                    day.year == DateTime.now().year;
    final hasEntry = _hasEntryForDate(day);
    final moodRating = _getMoodRatingForDate(day);

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[day.weekday - 1];

    return GestureDetector(
      onTap: () => _onDateTap(day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 13.w,
        margin: EdgeInsets.symmetric(horizontal: 0.8.w),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [warmBrown, warmAmber],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isSelected
              ? null
              : isToday
                  ? warmBrown.withOpacity(0.08)
                  : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isToday
                    ? warmBrown.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.12),
            width: isToday && !isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: warmBrown.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayName,
              style: TextStyle(
                fontSize: 11.sp,
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey[500],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 0.3.h),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14.sp,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            SizedBox(height: 0.3.h),
            // Mood dot indicator
            if (hasEntry)
              Container(
                width: 2.w,
                height: 2.w,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : _getMoodDotColor(moodRating),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isSelected
                              ? Colors.white
                              : _getMoodDotColor(moodRating))
                          .withOpacity(0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              )
            else
              SizedBox(width: 2.w, height: 2.w),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCalendar(Color warmBrown, Color warmAmber) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday;

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: EdgeInsets.all(3.w),
      child: Column(
        children: [
          // Day labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dayLabels.map((day) => SizedBox(
              width: 10.w,
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: warmBrown.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )).toList(),
          ),
          SizedBox(height: 1.h),

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayNumber = index - startingWeekday + 2;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final day = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
              final isSelected = day.day == widget.selectedDate.day &&
                                 day.month == widget.selectedDate.month &&
                                 day.year == widget.selectedDate.year;
              final isToday = day.day == DateTime.now().day &&
                              day.month == DateTime.now().month &&
                              day.year == DateTime.now().year;
              final hasEntry = _hasEntryForDate(day);
              final moodRating = _getMoodRatingForDate(day);

              return GestureDetector(
                onTap: () => _onDateTap(day),
                child: Container(
                  margin: EdgeInsets.all(0.5.w),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [warmBrown, warmAmber])
                        : null,
                    color: isSelected
                        ? null
                        : isToday
                            ? warmBrown.withOpacity(0.08)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected
                        ? Border.all(color: warmBrown, width: 1.5)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isSelected ? Colors.white : Colors.grey[800],
                          fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      if (hasEntry)
                        Positioned(
                          bottom: 0.3.h,
                          child: Container(
                            width: 1.5.w,
                            height: 1.5.w,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : _getMoodDotColor(moodRating),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
